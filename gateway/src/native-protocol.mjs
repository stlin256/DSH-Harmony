const fullText = value => typeof value === 'string' ? value : value === undefined || value === null ? '' : JSON.stringify(value);
export const sessionIdValid = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,160}$/.test(value);
export function normalizeProjectionTitle(value) {
  if (typeof value !== 'string') return '';
  return value.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 160);
}

const permissionPresetPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;

/** Normalize one Host-owned permission preset identity. */
export function normalizePermissionPreset(value) {
  return typeof value === 'string' && permissionPresetPattern.test(value) ? value : '';
}

/** Normalize the complete Session permissions projection. */
export function normalizePermissionSelection(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const currentValue = normalizePermissionPreset(value.currentValue);
  return currentValue ? { currentValue } : null;
}

function normalizePermissionText(value, maxLength) {
  if (typeof value !== 'string') return '';
  return value.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, maxLength);
}

function normalizePermissionOption(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).some(key => !['value', 'name', 'description'].includes(key))) return null;
  const preset = normalizePermissionPreset(value.value);
  const name = normalizePermissionText(value.name, 120);
  if (!preset || !name) return null;
  const description = value.description === undefined
    ? ''
    : normalizePermissionText(value.description, 320);
  if (value.description !== undefined && !description) return null;
  return {
    value: preset,
    name,
    ...(description ? { description } : {})
  };
}

/**
 * Normalize the process permission catalogue without inventing options.
 * `custom` is display-only and `auto` can never be a future-session default.
 */
export function normalizePermissionCatalog(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).some(key => !['options', 'defaultOptions', 'defaultPreset'].includes(key)) ||
      !Array.isArray(value.options) || !Array.isArray(value.defaultOptions) ||
      value.options.length > 32 || value.defaultOptions.length > 32) return null;
  const options = [];
  const defaultOptions = [];
  const optionValues = new Set();
  for (const raw of value.options) {
    const option = normalizePermissionOption(raw);
    if (!option || option.value === 'custom' || optionValues.has(option.value)) return null;
    optionValues.add(option.value);
    options.push(option);
  }
  const defaultValues = new Set();
  for (const raw of value.defaultOptions) {
    const option = normalizePermissionOption(raw);
    if (!option || ['custom', 'auto'].includes(option.value) ||
        defaultValues.has(option.value) || !optionValues.has(option.value)) return null;
    defaultValues.add(option.value);
    defaultOptions.push(option);
  }
  const defaultPreset = normalizePermissionPreset(value.defaultPreset);
  if (!defaultPreset || !defaultValues.has(defaultPreset)) return null;
  return { options, defaultOptions, defaultPreset };
}

const subagentModes = new Set(['one-shot', 'continuable', 'external', 'unknown']);
const traversableSubagentModes = new Set(['one-shot', 'continuable', 'unknown']);

function normalizeProjectionLabel(value) {
  return normalizeProjectionTitle(value);
}

function nonNegativeSafeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

function cursorSafeInteger(value) {
  return Number.isSafeInteger(value) && value >= -1;
}

function stringRun(value) {
  return Array.isArray(value) && value.length > 0 &&
    value.every(item => typeof item === 'string');
}

function validAssistantStream(stream) {
  if (!Array.isArray(stream)) return false;
  return stream.every(record => {
    if (!record || typeof record !== 'object' || Array.isArray(record)) return false;
    if (record.type === 'text-chunks' || record.type === 'reasoning-chunks') {
      if (!Number.isSafeInteger(record.time0) ||
          !nonNegativeSafeInteger(record.index) ||
          !stringRun(record.texts) ||
          !Array.isArray(record.dt) ||
          record.dt.length !== record.texts.length - 1 ||
          !record.dt.every(value => Number.isSafeInteger(value) && value >= 0)) {
        return false;
      }
      return true;
    }
    if (record.type === 'tool-call-chunks') {
      if (!Number.isSafeInteger(record.time0) ||
          !nonNegativeSafeInteger(record.index) ||
          typeof record.id !== 'string' || !record.id ||
          (record.name !== undefined &&
            (typeof record.name !== 'string' || !record.name)) ||
          !stringRun(record.args) ||
          !Array.isArray(record.dt) ||
          record.dt.length !== record.args.length - 1 ||
          !record.dt.every(value => Number.isSafeInteger(value) && value >= 0)) {
        return false;
      }
      return true;
    }
    return record.type === 'chunk' &&
      Number.isSafeInteger(record.time) &&
      record.chunk !== null &&
      typeof record.chunk === 'object' &&
      !Array.isArray(record.chunk);
  });
}

