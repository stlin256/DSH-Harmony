import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer, request } from 'node:http';
import { randomBytes, createHash } from 'node:crypto';
import { once } from 'node:events';
import { readFileSync } from 'node:fs';
import WebSocket, { WebSocketServer } from 'ws';
import { openStore } from '../src/store.mjs';
import { createApp } from '../src/app.mjs';
import {
  normalizeFollow,
  normalizePermissionCatalog,
  normalizePermissionPreset,
  normalizePermissionSelection,
  normalizeProjectionTitle,
  normalizedHistory,
  queueFromInbox,
  richBlocks,
  normalizeRecord
} from '../src/native-protocol.mjs';
import {
  changedFilesSummary,
  nativeDeliveryDrainReady,
  nativeDeliveryStallReady,
  nativeHeartbeatPayload,
  nativeHeartbeatPolicy,
  normalizedProjectionSnapshot
} from '../src/native-harness.mjs';

const origin = 'https://dsh.example.com';

test('native heartbeat policy keeps foreground and background deadlines bounded', () => {
  assert.deepEqual(nativeHeartbeatPolicy(), { intervalMs: 5000, deadlineMs: 20000, openingMs: 30000 });
  assert.deepEqual(nativeHeartbeatPolicy('foreground'), { intervalMs: 5000, deadlineMs: 20000, openingMs: 30000 });
  assert.deepEqual(nativeHeartbeatPolicy('background'), { intervalMs: 15000, deadlineMs: 45000, openingMs: 45000 });
});

test('native heartbeat carries generation-bound progress and authoritative run state', () => {
  assert.deepEqual(nativeHeartbeatPayload('generation-a', {
    cursor: 17, attemptId: 'attempt', nextIndex: 4, revision: 9
  }, true, true, false), {
    type: 'heartbeat',
    generation: 'generation-a',
    cursor: 17,
    attemptId: 'attempt',
    nextIndex: 4,
    revision: 9,
    stateKnown: true,
    running: true,
    waiting: false
  });
  assert.equal(nativeHeartbeatPayload('generation-a', {
    cursor: -1, attemptId: '', nextIndex: 0, revision: 0
  }, false, true, true).stateKnown, false);
});

test('native delivery drain requires pause, low buffer and an open upstream', () => {
  assert.equal(nativeDeliveryDrainReady(true, 32 * 1024, 32 * 1024, true), true);
  assert.equal(nativeDeliveryDrainReady(false, 0, 32 * 1024, true), false);
  assert.equal(nativeDeliveryDrainReady(true, 32 * 1024 + 1, 32 * 1024, true), false);
  assert.equal(nativeDeliveryDrainReady(true, 0, 32 * 1024, false), false);
  assert.equal(nativeDeliveryDrainReady(true, Number.NaN, 32 * 1024, true), false);
});


test('native delivery stall watchdog bounds backpressure pauses', () => {
  const now = 1000000;
  assert.equal(nativeDeliveryStallReady(true, now - 60000, now), true);
  assert.equal(nativeDeliveryStallReady(true, now - 59999, now), false);
  assert.equal(nativeDeliveryStallReady(false, now - 60000, now), false);
  assert.equal(nativeDeliveryStallReady(true, 0, now), false);
  assert.equal(nativeDeliveryStallReady(true, Number.NaN, now), false);
  assert.equal(nativeDeliveryStallReady(true, now - 119999, now, 120000), false);
});

test('native live closes a generation when assistant revision data is incomplete', async t => {
  const { connect } = await setup(t, { malformedAssistantFrame: true });
  const ws = connect();
  const closed = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(Error('malformed stream was not closed')), 2000);
    ws.once('close', code => {
      clearTimeout(timer);
      resolve(code);
    });
  });
  await once(ws, 'open');
  assert.equal(await closed, 1011);
});

test('native live closes a generation when the opening snapshot is malformed', async t => {
  const { connect } = await setup(t, { malformedSnapshot: true });
  const ws = connect();
  const closed = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(Error('malformed snapshot was not closed')), 2000);
    ws.once('close', code => {
      clearTimeout(timer);
      resolve(code);
    });
  });
  await once(ws, 'open');
  assert.equal(await closed, 1011);
});

