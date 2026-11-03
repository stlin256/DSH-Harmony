import { randomUUID } from 'node:crypto';
import WebSocket, { WebSocketServer } from 'ws';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import {
  normalizeFollow,
  normalizePermissionCatalog,
  normalizePermissionPreset,
  normalizePermissionSelection,
  normalizePlanProjection,
  normalizeProjectionTitle,
  normalizeQueuedState,
  normalizeSubagentAddress,
  normalizeSubagentCatalog,
  normalizeSubagentIdentity,
  normalizeSubagentTiming,
  normalizedHistory,
  queueFromInbox,
  sessionIdValid
} from './native-protocol.mjs';
import {
  automationCreateRequest,
  automationEditRequest,
  automationHistoryRequest,
  automationTaskId,
  normalizeAutomationCatalog,
  normalizeAutomationHistory,
  normalizeAutomationTask,
  normalizePluginChange,
  normalizePluginInspection,
  normalizePluginInventory,
  normalizePluginVersions,
  pluginSpec
} from './native-admin-protocol.mjs';

export function nativeHeartbeatPolicy(profile = 'foreground') {
  return profile === 'background' ?
    { intervalMs: 15000, deadlineMs: 45000, openingMs: 45000 } :
    { intervalMs: 5000, deadlineMs: 20000, openingMs: 30000 };
}

export function nativeHeartbeatPayload(generation, active, stateKnown, running, waiting) {
  return {
    type: 'heartbeat',
    generation,
    cursor: active.cursor,
    attemptId: active.attemptId,
    nextIndex: active.nextIndex,
    revision: active.revision,
    stateKnown: stateKnown === true,
    running: running === true,
    waiting: waiting === true
  };
}

export function nativeDeliveryDrainReady(paused, bufferedAmount, lowWater, upstreamOpen) {
  return paused === true && Number.isFinite(bufferedAmount) &&
    bufferedAmount <= lowWater && upstreamOpen === true;
}

function nonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

/** Strip Host-only cwd/snapshot fields and reject malformed summary records. */
export function changedFilesSummary(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const { turn, files, total, added, deleted } = value;
  if (!Number.isSafeInteger(turn) || turn < 1 || !Array.isArray(files) || files.length > 500 ||
      !nonNegativeInteger(total) || total < files.length || total > 1_000_000 ||
      !nonNegativeInteger(added) || !nonNegativeInteger(deleted)) return null;
  const rows = [];
  for (const file of files) {
    if (!file || typeof file !== 'object' || Array.isArray(file)) return null;
    if (Object.keys(file).some(key => ![
      'path', 'display', 'added', 'deleted', 'binary', 'oversized'
    ].includes(key))) return null;
    const { path, display, added: fileAdded, deleted: fileDeleted, binary, oversized } = file;
    if (typeof path !== 'string' || !path || path.length > 4096 ||
        typeof display !== 'string' || !display || display.length > 8192 ||
        !nonNegativeInteger(fileAdded) || !nonNegativeInteger(fileDeleted) ||
        (binary !== undefined && binary !== true) ||
        (oversized !== undefined && oversized !== true)) return null;
    rows.push({
      path,
      display,
      added: fileAdded,
      deleted: fileDeleted,
      ...(binary === true ? { binary: true } : {}),
      ...(oversized === true ? { oversized: true } : {})
    });
  }
  return { turn, files: rows, total, added, deleted };
}

/** Allowlist session projection values consumed by the native mode and lineage UI. */
export function normalizedProjectionSnapshot(value) {
  const source = value && typeof value === 'object' && !Array.isArray(value) ? value : {};
  const raw = source.values && typeof source.values === 'object' && !Array.isArray(source.values)
    ? source.values : {};
  const values = {};
  const plan = normalizePlanProjection(raw.plan);
  if (plan) values.plan = plan;
  const catalog = normalizeSubagentCatalog(raw.subagentCatalog);
  if (catalog) values.subagentCatalog = catalog;
  if (Object.prototype.hasOwnProperty.call(raw, 'subagent')) {
    values.subagentKnown = true;
    if (raw.subagent === null) values.subagent = null;
    else {
      const identity = normalizeSubagentIdentity(raw.subagent);
      if (identity) values.subagent = identity;
      else delete values.subagentKnown;
    }
  }
  const timing = normalizeSubagentTiming(raw.subagentTiming);
  if (timing) values.subagentTiming = timing;
  const permissions = normalizePermissionSelection(raw.permissions);
  if (permissions) values.permissions = permissions;
  return {
    kind: typeof source.kind === 'string' ? source.kind : 'sequenced',
    asOfSeq: Number.isSafeInteger(source.asOfSeq) && source.asOfSeq >= 0 ? source.asOfSeq : -1,
    values
  };
}