/** Normalize the complete Plan projection wire value. */
export function normalizePlanProjection(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      typeof value.active !== 'boolean' || typeof value.pending !== 'boolean') return null;
  return { active: value.active, pending: value.pending };
}

/** Resolve the host-defined target of a Plan projection. */
export function planTargetActive(value) {
  const plan = normalizePlanProjection(value);
  return plan === null ? false : plan.pending ? !plan.active : plan.active;
}

/** Normalize a direct-child catalogue without inventing members. */
export function normalizeSubagentCatalog(value) {
  if (!Array.isArray(value)) return null;
  const seen = new Set();
  const rows = [];
  for (const entry of value.slice(0, 100)) {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry) ||
        !sessionIdValid(entry.id) || !nonNegativeSafeInteger(entry.createdAt) ||
        !subagentModes.has(entry.mode)) continue;
    if (seen.has(entry.id)) continue;
    const label = normalizeProjectionLabel(entry.label);
    if (entry.mode === 'continuable' && !label) continue;
    seen.add(entry.id);
    rows.push({
      id: entry.id,
      createdAt: entry.createdAt,
      mode: entry.mode,
      ...(label ? { label } : {})
    });
  }
  return rows;
}

/** Normalize a child-owned identity. Explicit null remains an authoritative reset. */
export function normalizeSubagentIdentity(value) {
  if (value === null) return null;
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      !['one-shot', 'continuable'].includes(value.mode) ||
      !nonNegativeSafeInteger(value.seq)) return null;
  const label = normalizeProjectionLabel(value.label);
  if (value.mode === 'continuable' && !label) return null;
  return {
    mode: value.mode,
    ...(label ? { label } : {}),
    seq: value.seq
  };
}

/** Normalize durable active-turn timing. */
export function normalizeSubagentTiming(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      !nonNegativeSafeInteger(value.settledMs)) return null;
  let active;
  if (value.active !== undefined) {
    if (!value.active || typeof value.active !== 'object' || Array.isArray(value.active) ||
        !nonNegativeSafeInteger(value.active.since) ||
        !nonNegativeSafeInteger(value.active.through) ||
        value.active.through < value.active.since) return null;
    active = { since: value.active.since, through: value.active.through };
  }
  if (value.lastTurnCompleted !== undefined && typeof value.lastTurnCompleted !== 'boolean') return null;
  return {
    settledMs: value.settledMs,
    ...(active ? { active } : {}),
    ...(value.lastTurnCompleted === undefined ? {} : { lastTurnCompleted: value.lastTurnCompleted })
  };
}

/** Normalize a traversable parent/child address. External is intentionally excluded. */
export function normalizeSubagentAddress(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      value.kind !== 'subagent' ||
      !sessionIdValid(value.parentSessionId) ||
      !sessionIdValid(value.childSessionId) ||
      value.parentSessionId === value.childSessionId ||
      !traversableSubagentModes.has(value.mode)) return null;
  return {
    kind: 'subagent',
    parentSessionId: value.parentSessionId,
    childSessionId: value.childSessionId,
    mode: value.mode
  };
}

function boundedString(value, maxLength) {
  return typeof value === 'string' ? value.slice(0, maxLength) : '';
}