async function setup(t, options = {}) {
  const calls = [];
  const uploads = [];
  const backend = createServer(async (req, res) => {
    if (req.method === 'GET' || req.method === 'HEAD') {
      assert.equal(req.headers.cookie, 'harness=server-only');
      const route = new URL(req.url, 'http://localhost');
      if (route.pathname === '/api/changes.summary') {
        assert.equal(route.searchParams.get('seq'), '17');
        if (options.changesUnavailable) { res.writeHead(404).end(); return; }
        if (options.changesMalformed) {
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ turn: 1, cwd: '/private/workspace', total: 1, added: 4, deleted: 2,
            files: [{ path: 'src/app.ts', display: 'app.ts', added: 4, deleted: 2, binary: false, cookie: 'no' }] }));
          return;
        }
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ turn: 1, cwd: '/private/workspace',
          snapshot: { before: 'private-before', after: 'private-after' },
          total: 2, added: 7, deleted: 3, files: [
            { path: 'src/app.ts', display: 'app.ts', added: 5, deleted: 3 },
            { path: 'assets/logo.bin', display: 'logo.bin', added: 0, deleted: 0, binary: true }
          ] }));
        return;
      }
      if (options.unavailableExports) { res.writeHead(404).end(); return; }
      if (options.htmlExport) { res.setHeader('Content-Type','text/html'); res.end('<h1>Authentication required</h1>'); return; }
      assert.equal(route.searchParams.get('sessionId'), 'session');
      if (route.pathname === '/api/session.markdown') { res.setHeader('Content-Type','text/markdown'); res.end('# Complete transcript\n\nnot just the visible window'); return; }
      if (route.pathname === '/api/session.export') { assert.equal(route.searchParams.get('includeDescendants'),'true'); res.setHeader('Content-Type','application/zip'); res.end(Buffer.from([0x50,0x4b,3,4,0,255])); return; }
      res.writeHead(404).end(); return;
    }
    const route = new URL(req.url, 'http://localhost');
    const chunks = []; for await (const part of req) chunks.push(part);
    if (route.pathname === '/api/session/uploadFileBinary') {
      assert.equal(req.headers.cookie, 'harness=server-only');
      assert.equal(req.headers['content-type'], 'application/octet-stream');
      const bytes = Buffer.concat(chunks);
      uploads.push({ query: Object.fromEntries(route.searchParams), bytes, headers: req.headers });
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ ok: true, value: { receiptId: 'receipt-1',
        file: { attachmentId: 'attachment-1', name: route.searchParams.get('name'), bytes: bytes.length } } }));
      return;
    }
    const value = JSON.parse(Buffer.concat(chunks).toString());
    calls.push({ headers: req.headers, value });
    if (options.readBytesErrorCode && value.method === 'workspaceFiles/readBytes') {
      res.setHeader('Content-Type','application/json');
      res.end(JSON.stringify({ type:'server-response', rpcId:value.rpcId,
        result:{ ok:false, error:{ code: options.readBytesErrorCode } } }));
      return;
    }
    if (options.workspaceFileError && value.method === 'workspaceFiles/stat') {
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ type: 'server-response', rpcId: value.rpcId,
        result: { ok: false, error: { code: 'workspace-file/not-found' } } }));
      return;
    }
    let result;
    if (value.method === 'workspaceFiles/read') {
      result = { absolutePath: '/workspace/project/README.md', version: 'v7', text: '# Fixture\n\npreview', lines: 3, offset: 1, eof: true };
    } else if (value.method === 'workspaceFiles/stat') {
      result = { absolutePath: '/workspace/project/file.txt', version: 'v8', bytes: 7 };
    } else if (value.method === 'workspaceFiles/list') {
      const path = value.payload.args.path;
      result = { path: path === '.' ? '' : path, entries: [
        { name: 'nested', type: 'directory' },
        { name: 'file.txt', type: 'file', size: 7 },
        { name: 'socket', type: 'other' }
      ], truncated: false };
    } else if (value.method === 'workspaceFiles/readBytes') {
      const bytes = options.emptyReadBytes ? [] : [0, 1, 2, 255, 65, 66, 67];
      const form = new FormData();
      form.set('metadata', JSON.stringify({
        type: 'server-response',
        rpcId: value.rpcId,
        result: { ok: true, value: {
          absolutePath: '/workspace/project/file.txt', version: 'v8', bytes: bytes.length,
          offset: value.payload.args.options.range.offset, data: null, eof: true
        } },
        attachments: [{ codec: 'bytes', part: 'bytes-0', path: ['data'] }]
      }));
      form.set('bytes-0', new Blob([Buffer.from(bytes)]), 'bytes.bin');
      if (options.unexpectedAttachment) {
        form.set('bytes-extra', new Blob([Buffer.from([9])]), 'extra.bin');
      }
      const encoded = new Response(form);
      res.writeHead(200, Object.fromEntries(encoded.headers));
      res.end(Buffer.from(await encoded.arrayBuffer()));
      return;
    } else if (value.method === 'session/list') {
      assert.deepEqual(value.payload.args, { _request: {} }, 'source _request parameter must keep its exact wire name');
      result = { items: [{
        sessionId: 'session', blank: false,
        ...(options.omitAgentAvailable ? {} : { agentAvailable: true }),
        running: true, updatedAt: 42,
        projections: { values: { title: 'Native session' } }
      }] };
    } else if (value.method === 'session/create') result = {sessionId:value.payload.args.request.sessionId};
    else if (value.method === 'pluginManager/listBundles') result = [{
      name: 'dsh.example', official: false, availability: 'profile', enabled: true,
      installed: true, removable: true, updatable: true, optional: false,
      version: '1.2.3', description: 'Example bundle', rows: []
    }];
    else if (value.method === 'pluginManager/listPlugins') result = [{
      entryId: 'entry', moduleName: 'dsh.example/main', enabled: true,
      fiberPhase: 'active'
    }];
    else if (['pluginManager/setBundleEnabled', 'pluginManager/setPluginEnabled',
      'pluginManager/installBundle', 'pluginManager/removeBundle'].includes(value.method)) {
      result = { changed: true, application: 'applied', stage: value.method.endsWith('removeBundle') ? 'remove' : 'enable',
        target: value.payload.args.name || value.payload.args.spec || value.payload.args.id };
    } else if (value.method === 'pluginManager/inspect') {
      result = { status: 'accepted', kind: 'registry', name: 'dsh.example',
        version: '1.2.3', bundle: true, registry: null };
    } else if (value.method === 'pluginManager/listVersions') {
      result = { status: 'listed', installed: '1.2.3', registry: null, omitted: 0, versions: [] };
    } else if (value.method === 'pluginManager/updateBundle') {
      result = { from: '1.2.3', to: '1.3.0', step: 'install',
        result: { changed: true, application: 'applied', stage: 'install', target: 'dsh.example@1.3.0' } };
    } else if (value.method === 'schedule/catalog') result = [{
      id: 'schedule-one', kind: 'every', title: 'Periodic check', prompt: 'Run the check',
      everySeconds: 900, scheduledAt: '2026-11-02T00:00:00.000Z', status: 'active',
      target: { kind: 'new_once', create: {} }, updatedAt: '2026-11-01T00:00:00.000Z'
    }];
    else if (value.method === 'schedule/view') result = {
      id: 'schedule-one', kind: 'every', title: 'Periodic check', prompt: 'Run the check',
      everySeconds: 900, scheduledAt: '2026-11-02T00:00:00.000Z', status: 'active',
      target: { kind: 'new_once', create: {} }, updatedAt: '2026-11-01T00:00:00.000Z'
    };
    else if (value.method === 'schedule/history') result = {
      id: 'schedule-one', records: [], earlierRecordsUnavailable: false, earlierRecordsPruned: false
    };
    else if (value.method === 'schedule/create') result = {
      id: 'schedule-created', kind: value.payload.args.request.timing.kind,
      title: value.payload.args.request.title, prompt: value.payload.args.request.prompt,
      ...(value.payload.args.request.timing.kind === 'every'
        ? { everySeconds: value.payload.args.request.timing.every_seconds } : {}),
      scheduledAt: '2026-11-02T00:00:00.000Z', status: 'active',
      target: value.payload.args.request.target || { kind: 'new_once', create: {} },
      updatedAt: '2026-11-01T00:00:00.000Z'
    };
    else if (value.method === 'schedule/edit') result = options.scheduleConflict
      ? { id: 'schedule-one', code: 'schedule_conflict' }
      : value.payload.args.request.action === 'delete'
        ? { id: 'schedule-one', deleted: true }
        : { id: 'schedule-one', kind: 'every', title: 'Edited', prompt: 'Run the check',
          everySeconds: 900, scheduledAt: '2026-11-02T00:00:00.000Z', status: 'paused',
          target: { kind: 'new_once', create: {} }, updatedAt: '2026-11-01T00:01:00.000Z' };
    else if (value.method === 'schedule/run') result = {
      id: 'schedule-one', kind: 'every', title: 'Periodic check', prompt: 'Run the check',
      everySeconds: 900, scheduledAt: '2026-11-02T00:00:00.000Z', status: 'active',
      target: { kind: 'new_once', create: {} }, updatedAt: '2026-11-01T00:00:00.000Z'
    };
    else if (value.method === 'settings/describe') result = {writable:true,namespaces:[
      {ns:'ui-chat',value:{transcriptView:'standard'},revision:4},
      ...(options.permissionSettings ? [{ns:'permission',value:{
        defaultPreset:'workspace-write', hidden:'must-not-forward'
      },revision:6}] : []),
      {ns:'private-provider',value:{credential:'must-not-forward'},revision:1}
    ]};
    else if (value.method === 'settings/mutate') result = {ns:value.payload.args.ns,value:{[value.payload.args.ops[0].path[0]]:value.payload.args.ops[0].value},revision:5};
    else if (value.method === 'commands/execute') result = options.commandRejected ?
      { commandId: 'cmd-1', result: { kind: 'error', text: 'preset not applied' } } :
      { commandId: 'cmd-1', result: { kind: 'success', text: 'preset applied' } };
    else if (value.method === 'permissionPresets/catalog') result = {
      options: [
        { value: 'read-only', name: 'Read Only', description: 'Inspect only' },
        { value: 'workspace-write', name: 'Workspace Write', description: 'Edit the workspace' },
        { value: 'danger-full-access', name: 'Full access', description: 'Use full access' },
        { value: 'auto', name: 'Auto review', description: 'Review automatically' }
      ],
      defaultOptions: [
        { value: 'read-only', name: 'Read Only' },
        { value: 'workspace-write', name: 'Workspace Write' },
        { value: 'danger-full-access', name: 'Full access' }
      ],
      defaultPreset: 'workspace-write'
    };
    else if (value.method === 'session/page') result = { records:[{type:'event',event:{seq:0,type:'user/message',data:{content:[{type:'text',text:'older'}]}}}], cursor:3,hasMore:false };
    else if (value.method === 'session/projections') result = {
      kind: 'sequenced', asOfSeq: 12, values: {
        title: 'Native session',
        plan: { active: false, pending: true },
        subagentCatalog: [{
          id: 'child-a', createdAt: 50, mode: 'continuable', label: 'Reviewer'
        }],
        subagent: { mode: 'continuable', label: 'Reviewer', seq: 7 },
        subagentTiming: {
          settledMs: 1200, active: { since: 20, through: 30 }, lastTurnCompleted: false
        }
      }
    };
    else result = {accepted:true};
    res.setHeader('Content-Type','application/json');
    res.end(JSON.stringify({type:'server-response',rpcId:value.rpcId,result:{ok:true,value:result}}));
  });
  const upstreamWS = new WebSocketServer({noServer:true});
  const openings = [];
  backend.on('upgrade',(req,socket,head)=>{
    assert.equal(req.url,'/api/remote.mux');
    assert.equal(req.headers.cookie,'harness=server-only');
    assert.equal(req.headers.origin,`http://127.0.0.1:${backend.address().port}`);
    upstreamWS.handleUpgrade(req,socket,head,ws=>{
      upstreamWS.emit('connection',ws);
      ws.on('message',raw=>{
        const frame=JSON.parse(raw); openings.push(frame);
        assert.equal(frame.type,'open');
        if (frame.endpoint === 'workspace/follow') {
          assert.deepEqual(frame.payload,{args:{}});
          ws.send(JSON.stringify({type:'item',streamId:frame.streamId,value:{type:'baseline',value:{items:[
            {workspaceId:'workspace',title:'Project',path:'/workspace/project',sessionIds:['session']}
          ],archivedSessionIds:['archived'],pinnedSessionIds:['session']}}})); return;
        }
        if (frame.endpoint === 'userQuestions/attachWait') {
          assert.deepEqual(frame.payload.args,{agent:'session',callId:'timed-call'});
          ws.send(JSON.stringify({type:'item',streamId:frame.streamId,value:{remainingMs:options.waitRemainingMs ?? 80}}));
          if (options.renewWaitMs) ws.send(JSON.stringify({type:'item',streamId:frame.streamId,value:{remainingMs:options.renewWaitMs}}));
          return;
        }
        if (frame.endpoint === '$events') {
          assert.deepEqual(frame.payload, {args:{}});
          ws.send(JSON.stringify({type:'item',streamId:frame.streamId,value:{type:'ready',clientId:'client-generation',host:{home:'~'}}}));
          return;
        }
        if (frame.endpoint === 'session/observeProjections' && !options.modern) {
          assert.deepEqual(frame.payload, {args:{request:{sessionId:'session'}}});
          ws.send(JSON.stringify({type:'item',streamId:frame.streamId,value:{type:'ready'}}));
          ws.send(JSON.stringify({type:'item',streamId:frame.streamId,value:{
            type:'projection',changes:[{key:'title',val:'Initial live title'}],seq:1
          }}));
          return;
        }
        if (options.modern && ['session/observeState', 'session/observeProjections'].includes(frame.endpoint)) {
          ws.send(JSON.stringify({ type: 'error', streamId: frame.streamId, error: { code: 'gateway/invocation-unavailable' } })); return;
        }
        if (frame.endpoint === 'session/control') {
          assert.deepEqual(frame.payload, { args: {} });
          ws.send(JSON.stringify({ type: 'item', streamId: frame.streamId, value: { type: 'baseline', value: {
            projections: { session: { asOfSeq: 0, values: {
              userQuestions: { active: [] }, title: 'Initial control title',
              plan: { active: false, pending: true },
              subagentCatalog: [{
                id: 'child-a', createdAt: 50, mode: 'continuable', label: 'Reviewer'
              }],
              subagent: { mode: 'continuable', label: 'Reviewer', seq: 7 },
              subagentTiming: {
                settledMs: 1200, active: { since: 20, through: 30 }, lastTurnCompleted: false
              },
              inbox: { 'next-turn': [{
                id: 'control-queued', source: { kind: 'user', rpcId: 'control-request' },
                content: [{ type: 'text', text: 'queued from control' }]
              }], 'next-step': [] }
            } } }
          } } })); return;
        }
        assert.equal(frame.payload.args.request.sessionId ||
          frame.payload.args.request.address.sessionId ||
          frame.payload.args.request.address.childSessionId, 'session');
        if(frame.endpoint==='session/follow') {
          if (options.historyError) {
            ws.send(JSON.stringify({ type: 'error', streamId: frame.streamId,
              error: { code: options.historyError, message: 'SYNTHETIC-PRIVATE-DETAIL', details: { id: 'synthetic-private' } } }));
            return;
          }
          ws.send(JSON.stringify({type:'item',streamId:frame.streamId,value:{type:'snapshot',cursor:options.malformedSnapshot?-2:0,hasMore:false,
            records:[{type:'event',event:{seq:0,type:'user/message',data:{content:[{type:'text',text:options.text || 'hello'}]}}}],
            assistantStream:{revision:0,activeAttempt:{attemptId:'attempt',startedAfterSeq:0,turn:0,step:0,nextIndex:2,stream:[{type:'text-chunks',time0:0,index:0,dt:[1],texts:['he','l']}]}}}}));
          ws.send(JSON.stringify({type:'item',streamId:frame.streamId,value:{type:'assistant-stream',frame:{
            type:'chunk',
            ...(options.malformedAssistantFrame ? {} : { revision:1 }),
            attemptId:'attempt',index:2,chunk:{type:'text-delta',text:'lo'}
          }}}));
        } else if(frame.endpoint==='session/observeState') ws.send(JSON.stringify({type:'item',streamId:frame.streamId,value:{
          running:true,pendingInput:['approval'],queue:[{
            id:'state-queued',placement:'queued',rpcId:'state-request',content:[
              {type:'text',text:'queued from state'},
              {type:'file',attachment:{attachmentId:'file-id',name:'notes.txt',bytes:12}}
            ]
          },{
            id:'state-context',placement:'context',content:[{type:'text',text:'hidden'}]
          }]
        }}));
      });
    });
  });
  await new Promise(resolve=>backend.listen(0,'127.0.0.1',resolve));
  const db=openStore(':memory:');
  const token=randomBytes(32).toString('base64url');
  const cookie='pocket='+token;
  db.prepare('INSERT INTO sessions VALUES (?,?)').run(createHash('sha256').update(token).digest('hex'),Date.now()+60000);
  const pocket=createApp({db,origin,upstream:`http://127.0.0.1:${backend.address().port}`,upstreamCookie:'harness=server-only',bootstrapSecret:'bootstrap-'.repeat(8),eventSecret:'events-'.repeat(8),pushConfigured:true});
  const server=createServer(pocket.app); server.on('upgrade',pocket.upgrade);
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  t.after(()=>{pocket.close();for(const ws of upstreamWS.clients)ws.terminate();upstreamWS.close();server.closeAllConnections();server.close();backend.closeAllConnections();backend.close();db.close();});
  const call=(path,body,authorized=true)=>new Promise((resolve,reject)=>{
    const req=request({hostname:'127.0.0.1',port:server.address().port,path,method:body===undefined?'GET':'POST',headers:{host:'dsh.example.com',origin,'content-type':'application/json',...(authorized?{cookie:typeof authorized === 'string' ? authorized : cookie}:{})}},res=>{
      const chunks=[];res.on('data',part=>chunks.push(part));res.on('end',()=>{
        const buffer=Buffer.concat(chunks);
        resolve({status:res.statusCode,headers:res.headers,buffer,text:buffer.toString()});
      });
    });req.on('error',reject);req.end(body===undefined?undefined:JSON.stringify(body));
  });
  const upload=(path,bytes,headers={})=>new Promise((resolve,reject)=>{
    const req=request({hostname:'127.0.0.1',port:server.address().port,path,method:'POST',
      headers:{host:'dsh.example.com',origin,'content-type':'application/octet-stream',cookie,...headers}},res=>{
      const chunks=[];res.on('data',part=>chunks.push(part));res.on('end',()=>{
        const buffer=Buffer.concat(chunks);resolve({status:res.statusCode,text:buffer.toString()});
      });
    });req.on('error',reject);req.end(bytes);
  });
  const connect=(headers={},query='')=>new WebSocket(`ws://127.0.0.1:${server.address().port}/pocket/native/live?sessionId=session${query}`,{headers:{Host:'dsh.example.com',Origin:origin,Cookie:cookie,...headers}});
  return {call,upload,calls,uploads,connect,openings,db,
    emit: value => { for (const ws of upstreamWS.clients) ws.send(JSON.stringify({type:'item',streamId:'interactions',value})); },
    emitProjection: (streamId, value) => { for (const ws of upstreamWS.clients) ws.send(JSON.stringify({type:'item',streamId,value})); }};
}