export function createNativeHarness({ upstream, upstreamCookie, publicOrigin, ownerOf }) {
  const credential = () => typeof upstreamCookie === 'function' ? upstreamCookie() : upstreamCookie;
  const connections = new Map();
  const target = new URL(upstream);
  const wss = new WebSocketServer({ noServer: true, maxPayload: 16384, perMessageDeflate: false });
  async function rpcArgs(endpoint, args, signal, timeoutMs = 20000) {
    const rpcId = randomUUID();
    const response = await fetch(new URL('/api/' + endpoint, target), {
      method: 'POST', redirect: 'error', signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(timeoutMs)]) : AbortSignal.timeout(timeoutMs),
      headers: { 'Content-Type': 'application/json', Origin: target.origin, Cookie: await credential() },
      body: JSON.stringify({ type: 'client-request', rpcId, method: endpoint, payload: { args } })
    });
    if (!response.ok) throw Error('Harness native API unavailable');
    const envelope = await response.json();
    if (envelope.type !== 'server-response' || envelope.rpcId !== rpcId || envelope.result?.ok !== true) {
      // Preserve only stable decision codes; do not relay arbitrary error messages.
      const error = new Error('Harness rejected this operation');
      const stableCode = envelope.result?.error?.code;
      if (['workspace/session-active', 'workspace/name-conflict', 'workspace/invalid-path', 'settings/conflict', 'settings/rejected',
        'directory-picker/unavailable', 'directory-picker/unreadable', 'directory-picker/exists', 'directory-picker/create-failed',
        'workspace-file/not-found', 'workspace-file/not-directory', 'workspace-file/not-regular-file',
        'workspace-file/not-text', 'workspace-file/outside-workspace', 'workspace-file/too-large',
        'gateway/bad-request', 'gateway/lookup-not-found',
        'session/writer-held', 'session/migration-required',
        'subagent/attachment-invalid', 'subagent/delivery-unavailable',
        'subagent/invalid-time-zone', 'subagent/not-resumable',
        'subagent/parent-unavailable', 'subagent/unauthorized'].includes(stableCode) ||
        (typeof stableCode === 'string' && /^(?:plugin-manager|schedule)\/[A-Za-z0-9-]+$/.test(stableCode))) {
        error.code = stableCode;
      }
      throw error;
    }
    return envelope.result.value;
  }
  async function directRpc(endpoint, args, signal, timeoutMs = 20000) {
    if (typeof endpoint !== 'string' || !/^[A-Za-z][A-Za-z0-9]*\/[A-Za-z][A-Za-z0-9]*$/.test(endpoint) ||
        !args || typeof args !== 'object' || Array.isArray(args)) {
      throw Error('Invalid native admin request');
    }
    return rpcArgs(endpoint, args, signal, timeoutMs);
  }
  async function rpc(method, request, signal) {
    const unwrapped = method.startsWith('settings/') || method.startsWith('directoryPicker/') ||
      method.startsWith('workspaceFiles/') || method === '$events/result';
    const endpoint = unwrapped || method.startsWith('workspace/') ? method
      : method === 'answerQuestion' ? 'userQuestions/answer'
        : 'session/' + method;
    const args = unwrapped ? request
      : method === 'answerQuestion' ? { agent: request.sessionId, callId: request.callId, answer: request.answer }
        : method === 'list' ? { _request: request }
          : method === 'modelCatalog' ? {}
            : { request };
    return rpcArgs(endpoint, args, signal);
  }
  async function rpcWithBytes(method, request, signal) {
    const rpcId = randomUUID();
    const endpoint = method;
    const response = await fetch(new URL('/api/' + endpoint, target), {
      method: 'POST', redirect: 'error', signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(20000)]) : AbortSignal.timeout(20000),
      headers: { 'Content-Type': 'application/json', Origin: target.origin, Cookie: await credential() },
      body: JSON.stringify({ type: 'client-request', rpcId, method: endpoint, payload: { args: request } })
    });
    if (!response.ok) throw Error('Harness native API unavailable');
    const type = (response.headers.get('content-type') || '').split(';', 1)[0].trim().toLowerCase();
    let envelope;
    let attachments = [];
    if (type === 'multipart/form-data') {
      const form = await response.formData();
      const metadata = form.get('metadata');
      if (typeof metadata !== 'string') throw Error('Invalid binary response metadata');
      envelope = JSON.parse(metadata);
      form.delete('metadata');
      attachments = Array.isArray(envelope?.attachments) ? envelope.attachments : [];
      if (!attachments.length) throw Error('Invalid binary response attachments');
      if (!form || typeof form.entries !== 'function') throw Error('Invalid binary response form');
      const seen = new Set();
      const valueRoot = { value: envelope?.result?.value };
      for (const attachment of attachments) {
        if (!attachment || attachment.codec !== 'bytes' || typeof attachment.part !== 'string' ||
            !attachment.part || !Array.isArray(attachment.path) || !attachment.path.length) {
          throw Error('Invalid binary response attachment');
        }
        if (seen.has(attachment.part)) throw Error('Duplicate binary response attachment');
        seen.add(attachment.part);
        const data = form.get(attachment.part);
        form.delete(attachment.part);
        if (!data || typeof data.arrayBuffer !== 'function') throw Error('Missing binary response attachment');
        let parent = valueRoot;
        let key = 'value';
        for (const segment of attachment.path) {
          const value = parent[key];
          if (value === null || typeof value !== 'object') throw Error('Invalid binary response path');
          if (Array.isArray(value) &&
              (!Number.isSafeInteger(segment) || segment < 0 || segment >= value.length)) {
            throw Error('Invalid binary response path');
          }
          if (!Array.isArray(value) && typeof segment !== 'string') throw Error('Invalid binary response path');
          if (!Object.prototype.hasOwnProperty.call(value, segment)) throw Error('Invalid binary response path');
          parent = value;
          key = segment;
        }
        if (parent[key] !== null) throw Error('Invalid binary response placeholder');
        parent[key] = new Uint8Array(await data.arrayBuffer());
      }
      if ([...form.keys()].length) throw Error('Unexpected binary response attachment');
    } else {
      envelope = await response.json();
    }
    if (envelope?.type !== 'server-response' || envelope.rpcId !== rpcId || envelope.result?.ok !== true) {
      const error = new Error('Harness rejected this operation');
      if (typeof envelope?.result?.error?.code === 'string') error.code = envelope.result.error.code;
      throw error;
    }
    return envelope.result.value;
  }
  async function workspaceBaseline(signal) {
    const url = new URL('/api/remote.mux', target); url.protocol = target.protocol === 'https:' ? 'wss:' : 'ws:';
    const cookie = await credential();
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(url, { headers: { Cookie: cookie, Origin: target.origin }, handshakeTimeout: 10000 });
      let done = false;
      const finish = (error, value) => {
        if (done) return; done = true; clearTimeout(timer); signal?.removeEventListener('abort', aborted);
        ws.close(); error ? reject(error) : resolve(value);
      };
      const aborted = () => finish(Error('Workspace request cancelled'));
      const timer = setTimeout(() => finish(Error('Workspace baseline timeout')), 15000);
      ws.once('error', () => finish(Error('Workspace connection unavailable')));
      ws.once('close', () => { if (!done) finish(Error('Workspace stream ended')); });
      signal?.addEventListener('abort', aborted, { once: true });
      if (signal?.aborted) { aborted(); return; }
      ws.once('open', () => ws.send(JSON.stringify({ type: 'open', streamId: 'workspaces', endpoint: 'workspace/follow', payload: { args: {} } })));
      ws.on('message', raw => {
        try {
          const frame = JSON.parse(raw.toString());
          if (frame.type === 'error') { finish(Error('Workspace API unavailable')); return; }
          if (frame.type === 'item' && frame.streamId === 'workspaces' && frame.value?.type === 'baseline' && Array.isArray(frame.value.value?.items)) finish(null, frame.value.value);
        } catch { finish(Error('Invalid workspace baseline')); }
      });
    });
  }
  function routes(app, requireAuth) {
    app.use('/pocket/api/native', requireAuth);
    const guarded = fn => async (req, res) => {
      const abort = new AbortController();
      res.once('close', () => { if (!res.writableEnded) abort.abort(); });
      try { await fn(req, res, abort.signal); }
      catch (error) { if (!res.headersSent && !res.destroyed) res.status(error.code ? 409 : 502).json({ error: '操作未确认，请刷新', ...(error.code ? { code: error.code } : {}) }); }
    };
    app.get('/pocket/api/native/sessions', guarded(async (_req, res, signal) => {
      const value = await rpc('list', {}, signal);
      const rows = Array.isArray(value?.items) ? value.items : [];
      res.json({ protocol: 2, truncated: false, items: rows.filter(row => sessionIdValid(row.sessionId)).map(row => {
        const projections = normalizedProjectionSnapshot(row.projections);
        return {
          id: row.sessionId, title: typeof row.projections?.values?.title === 'string' ? normalizeProjectionTitle(row.projections.values.title) : '新会话',
          titleKnown: typeof row.projections?.values?.title === 'string',
          ...(typeof row.blank === 'boolean' ? { blank: row.blank } : {}),
          ...(typeof row.cwd === 'string' ? { cwd: row.cwd } : {}),
          ...(typeof row.origin === 'string' ? { origin: row.origin } : {}),
          ...(typeof row.parentSessionId === 'string' ? { parentSessionId: row.parentSessionId } : {}),
          ...(typeof row.projections?.values?.agentPreset === 'string' ? { agentPreset: row.projections.values.agentPreset } : {}),
          ...(Object.keys(projections.values).length ? { projections: projections.values } : {}),
          ...(typeof row.agentAvailable === 'boolean' ? { agentAvailable: row.agentAvailable } : {}),
          running: row.running === true,
          updatedAt: Number.isFinite(row.updatedAt) ? row.updatedAt : 0
        };
      }) });
    }));
    app.get('/pocket/api/native/workspaces', guarded(async (_req, res, signal) => {
      try { res.json({ available: true, ...await workspaceBaseline(signal) }); }
      catch { if (!res.destroyed) res.json({ available: false, items: [], archivedSessionIds: [], pinnedSessionIds: [] }); }
    }));
    app.get('/pocket/api/native/changes/summary', guarded(async (req, res, signal) => {
      const id = req.query?.sessionId;
      const rawSeq = req.query?.seq;
      if (!sessionIdValid(id) || typeof rawSeq !== 'string' || !/^(?:0|[1-9]\d*)$/.test(rawSeq) ||
          !Number.isSafeInteger(Number(rawSeq))) return res.sendStatus(400);
      const url = new URL('/api/changes.summary', target);
      url.searchParams.set('sessionId', id);
      url.searchParams.set('seq', rawSeq);
      const response = await fetch(url, {
        redirect: 'error',
        signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(20000)]) : AbortSignal.timeout(20000),
        headers: { Origin: target.origin, Cookie: await credential(), Accept: 'application/json' }
      });
      if (response.status === 404) { await response.body?.cancel(); res.sendStatus(404); return; }
      if (!response.ok) { await response.body?.cancel(); res.sendStatus(502); return; }
      const type = (response.headers.get('content-type') || '').split(';', 1)[0].trim().toLowerCase();
      const length = Number(response.headers.get('content-length'));
      if (type !== 'application/json' || (Number.isFinite(length) && length > 2 * 1024 * 1024)) {
        await response.body?.cancel();
        res.sendStatus(502);
        return;
      }
      const body = await response.text();
      if (Buffer.byteLength(body) > 2 * 1024 * 1024) { res.sendStatus(502); return; }
      let value;
      try { value = changedFilesSummary(JSON.parse(body)); } catch { value = null; }
      if (!value) { res.sendStatus(502); return; }
      res.setHeader('Cache-Control', 'no-store');
      res.json(value);
    }));
    app.get('/pocket/api/native/export', guarded(async (req, res, signal) => {
      if (!sessionIdValid(req.query.sessionId) || !['markdown', 'zip'].includes(req.query.format) ||
        (req.query.includeDescendants !== undefined && !['true', 'false'].includes(req.query.includeDescendants))) return res.sendStatus(400);
      const url = new URL(req.query.format === 'markdown' ? '/api/session.markdown' : '/api/session.export', target);
      url.searchParams.set('sessionId', req.query.sessionId);
      if (req.query.format === 'zip') url.searchParams.set('includeDescendants', req.query.includeDescendants || 'true');
      const response = await fetch(url, { signal, redirect: 'error', headers: { Cookie: await credential(), Origin: target.origin } });
      if (!response.ok || !response.body) { await response.body?.cancel(); return res.sendStatus(response.status === 404 ? 404 : 502); }
      const type = response.headers.get('content-type') || '';
      if (!(req.query.format === 'zip' ? /^application\/zip(?:;|$)/i : /^text\/markdown(?:;|$)/i).test(type)) { await response.body.cancel(); return res.sendStatus(502); }
      res.setHeader('Content-Type', req.query.format === 'zip' ? 'application/zip' : 'text/markdown; charset=utf-8');
      res.setHeader('Cache-Control', 'no-store');
      await pipeline(Readable.fromWeb(response.body), res, { signal });
    }));
    app.post('/pocket/api/native/create', guarded(async (req, res, signal) => {
      // A caller-chosen ID makes a timed-out create recoverable through the list.
      if (!sessionIdValid(req.body?.requestId) || (req.body.cwd !== undefined && typeof req.body.cwd !== 'string')) return res.sendStatus(400);
      if (req.body.workspaceId !== undefined && (!sessionIdValid(req.body.workspaceId) || req.body.cwd)) return res.sendStatus(400);
      const value = await rpc('create', { sessionId: req.body.requestId, ...(req.body.workspaceId ? { workspaceId: req.body.workspaceId } : req.body.cwd ? { cwd: req.body.cwd } : {}), ...(typeof req.body.agentPreset === 'string' && req.body.agentPreset ? { agentPreset: req.body.agentPreset } : {}) }, signal);
      if (!sessionIdValid(value?.sessionId)) throw Error('Invalid session');
      res.json({ id: value.sessionId });
    }));
    app.post('/pocket/api/native/page', guarded(async (req, res, signal) => {
      if (!sessionIdValid(req.body?.sessionId) || !Number.isSafeInteger(req.body.beforeSeq) || req.body.beforeSeq < 0) return res.sendStatus(400);
      const subagent = req.body.parentSessionId === undefined ? null : normalizeSubagentAddress({
        kind: 'subagent',
        parentSessionId: req.body.parentSessionId,
        childSessionId: req.body.sessionId,
        mode: req.body.parentMode
      });
      if (req.body.parentSessionId !== undefined && !subagent) return res.sendStatus(400);
      const address = subagent || { kind: 'session', sessionId: req.body.sessionId };
      const value = await rpc('page', { address, beforeSeq: req.body.beforeSeq, ...(Number.isSafeInteger(req.body.throughSeq) ? { throughSeq: req.body.throughSeq } : {}), maxMessages: 60 }, signal);
      const history = normalizedHistory(value.records);
      res.json({ ...history, hasMore: value.hasMore || history.trimmed, cursor: value.cursor, beforeSeq: value.records?.[0]?.event?.seq ?? req.body.beforeSeq, throughSeq: value.cursor });
    }));
    app.post('/pocket/api/native/file', guarded(async (req, res, signal) => {
      const { sessionId, path, offset = 1, limit = 240 } = req.body || {};
      if (!sessionIdValid(sessionId) || typeof path !== 'string' || !path.trim() || path.length > 4096 ||
        !Number.isSafeInteger(offset) || offset < 1 || !Number.isSafeInteger(limit) || limit < 1 || limit > 500) return res.sendStatus(400);
      const value = await rpc('workspaceFiles/read', { workspaceFileScopeId: sessionId, path,
        range: { offset, limit } }, signal);
      if (typeof value?.absolutePath !== 'string' || typeof value?.text !== 'string' ||
        typeof value?.version !== 'string' || !value.version ||
        !Number.isSafeInteger(value?.lines) || !Number.isSafeInteger(value?.offset) || typeof value?.eof !== 'boolean') {
        throw Error('Invalid workspace file response');
      }
      res.json({ absolutePath: value.absolutePath, version: value.version, text: value.text,
        lines: value.lines, offset: value.offset, eof: value.eof });
    }));
    app.post('/pocket/api/native/file/stat', guarded(async (req, res, signal) => {
      const { sessionId, path } = req.body || {};
      if (!sessionIdValid(sessionId) || typeof path !== 'string' || !path.trim() || path.length > 4096) {
        return res.sendStatus(400);
      }
      const value = await rpc('workspaceFiles/stat', { workspaceFileScopeId: sessionId, path }, signal);
      if (typeof value?.absolutePath !== 'string' || typeof value?.version !== 'string' || !value.version ||
          (value.bytes !== undefined && (!Number.isSafeInteger(value.bytes) || value.bytes < 0))) {
        throw Error('Invalid workspace file stat');
      }
      res.json({
        absolutePath: value.absolutePath,
        version: value.version,
        ...(value.bytes === undefined ? {} : { bytes: value.bytes })
      });
    }));
    app.post('/pocket/api/native/file/list', guarded(async (req, res, signal) => {
      const { sessionId, path } = req.body || {};
      if (!sessionIdValid(sessionId) || typeof path !== 'string' || path.length > 4096) return res.sendStatus(400);
      const value = await rpc('workspaceFiles/list', { workspaceFileScopeId: sessionId, path: path || '.' }, signal);
      if (typeof value?.path !== 'string' || !Array.isArray(value.entries) || typeof value.truncated !== 'boolean') {
        throw Error('Invalid workspace directory listing');
      }
      const entries = value.entries.map(entry => {
        if (!entry || typeof entry.name !== 'string' || !entry.name || entry.name.length > 255 ||
            !['file', 'directory', 'other'].includes(entry.type) ||
            (entry.size !== undefined && (!Number.isSafeInteger(entry.size) || entry.size < 0))) {
          throw Error('Invalid workspace directory entry');
        }
        return { name: entry.name, type: entry.type, ...(entry.size === undefined ? {} : { size: entry.size }) };
      });
      res.json({ path: value.path, entries, truncated: value.truncated });
    }));
    app.post('/pocket/api/native/file/bytes', guarded(async (req, res, signal) => {
      const { sessionId, path, baseFile, offset = 0, length = 262144 } = req.body || {};
      if (!sessionIdValid(sessionId) || typeof path !== 'string' || !path.trim() || path.length > 4096 ||
          (baseFile !== undefined && (typeof baseFile !== 'string' || !baseFile || baseFile.length > 4096)) ||
          !Number.isSafeInteger(offset) || offset < 0 ||
          !Number.isSafeInteger(length) || length < 1 || length > 2 * 1024 * 1024 ||
          offset + length > Number.MAX_SAFE_INTEGER) return res.sendStatus(400);
      const args = {
        workspaceFileScopeId: sessionId,
        path,
        options: { range: { offset, length }, ...(baseFile === undefined ? {} : { baseFile }) }
      };
      const value = await rpcWithBytes('workspaceFiles/readBytes', args, signal);
      if (typeof value?.absolutePath !== 'string' || typeof value?.version !== 'string' || !value.version ||
          value.offset !== offset || !(value.data instanceof Uint8Array) ||
          value.data.length > length || typeof value.eof !== 'boolean' ||
          (value.bytes !== undefined && (!Number.isSafeInteger(value.bytes) || value.bytes < 0))) {
        throw Error('Invalid workspace file bytes');
      }
      const metadata = Buffer.from(JSON.stringify({
        protocol: 1,
        absolutePath: value.absolutePath,
        version: value.version,
        ...(value.bytes === undefined ? {} : { bytes: value.bytes }),
        offset: value.offset,
        eof: value.eof,
        length: value.data.length
      })).toString('base64url');
      res.setHeader('Content-Type', 'application/octet-stream');
      res.setHeader('Cache-Control', 'no-store');
      res.setHeader('X-DSH-File-Window', metadata);
      res.end(Buffer.from(value.data));
    }));
    app.post('/pocket/api/native/upload', guarded(async (req, res, signal) => {
      const id = req.query?.sessionId;
      const name = req.query?.name;
      const mediaType = req.query?.mediaType;
      if (!sessionIdValid(id) || typeof name !== 'string' || !name || name.length > 512 ||
          (mediaType !== undefined && typeof mediaType !== 'string')) return res.sendStatus(400);
      const rawLength = req.headers['content-length'];
      if (typeof rawLength !== 'string' || !/^(?:0|[1-9]\d*)$/.test(rawLength) ||
          !Number.isSafeInteger(Number(rawLength))) return res.sendStatus(411);
      const url = new URL('/api/session/uploadFileBinary', target);
      url.searchParams.set('sessionId', id);
      url.searchParams.set('name', name);
      if (mediaType) url.searchParams.set('mediaType', mediaType);
      const response = await fetch(url, {
        method: 'POST', redirect: 'error', duplex: 'half',
        signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(120000)]) : AbortSignal.timeout(120000),
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': rawLength,
          Origin: target.origin,
          Cookie: await credential()
        },
        body: Readable.toWeb(req)
      });
      const body = await response.text();
      res.status(response.status).type('application/json').send(body);
    }));
    app.post('/pocket/api/native/prompt', guarded(async (req, res, signal) => {
      const { sessionId, requestId, text } = req.body || {};
      const files = req.body.attachments === undefined ? [] : req.body.attachments;
      if (!sessionIdValid(sessionId) || !sessionIdValid(requestId) || typeof text !== 'string' ||
          (!text.trim() && !files.length && !req.body.images?.length)) return res.sendStatus(400);
      if (req.body.mode !== undefined && !['queue', 'steer'].includes(req.body.mode)) return res.sendStatus(400);
      if (!Array.isArray(files) || !files.every(file =>
        file?.type === 'file' && typeof file.receiptId === 'string' && file.receiptId.length > 0 && file.receiptId.length <= 4096)) {
        return res.sendStatus(400);
      }
      if (req.body.images !== undefined && (!Array.isArray(req.body.images) || !req.body.images.every(image =>
        ['image/png','image/jpeg','image/webp','image/gif'].includes(image?.mediaType) && typeof image.data === 'string' && image.data.length > 0 &&
        (image.name === undefined || typeof image.name === 'string')))) return res.sendStatus(400);
      const content = [...files.map(file => ({ type: 'file', receiptId: file.receiptId })),
        ...(text.trim() ? [{ type: 'text', text }] : []), ...(req.body.images || []).map(image => ({ type: 'image',
        mediaType: image.mediaType, data: image.data, ...(image.name ? { name: image.name } : {}) }))];
      if (req.body.parentSessionId !== undefined) {
        const address = normalizeSubagentAddress({
          kind: 'subagent',
          parentSessionId: req.body.parentSessionId,
          childSessionId: sessionId,
          mode: req.body.parentMode
        });
        if (!address || files.length) return res.sendStatus(400);
        await rpcArgs('subagents/prompt', {
          request: {
            requestId,
            parentSessionId: address.parentSessionId,
            childSessionId: address.childSessionId,
            mode: 'continuable',
            delivery: req.body.mode || 'queue',
            content: content.filter(part => part.type === 'text' || part.type === 'image')
          }
        }, signal);
      } else {
        await rpc('prompt', { sessionId, requestId, mode: req.body.mode || 'queue', content }, signal);
      }
      res.json({ accepted: true });
    }));
    app.post('/pocket/api/native/answer', guarded(async (req, res, signal) => {
      const connection = connections.get(req.body?.connectionId);
      const pending = connection?.pending.get(req.body?.eventId);
      if (!connection || connection.owner !== ownerOf(req) || !pending) return res.sendStatus(409);
      if (req.body.engage === true) { clearTimeout(pending.timer); pending.engaged = true; return res.json({ accepted: true }); }
      let outcome;
      if (req.body.delegate === true) outcome = { kind: 'next' };
      else if (pending.event === 'approval/request') {
        if (!['allowed-once', 'rejected'].includes(req.body.value)) return res.sendStatus(400);
        outcome = { kind: 'result', value: req.body.value };
      } else {
        const questions = pending.request.questions;
        const answers = req.body.value?.answers;
        if (!Array.isArray(questions) || !Array.isArray(answers) || answers.length !== questions.length ||
            new Set(answers.map(answer => answer.id)).size !== questions.length ||
            !questions.every(question => {
              const answer = answers.find(item => item.id === question.id);
              return answer && Array.isArray(answer.selected) && answer.selected.every(label => typeof label === 'string' && question.options?.some(option => option.label === label)) &&
                new Set(answer.selected).size === answer.selected.length && (question.multiSelect || answer.selected.length <= 1) &&
                (answer.custom === undefined || typeof answer.custom === 'string') &&
                !(question.intent?.kind === 'approval' && (answer.custom || answer.selected.length !== 1));
            })) return res.sendStatus(400);
        outcome = { kind: 'result', value: { answers } };
      }
      // One user action, one result. Never repeat a potentially accepted decision.
      clearTimeout(pending.timer);
      connection.pending.delete(req.body.eventId);
      if (req.body.delegate === true && pending.request?.wait?.timed === true) connection.cancelWait(req.body.eventId);
      await rpc('$events/result', { clientId: connection.clientId, eventId: req.body.eventId, outcome }, signal);
      connection.send({ type: 'interaction-ended', eventId: req.body.eventId });
      res.json({ accepted: true });
    }));
    app.post('/pocket/api/native/operation', guarded(async (req, res, signal) => {
      const { operation, sessionId } = req.body || {};
      const sessionOptionalOperations = [
        'modelCatalog', 'permissionCatalog', 'workspaceCreate', 'workspaceRename', 'workspaceDelete',
        'workspaceOrder', 'sessionInsertBefore', 'settingsDescribe', 'settingsSet',
        'directoryList', 'directoryCreate', 'pluginsList', 'pluginSetEnabled',
        'pluginSetRowEnabled', 'pluginInspect', 'pluginInstall', 'pluginRemove',
        'pluginVersions', 'pluginUpdate', 'automationList', 'automationView',
        'automationHistory', 'automationCreate', 'automationEdit', 'automationRun',
        'automationDelete'
      ];
      if (!sessionOptionalOperations.includes(operation) && !sessionIdValid(sessionId)) return res.sendStatus(400);
      let request;
      switch (operation) {
        case 'pluginsList': {
          const [bundles, plugins] = await Promise.all([
            directRpc('pluginManager/listBundles', {}, signal),
            directRpc('pluginManager/listPlugins', {}, signal)
          ]);
          res.json(normalizePluginInventory(bundles, plugins)); return;
        }
        case 'pluginSetEnabled': {
          const name = pluginSpec(req.body.name);
          if (!name || typeof req.body.enabled !== 'boolean') return res.sendStatus(400);
          const value = normalizePluginChange(await directRpc('pluginManager/setBundleEnabled',
            { name, enabled: req.body.enabled }, signal, 45000));
          if (!value) throw Error('Invalid plugin change response');
          res.json(value); return;
        }
        case 'pluginSetRowEnabled': {
          const entryId = pluginSpec(req.body.entryId);
          if (!entryId || typeof req.body.enabled !== 'boolean') return res.sendStatus(400);
          const value = normalizePluginChange(await directRpc('pluginManager/setPluginEnabled',
            { id: entryId, enabled: req.body.enabled }, signal, 45000));
          if (!value) throw Error('Invalid plugin change response');
          res.json(value); return;
        }
        case 'pluginInspect': {
          const spec = pluginSpec(req.body.spec);
          if (!spec) return res.sendStatus(400);
          const value = normalizePluginInspection(await directRpc('pluginManager/inspect',
            { spec }, signal, 30000));
          if (!value) throw Error('Invalid plugin inspection response');
          res.json(value); return;
        }
        case 'pluginInstall': {
          const spec = pluginSpec(req.body.spec);
          if (!spec || (req.body.approvedBuilds !== undefined &&
              (!Array.isArray(req.body.approvedBuilds) || req.body.approvedBuilds.length > 100 ||
                req.body.approvedBuilds.some(name => !pluginSpec(name))))) return res.sendStatus(400);
          const options = {
            enabled: req.body.enabled !== false,
            ...(req.body.saveExact === true ? { saveExact: true } : {}),
            ...(req.body.approvedBuilds === undefined ? {} : {
              approvedBuilds: req.body.approvedBuilds.map(name => pluginSpec(name))
            })
          };
          const value = normalizePluginChange(await directRpc('pluginManager/installBundle',
            { spec, options }, signal, 120000));
          if (!value) throw Error('Invalid plugin change response');
          res.json(value); return;
        }
        case 'pluginRemove': {
          const name = pluginSpec(req.body.name);
          if (!name) return res.sendStatus(400);
          const value = normalizePluginChange(await directRpc('pluginManager/removeBundle',
            { name }, signal, 120000));
          if (!value) throw Error('Invalid plugin change response');
          res.json(value); return;
        }
        case 'pluginVersions': {
          const name = pluginSpec(req.body.name);
          if (!name) return res.sendStatus(400);
          const value = normalizePluginVersions(await directRpc('pluginManager/listVersions',
            { name, options: {} }, signal, 45000));
          if (!value) throw Error('Invalid plugin version response');
          res.json(value); return;
        }
        case 'pluginUpdate': {
          const name = pluginSpec(req.body.name);
          const version = pluginSpec(req.body.version);
          if (!name || !version) return res.sendStatus(400);
          const raw = await directRpc('pluginManager/updateBundle',
            { name, version, options: {} }, signal, 120000);
          const value = normalizePluginChange(raw?.result);
          if (!value) throw Error('Invalid plugin change response');
          res.json(value); return;
        }
        case 'automationList': {
          const value = normalizeAutomationCatalog(await directRpc('schedule/catalog', {}, signal, 30000));
          res.json(value); return;
        }
        case 'automationView': {
          const id = automationTaskId(req.body.id);
          if (!id) return res.sendStatus(400);
          const value = normalizeAutomationTask(await directRpc('schedule/view', { request: { id } }, signal, 30000));
          if (!value) return res.status(404).json({ error: '任务不存在', code: 'schedule_not_found' });
          res.json(value); return;
        }
        case 'automationHistory': {
          const request = automationHistoryRequest(req.body);
          if (!request) return res.sendStatus(400);
          const value = normalizeAutomationHistory(await directRpc('schedule/history', { request }, signal, 30000));
          if (!value) throw Error('Invalid schedule history response');
          res.json(value); return;
        }
        case 'automationCreate': {
          const request = automationCreateRequest(req.body.request);
          if (!request) return res.sendStatus(400);
          const value = normalizeAutomationTask(await directRpc('schedule/create', { request }, signal, 45000));
          if (!value) throw Error('Invalid schedule response');
          res.json(value); return;
        }
        case 'automationEdit': {
          const request = automationEditRequest(req.body.request);
          if (!request) return res.sendStatus(400);
          const raw = await directRpc('schedule/edit', { request }, signal, 45000);
          if (raw?.code === 'schedule_conflict' || raw?.code === 'schedule_not_found') {
            res.status(409).json({ error: raw.code === 'schedule_conflict' ? '任务已被更新' : '任务不存在', code: raw.code });
            return;
          }
          if (raw?.deleted === true) { res.json({ deleted: true, id: raw.id }); return; }
          const value = normalizeAutomationTask(raw);
          if (!value) throw Error('Invalid schedule response');
          res.json(value); return;
        }
        case 'automationRun': {
          const id = automationTaskId(req.body.id);
          if (!id) return res.sendStatus(400);
          const raw = await directRpc('schedule/run', { request: { id } }, signal, 45000);
          if (raw?.code) {
            res.status(raw.code === 'schedule_execution_pending' ? 409 : 404)
              .json({ error: raw.code === 'schedule_execution_pending' ? '任务正在执行' : '任务不存在', code: raw.code });
            return;
          }
          const value = normalizeAutomationTask(raw);
          if (!value) throw Error('Invalid schedule response');
          res.json(value); return;
        }
        case 'automationDelete': {
          const request = automationEditRequest({ id: req.body.id, action: 'delete',
            expectedUpdatedAt: req.body.expectedUpdatedAt });
          if (!request) return res.sendStatus(400);
          const raw = await directRpc('schedule/edit', { request }, signal, 45000);
          if (raw?.code) {
            res.status(409).json({ error: raw.code === 'schedule_conflict' ? '任务已被更新' : '任务不存在', code: raw.code });
            return;
          }
          if (raw?.deleted !== true) throw Error('Invalid schedule delete response');
          res.json({ deleted: true, id: raw.id }); return;
        }
        case 'capabilities': {
          const headers = { Cookie: await credential(), Origin: target.origin };
          const check = async (path, type) => {
            const url = new URL(path, target); url.searchParams.set('sessionId', sessionId);
            url.searchParams.set('includeDescendants', 'true');
            const response = await fetch(url, { method: 'HEAD', headers, redirect: 'error', signal });
            await response.body?.cancel();
            return response.ok && (response.headers.get('content-type') || '').split(';')[0].trim().toLowerCase() === type;
          };
          const [copyMarkdown, downloadLog] = await Promise.all([check('/api/session.markdown', 'text/markdown'), check('/api/session.export', 'application/zip')]);
          res.json({ copyMarkdown, downloadLog }); return;
        }
        case 'settingsDescribe': {
          const value = await rpc('settings/describe', {}, signal);
          const namespaces = (value?.namespaces || []).flatMap(row => {
            if (!row || !['ui-chat', 'ui-theme', 'ui-conversation', 'locale', 'permission'].includes(row.ns)) return [];
            if (row.ns !== 'permission') return [{ ns: row.ns, value: row.value, revision: row.revision }];
            const defaultPreset = normalizePermissionPreset(row.value?.defaultPreset);
            return defaultPreset ? [{ ns: row.ns, value: { defaultPreset }, revision: row.revision }] : [];
          });
          res.json({ writable: value?.writable === true, namespaces }); return;
        }
        case 'settingsSet': {
          const { ns, field, value, revision } = req.body;
          const enums = { 'ui-chat': { transcriptView: ['compact','standard','detailed','verbose'], collapseTiming: ['completion','next-input'], foldedReplies: ['all','final'] },
            'ui-theme': { preference: ['light','dark','system'] }, 'ui-conversation': { busyEnter: ['queue','steer'] } };
          const bounds = { fontSize: [10,22], codeFontSize: [10,16], terminalFontSize: [10,20] };
          let valid = enums[ns]?.[field]?.includes(value) || (ns === 'ui-theme' && bounds[field] && Number.isInteger(value) && value >= bounds[field][0] && value <= bounds[field][1]);
          if (ns === 'permission') {
            const catalog = normalizePermissionCatalog(await rpcArgs('permissionPresets/catalog', {}, signal));
            valid = field === 'defaultPreset' && catalog !== null &&
              catalog.defaultOptions.some(option => option.value === value);
          }
          if (!valid || !Number.isSafeInteger(revision) || revision < 0) return res.sendStatus(400);
          res.json(await rpc('settings/mutate', { ns, ops: [{ op: 'set', path: [field], value }], expectedRevision: revision }, signal)); return;
        }
        case 'directoryList':
          if (req.body.path !== undefined && typeof req.body.path !== 'string') return res.sendStatus(400);
          res.json(await rpc('directoryPicker/list', req.body.path ? { path: req.body.path } : {}, signal)); return;
        case 'directoryCreate':
          if (typeof req.body.path !== 'string' || typeof req.body.name !== 'string' || !req.body.name.trim() || /[/\\]/.test(req.body.name) || ['.','..'].includes(req.body.name)) return res.sendStatus(400);
          res.json(await rpc('directoryPicker/createDirectory', { path: req.body.path, name: req.body.name }, signal)); return;
        case 'workspaceCreate':
          if (typeof req.body.path !== 'string' || !req.body.path.trim() || req.body.path.length > 4096) return res.sendStatus(400);
          res.json(await rpc('workspace/create', { path: req.body.path }, signal)); return;
        case 'workspaceRename':
          if (!sessionIdValid(req.body.workspaceId) || typeof req.body.title !== 'string' || !req.body.title.trim()) return res.sendStatus(400);
          res.json(await rpc('workspace/rename', { workspaceId: req.body.workspaceId, title: req.body.title }, signal)); return;
        case 'workspaceDelete':
          if (!sessionIdValid(req.body.workspaceId)) return res.sendStatus(400);
          res.json(await rpc('workspace/delete', { workspaceId: req.body.workspaceId }, signal)); return;
        case 'workspaceOrder':
          if (!sessionIdValid(req.body.workspaceId) || (req.body.beforeWorkspaceId !== undefined && !sessionIdValid(req.body.beforeWorkspaceId))) return res.sendStatus(400);
          res.json(await rpc('workspace/insertBefore', { workspaceId: req.body.workspaceId, ...(req.body.beforeWorkspaceId ? { beforeWorkspaceId: req.body.beforeWorkspaceId } : {}) }, signal)); return;
        case 'sessionInsertBefore':
          if (!sessionIdValid(req.body.workspaceId) || !sessionIdValid(sessionId) ||
              (req.body.beforeSessionId !== undefined && !sessionIdValid(req.body.beforeSessionId))) {
            return res.sendStatus(400);
          }
          res.json(await rpc('workspace/insertSessionBefore', {
            workspaceId: req.body.workspaceId,
            sessionId,
            ...(req.body.beforeSessionId ? { beforeSessionId: req.body.beforeSessionId } : {})
          }, signal)); return;
        case 'archive': case 'unarchive': case 'pin': case 'unpin':
          if (req.body.stopActivity !== undefined && (operation !== 'archive' || typeof req.body.stopActivity !== 'boolean')) return res.sendStatus(400);
          res.json(await rpc('workspace/' + ({ archive: 'archiveSession', unarchive: 'unarchiveSession', pin: 'pinSession', unpin: 'unpinSession' }[operation]),
            { sessionId, ...(operation === 'archive' && req.body.stopActivity === true ? { stopActivity: true } : {}) }, signal)); return;
        case 'modelCatalog': request = {}; break;
        case 'answerQuestion':
          if (typeof req.body.callId !== 'string' || !req.body.callId || !Array.isArray(req.body.answer?.answers) ||
              !req.body.answer.answers.every(answer => typeof answer.id === 'string' && Array.isArray(answer.selected) &&
                answer.selected.every(value => typeof value === 'string') && (answer.custom === undefined || typeof answer.custom === 'string'))) return res.sendStatus(400);
          request = { sessionId, callId: req.body.callId, answer: req.body.answer }; break;
        case 'attachment': {
          const ref = req.body.attachment;
          if (!ref || typeof ref.attachmentId !== 'string' || !ref.attachmentId ||
              !['image/png','image/jpeg','image/webp','image/gif'].includes(ref.mediaType) ||
              ![ref.bytes,ref.width,ref.height].every(value => Number.isSafeInteger(value) && value > 0)) return res.sendStatus(400);
          request = { sessionId, attachment: ref }; break;
        }
        case 'state': request = { sessionId }; break;
        case 'projections': {
          const value = await rpc('projections', { sessionId }, signal);
          res.json(normalizedProjectionSnapshot(value)); return;
        }
        case 'permissionCatalog': {
          const catalog = normalizePermissionCatalog(
            await rpcArgs('permissionPresets/catalog', {}, signal));
          if (!catalog) {
            res.status(502).json({ error: '权限目录不可用', code: 'permission/catalog-invalid' });
            return;
          }
          res.json(catalog); return;
        }
        case 'setPermissionPreset': {
          const preset = normalizePermissionPreset(req.body.preset);
          if (!sessionIdValid(sessionId) || !preset || preset === 'custom') return res.sendStatus(400);
          const catalog = normalizePermissionCatalog(
            await rpcArgs('permissionPresets/catalog', {}, signal));
          if (!catalog) {
            res.status(502).json({ error: '权限目录不可用', code: 'permission/catalog-invalid' });
            return;
          }
          if (!catalog.options.some(option => option.value === preset)) {
            res.status(409).json({ error: '权限选项已失效', code: 'permission/preset-unavailable' });
            return;
          }
          await rpcArgs('commands/execute', [sessionId, '/permission ' + preset, []], signal);
          res.json({ accepted: true }); return;
        }
        case 'planOff':
          await rpcArgs('commands/execute', [sessionId, '/plan off', []], signal);
          res.json({ accepted: true }); return;
        case 'rename':
          if (typeof req.body.title !== 'string' || !req.body.title.trim()) return res.sendStatus(400);
          request = { sessionId, title: req.body.title }; break;
        case 'fork':
          if (req.body.atSeq !== undefined && (!Number.isSafeInteger(req.body.atSeq) || req.body.atSeq < 0)) return res.sendStatus(400);
          request = { sessionId, ...(req.body.atSeq === undefined ? {} : { atSeq: req.body.atSeq }), allowMigration: false }; break;
        case 'selectModel':
          if (![req.body.provider, req.body.model].every(value => typeof value === 'string' && value.trim()) ||
              (req.body.reasoningEffort !== undefined && typeof req.body.reasoningEffort !== 'string')) return res.sendStatus(400);
          request = { sessionId, provider: req.body.provider, model: req.body.model,
            ...(req.body.reasoningEffort === undefined ? {} : { reasoningEffort: req.body.reasoningEffort }) }; break;
        case 'updateQueue': {
          if (typeof req.body.itemId !== 'string' || !req.body.itemId || !['edit', 'remove', 'steer'].includes(req.body.kind)) return res.sendStatus(400);
          if (req.body.kind === 'edit' && (typeof req.body.text !== 'string' || !req.body.text.trim())) return res.sendStatus(400);
          request = { sessionId, itemId: req.body.itemId, action: { kind: req.body.kind,
            ...(req.body.kind === 'edit' ? { content: [{ type: 'text', text: req.body.text }] } : {}) } }; break;
        }
        default: return res.sendStatus(400);
      }
      res.json(await rpc(operation, request, signal) ?? { accepted: true });
    }));
    app.post('/pocket/api/native/cancel', guarded(async (req, res, signal) => {
      if (!sessionIdValid(req.body?.sessionId)) return res.sendStatus(400);
      if (req.body.parentSessionId !== undefined) {
        const address = normalizeSubagentAddress({
          kind: 'subagent',
          parentSessionId: req.body.parentSessionId,
          childSessionId: req.body.sessionId,
          mode: req.body.parentMode
        });
        if (!address) return res.sendStatus(400);
        await rpcArgs('subagents/interruptByParent',
          [address.childSessionId, address.parentSessionId, 'continuable'], signal);
      } else {
        await rpc('cancel', { sessionId: req.body.sessionId }, signal);
      }
      res.json({ accepted: true });
    }));
  }
  async function upgrade(req, socket, head) {
    const query = new URL(req.url, publicOrigin).searchParams;
    const id = query.get('sessionId');
    const profile = query.get('profile') || 'foreground';
    const parentSessionId = query.get('parentSessionId');
    const parentMode = query.get('parentMode');
    const address = parentSessionId === null
      ? { kind: 'session', sessionId: id }
      : normalizeSubagentAddress({
        kind: 'subagent',
        parentSessionId,
        childSessionId: id,
        mode: parentMode
      });
    if (!sessionIdValid(id) || !address || !['foreground', 'background'].includes(profile)) {
      socket.destroy(); return;
    }
    const timing = nativeHeartbeatPolicy(profile);
    const cookie = await credential();
    wss.handleUpgrade(req, socket, head, client => {
      const url = new URL('/api/remote.mux', target); url.protocol = target.protocol === 'https:' ? 'wss:' : 'ws:';
      const upstream = new WebSocket(url, { headers: { Cookie: cookie, Origin: target.origin },
        handshakeTimeout: 10000, maxPayload: 0, followRedirects: false });
      const connectionId = randomUUID();
      const connection = { owner: ownerOf(req), clientId: '', running: false, waiting: false,
        runningKnown: false, waitingKnown: false, queue: [],
        pending: new Map(), projectionSeq: new Map(), send: value => send(value), cancelWait: eventId => {
        if (upstream.readyState === WebSocket.OPEN) upstream.send(JSON.stringify({ type: 'cancel', streamId: 'wait:' + eventId }));
      } };
      connections.set(connectionId, connection);
      let alive = true;
      let upstreamAlive = true;
      let upstreamSilentMs = 0;
      const active = { cursor: -1, attemptId: '', nextIndex: 0, revision: 0 };
      client.on('pong', () => { alive = true; });
      upstream.on('pong', () => { upstreamAlive = true; });
      const heartbeat = setInterval(() => {
        if (!alive) { client.terminate(); return; }
        alive = false; client.ping();
        if (upstream.readyState === WebSocket.OPEN) {
          upstreamSilentMs = upstreamAlive ? 0 : upstreamSilentMs + timing.intervalMs;
          if (upstreamSilentMs >= timing.deadlineMs) {
            upstream.terminate(); client.close(1011, 'Upstream heartbeat timeout'); return;
          }
          upstreamAlive = false; upstream.ping();
        }
        if (upstream.readyState === WebSocket.OPEN) send(nativeHeartbeatPayload(
          connectionId, active, connection.runningKnown && connection.waitingKnown,
          connection.running, connection.waiting));
      }, timing.intervalMs);
      heartbeat.unref();
      const sendHighWater = 128 * 1024;
      const sendLowWater = 32 * 1024;
      let upstreamPausedForDelivery = false;
      const resumeDelivery = () => {
        if (!upstreamPausedForDelivery) return;
        upstreamPausedForDelivery = false;
        if (upstream.readyState === WebSocket.OPEN) upstream.resume();
      };
      const send = value => {
        if (client.readyState !== WebSocket.OPEN) return Promise.resolve();
        const text = Buffer.from(JSON.stringify(value));
        if (!upstreamPausedForDelivery && (client.bufferedAmount || 0) >= sendHighWater) {
          upstream.pause();
          upstreamPausedForDelivery = true;
        }
        // ws preserves the ordering of concurrently queued writes. Waiting for a
        // callback per token would instead serialize every small delta and add a
        // full event-loop turn to the visible stream. Pause the source only when
        // the socket's own buffer crosses the high-water mark.
        const writes = [];
        for (let offset = 0; offset < text.length && client.readyState === WebSocket.OPEN; offset += 32768) {
          writes.push(new Promise((resolve, reject) => client.send(
            text.subarray(offset, offset + 32768),
            { binary: false, fin: offset + 32768 >= text.length },
            error => {
              if (error) {
                reject(error);
                return;
              }
              if (nativeDeliveryDrainReady(upstreamPausedForDelivery,
                client.bufferedAmount || 0, sendLowWater,
                upstream.readyState === WebSocket.OPEN)) resumeDelivery();
              resolve();
            }
          )));
        }
        return Promise.all(writes)
          .catch(() => { client.close(1011, 'Delivery interrupted'); })
          .then(() => undefined);
      };
      const deliveryDrain = setInterval(() => {
        if (nativeDeliveryDrainReady(upstreamPausedForDelivery,
          client.bufferedAmount || 0, sendLowWater,
          upstream.readyState === WebSocket.OPEN)) resumeDelivery();
      }, 250);
      deliveryDrain.unref();
      const publishState = patch => {
        if (patch.running !== undefined) {
          connection.running = patch.running === true;
          connection.runningKnown = true;
        }
        if (patch.waiting !== undefined) {
          connection.waiting = patch.waiting === true;
          connection.waitingKnown = true;
        }
        if (patch.queueKnown === true) connection.queue = normalizeQueuedState(patch.queue);
        send({
          type: 'state',
          running: connection.running,
          waiting: connection.waiting,
          ...(patch.queueKnown === true ? { queueKnown: true, queue: connection.queue } : {})
        });
      };
      const opening = setTimeout(() => { send({ type: 'error', code: 'snapshot-timeout', retryable: true }).finally(() => client.close(1011)); }, timing.openingMs);
      opening.unref();
      client.once('close', () => clearTimeout(opening));
      upstream.once('open', () => {
        upstream.send(JSON.stringify({ type: 'open', streamId: 'interactions', endpoint: '$events', payload: { args: {} } }));
        for (const [streamId, method, request] of [
          ['history', 'follow', { address, activate: address.kind === 'session',
            assistantStream: true, maxMessages: 24 }],
          ['state', 'observeState', { sessionId: id }],
          ['projections', 'observeProjections', { sessionId: id }]
        ]) upstream.send(JSON.stringify({ type: 'open', streamId, endpoint: 'session/' + method, payload: { args: { request } } }));
      });
      let questionSeq = -1;
      const retired = new Set();
      let controlOpened = false;
      const useControl = stream => {
        retired.add(stream);
        if (controlOpened) return;
        controlOpened = true;
        upstream.send(JSON.stringify({ type: 'open', streamId: 'control', endpoint: 'session/control', payload: { args: {} } }));
        rpc('list', {}).then(value => {
          const row = value?.items?.find(item => item.sessionId === id);
          if (row) publishState({ running: row.running === true });
        }).catch(() => {});
      };
      const questions = (value, seq) => {
        if (!Number.isSafeInteger(seq) || seq < questionSeq || client.readyState !== WebSocket.OPEN) return;
        questionSeq = seq;
        send({ type: 'questions', questions: Array.isArray(value?.active) ? value.active.filter(item => item.state === 'continued') : [] });
      };
      const sessionTitle = value => {
        const title = normalizeProjectionTitle(value);
        if (title) send({ type: 'title', title });
      };
      const publishProjection = (key, value, seq) => {
        const projectionSeq = Number.isSafeInteger(seq) && seq >= 0 ? seq : -1;
        const previous = connection.projectionSeq.get(key);
        if (projectionSeq >= 0 && previous !== undefined && projectionSeq <= previous) return;
        if (projectionSeq >= 0) connection.projectionSeq.set(key, projectionSeq);
        if (key === 'plan') {
          const plan = normalizePlanProjection(value);
          if (plan) send({ type: 'plan', plan, projectionSeq });
        } else if (key === 'subagentCatalog') {
          const catalog = normalizeSubagentCatalog(value);
          if (catalog) send({ type: 'subagent-catalog', catalog, projectionSeq });
        } else if (key === 'subagent') {
          const identity = value === null ? null : normalizeSubagentIdentity(value);
          if (value === null || identity) send({ type: 'subagent-identity', identity, projectionSeq });
        } else if (key === 'subagentTiming') {
          const timing = normalizeSubagentTiming(value);
          if (timing) send({ type: 'subagent-timing', timing, projectionSeq });
        } else if (key === 'permissions') {
          send({ type: 'permission', selection: normalizePermissionSelection(value), projectionSeq });
        }
      };
      const publishProjectionValues = (values, seq) => {
        if (!values || typeof values !== 'object' || Array.isArray(values)) return;
        publishProjection('plan', values.plan, seq);
        publishProjection('subagentCatalog', values.subagentCatalog, seq);
        if (Object.prototype.hasOwnProperty.call(values, 'subagent')) {
          publishProjection('subagent', values.subagent, seq);
        }
        publishProjection('subagentTiming', values.subagentTiming, seq);
        if (Object.prototype.hasOwnProperty.call(values, 'permissions')) {
          publishProjection('permissions', values.permissions, seq);
        }
      };
      const endInteraction = eventId => {
        clearTimeout(connection.pending.get(eventId)?.timer);
        connection.pending.delete(eventId);
        send({ type: 'interaction-ended', eventId });
      };
      upstream.on('message', raw => {
        try {
          const frame = JSON.parse(raw.toString());
          if (frame.type === 'error') {
            if (['state', 'projections'].includes(frame.streamId) && frame.error?.code === 'gateway/invocation-unavailable') { useControl(frame.streamId); return; }
            if (frame.streamId !== 'history') {
              retired.add(frame.streamId);
              send({ type: 'capability-error', capability: frame.streamId, code: 'optional-stream-unavailable' }); return;
            }
            const unsupported = frame.error?.code === 'gateway/invocation-unavailable';
            send({ type: 'error', code: unsupported ? 'history-unsupported' : 'history-unavailable', retryable: !unsupported })
              .finally(() => client.close(unsupported ? 4404 : 1011)); return;
          }
          if (frame.type === 'end' && frame.streamId?.startsWith('wait:')) {
            const eventId = frame.streamId.slice(5);
            if (connection.pending.has(eventId)) {
              endInteraction(eventId);
              rpc('$events/result', { clientId: connection.clientId, eventId, outcome: { kind: 'next' } }).catch(() => client.close(1011));
            }
            return;
          }
          if (frame.type === 'end') {
            if (frame.streamId === 'history') client.close(1012, 'History ended');
            else if (!retired.has(frame.streamId)) { retired.add(frame.streamId); send({ type: 'capability-error', capability: frame.streamId, code: 'optional-stream-ended' }); }
            return;
          }
          if (frame.type !== 'item') return;
          if (frame.streamId === 'control') {
            const value = frame.value;
            if (value?.type === 'baseline') {
              const baseline = value.value?.projections?.[id];
              if (baseline) {
                questions(baseline.values?.userQuestions, baseline.asOfSeq ?? -1);
                sessionTitle(baseline.values?.title);
                publishProjectionValues(baseline.values, baseline.asOfSeq ?? -1);
                if (baseline.values?.inbox !== undefined) {
                  publishState({ queueKnown: true, queue: queueFromInbox(baseline.values.inbox) });
                }
              }
            } else if (value?.type === 'projection' && value.sessionId === id) {
              if (value.key === 'userQuestions') questions(value.value, value.seq);
              else if (value.key === 'title') sessionTitle(value.value);
              else if (value.key === 'inbox') {
                publishState({ queueKnown: true, queue: queueFromInbox(value.value) });
              }
              publishProjection(value.key, value.value, value.seq);
            }
          } else if (frame.streamId === 'projections') {
            if (frame.value?.type === 'ready') rpc('projections', { sessionId: id }).then(value => {
              questions(value?.values?.userQuestions, value?.asOfSeq ?? -1);
              sessionTitle(value?.values?.title);
              publishProjectionValues(value?.values, value?.asOfSeq ?? -1);
              if (value?.values?.inbox !== undefined) {
                publishState({ queueKnown: true, queue: queueFromInbox(value.values.inbox) });
              }
            }).catch(() => {});
            else if (frame.value?.type === 'projection') {
              if (frame.value.key === 'userQuestions') questions(frame.value.value, frame.value.seq);
              else if (frame.value.key === 'title') sessionTitle(frame.value.value);
              else if (frame.value.key === 'inbox') {
                publishState({ queueKnown: true, queue: queueFromInbox(frame.value.value) });
              }
              publishProjection(frame.value.key, frame.value.value, frame.value.seq);
            }
          } else if (frame.streamId?.startsWith('wait:')) {
            const eventId = frame.streamId.slice(5), pending = connection.pending.get(eventId);
            const duration = frame.value?.remainingMs;
            if (!pending || !Number.isFinite(duration) || duration < 0) return;
            pending.timer = setTimeout(() => {
              if (connection.pending.get(eventId) !== pending || pending.engaged) return;
              endInteraction(eventId);
              rpc('$events/result', { clientId: connection.clientId, eventId, outcome: { kind: 'rejected',
                error: { name: 'UserQuestionError', message: 'Question wait timed out', code: 'ASK_TIMED_OUT' } } }).catch(() => client.close(1011));
            }, duration);
            pending.timer.unref();
            send({ type: 'interaction', connectionId, eventId, interaction: pending.event, request: pending.request, remainingMs: duration });
          } else if (frame.streamId === 'interactions') {
            const value = frame.value;
            if (value.type === 'ready') connection.clientId = value.clientId;
            else if (value.type === 'emit' && value.event === 'api-session/status' && value.args?.[0] === id) {
              publishState({ running: value.args[1] === true });
            }
            else if (value.type === 'cancel') {
              endInteraction(value.eventId);
            } else if (value.type === 'waterfall' && connection.clientId) {
              // Delegate other sessions and unrecognised plugin interactions immediately.
              if (value.agentId !== id || !['approval/request', 'user-questions/request'].includes(value.event)) {
                rpc('$events/result', { clientId: connection.clientId, eventId: value.eventId, outcome: { kind: 'next' } }).catch(() => client.close(1011));
              } else {
                connection.pending.set(value.eventId, value);
                if (value.request?.wait?.timed === true) {
                  upstream.send(JSON.stringify({ type: 'open', streamId: 'wait:' + value.eventId, endpoint: 'userQuestions/attachWait',
                    payload: { args: { agent: id, callId: value.request.wait.callId } } }));
                } else send({ type: 'interaction', connectionId, eventId: value.eventId, interaction: value.event, request: value.request });
              }
            }
          } else if (frame.streamId === 'state') publishState({
            running: frame.value?.running === true,
            waiting: Array.isArray(frame.value?.pendingInput) && frame.value.pendingInput.length > 0,
            queueKnown: true,
            queue: frame.value?.queue
          });
          else if (frame.streamId === 'history') {
            const value = normalizeFollow(frame.value);
            if (frame.value?.type === 'snapshot' && !value) {
              throw new Error('Invalid snapshot frame');
            }
            if (value) {
              if (value.type === 'snapshot') {
                clearTimeout(opening);
                active.cursor = value.cursor; active.attemptId = value.attemptId || '';
                active.nextIndex = value.nextIndex || 0; active.revision = value.revision || 0;
              } else if (value.type === 'event') active.cursor = value.seq;
              else if (value.type === 'start') {
                active.attemptId = value.attemptId || ''; active.nextIndex = 0;
                active.revision = value.revision || 0;
              } else if (value.type === 'delta') {
                active.nextIndex = (value.index || 0) + 1;
                active.revision = value.revision || active.revision;
              } else if (value.type === 'end') {
                active.attemptId = ''; active.nextIndex = 0;
                active.revision = value.revision || active.revision;
              }
              send(value);
            } else if (frame.value?.type === 'assistant-stream') {
              // A malformed assistant revision cannot be repaired in-place:
              // dropping it would leave the socket healthy while the visible
              // answer stays frozen. Close this generation so the client
              // reopens from an authoritative snapshot and retains its partial.
              throw new Error('Invalid assistant stream frame');
            }
          }
        } catch (error) {
          // Location-only diagnostics: never log frame data or exception messages.
          console.error(JSON.stringify({ event: 'native_stream_error', kind: error?.name || 'Error', at: error?.stack?.split('\n')[1]?.trim() || '' }));
          client.close(1011, 'Invalid stream');
        }
      });
      client.on('message', () => client.close(1008, 'Read-only channel'));
      client.once('close', () => {
        clearInterval(heartbeat);
        clearInterval(deliveryDrain);
        connections.delete(connectionId);
        for (const pending of connection.pending.values()) clearTimeout(pending.timer);
        upstream.terminate();
      });
      client.on('error', () => upstream.terminate());
      upstream.on('error', () => { send({ type: 'error', message: '实时连接失败，请检查连接或切换兼容模式' }); client.close(1011); });
      upstream.once('close', () => { if (client.readyState === WebSocket.OPEN) client.close(1012); });
    });
  }
  return { routes, upgrade, close() { for (const client of wss.clients) client.terminate(); wss.close(); } };
}