function normalizedImageReference(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const { attachmentId, mediaType, bytes, width, height, name } = value;
  if (typeof attachmentId !== 'string' || !attachmentId || attachmentId.length > 4096 ||
      !['image/png', 'image/jpeg', 'image/webp', 'image/gif'].includes(mediaType) ||
      ![bytes, width, height].every(number => Number.isSafeInteger(number) && number > 0) ||
      (name !== undefined && (typeof name !== 'string' || name.length > 512))) return null;
  return {
    attachmentId,
    mediaType,
    bytes,
    width,
    height,
    ...(name === undefined ? {} : { name })
  };
}

function normalizedFileReference(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const { attachmentId, name, bytes } = value;
  if (typeof attachmentId !== 'string' || !attachmentId || attachmentId.length > 4096 ||
      typeof name !== 'string' || !name || name.length > 512 ||
      !Number.isSafeInteger(bytes) || bytes < 0) return null;
  return { attachmentId, name, bytes };
}

/**
 * Turn authoritative SessionState.queue rows into a bounded native display
 * contract. Only user queue rows are mutable by this client.
 */
export function normalizeQueuedState(value) {
  if (!Array.isArray(value)) return [];
  const result = [];
  let textBudget = 64 * 1024;
  for (const item of value) {
    if (result.length >= 50 || !item || typeof item !== 'object' || Array.isArray(item)) continue;
    if (typeof item.id !== 'string' || !item.id || item.id.length > 160 || item.placement !== 'queued' ||
        (item.rpcId !== undefined &&
          (typeof item.rpcId !== 'string' || !/^[A-Za-z0-9_-]{1,160}$/.test(item.rpcId))) ||
        (!Array.isArray(item.content) && !Array.isArray(item.blocks))) continue;
    const blocks = [];
    const content = Array.isArray(item.content) ? item.content : item.blocks;
    for (const block of content.slice(0, 40)) {
      if (!block || typeof block !== 'object' || Array.isArray(block)) continue;
      const kind = block.type || block.kind;
      if (kind === 'text' && typeof block.text === 'string' && textBudget > 0) {
        const text = block.text.slice(0, Math.min(textBudget, 64 * 1024));
        if (!text) continue;
        blocks.push({ kind: 'text', text });
        textBudget -= text.length;
      } else if (kind === 'image') {
        const image = normalizedImageReference(block.attachment || block.image);
        if (image) blocks.push({ kind: 'image', image });
      } else if (kind === 'file') {
        const file = normalizedFileReference(block.attachment || block.file);
        if (file) blocks.push({ kind: 'file', file });
      }
    }
    if (!blocks.length) continue;
    result.push({
      id: item.id,
      placement: 'queued',
      ...(item.rpcId === undefined ? {} : { rpcId: item.rpcId }),
      ...(typeof item.sourceKind === 'string' && item.sourceKind
        ? { sourceKind: item.sourceKind } : {}),
      ...(typeof item.sourceForm === 'string' && item.sourceForm
        ? { sourceForm: item.sourceForm } : {}),
      blocks
    });
  }
  return result;
}

/** Convert the modern control projection's next-turn inbox into queue rows. */
export function queueFromInbox(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || !Array.isArray(value['next-turn'])) return [];
  return normalizeQueuedState(value['next-turn'].filter(message => {
    if (!message || typeof message !== 'object' || Array.isArray(message)) return false;
    const source = message.source;
    return (source?.kind === 'user' || source?.kind === 'tool-jobs') &&
      (source.rpcId === undefined || typeof source.rpcId === 'string');
  }).map(message => ({
    id: message.id,
    placement: 'queued',
    ...(message.source.rpcId === undefined ? {} : { rpcId: message.source.rpcId }),
    sourceKind: message.source.kind,
    ...(typeof message.source.form === 'string' && message.source.form
      ? { sourceForm: message.source.form } : {}),
    content: message.content
  })));
}