test('current Host projection batches deliver every same-sequence key', async t => {
  const { connect, emitProjection } = await setup(t);
  const ws = connect();
  const frames = [];
  ws.on('message', raw => frames.push(JSON.parse(raw.toString())));
  await once(ws, 'open');
  for (let i = 0; i < 100 && !frames.some(f => f.type === 'snapshot'); i++) await new Promise(r => setTimeout(r, 5));
  emitProjection('projections', { type: 'projection', seq: 50, changes: [
    { key: 'plan', val: { active: true, pending: false } },
    { key: 'subagentCatalog', val: [{ id: 'child-new', createdAt: 1, mode: 'continuable', label: 'Synthetic child' }] },
    { key: 'subagent', val: null },
  ] });
  for (let i = 0; i < 100 && !frames.some(f => f.type === 'subagent-identity' && f.projectionSeq === 50); i++) await new Promise(r => setTimeout(r, 5));
  assert.equal(frames.find(f => f.type === 'plan' && f.projectionSeq === 50)?.plan.active, true);
  assert.equal(frames.find(f => f.type === 'subagent-catalog' && f.projectionSeq === 50)?.catalog[0].id, 'child-new');
  assert.equal(frames.find(f => f.type === 'subagent-identity' && f.projectionSeq === 50)?.identity, null);
  ws.close();
});

test('child opening failure preserves permanent code without leaking Host details', async t => {
  const { connect } = await setup(t, { historyError: 'subagent/catalog-diagnostic' });
  const ws = connect({}, '&parentSessionId=parent&parentMode=continuable');
  const frames = [];
  ws.on('message', raw => frames.push(JSON.parse(raw.toString())));
  const [code] = await once(ws, 'close');
  assert.equal(code, 4404);
  assert.deepEqual(frames.find(f => f.type === 'error'), {
    type: 'error', code: 'subagent/catalog-diagnostic', retryable: false,
  });
  assert.doesNotMatch(JSON.stringify(frames), /SYNTHETIC-PRIVATE-DETAIL|synthetic-private/);
});

test('modern Harness control stream replaces removed per-session observers without dropping history', async t => {
  const { connect, openings } = await setup(t, { modern: true });
  const ws = connect();
  const frames = [];
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(Error('control fallback timeout')), 2000);
    ws.on('message', raw => {
      frames.push(JSON.parse(raw));
      if (frames.some(x => x.type === 'questions') &&
          frames.some(x => x.type === 'state' && x.queueKnown === true && x.queue.length) &&
          frames.some(x => x.type === 'snapshot')) {
        clearTimeout(timer); resolve();
      }
    });
    ws.once('error', reject);
  });
  assert.equal(openings.filter(x => x.endpoint === 'session/control').length, 1);
  assert.equal(frames.some(x => x.type === 'error'), false);
  assert.equal(frames.find(x => x.type === 'title')?.title, 'Initial control title');
  assert.deepEqual(frames.find(x => x.type === 'plan')?.plan, { active: false, pending: true });
  assert.equal(frames.find(x => x.type === 'subagent-catalog')?.catalog[0]?.id, 'child-a');
  assert.deepEqual(frames.find(x => x.type === 'subagent-identity')?.identity,
    { mode: 'continuable', label: 'Reviewer', seq: 7 });
  assert.deepEqual(frames.find(x => x.type === 'subagent-timing')?.timing, {
    settledMs: 1200, active: { since: 20, through: 30 }, lastTurnCompleted: false
  });
  const state = frames.find(x => x.type === 'state' && x.queueKnown === true && x.queue.length);
  assert.deepEqual(state?.queue, [{
    id: 'control-queued', placement: 'queued', rpcId: 'control-request', sourceKind: 'user',
    blocks: [{ kind: 'text', text: 'queued from control' }]
  }]);
  ws.close();
});

test('native live forwards bounded authoritative queue rows from state observation', async t => {
  const { frames, until } = await live(t);
  await until(() => frames.some(frame => frame.type === 'state' && frame.queueKnown === true && frame.queue.length));
  const state = frames.find(frame => frame.type === 'state' && frame.queueKnown === true && frame.queue.length);
  assert.deepEqual(state.queue, [{
    id: 'state-queued', placement: 'queued', rpcId: 'state-request',
    blocks: [
      { kind: 'text', text: 'queued from state' },
      { kind: 'file', file: { attachmentId: 'file-id', name: 'notes.txt', bytes: 12 } }
    ]
  }]);
});

test('native live forwards modern title projections and ignores malformed values', async t => {
  const {frames,until,emitProjection} = await live(t);
  await until(() => frames.some(frame => frame.type === 'title' && frame.title === 'Initial live title'));
  emitProjection('projections', {type:'projection',key:'title',value:'Updated live title',seq:2});
  await until(() => frames.some(frame => frame.type === 'title' && frame.title === 'Updated live title'));
  const beforeInvalid = frames.filter(frame => frame.type === 'title').length;
  emitProjection('projections', {type:'projection',key:'title',value:'   ',seq:3});
  await new Promise(resolve => setTimeout(resolve, 20));
  assert.equal(frames.filter(frame => frame.type === 'title').length, beforeInvalid);
});

test('native live forwards typed mode projections and rejects stale per-key values', async t => {
  const {frames,until,emitProjection} = await live(t);
  await until(() => frames.some(frame => frame.type === 'subagent-identity' &&
    frame.identity?.seq === 7));
  emitProjection('projections', {
    type: 'projection', key: 'plan', value: { active: false, pending: true }, seq: 13
  });
  emitProjection('projections', {
    type: 'projection', key: 'plan', value: { active: true, pending: false }, seq: 12
  });
  emitProjection('projections', {
    type: 'projection', key: 'subagentCatalog',
    value: [{ id: 'child-a', createdAt: 50, mode: 'continuable', label: 'Reviewer' }],
    seq: 13
  });
  emitProjection('projections', {
    type: 'projection', key: 'subagent', value: null, seq: 13
  });
  emitProjection('projections', {
    type: 'projection', key: 'subagentTiming',
    value: { settledMs: 100, lastTurnCompleted: true }, seq: 13
  });
  emitProjection('projections', {
    type: 'projection', key: 'permissions', value: { currentValue: 'workspace-write' }, seq: 13
  });
  emitProjection('projections', {
    type: 'projection', key: 'permissions', value: { currentValue: 'read-only' }, seq: 12
  });
  await until(() => frames.some(frame => frame.type === 'plan' && frame.projectionSeq === 13) &&
    frames.some(frame => frame.type === 'subagent-catalog' && frame.projectionSeq === 13) &&
    frames.some(frame => frame.type === 'subagent-identity' && frame.projectionSeq === 13) &&
    frames.some(frame => frame.type === 'subagent-timing' && frame.projectionSeq === 13) &&
    frames.some(frame => frame.type === 'permission' && frame.projectionSeq === 13));
  assert.deepEqual(frames.find(frame => frame.type === 'plan')?.plan,
    { active: false, pending: true });
  assert.equal(frames.find(frame => frame.type === 'subagent-catalog')?.catalog.length, 1);
  assert.deepEqual(frames.filter(frame => frame.type === 'subagent-identity')
    .map(frame => ({ identity: frame.identity, seq: frame.projectionSeq })), [
    { identity: { mode: 'continuable', label: 'Reviewer', seq: 7 }, seq: 12 },
    { identity: null, seq: 13 }
  ]);
  assert.deepEqual(frames.filter(frame => frame.type === 'subagent-timing').at(-1)?.timing,
    { settledMs: 100, lastTurnCompleted: true });
  assert.deepEqual(frames.filter(frame => frame.type === 'permission')
    .map(frame => frame.selection), [{ currentValue: 'workspace-write' }]);
});

test('permission contracts reject reserved defaults and preserve only selectable presets', () => {
  const catalog = {
    options: [
      { value: 'read-only', name: ' Read Only ', description: 'Inspect only' },
      { value: 'workspace-write', name: 'Workspace Write' },
      { value: 'auto', name: 'Auto review' }
    ],
    defaultOptions: [
      { value: 'read-only', name: 'Read Only' },
      { value: 'workspace-write', name: 'Workspace Write' }
    ],
    defaultPreset: 'workspace-write'
  };
  assert.deepEqual(normalizePermissionCatalog(catalog), {
    options: [
      { value: 'read-only', name: 'Read Only', description: 'Inspect only' },
      { value: 'workspace-write', name: 'Workspace Write' },
      { value: 'auto', name: 'Auto review' }
    ],
    defaultOptions: [
      { value: 'read-only', name: 'Read Only' },
      { value: 'workspace-write', name: 'Workspace Write' }
    ],
    defaultPreset: 'workspace-write'
  });
  for (const value of [
    { ...catalog, defaultPreset: 'auto' },
    { ...catalog, defaultOptions: [{ value: 'auto', name: 'Auto review' }] },
    { ...catalog, options: [{ value: 'custom', name: 'Custom' }] },
    { ...catalog, options: [{ value: 'workspace-write', name: 'One' },
      { value: 'workspace-write', name: 'Two' }] },
    { ...catalog, options: [{ value: 'read-only', name: 'Read Only', forged: true }] }
  ]) assert.equal(normalizePermissionCatalog(value), null);
  assert.equal(normalizePermissionPreset('../full'), '');
  assert.deepEqual(normalizePermissionSelection({ currentValue: 'custom' }),
    { currentValue: 'custom' });
  assert.equal(normalizePermissionSelection({ currentValue: '' }), null);
  assert.deepEqual(normalizedProjectionSnapshot({
    asOfSeq: 9,
    values: { permissions: { currentValue: 'danger-full-access', extra: true } }
  }).values.permissions, { currentValue: 'danger-full-access' });
});

test('permission catalog and current-session writes stay behind fixed Host contracts', async t => {
  const { call, calls } = await setup(t);
  const operation = body => call('/pocket/api/native/operation', body);
  const catalogResponse = await operation({ operation: 'permissionCatalog' });
  assert.equal(catalogResponse.status, 200);
  assert.deepEqual(JSON.parse(catalogResponse.text).options.map(option => option.value),
    ['read-only', 'workspace-write', 'danger-full-access', 'auto']);
  assert.equal(calls.at(-1).value.method, 'permissionPresets/catalog');
  assert.deepEqual(calls.at(-1).value.payload.args, {});

  assert.equal((await operation({
    operation: 'setPermissionPreset', sessionId: 'session', preset: 'danger-full-access'
  })).status, 200);
  assert.equal(calls.at(-2).value.method, 'permissionPresets/catalog');
  assert.equal(calls.at(-1).value.method, 'commands/execute');
  assert.deepEqual(calls.at(-1).value.payload.args,
    { agentId: 'session', line: '/permission danger-full-access', submittedAttachments: [] });

  assert.equal((await operation({
    operation: 'setPermissionPreset', sessionId: 'session', preset: 'custom'
  })).status, 400);
  assert.equal((await operation({
    operation: 'setPermissionPreset', sessionId: '../bad', preset: 'read-only'
  })).status, 400);
  assert.equal((await operation({
    operation: 'setPermissionPreset', sessionId: 'session', preset: 'not-in-catalog'
  })).status, 409);
});

test('rejected Host command results surface as conflicts instead of false success', async t => {
  const { call, calls } = await setup(t, { commandRejected: true });
  const permission = await call('/pocket/api/native/operation', {
    operation: 'setPermissionPreset', sessionId: 'session', preset: 'read-only'
  });
  assert.equal(permission.status, 409);
  assert.equal(JSON.parse(permission.text).code, 'permission/rejected');
  assert.deepEqual(calls.at(-1).value.payload.args,
    { agentId: 'session', line: '/permission read-only', submittedAttachments: [] });
  const plan = await call('/pocket/api/native/operation', {
    operation: 'planOff', sessionId: 'session'
  });
  assert.equal(plan.status, 409);
  assert.equal(JSON.parse(plan.text).code, 'plan/rejected');
});

test('native mode and subagent operations use projection, address and command contracts', async t => {
  const {call,calls,connect,openings} = await setup(t);
  const snapshot = await call('/pocket/api/native/operation', {
    operation: 'projections', sessionId: 'session'
  });
  assert.equal(snapshot.status, 200);
  assert.deepEqual(JSON.parse(snapshot.text), {
    kind: 'sequenced',
    asOfSeq: 12,
    values: {
      plan: { active: false, pending: true },
      subagentCatalog: [{
        id: 'child-a', createdAt: 50, mode: 'continuable', label: 'Reviewer'
      }],
      subagentKnown: true,
      subagent: { mode: 'continuable', label: 'Reviewer', seq: 7 },
      subagentTiming: {
        settledMs: 1200, active: { since: 20, through: 30 }, lastTurnCompleted: false
      }
    }
  });
  assert.equal(calls.at(-1).value.method, 'session/projections');

  assert.equal((await call('/pocket/api/native/operation', {
    operation: 'planOff', sessionId: 'session'
  })).status, 200);
  assert.equal(calls.at(-1).value.method, 'commands/execute');
  assert.deepEqual(calls.at(-1).value.payload.args,
    { agentId: 'session', line: '/plan off', submittedAttachments: [] });

  const child = {
    sessionId: 'child-a', parentSessionId: 'session', parentMode: 'continuable'
  };
  const page = await call('/pocket/api/native/page', {
    ...child, beforeSeq: 3
  });
  assert.equal(page.status, 200);
  assert.deepEqual(calls.at(-1).value.payload.args.request.address, {
    kind: 'subagent',
    parentSessionId: 'session',
    childSessionId: 'child-a',
    mode: 'continuable'
  });

  const childPrompt = await call('/pocket/api/native/prompt', {
    ...child, requestId: 'child-request', text: 'continue', mode: 'queue'
  });
  assert.equal(childPrompt.status, 200,
    childPrompt.text + ' ' + JSON.stringify(calls.at(-1)));
  assert.equal(calls.at(-1).value.method, 'subagents/prompt');
  assert.deepEqual(calls.at(-1).value.payload.args.request, {
    requestId: 'child-request',
    childSessionId: 'child-a',
    delivery: 'queue',
    content: [{ type: 'text', text: 'continue' }]
  });

  assert.equal((await call('/pocket/api/native/cancel', child)).status, 200);
  assert.equal(calls.at(-1).value.method, 'subagents/interruptByUser');
  assert.deepEqual(calls.at(-1).value.payload.args,
    ['child-a']);

  assert.equal((await call('/pocket/api/native/prompt', {
    ...child, parentMode: 'external', requestId: 'invalid-child', text: 'continue'
  })).status, 400);
  assert.equal((await call('/pocket/api/native/prompt', {
    ...child, requestId: 'file-child', text: 'continue',
    attachments: [{ type: 'file', receiptId: 'receipt-1' }]
  })).status, 400);

  const ws = connect({}, '&parentSessionId=parent&parentMode=continuable');
  await once(ws, 'open');
  for (let index = 0; index < 200 && !openings.some(row => row.endpoint === 'session/follow'); index++) {
    await new Promise(resolve => setTimeout(resolve, 5));
  }
  const follow = openings.find(row => row.endpoint === 'session/follow');
  assert.deepEqual(follow?.payload.args.request.address, {
    kind: 'subagent',
    parentSessionId: 'parent',
    childSessionId: 'session',
    mode: 'continuable'
  });
  assert.equal(follow?.payload.args.request.activate, false);
  ws.close();

  openings.length = 0;
  const root = connect();
  await once(root, 'open');
  for (let index = 0; index < 200 && !openings.some(row => row.endpoint === 'session/follow'); index++) {
    await new Promise(resolve => setTimeout(resolve, 5));
  }
  const rootFollow = openings.find(row => row.endpoint === 'session/follow');
  assert.equal(rootFollow?.payload.args.request.activate, true);
  root.close();
});

test('native admin operations use fixed plugin and schedule Remotes', async t => {
  const { call, calls } = await setup(t);
  const operation = body => call('/pocket/api/native/operation', body);
  const inventory = await operation({ operation: 'pluginsList' });
  assert.equal(inventory.status, 200);
  assert.equal(JSON.parse(inventory.text).bundles[0].name, 'dsh.example');
  assert.equal((await operation({ operation: 'pluginSetEnabled', name: 'dsh.example', enabled: false })).status, 200);
  assert.equal((await operation({ operation: 'pluginInspect', spec: 'dsh.example@1.2.3' })).status, 200);
  assert.equal((await operation({ operation: 'pluginInstall', spec: 'dsh.example@1.2.3' })).status, 200);
  assert.equal((await operation({ operation: 'pluginVersions', name: 'dsh.example' })).status, 200);
  assert.equal((await operation({ operation: 'pluginUpdate', name: 'dsh.example', version: '1.3.0' })).status, 200);
  assert.equal((await operation({ operation: 'pluginRemove', name: 'dsh.example' })).status, 200);

  const schedules = await operation({ operation: 'automationList' });
  assert.equal(schedules.status, 200);
  assert.equal(JSON.parse(schedules.text).items[0].id, 'schedule-one');
  assert.equal((await operation({ operation: 'automationView', id: 'schedule-one' })).status, 200);
  assert.equal((await operation({ operation: 'automationHistory', id: 'schedule-one', limit: 20 })).status, 200);
  assert.equal((await operation({ operation: 'automationCreate', request: {
    title: 'Task', prompt: 'Prompt', timing: { kind: 'every', every_seconds: 900 }
  } })).status, 200);
  assert.equal((await operation({ operation: 'automationEdit', request: {
    id: 'schedule-one', action: 'update', patch: { active: false }, expectedUpdatedAt: '2026-11-01T00:00:00.000Z'
  } })).status, 200);
  assert.equal((await operation({ operation: 'automationRun', id: 'schedule-one' })).status, 200);
  assert.equal((await operation({ operation: 'automationDelete', id: 'schedule-one',
    expectedUpdatedAt: '2026-11-01T00:00:00.000Z' })).status, 200);

  const pluginBundle = calls.find(row => row.value.method === 'pluginManager/setBundleEnabled');
  assert.deepEqual(pluginBundle.value.payload.args, { name: 'dsh.example', enabled: false });
  const created = calls.find(row => row.value.method === 'schedule/create');
  assert.deepEqual(created.value.payload.args.request.timing, { kind: 'every', every_seconds: 900 });
  assert.equal((await operation({ operation: 'pluginSetEnabled', name: 'dsh.example', enabled: 'yes' })).status, 400);
  assert.equal((await operation({ operation: 'automationEdit', request: {
    id: 'schedule-one', action: 'update', patch: {}, expectedUpdatedAt: null
  } })).status, 400);
});