export function textBlocks(content) {
  if (typeof content === 'string') return { text: fullText(content), reasoning: '' };
  const blocks = Array.isArray(content) ? content : [];
  const text = [], reasoning = [];
  for (const block of blocks) {
    if (block?.type === 'text') text.push(fullText(block.text));
    else if (block?.type === 'reasoning') reasoning.push(fullText(block.text));
    else if (block?.type === 'image' || block?.type === 'tool-call') continue;
    else text.push(fullText(block));
  }
  return { text: fullText(text.join('\n')), reasoning: fullText(reasoning.join('\n')) };
}
function textRuns(text) {
  return text.split(/\n\s*\n/).filter(part => part.trim()).map(part => {
    const heading = /^(#{1,4})\s+(.+)$/.exec(part.trim());
    if (heading) return { kind: 'heading', text: heading[2], language: '' };
    if (part.split('\n').every(line => /^>\s?/.test(line))) return { kind: 'quote', text: part.replace(/^>\s?/gm, ''), language: '' };
    return { kind: 'text', text: part.replace(/^[-*]\s+/gm, '• '), language: '' };
  });
}
export function richBlocks(text) {
  const result = [];
  const pattern = /```([^\n`]*)\n([\s\S]*?)```/g;
  let previous = 0;
  for (const match of text.matchAll(pattern)) {
    if (match.index > previous) result.push(...textRuns(text.slice(previous, match.index)));
    result.push({ kind: 'code', text: match[2], language: fullText(match[1].trim(), 30) });
    previous = match.index + match[0].length;
  }
  if (previous < text.length) result.push(...textRuns(text.slice(previous)));
  return result;
}
export function normalizeRecord(record) {
  const event = record?.event;
  if (record?.type !== 'event' || !event || !Number.isSafeInteger(event.seq)) return null;
  const data = event.data || {};
  let role, label, content, detail = '';
  let structuredMeta = null;
  const source = data.source || data.message?.source;
  const sourceKind = typeof source?.kind === 'string' ? source.kind : '';
  const sourceForm = typeof source?.form === 'string' ? source.form : '';
  if (event.type === 'user/message') {
    content = textBlocks(data.content);
    if (sourceKind === 'tool-jobs' && source?.form !== 'notice') return null;
    if (sourceKind === 'tool-jobs') {
      role = 'background-notice'; label = '后台任务';
    } else {
      if (sourceKind && !['user', 'client', 'steer'].includes(sourceKind)) return null;
      if (!sourceKind && /^(?:current runtime context\.|time sampled while preparing turn|browser time zone for this request:|elapsed since the preceding model-visible message:|current working directory:|current dsh file policy:|<system[-_]reminder>)/i.test(content.text.trimStart())) return null;
      role = 'user'; label = '你';
    }
  }
  else if (event.type === 'assistant/message') { role = 'assistant'; label = 'DeepSeek'; content = textBlocks(data.message?.content); }
  else if (event.type === 'tool/call') { role = 'tool'; label = '工具 · ' + fullText(data.name, 100); content = { text: fullText(data.arguments), reasoning: '' }; }
  else if (event.type === 'tool/result') { role = 'tool'; label = data.message?.isError ? '工具执行失败' : '工具结果'; content = textBlocks(data.message?.content); }
  else if (event.type === 'tool/ptc-dispatch-start' || event.type === 'tool/ptc-dispatch') {
    role = 'tool'; label = fullText(data.name); content = event.type.endsWith('-start') ? { text: fullText(data.arguments), reasoning: '' } : textBlocks(data.content);
  }
  else if (event.type === 'command/run' || event.type === 'command/done') {
    role = 'tool';
    label = event.type === 'command/run' ? '/' + fullText(data.name) : '命令结果';
    content = { text: fullText(event.type === 'command/run' ? data.args : data.text), reasoning: '' };
    structuredMeta = data;
  }
  else if (event.type === 'job/registered' || event.type === 'job/settled') {
    role = 'tool';
    label = event.type === 'job/registered' ? '后台任务已启动' : '后台任务已结束';
    content = {
      text: fullText(event.type === 'job/settled' ? data.detail : data.label),
      reasoning: ''
    };
    structuredMeta = data;
  }
  else if (event.type === 'deliverables/presented') {
    role = 'detail';
    label = '';
    content = { text: '', reasoning: '' };
    detail = JSON.stringify(data);
    structuredMeta = data;
  }
  else if (event.type === 'turn/start' || event.type === 'turn/end') {
    role = 'turn'; label = event.type === 'turn/start' ? '进行中' : data.reason?.kind === 'error' ? '执行失败' : data.reason?.kind === 'cancelled' ? '已停止' : '已完成';
    content = { text: event.type === 'turn/end' && data.reason?.kind === 'error' ? fullText(data.reason.error?.message || '任务执行失败') : '', reasoning: '' };
  }
  else if (event.type === 'step/end') { role = 'boundary'; label = ''; content = { text: '', reasoning: '' }; }
  else if (event.type === 'approval/asked') { role = 'notice'; label = '等待确认'; content = { text: '', reasoning: '' }; }
  else return null;
  const parts = event.type === 'user/message' ? data.content : event.type === 'assistant/message' || event.type === 'tool/result' ? data.message?.content : [];
  const images = Array.isArray(parts) ? parts.filter(part => part?.type === 'image' && part.attachment).map(part => part.attachment) : [];
  const segments = role === 'assistant' && Array.isArray(parts) ? parts.flatMap(part => {
    if (part?.type === 'text' || part?.type === 'reasoning') return [{ kind: part.type, text: fullText(part.text), blocks: richBlocks(fullText(part.text)), images: [] }];
    if (part?.type === 'image' && part.attachment) return [{ kind: 'image', text: '', blocks: [], images: [part.attachment] }];
    return [];
  }) : [];
  const callId = event.type === 'job/registered' || event.type === 'job/settled'
    ? data.jobId
    : data.callId ?? data.subCallId ?? data.message?.source?.callId ?? data.commandId;
  const toolName = event.type === 'command/run' || event.type === 'command/done'
    ? 'slash_command'
    : event.type === 'job/registered' || event.type === 'job/settled'
      ? 'job_lifecycle' : fullText(data.name);
  const phase = /(?:tool\/call|dispatch-start|command\/run|job\/registered)$/.test(event.type)
    ? 'start' : 'result';
  return { images, id: 'event-' + event.seq, seq: event.seq, role, label, text: content.text, reasoning: content.reasoning,
    metaRaw: JSON.stringify(structuredMeta ?? data.message?.meta ?? data.meta ?? null), contentRaw: JSON.stringify(parts || []),
    errorRaw: JSON.stringify(data.message?.error ?? data.error ?? null),
    blocks: richBlocks(content.text), segments, detail, eventType: event.type, sourceKind, sourceForm,
    turn: Number.isSafeInteger(data.turn) ? data.turn : -1, step: Number.isSafeInteger(data.step) ? data.step : -1,
    time: Number.isFinite(event.time) ? event.time : 0, callId: callId == null ? '' : String(callId),
    parentCallId: fullText(data.parentCallId), rootCallId: fullText(data.rootCallId),
    toolName, phase,
    failed: data.message?.isError === true || data.isError === true ||
      data.kind === 'error' || data.status === 'failed' || data.status === 'killed',
    outcome: fullText(data.reason?.kind) || fullText(data.status),
    error: fullText(data.error?.message || data.error?.reason || data.detail || ''),
    authoritativeRaw: event.type === 'deliverables/presented' ? JSON.stringify(data) : '' };
}
export function normalizedHistory(records) {
  let messages = [];
  for (const record of Array.isArray(records) ? records : []) {
    const op = record?.event?.surfaceOp;
    if (op?.op === 'replace') messages = messages.filter(row => row.seq < op.startSeq || row.seq > op.endSeq);
    const row = normalizeRecord(record);
    if (row) messages.push(row);
  }
  return { messages, journal: (records || []).filter(record => record?.type === 'event' && Number.isSafeInteger(record.event?.seq))
    .map(record => ({ seq: record.event.seq, raw: JSON.stringify(record.event) })), trimmed: false, replacements: (records || []).map(record => record.event?.surfaceOp)
    .filter(op => op?.op === 'replace').map(op => ({ start: op.startSeq, end: op.endSeq })) };
}
function appendTextStreamPart(parts, kind, value) {
  const text = fullText(value);
  if (!text) return;
  const last = parts[parts.length - 1];
  if (last?.kind === kind) {
    last.text += text;
    return;
  }
  parts.push({ kind, text });
}
function appendToolStreamPart(parts, update) {
  if (!update?.callId) return;
  const existing = parts.find(part => part.kind === 'tool' && part.callId === update.callId);
  if (existing) {
    if (update.name && !existing.name) existing.name = update.name;
    return;
  }
  parts.push({ kind: 'tool', callId: update.callId, name: update.name || '' });
}
export function compactText(stream) {
  let text = '', reasoning = '';
  const toolUpdates = [];
  const streamParts = [];
  for (const record of Array.isArray(stream) ? stream : []) {
    if (record?.type === 'text-chunks' && stringRun(record.texts)) {
      const value = record.texts.join('');
      text += value;
      appendTextStreamPart(streamParts, 'text', value);
    }
    if (record?.type === 'reasoning-chunks' && stringRun(record.texts)) {
      const value = record.texts.join('');
      reasoning += value;
      appendTextStreamPart(streamParts, 'reasoning', value);
    }
    if (record?.type === 'tool-call-chunks' && stringRun(record.args)) {
      const update = {
        callId: record.id,
        name: fullText(record.name),
        argsDelta: record.args.join(''),
        arguments: '',
        replace: false,
      };
      toolUpdates.push(update);
      appendToolStreamPart(streamParts, update);
    }
    if (record?.type === 'chunk' && record.chunk?.type === 'text-delta') {
      const value = fullText(record.chunk.text);
      text += value;
      appendTextStreamPart(streamParts, 'text', value);
    }
    if (record?.type === 'chunk' && record.chunk?.type === 'reasoning-delta') {
      const value = fullText(record.chunk.text);
      reasoning += value;
      appendTextStreamPart(streamParts, 'reasoning', value);
    }
    if (record?.type === 'chunk') {
      const update = toolUpdate(record.chunk);
      if (update) {
        toolUpdates.push(update);
        appendToolStreamPart(streamParts, update);
      }
    }
  }
  return {
    text: fullText(text),
    reasoning: fullText(reasoning),
    ...(toolUpdates.length ? { toolUpdates } : {}),
    ...(streamParts.length ? { streamParts } : {}),
  };
}
function toolUpdate(chunk) {
  if (chunk?.type === 'tool-call-delta') return { callId: String(chunk.id), name: fullText(chunk.name), argsDelta: fullText(chunk.argumentsDelta), arguments: '', replace: false };
  if (chunk?.type === 'block-end' && chunk.block?.type === 'tool-call') return { callId: String(chunk.block.id), name: fullText(chunk.block.name), argsDelta: '', arguments: fullText(chunk.block.arguments), replace: true };
  return null;
}
export function normalizeFollow(frame) {
  if (frame?.type === 'snapshot') {
    const active = frame.assistantStream?.activeAttempt;
    if (!cursorSafeInteger(frame.cursor) ||
        !nonNegativeSafeInteger(frame.assistantStream?.revision) ||
        typeof frame.hasMore !== 'boolean' ||
        !Array.isArray(frame.records) ||
        frame.records.some(record => record?.type !== 'event' ||
          !nonNegativeSafeInteger(record.event?.seq))) return null;
    for (let index = 1; index < frame.records.length; index += 1) {
      if (frame.records[index].event.seq !==
          frame.records[index - 1].event.seq + 1) return null;
    }
    if (frame.records.length > 0 &&
        frame.records[frame.records.length - 1].event.seq !== frame.cursor) {
      return null;
    }
    for (const record of frame.records) {
      const op = record.event.surfaceOp;
      if (op && typeof op === 'object' && op.op === 'replace' &&
          (!nonNegativeSafeInteger(op.startSeq) ||
           !nonNegativeSafeInteger(op.endSeq) ||
           op.startSeq > op.endSeq)) return null;
    }
    if (active !== undefined && active !== null) {
      if (!active || typeof active !== 'object' || Array.isArray(active) ||
          typeof active.attemptId !== 'string' || !active.attemptId ||
          !cursorSafeInteger(active.startedAfterSeq) ||
          !nonNegativeSafeInteger(active.nextIndex) ||
          !nonNegativeSafeInteger(active.turn) ||
          !nonNegativeSafeInteger(active.step) ||
          !validAssistantStream(active.stream)) return null;
    }
    const history = normalizedHistory(frame.records);
    return { type: 'snapshot', ...history, cursor: frame.cursor, hasMore: frame.hasMore, beforeSeq: frame.records?.[0]?.event?.seq ?? 0,
      attemptId: active?.attemptId || '', nextIndex: active?.nextIndex ?? 0,
      revision: frame.assistantStream.revision,
      startedAfterSeq: active?.startedAfterSeq ?? -1,
      turn: active?.turn ?? -1,
      step: active?.step ?? -1,
      ...compactText(active?.stream) };
  }
  if (frame?.type === 'event') {
    const op = frame.event?.surfaceOp;
    return { type: 'event', seq: frame.event?.seq, message: normalizeRecord(frame),
      journal: Number.isSafeInteger(frame.event?.seq) ? [{ seq: frame.event.seq, raw: JSON.stringify(frame.event) }] : [],
      replaceStart: op?.op === 'replace' ? op.startSeq : -1, replaceEnd: op?.op === 'replace' ? op.endSeq : -1 };
  }
  if (frame?.type === 'assistant-stream') {
    const item = frame.frame;
    if (!item || typeof item.attemptId !== 'string' || !item.attemptId ||
        !Number.isSafeInteger(item.revision) || item.revision < 0) return null;
    if (item.type === 'start') {
      if (!cursorSafeInteger(item.startedAfterSeq) ||
          !nonNegativeSafeInteger(item.turn) ||
          !nonNegativeSafeInteger(item.step)) return null;
      return { type: 'start', attemptId: item.attemptId, nextIndex: 0,
        revision: item.revision, startedAfterSeq: item.startedAfterSeq,
        turn: item.turn, step: item.step };
    }
    if (item.type === 'chunk' && Number.isSafeInteger(item.index) && item.index >= 0) {
      const update = toolUpdate(item.chunk);
      const text = item.chunk?.type === 'text-delta' ? fullText(item.chunk.text) : '';
      const reasoning = item.chunk?.type === 'reasoning-delta' ? fullText(item.chunk.text) : '';
      const streamParts = [];
      if (text) streamParts.push({ kind: 'text', text });
      if (reasoning) streamParts.push({ kind: 'reasoning', text: reasoning });
      if (update) appendToolStreamPart(streamParts, update);
      return { type: 'delta', attemptId: item.attemptId, revision: item.revision, index: item.index,
        text, reasoning,
        ...(update ? { toolUpdates: [update] } : {}),
        ...(streamParts.length ? { streamParts } : {}) };
    }
    if (item.type === 'end' && Number.isSafeInteger(item.index) && item.index >= 0) {
      const outcomeKind = item.outcome?.kind;
      if (!['committed', 'abandoned'].includes(outcomeKind)) return null;
      if (outcomeKind === 'committed' && !nonNegativeSafeInteger(item.outcome?.seq)) return null;
      if (outcomeKind === 'committed' &&
          !['assistant/message', 'assistant/attempt'].includes(item.outcome?.eventType)) {
        return null;
      }
      return { type: 'end', attemptId: item.attemptId, revision: item.revision, index: item.index,
      outcomeKind: outcomeKind,
      committedEventType: outcomeKind === 'committed' ? item.outcome.eventType : '',
      committedSeq: outcomeKind === 'committed' ? item.outcome.seq : -1 };
    }
  }
  return null;
}