test('native automation edits expose revision conflicts', async t => {
  const { call } = await setup(t, { scheduleConflict: true });
  const response = await call('/pocket/api/native/operation', { operation: 'automationEdit', request: {
    id: 'schedule-one', action: 'update', patch: { title: 'Changed' }, expectedUpdatedAt: 'stale'
  } });
  assert.equal(response.status, 409);
  assert.equal(JSON.parse(response.text).code, 'schedule_conflict');
});

test('header utilities export complete Host content and profile writes use named revision arguments', async t => {
  const {call,calls}=await setup(t);
  const markdown=await call('/pocket/api/native/export?sessionId=session&format=markdown');
  assert.equal(markdown.status,200);assert.match(markdown.text,/not just the visible window/);
  assert.equal((await call('/pocket/api/native/export?sessionId=session&format=zip')).status,200);
  assert.equal((await call('/pocket/api/native/export?sessionId=../bad&format=zip')).status,400);
  assert.equal((await call('/pocket/api/native/export?sessionId=session&format=markdown',undefined,false)).status,401);
  assert.deepEqual(JSON.parse((await call('/pocket/api/native/operation',{operation:'capabilities',sessionId:'session'})).text),{copyMarkdown:true,downloadLog:true});
  const settings=JSON.parse((await call('/pocket/api/native/operation',{operation:'settingsDescribe'})).text);
  assert.equal(settings.namespaces.length,1);assert.doesNotMatch(JSON.stringify(settings),/must-not-forward/);
  assert.deepEqual(calls.at(-1).value.payload.args,{});
  assert.equal((await call('/pocket/api/native/operation',{operation:'settingsSet',ns:'ui-chat',field:'transcriptView',value:'detailed',revision:4})).status,200);
  assert.equal(calls.at(-1).value.method,'settings/mutate');
  assert.deepEqual(calls.at(-1).value.payload.args,{ns:'ui-chat',ops:[{op:'set',path:['transcriptView'],value:'detailed'}],expectedRevision:4});
  for (const body of [
    {ns:'provider',field:'apiKey',value:'never'}, {ns:'ui-chat',field:'transcriptView',value:'invented'},
    {ns:'ui-theme',field:'fontSize',value:23}, {ns:'ui-chat',field:'collapseTiming',value:'completion',revision:-1}
  ]) assert.equal((await call('/pocket/api/native/operation',{operation:'settingsSet',revision:4,...body})).status,400);
});

test('new-session permission settings expose only defaultPreset and validate it against the live catalog', async t => {
  const { call, calls } = await setup(t, { permissionSettings: true });
  const operation = body => call('/pocket/api/native/operation', body);
  const settings = JSON.parse((await operation({ operation: 'settingsDescribe' })).text);
  assert.deepEqual(settings.namespaces.find(row => row.ns === 'permission'), {
    ns: 'permission', value: { defaultPreset: 'workspace-write' }, revision: 6
  });
  assert.doesNotMatch(JSON.stringify(settings), /must-not-forward/);
  assert.equal((await operation({
    operation: 'settingsSet', ns: 'permission', field: 'defaultPreset',
    value: 'read-only', revision: 6
  })).status, 200);
  assert.equal(calls.at(-2).value.method, 'permissionPresets/catalog');
  assert.equal(calls.at(-1).value.method, 'settings/mutate');
  assert.deepEqual(calls.at(-1).value.payload.args, {
    ns: 'permission',
    ops: [{ op: 'set', path: ['defaultPreset'], value: 'read-only' }],
    expectedRevision: 6
  });
  for (const body of [
    { field: 'defaultPreset', value: 'auto' },
    { field: 'defaultPreset', value: 'custom' },
    { field: 'other', value: 'read-only' }
  ]) assert.equal((await operation({
    operation: 'settingsSet', ns: 'permission', revision: 6, ...body
  })).status, 400);
});

test('native changed-files bridge forwards only the authenticated stopped-turn summary', async t => {
  const { call } = await setup(t);
  const response = await call('/pocket/api/native/changes/summary?sessionId=session&seq=17');
  assert.equal(response.status, 200);
  assert.deepEqual(JSON.parse(response.text), {
    turn: 1,
    total: 2,
    added: 7,
    deleted: 3,
    files: [
      { path: 'src/app.ts', display: 'app.ts', added: 5, deleted: 3 },
      { path: 'assets/logo.bin', display: 'logo.bin', added: 0, deleted: 0, binary: true }
    ]
  });
  assert.equal((await call('/pocket/api/native/changes/summary?sessionId=../bad&seq=17')).status, 400);
  assert.equal((await call('/pocket/api/native/changes/summary?sessionId=session&seq=-1')).status, 400);
  assert.equal((await call('/pocket/api/native/changes/summary?sessionId=session&seq=17', undefined, false)).status, 401);

  const unavailable = await setup(t, { changesUnavailable: true });
  assert.equal((await unavailable.call('/pocket/api/native/changes/summary?sessionId=session&seq=17')).status, 404);
  const malformed = await setup(t, { changesMalformed: true });
  assert.equal((await malformed.call('/pocket/api/native/changes/summary?sessionId=session&seq=17')).status, 502);
  assert.equal(changedFilesSummary({
    turn: 1, total: 1, added: 1, deleted: 0,
    files: [{ path: 'a', display: 'a', added: 1, deleted: 0, binary: false }]
  }), null);
});

test('native file preview uses the official workspaceFiles scope and bounded ranges', async t => {
  const { call, calls } = await setup(t);
  const response = await call('/pocket/api/native/file', { sessionId: 'session', path: 'README.md', offset: 1, limit: 80 });
  assert.equal(response.status, 200);
  assert.deepEqual(JSON.parse(response.text), {
    absolutePath: '/workspace/project/README.md', version: 'v7', text: '# Fixture\n\npreview',
    lines: 3, offset: 1, eof: true
  });
  assert.equal(calls.at(-1).value.method, 'workspaceFiles/read');
  assert.deepEqual(calls.at(-1).value.payload.args, {
    workspaceFileScopeId: 'session', path: 'README.md', range: { offset: 1, limit: 80 }
  });
  assert.equal((await call('/pocket/api/native/file', { sessionId: 'session', path: 'README.md', offset: 0 })).status, 400);
  assert.equal((await call('/pocket/api/native/file', { sessionId: 'session', path: 'README.md', limit: 501 })).status, 400);
});

test('native file browser resolves file types, directories and authenticated binary windows', async t => {
  const { call, calls } = await setup(t);
  const stat = await call('/pocket/api/native/file/stat', { sessionId: 'session', path: 'file.txt' });
  assert.equal(stat.status, 200);
  assert.deepEqual(JSON.parse(stat.text), {
    absolutePath: '/workspace/project/file.txt', version: 'v8', bytes: 7
  });
  assert.equal(calls.at(-1).value.method, 'workspaceFiles/stat');
  assert.deepEqual(calls.at(-1).value.payload.args, {
    workspaceFileScopeId: 'session', path: 'file.txt'
  });

  const list = await call('/pocket/api/native/file/list', { sessionId: 'session', path: 'src' });
  assert.equal(list.status, 200);
  assert.deepEqual(JSON.parse(list.text), {
    path: 'src', entries: [
      { name: 'nested', type: 'directory' },
      { name: 'file.txt', type: 'file', size: 7 },
      { name: 'socket', type: 'other' }
    ], truncated: false
  });
  assert.equal(calls.at(-1).value.method, 'workspaceFiles/list');

  const nested = await call('/pocket/api/native/file/list', { sessionId: 'session', path: 'src/nested' });
  assert.equal(nested.status, 200);
  assert.deepEqual(calls.at(-1).value.payload.args, {
    workspaceFileScopeId: 'session', path: 'src/nested'
  });

  const root = await call('/pocket/api/native/file/list', { sessionId: 'session', path: '' });
  assert.equal(root.status, 200);
  assert.equal(JSON.parse(root.text).path, '');
  assert.deepEqual(calls.at(-1).value.payload.args, {
    workspaceFileScopeId: 'session', path: '.'
  });

  const bytes = await call('/pocket/api/native/file/bytes', {
    sessionId: 'session', path: 'file.txt', offset: 0, length: 8
  });
  assert.equal(bytes.status, 200);
  assert.deepEqual([...bytes.buffer], [0, 1, 2, 255, 65, 66, 67]);
  assert.match(bytes.headers['content-type'], /^application\/octet-stream/);
  const metadata = JSON.parse(Buffer.from(bytes.headers['x-dsh-file-window'], 'base64url').toString());
  assert.deepEqual(metadata, {
    protocol: 1, absolutePath: '/workspace/project/file.txt', version: 'v8',
    bytes: 7, offset: 0, eof: true, length: 7
  });
  assert.equal(calls.at(-1).value.method, 'workspaceFiles/readBytes');
  assert.deepEqual(calls.at(-1).value.payload.args.options, { range: { offset: 0, length: 8 } });

  assert.equal((await call('/pocket/api/native/file/stat', { sessionId: '../bad', path: 'x' })).status, 400);
  assert.equal((await call('/pocket/api/native/file/list', { sessionId: 'session', path: 'x'.repeat(4097) })).status, 400);
  assert.equal((await call('/pocket/api/native/file/bytes', {
    sessionId: 'session', path: 'file.txt', length: 2 * 1024 * 1024 + 1
  })).status, 400);
});

test('native file routes preserve stable workspace-file failures', async t => {
  const { call } = await setup(t, { workspaceFileError: true });
  const stat = await call('/pocket/api/native/file/stat', { sessionId: 'session', path: 'missing.py' });
  assert.equal(stat.status, 409);
  assert.deepEqual(JSON.parse(stat.text), {
    error: '操作未确认，请刷新',
    code: 'workspace-file/not-found'
  });
});

test('native workspace file surface is read-only and rejects write-shaped routes', async t => {
  const { call, calls } = await setup(t);
  await call('/pocket/api/native/file/stat', { sessionId: 'session', path: 'file.txt' });
  await call('/pocket/api/native/file/list', { sessionId: 'session', path: '' });
  await call('/pocket/api/native/file/bytes', {
    sessionId: 'session', path: 'file.txt', offset: 0, length: 16
  });
  assert.deepEqual(calls.map(row => row.value.method), [
    'workspaceFiles/stat', 'workspaceFiles/list', 'workspaceFiles/readBytes'
  ]);
  for (const route of ['write', 'delete', 'rename', 'create', 'upload']) {
    assert.equal((await call('/pocket/api/native/file/' + route, {
      sessionId: 'session', path: 'file.txt'
    })).status, 404);
  }
});

test('native binary windows accept empty files and reject unexpected multipart parts', async t => {
  const empty = await setup(t, { emptyReadBytes: true });
  const value = await empty.call('/pocket/api/native/file/bytes', {
    sessionId: 'session', path: 'empty.txt', offset: 0, length: 16
  });
  assert.equal(value.status, 200);
  assert.equal(value.buffer.length, 0);
  const metadata = JSON.parse(Buffer.from(value.headers['x-dsh-file-window'], 'base64url').toString());
  assert.equal(metadata.bytes, 0);
  assert.equal(metadata.length, 0);

  const invalid = await setup(t, { unexpectedAttachment: true });
  const rejected = await invalid.call('/pocket/api/native/file/bytes', {
    sessionId: 'session', path: 'file.txt', offset: 0, length: 16
  });
  assert.equal(rejected.status, 502);
});

test('older Host exports are negotiated and an HTML login response never becomes a transcript or archive',async t=>{
  const old=await setup(t,{unavailableExports:true});
  assert.deepEqual(JSON.parse((await old.call('/pocket/api/native/operation',{operation:'capabilities',sessionId:'session'})).text),{copyMarkdown:false,downloadLog:false});
  const html=await setup(t,{htmlExport:true});
  assert.deepEqual(JSON.parse((await html.call('/pocket/api/native/operation',{operation:'capabilities',sessionId:'session'})).text),{copyMarkdown:false,downloadLog:false});
  assert.equal((await html.call('/pocket/api/native/export?sessionId=session&format=markdown')).status,502);
  assert.equal((await html.call('/pocket/api/native/export?sessionId=session&format=zip')).status,502);
});

test('native adapter uses official RPC envelopes and keeps upstream credentials server-side',async t=>{
  const {call,calls}=await setup(t);
  assert.equal((await call('/pocket/api/native/sessions',undefined,false)).status,401);
  const sessions=await call('/pocket/api/native/sessions');
  assert.equal(sessions.status,200);
  assert.deepEqual(JSON.parse(sessions.text),{protocol:2,truncated:false,items:[{id:'session',title:'Native session',titleKnown:true,blank:false,agentAvailable:true,running:true,updatedAt:42}]});
  assert.equal((await call('/pocket/api/native/create',{requestId:'new-session'})).status,200);
  assert.equal((await call('/pocket/api/native/prompt',{sessionId:'session',requestId:'request',text:'test prompt'})).status,200);
  assert.equal(calls.at(-1).value.method,'session/prompt');
  assert.deepEqual(calls.at(-1).value.payload.args.request.content,[{type:'text',text:'test prompt'}]);
  assert.equal((await call('/pocket/api/native/cancel',{sessionId:'session'})).status,200);
  assert.equal((await call('/pocket/api/native/prompt',{sessionId:'../bad',requestId:'request',text:'x'})).status,400);
  assert.equal((await call('/pocket/api/native/prompt',{sessionId:'session',requestId:'request',text:'x'.repeat(100000)})).status,200);
  const page=await call('/pocket/api/native/page',{sessionId:'session',beforeSeq:3});
  assert.equal(JSON.parse(page.text).messages[0].text,'older');
  for(const call of calls) {
    assert.equal(call.headers.cookie,'harness=server-only');
    assert.doesNotMatch(JSON.stringify(call.value),/pocket=/);
  }
});

test('native session list keeps unknown parent availability unknown', async t => {
  const { call } = await setup(t, { omitAgentAvailable: true });
  const sessions = await call('/pocket/api/native/sessions');
  assert.equal(sessions.status, 200);
  assert.equal(Object.hasOwn(JSON.parse(sessions.text).items[0], 'agentAvailable'), false);
});

test('Workspace baseline, named Session creation and archive/pin commands use the public controller contracts',async t=>{
  const {call,calls}=await setup(t);
  const response=await call('/pocket/api/native/workspaces');
  const baseline=JSON.parse(response.text);
  assert.equal(baseline.available,true);assert.equal(baseline.items[0].workspaceId,'workspace');
  assert.deepEqual(baseline.archivedSessionIds,['archived']);
  assert.equal((await call('/pocket/api/native/create',{requestId:'reusable-blank',workspaceId:'workspace'})).status,200);
  assert.deepEqual(calls.at(-1).value.payload.args.request,{sessionId:'reusable-blank',workspaceId:'workspace'});
  assert.equal((await call('/pocket/api/native/create',{requestId:'new',workspaceId:'workspace',cwd:'/workspace/other'})).status,400);
  for(const [operation,method] of [['workspaceCreate','create'],['workspaceRename','rename'],['archive','archiveSession'],['unarchive','unarchiveSession'],['pin','pinSession'],['unpin','unpinSession']]) {
    const body={operation,sessionId:'session',workspaceId:'workspace',path:'/workspace/project',title:'Renamed'};
    assert.equal((await call('/pocket/api/native/operation',body)).status,200);
    assert.equal(calls.at(-1).value.method,'workspace/'+method);
    const expected=operation==='workspaceCreate'?{path:body.path}:operation==='workspaceRename'?{workspaceId:body.workspaceId,title:body.title}:{sessionId:body.sessionId};
    assert.deepEqual(calls.at(-1).value.payload.args,{request:expected});
  }
  assert.equal((await call('/pocket/api/native/operation',{operation:'workspaceRename',workspaceId:'../bad',title:'x'})).status,400);
});

test('session ordering maps only the public workspace membership RPC', async t => {
  const { call, calls } = await setup(t);
  const response = await call('/pocket/api/native/operation', {
    operation: 'sessionInsertBefore',
    workspaceId: 'workspace',
    sessionId: 'session',
    beforeSessionId: 'next-session'
  });
  assert.equal(response.status, 200);
  assert.equal(calls.at(-1).value.method, 'workspace/insertSessionBefore');
  assert.deepEqual(calls.at(-1).value.payload.args, {
    request: {
      workspaceId: 'workspace', sessionId: 'session', beforeSessionId: 'next-session'
    }
  });
  assert.equal((await call('/pocket/api/native/operation', {
    operation: 'sessionInsertBefore', workspaceId: '../bad', sessionId: 'session'
  })).status, 400);
  assert.equal((await call('/pocket/api/native/operation', {
    operation: 'sessionInsertBefore', workspaceId: 'workspace', sessionId: 'session',
    beforeSessionId: '../bad'
  })).status, 400);
});

test('native live channel restores stream baseline and revokes both sockets on logout',async t=>{
  const {connect,call,openings}=await setup(t);
  const ws=connect(); const frames=[];
  const ready=new Promise((resolve,reject)=>{
    const timeout=setTimeout(()=>reject(Error('stream timeout')),5000);
    ws.on('error',reject);
    ws.on('message',raw=>{const frame=JSON.parse(raw);frames.push(frame);if(frames.some(item=>item.type==='state')&&frames.some(item=>item.type==='delta')){clearTimeout(timeout);resolve();}});
  });
  await ready;
  assert.equal(frames.find(frame=>frame.type==='snapshot').text,'hel');
  assert.equal(frames.find(frame=>frame.type==='delta').text,'lo');
  assert.equal(frames.find(frame=>frame.type==='state').waiting,true);
  assert.deepEqual(openings.map(frame=>frame.endpoint),['$events','session/follow','session/observeState','session/observeProjections']);
  const closed=once(ws,'close');
  assert.equal((await call('/pocket/api/logout',{})).status,200);
  await closed;
  assert.equal(ws.readyState,WebSocket.CLOSED);
});

test('native stream rejects foreign origins and client command injection',async t=>{
  const {connect}=await setup(t);
  const rejected=connect({Origin:'https://other.example.com'});
  await once(rejected,'error');
  const ws=connect(); await once(ws,'open');
  const closed=once(ws,'close');
  ws.send(JSON.stringify({endpoint:'session/prompt',text:'injected'}));
  const [code]=await closed; assert.equal(code,1008);
});

test('normalization respects history replacements and produces native code blocks',()=>{
  assert.equal(normalizeProjectionTitle('  generated\u0000 title  '),'generated title');
  assert.equal(normalizeProjectionTitle('x'.repeat(200)).length,160);
  assert.equal(normalizeProjectionTitle({title:'invalid'}),'');
  const history=normalizedHistory([
    {type:'event',event:{seq:1,type:'user/message',data:{content:[{type:'text',text:'old'}]}}},
    {type:'event',event:{seq:2,type:'user/message',surfaceOp:{op:'replace',startSeq:1,endSeq:1},data:{content:[{type:'text',text:'new'}]}}}
  ]);
  assert.equal(history.messages.length,1);assert.equal(history.messages[0].text,'new');
  assert.equal(richBlocks('text\n```js\nconst x=1;\n```')[1].kind,'code');
  assert.deepEqual(normalizeFollow({type:'assistant-stream',frame:{type:'chunk',revision:1,attemptId:'a',index:1,chunk:{type:'reasoning-delta',text:'thinking'}}}),
    {type:'delta',attemptId:'a',revision:1,index:1,text:'',reasoning:'thinking',
      streamParts:[{kind:'reasoning',text:'thinking'}]});
  assert.equal(normalizeFollow({type:'assistant-stream',frame:{
    type:'chunk',attemptId:'a',index:1,chunk:{type:'text-delta',text:'missing revision'}
  }}),null);
});

test('Chat filters injected source kinds at the durable source field while retaining actual human text', () => {
  const message=(source,text='context')=>({type:'event',event:{seq:1,type:'user/message',data:{source,content:[{type:'text',text}]}}});
  for(const kind of ['agent-instructions','runtime-context','session-reference','skill-invocation','compact-checkpoint']) {
    assert.equal(normalizeRecord(message({kind})),null,kind);
  }
  assert.equal(normalizeRecord(message({kind:'user'},'Current runtime context. is a phrase I want explained')).role,'user');
  assert.equal(normalizeRecord(message(undefined,'  Time sampled while preparing turn: now')),null);
  assert.equal(normalizeRecord(message(undefined,'Please explain current runtime context.')).role,'user');
  const background = normalizeRecord(message(
    { kind: 'tool-jobs', form: 'notice', summary: 'job completed' },
    'background job bash-1 finished'
  ));
  assert.equal(background.role, 'background-notice');
  assert.equal(background.sourceForm, 'notice');
  assert.equal(background.sourceKind, 'tool-jobs');
  assert.equal(normalizeRecord(message(
    { kind: 'user', form: 'notice' },
    '{"source":{"kind":"tool-jobs","form":"notice"}}'
  )).role, 'user');
  const assistant=normalizeRecord({type:'event',event:{seq:2,type:'assistant/message',data:{message:{content:[{type:'tool-call',id:'x',name:'read',arguments:'{}'},{type:'text',text:'reply'}]}}}});
  assert.equal(assistant.text,'reply');
});

test('native lifecycle normalization preserves stable command and job identities', () => {
  const command = normalizeRecord({ type: 'event', event: {
    seq: 4, type: 'command/run', data: {
      commandId: 'cmd-1', name: 'compact', args: '', source: { kind: 'user' }
    }
  }});
  assert.equal(command.callId, 'cmd-1');
  assert.equal(command.toolName, 'slash_command');
  assert.equal(command.phase, 'start');
  assert.equal(JSON.parse(command.metaRaw).name, 'compact');

  const registered = normalizeRecord({ type: 'event', event: {
    seq: 5, type: 'job/registered', data: {
      jobId: 'job-1', owner: 'session', kind: 'bash', label: 'npm test',
      startedAt: 1000, toolCall: { callId: 'call-1', rootCallId: 'call-1' }
    }
  }});
  assert.equal(registered.callId, 'job-1');
  assert.equal(registered.toolName, 'job_lifecycle');
  assert.equal(JSON.parse(registered.metaRaw).toolCall.callId, 'call-1');

  const settled = normalizeRecord({ type: 'event', event: {
    seq: 6, type: 'job/settled', data: {
      jobId: 'job-1', owner: 'session', kind: 'bash', label: 'npm test',
      startedAt: 1000, finishedAt: 2000, status: 'completed', cause: 'producer',
      producerReported: true, detail: 'exit code: 0'
    }
  }});
  assert.equal(settled.phase, 'result');
  assert.equal(settled.failed, false);
  assert.equal(settled.outcome, 'completed');

  const delivered = normalizeRecord({ type: 'event', event: {
    seq: 7, type: 'deliverables/presented', data: {
      turn: 1, callId: 'present-1', files: [{ path: 'out/report.pdf' }]
    }
  }});
  assert.equal(delivered.role, 'detail');
  assert.equal(delivered.callId, 'present-1');
  assert.equal(JSON.parse(delivered.authoritativeRaw).files.length, 1);
});

test('native history and stream preserve arbitrarily long Unicode content without display truncation', () => {
  const text = '长内容😀\n'.repeat(200000);
  const history = normalizedHistory([{type:'event',event:{seq:1,type:'assistant/message',data:{message:{content:[{type:'text',text}]}}}}]);
  assert.equal(history.messages[0].text, text);
  assert.equal(history.trimmed, false);
  const snapshot = normalizeFollow({type:'snapshot',cursor:2,hasMore:true,records:[],assistantStream:{revision:0,activeAttempt:{attemptId:'a',startedAfterSeq:-1,turn:0,step:0,nextIndex:1,stream:[{type:'text-chunks',time0:0,index:0,dt:[],texts:[text]}]}}});
  assert.equal(snapshot.text, text);
  const unknown = normalizedHistory([{type:'event',event:{seq:3,type:'custom/record',data:{text}}}]);
  assert.equal(unknown.messages.length, 0, 'internal protocol events are not rendered as chat messages');
});

test('advanced native commands use exact public Session contracts and reject arbitrary RPCs', async t => {
  const {call,calls} = await setup(t);
  const operation = body => call('/pocket/api/native/operation',body);
  assert.equal((await operation({operation:'modelCatalog'})).status,200);
  assert.deepEqual(calls.at(-1).value.payload,{args:{}});
  assert.equal((await operation({operation:'rename',sessionId:'session',title:'标题'.repeat(2000)})).status,400);
  assert.equal((await operation({operation:'rename',sessionId:'session',title:'标题'.repeat(20)})).status,200);
  assert.equal(calls.at(-1).value.method,'session/rename');
  assert.equal((await operation({operation:'fork',sessionId:'session',atSeq:42})).status,200);
  assert.deepEqual(calls.at(-1).value.payload.args.request,{sessionId:'session',atSeq:42,allowMigration:false});
  assert.equal((await operation({operation:'selectModel',sessionId:'session',provider:'provider',model:'model',reasoningEffort:'high'})).status,200);
  assert.equal(calls.at(-1).value.payload.args.request.reasoningEffort,'high');
  assert.equal((await operation({operation:'updateQueue',sessionId:'session',itemId:'item',kind:'edit',text:'updated'})).status,200);
  assert.deepEqual(calls.at(-1).value.payload.args.request.action,{kind:'edit',content:[{type:'text',text:'updated'}]});
  assert.equal((await operation({operation:'deleteEverything',sessionId:'session'})).status,400);
  assert.equal((await operation({operation:'updateQueue',sessionId:'session',itemId:'item',kind:'edit',text:''})).status,400);
  assert.equal((await call('/pocket/api/native/prompt',{sessionId:'session',requestId:'steer',text:'adjust',mode:'steer'})).status,200);
  assert.equal(calls.at(-1).value.payload.args.request.mode,'steer');
});

test('native request magnitude caps bound prompts, attachments, images, uploads and settings', async t => {
  const { call, upload } = await setup(t);
  const prompt = body => call('/pocket/api/native/prompt', body);
  assert.equal((await prompt({sessionId:'session',requestId:'cap',text:'x'.repeat(262145)})).status,400);
  assert.equal((await prompt({sessionId:'session',requestId:'cap',text:'x'.repeat(262144)})).status,200);
  assert.equal((await prompt({sessionId:'session',requestId:'cap',text:'x',
    attachments:Array.from({length:33},() => ({type:'file',receiptId:'r'}))})).status,400);
  assert.equal((await prompt({sessionId:'session',requestId:'cap',text:'x',
    images:Array.from({length:17},() => ({mediaType:'image/png',data:'aGk='}))})).status,400);
  assert.equal((await prompt({sessionId:'session',requestId:'cap',text:'x',
    images:[{mediaType:'image/png',data:'a'.repeat(16*1024*1024+1)}]})).status,400);
  assert.equal((await prompt({sessionId:'session',requestId:'cap',text:'x',
    images:[{mediaType:'image/png',data:'aGk=',name:'n'.repeat(256)}]})).status,400);
  // settingsSet must be a real allowlist: inherited object properties never pass.
  assert.equal((await call('/pocket/api/native/operation',{operation:'settingsSet',ns:'constructor',field:'name',value:'Obj',revision:1})).status,400);
  assert.equal((await call('/pocket/api/native/operation',{operation:'settingsSet',ns:'__proto__',field:'x',value:'y',revision:1})).status,400);
  assert.equal((await call('/pocket/api/native/operation',{operation:'settingsSet',ns:'toString',field:'x',value:'y',revision:1})).status,400);
  // upload: filename charset, media type shape and declared size are all enforced.
  assert.equal((await upload('/pocket/api/native/upload?sessionId=session&name=..%2Fescape.bin',Buffer.from('x'))).status,400);
  assert.equal((await upload('/pocket/api/native/upload?sessionId=session&name=sub%5Cdir.bin',Buffer.from('x'))).status,400);
  assert.equal((await upload('/pocket/api/native/upload?sessionId=session&name=ok.bin&mediaType=text%2Fplain',Buffer.from('x'))).status,200);
  assert.equal((await upload('/pocket/api/native/upload?sessionId=session&name=ok2.bin&mediaType=not%20a%20media%20type',Buffer.from('x'))).status,400);
  assert.equal((await upload('/pocket/api/native/upload?sessionId=session&name=big.bin',Buffer.from([1]),
    {'content-length':String(128*1024*1024+1)})).status,413);
});

test('binary reads relay only stable decision codes from the Host', async t => {
  const stable = await setup(t, { readBytesErrorCode: 'workspace-file/not-found' });
  const accepted = await stable.call('/pocket/api/native/file/bytes',{sessionId:'session',path:'file.txt',offset:0,length:16});
  assert.equal(accepted.status,409);
  assert.equal(JSON.parse(accepted.text).code,'workspace-file/not-found');
  const unstable = await setup(t, { readBytesErrorCode: 'internal/fancy-new-code' });
  const rejected = await unstable.call('/pocket/api/native/file/bytes',{sessionId:'session',path:'file.txt',offset:0,length:16});
  assert.equal(rejected.status,502);
  assert.equal(JSON.parse(rejected.text).code,undefined);
});

test('history and live events reject malformed replace ops and sequences', () => {
  const history = normalizedHistory([
    {type:'event',event:{seq:1,type:'user/message',data:{content:[{type:'text',text:'one'}]}}},
    {type:'event',event:{seq:2,type:'user/message',surfaceOp:{op:'replace'},data:{content:[{type:'text',text:'two'}]}}},
    {type:'event',event:{seq:3,type:'user/message',data:{content:[{type:'text',text:'three'}]}}}
  ]);
  assert.equal(history.messages.length,2);
  assert.deepEqual(history.replacements,[]);
  assert.equal(normalizeFollow({type:'event',event:{type:'user/message',data:{}}}),null);
  assert.equal(normalizeFollow({type:'event',event:{seq:-1,type:'user/message',data:{}}}),null);
  const valid = normalizeFollow({type:'event',event:{seq:2,type:'user/message',data:{content:[{type:'text',text:'hi'}]}}});
  assert.equal(valid.seq,2);
  assert.equal(normalizeFollow({type:'event',event:{seq:3,type:'user/message',surfaceOp:{op:'replace'},data:{}}}),null);
});

test('protocol normalization applies the intended label, language and source caps', () => {
  const blocks = richBlocks('text\n\`\`\`' + 'x'.repeat(40) + '\nconst x=1;\n\`\`\`');
  assert.equal(blocks[1].kind,'code');
  assert.equal(blocks[1].language.length,30);
  const inbox = queueFromInbox({'next-turn':[{id:'m1',source:{kind:'user',form:'f'.repeat(100)},content:[{type:'text',text:'hi'}]}]});
  assert.equal(inbox[0].sourceForm.length,64);
  const capped = normalizeRecord({type:'event',event:{seq:1,type:'user/message',
    data:{source:{kind:'user',form:'f'.repeat(100)},content:[{type:'text',text:'hi'}]}}});
  assert.equal(capped.sourceForm.length,64);
});

async function live(t, options = {}) {
  const setupResult = await setup(t, options);
  const ws = setupResult.connect();
  const frames = [];
  ws.on('message', raw => frames.push(JSON.parse(raw)));
  await once(ws,'open');
  const until = async predicate => {
    for (let i=0;i<1000;i++) { if(predicate())return;await new Promise(resolve=>setTimeout(resolve,5)); }
    throw Error('fixture condition timed out');
  };
  await until(()=>frames.some(frame=>frame.type==='snapshot'));
  return {...setupResult,ws,frames,until};
}
test('native decisions are live, owner-bound, single-use and revoked on Host cancellation', async t => {
  const {call,calls,frames,emit,until,db} = await live(t);
  emit({type:'waterfall',event:'approval/request',eventId:'approval',agentId:'session',request:{toolName:'shell',reason:'Run command'}});
  await until(()=>frames.some(frame=>frame.type==='interaction'));
  const frame = frames.find(frame=>frame.type==='interaction');
  const answer = value => call('/pocket/api/native/answer',{connectionId:frame.connectionId,eventId:'approval',value});
  const other = randomBytes(32).toString('base64url');
  db.prepare('INSERT INTO sessions VALUES (?,?)').run(createHash('sha256').update(other).digest('hex'),Date.now()+60000);
  assert.equal((await call('/pocket/api/native/answer',{connectionId:frame.connectionId,eventId:'approval',value:'allowed-once'},'pocket='+other)).status,409);
  assert.equal((await answer('always-allow')).status,400);
  assert.equal((await answer('allowed-once')).status,200);
  assert.equal(calls.at(-1).value.method,'$events/result');
  assert.deepEqual(calls.at(-1).value.payload.args,{clientId:'client-generation',eventId:'approval',outcome:{kind:'result',value:'allowed-once'}});
  assert.equal((await answer('allowed-once')).status,409);
  emit({type:'waterfall',event:'approval/request',eventId:'cancelled',agentId:'session',request:{toolName:'shell'}});
  await until(()=>frames.some(frame=>frame.eventId==='cancelled'));
  emit({type:'cancel',eventId:'cancelled'});
  await until(()=>frames.some(frame=>frame.type==='interaction-ended'&&frame.eventId==='cancelled'));
  assert.equal((await call('/pocket/api/native/answer',{connectionId:frame.connectionId,eventId:'cancelled',value:'allowed-once'})).status,409);
});
test('native question answers validate exact IDs and choices; other scopes delegate', async t => {
  const {call,calls,frames,emit,until} = await live(t);
  emit({type:'waterfall',event:'user-questions/request',eventId:'question',agentId:'session',request:{questions:[{id:'q',question:'Choose',options:[{label:'A'},{label:'B'}]}]}});
  await until(()=>frames.some(frame=>frame.eventId==='question'));
  const frame=frames.find(frame=>frame.eventId==='question');
  const answer=answers=>call('/pocket/api/native/answer',{connectionId:frame.connectionId,eventId:'question',value:{answers}});
  assert.equal((await answer([{id:'q',selected:['forged']}])).status,400);
  assert.equal((await answer([{id:'q',selected:['A','B']}])).status,400);
  assert.equal((await answer([{id:'q',selected:['A'],custom:'details'}])).status,200);
  const before=calls.length;
  emit({type:'waterfall',event:'approval/request',eventId:'other',agentId:'other-session',request:{toolName:'shell'}});
  await until(()=>calls.length>before);
  assert.deepEqual(calls.at(-1).value.payload.args.outcome,{kind:'next'});
  assert.equal(frames.some(frame=>frame.eventId==='other'),false);
});

test('timed question claims start the deadline and user engagement preserves the wait', async t => {
  const {call,calls,frames,emit,until,openings} = await live(t);
  const request={questions:[{id:'q',question:'Choose',options:[{label:'A'}]}],wait:{timed:true,callId:'timed-call'}};
  emit({type:'waterfall',event:'user-questions/request',eventId:'timed',agentId:'session',request});
  await until(()=>frames.some(frame=>frame.eventId==='timed'));
  assert.equal(openings.at(-1).endpoint,'userQuestions/attachWait');
  const frame=frames.find(frame=>frame.eventId==='timed');
  assert.equal(frame.remainingMs,80);
  assert.equal((await call('/pocket/api/native/answer',{connectionId:frame.connectionId,eventId:'timed',engage:true})).status,200);
  await new Promise(resolve=>setTimeout(resolve,120));
  assert.equal(calls.some(call=>call.value.payload.args?.eventId==='timed'),false,'engagement pauses the local timeout');
  assert.equal((await call('/pocket/api/native/answer',{connectionId:frame.connectionId,eventId:'timed',value:{answers:[{id:'q',selected:['A']}]}})).status,200);
  emit({type:'waterfall',event:'user-questions/request',eventId:'timeout',agentId:'session',request});
  await until(()=>calls.some(call=>call.value.payload.args?.eventId==='timeout'));
  assert.equal(calls.at(-1).value.payload.args.outcome.error.code,'ASK_TIMED_OUT');
});


test('wait renewal replaces the previous deadline instead of stacking timers', async t => {
  const {calls,frames,emit,until} = await live(t,{waitRemainingMs:60,renewWaitMs:5000});
  const request={questions:[{id:'q',question:'Choose',options:[{label:'A'}]}],wait:{timed:true,callId:'timed-call'}};
  emit({type:'waterfall',event:'user-questions/request',eventId:'timed',agentId:'session',request});
  await until(()=>frames.some(frame=>frame.eventId==='timed'&&frame.remainingMs===5000));
  await new Promise(resolve=>setTimeout(resolve,260));
  assert.equal(calls.some(call=>call.value.payload.args?.eventId==='timed'),false,
    'the renewed deadline must replace the short one instead of stacking timers');
});

test('native images keep typed references and admit image-only prompts without text caps', async t => {
  const {call,calls} = await setup(t);
  const attachment={attachmentId:'a'.repeat(64),mediaType:'image/png',bytes:42,width:2,height:3,name:'example.png'};
  const content=[{type:'text',text:'image follows'},{type:'image',attachment}];
  const history=normalizedHistory([{type:'event',event:{seq:1,type:'user/message',data:{content}}}]);
  assert.deepEqual(history.messages[0].images,[attachment]);
  assert.equal((await call('/pocket/api/native/operation',{operation:'attachment',sessionId:'session',attachment})).status,200);
  assert.deepEqual(calls.at(-1).value.payload.args.request,{sessionId:'session',attachment});
  assert.equal((await call('/pocket/api/native/prompt',{sessionId:'session',requestId:'image-only',text:'',images:[{mediaType:'image/png',data:'AA==',name:'image.png'}]})).status,200);
  assert.deepEqual(calls.at(-1).value.payload.args.request.content,[{type:'image',mediaType:'image/png',data:'AA==',name:'image.png'}]);
  assert.equal((await call('/pocket/api/native/prompt',{sessionId:'session',requestId:'invalid',text:'',images:[{mediaType:'text/html',data:'AA=='}]})).status,400);
  assert.equal((await call('/pocket/api/native/prompt',{sessionId:'session',requestId:'empty',text:''})).status,400);
});

test('latest DSH raw uploads stay byte-exact and prompt emits staged file receipts', async t => {
  const {call,calls,upload,uploads}=await setup(t);
  const bytes=Buffer.from([0,1,2,3,255,65]);
  const response=await upload('/pocket/api/native/upload?sessionId=session&name=report.pdf',bytes);
  assert.equal(response.status,200);
  assert.equal(JSON.parse(response.text).value.receiptId,'receipt-1');
  assert.deepEqual(uploads[0].bytes,bytes);
  assert.equal(uploads[0].headers['content-length'],String(bytes.length));
  assert.deepEqual(uploads[0].query,{sessionId:'session',name:'report.pdf'});
  assert.equal((await call('/pocket/api/native/prompt',{sessionId:'session',requestId:'receipt-prompt',
    text:'inspect',attachments:[{type:'file',receiptId:'receipt-1'}]})).status,200);
  assert.deepEqual(calls.at(-1).value.payload.args.request.content,[
    {type:'file',receiptId:'receipt-1'},{type:'text',text:'inspect'}
  ]);
  assert.equal((await call('/pocket/api/native/prompt',{sessionId:'session',requestId:'bad-receipt',
    text:'',attachments:[{type:'file',receiptId:''}]})).status,400);
});

test('native raw uploads require and preserve an explicit byte length', async t => {
  const {upload,uploads}=await setup(t);
  const response=await upload('/pocket/api/native/upload?sessionId=session&name=missing-length',Buffer.from([1,2,3]),{
    'transfer-encoding':'chunked'
  });
  assert.equal(response.status,411);
  assert.equal(uploads.length,0);
});
test('continued question RPC uses agent scope rather than an invented request wrapper', async t => {
  const {call,calls} = await setup(t);
  const answer={answers:[{id:'q',selected:[],custom:'continue'}]};
  assert.equal((await call('/pocket/api/native/operation',{operation:'answerQuestion',sessionId:'session',callId:'call',answer})).status,200);
  assert.equal(calls.at(-1).value.method,'userQuestions/answer');
  assert.deepEqual(calls.at(-1).value.payload.args,{agent:'session',callId:'call',answer});
});

test('live transport delivers a complete Unicode record above former upstream and downstream ceilings', async t => {
  const text='内容😀'.repeat(800000);
  const {frames} = await live(t,{text});
  const snapshot=frames.find(frame=>frame.type==='snapshot');
  assert.equal(snapshot.messages[0].text,text);
  assert.equal(snapshot.messages[0].blocks[0].text,text);
});


test('gateway stream hardening keeps bounded pauses, renewed waits and idle snapshots cheap', () => {
  const source = readFileSync(new URL('../src/native-harness.mjs', import.meta.url), 'utf8');
  assert.match(source, /if \(pending\.timer\) clearTimeout\(pending\.timer\);/,
    'wait renewal clears the previous deadline timer');
  assert.match(source, /connection\.pending\.clear\(\);/,
    'client close removes pending entries so retired timers cannot act');
  assert.match(source, /nativeDeliveryStallReady\(upstreamPausedForDelivery, upstreamPausedSince, Date\.now\(\)\)/,
    'the drain interval enforces the delivery stall watchdog');
  assert.match(source, /!value\.turnStartedAt &&\s*\(!connection\.runningKnown \|\| connection\.running\)/,
    'idle snapshots skip the turn-start page RPC');
  assert.match(source, /maxPayload: 64 \* 1024 \* 1024/,
    'upstream receive frames stay bounded');
});
