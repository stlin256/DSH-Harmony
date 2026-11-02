import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
import { normalizeFollow } from '../src/native-protocol.mjs';

const services = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);
const gateway = new URL('../src/', import.meta.url);

function load(name, kits = {}) {
  const source = readFileSync(new URL(name + '.ets', services), 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS }
  });
  const module = { exports: {} };
  vm.runInNewContext(output.outputText, {
    module,
    exports: module.exports,
    setTimeout,
    clearTimeout,
    TextDecoder,
    TextEncoder,
    require: id => {
      if (id in kits) return kits[id];
      if (id.startsWith('./') && existsSync(new URL(id.slice(2) + '.ets', services))) {
        return load(id.slice(2), kits);
      }
      throw Error('Unexpected dependency: ' + id);
    }
  });
  return module.exports;
}

function validSnapshot(overrides = {}) {
  return {
    type: 'snapshot',
    cursor: 4,
    records: [],
    hasMore: false,
    assistantStream: {
      revision: 2,
      activeAttempt: {
        attemptId: 'attempt-a',
        nextIndex: 1,
        startedAfterSeq: 3,
        turn: 1,
        step: 2,
        stream: [{ type: 'text-chunks', time0: 0, index: 0, dt: [], texts: ['partial'] }]
      }
    },
    ...overrides
  };
}

test('protocol normalization rejects malformed snapshots before the reducer', () => {
  assert.equal(normalizeFollow(validSnapshot()).cursor, 4);
  assert.equal(normalizeFollow(validSnapshot({ cursor: -1, records: [] })).cursor, -1);
  assert.equal(normalizeFollow(validSnapshot({ records: null })), null);
  assert.equal(normalizeFollow(validSnapshot({ assistantStream: { revision: 2 } }))
    .nextIndex, 0);
  assert.equal(normalizeFollow(validSnapshot({ assistantStream: {} })), null);
  assert.equal(normalizeFollow(validSnapshot({
    assistantStream: {
      activeAttempt: {
        attemptId: 'attempt-a', nextIndex: 1,
        stream: [{ type: 'text-chunks', texts: ['partial'] }]
      }
    }
  })), null);
  assert.equal(normalizeFollow(validSnapshot({
    assistantStream: { revision: 2, activeAttempt: { attemptId: 'attempt-a' } }
  })), null);
  assert.equal(normalizeFollow(validSnapshot({
    assistantStream: { revision: -1, activeAttempt: { attemptId: 'a', nextIndex: 0 } }
  })), null);
  assert.equal(normalizeFollow(validSnapshot({
    assistantStream: { revision: 2, activeAttempt: { attemptId: 'a', nextIndex: -1 } }
  })), null);
  assert.equal(normalizeFollow(validSnapshot({
    assistantStream: {
      revision: 2,
      activeAttempt: {
        attemptId: 'a', nextIndex: 0, startedAfterSeq: -1,
        turn: 0, step: 0, stream: [],
      }
    }
  })).startedAfterSeq, -1);
  const tools = normalizeFollow(validSnapshot({
    assistantStream: {
      revision: 2,
      activeAttempt: {
        attemptId: 'a', nextIndex: 2, startedAfterSeq: -1, turn: 0, step: 0,
        stream: [{
          type: 'tool-call-chunks', time0: 1, index: 0, dt: [1],
          id: 'call-a', name: 'read', args: ['{"pa', 'th":"a"}'],
        }],
      },
    },
  }));
  assert.equal(tools.toolUpdates[0].callId, 'call-a');
  assert.equal(tools.toolUpdates[0].argsDelta, '{"path":"a"}');
  assert.equal(normalizeFollow(validSnapshot({
    assistantStream: {
      revision: 2,
      activeAttempt: {
        attemptId: 'a', nextIndex: 1, startedAfterSeq: -1, turn: 0, step: 0,
        stream: [{ type: 'text-chunks', texts: 'not-an-array' }],
      },
    },
  })), null);
  assert.equal(normalizeFollow(validSnapshot({
    records: [{ type: 'event', event: { seq: -1, type: 'user/message', data: {} } }]
  })), null);

  const { NativeSessionModel } = load('NativeSessionModel');
  const model = new NativeSessionModel();
  model.apply({ type: 'snapshot', cursor: 3, messages: [], revision: 1, nextIndex: 0 });
  assert.throws(() => model.apply({
    type: 'snapshot', cursor: 8, messages: [], revision: -1, nextIndex: 0
  }), /Invalid snapshot/);
  assert.equal(model.activityCursor(), 3);
  assert.equal(model.activityRevision(), 1);
  const empty = new NativeSessionModel();
  empty.apply({ type: 'snapshot', cursor: -1, messages: [], revision: 0, nextIndex: 0 });
  empty.apply({ type: 'event', seq: 0, messages: [] });
  assert.equal(empty.activityCursor(), 0);
  assert.throws(
    () => new NativeSessionModel().apply({ type: 'event', seq: 7, messages: [] }),
    /Missing opening snapshot/,
  );
});

test('committed assistant end requires a durable sequence and never clears partial output', () => {
  assert.deepEqual(normalizeFollow({
    type: 'assistant-stream',
    frame: {
      type: 'end', attemptId: 'attempt-a', revision: 3, index: 2,
      outcome: { kind: 'committed', eventType: 'assistant/message', seq: 5 }
    }
  }), {
    type: 'end', attemptId: 'attempt-a', revision: 3, index: 2,
    outcomeKind: 'committed', committedEventType: 'assistant/message', committedSeq: 5
  });
  for (const seq of [undefined, -1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
    assert.equal(normalizeFollow({
      type: 'assistant-stream',
      frame: {
        type: 'end', attemptId: 'attempt-a', revision: 3, index: 2,
        outcome: { kind: 'committed', eventType: 'assistant/message', seq }
      }
    }), null);
  }
  assert.equal(normalizeFollow({
    type: 'assistant-stream',
    frame: {
      type: 'end', attemptId: 'attempt-a', revision: 3, index: 2,
      outcome: { kind: 'unknown' },
    },
  }), null);

  const { NativeSessionModel } = load('NativeSessionModel');
  const model = new NativeSessionModel();
  model.apply({
    type: 'snapshot', cursor: 1, messages: [], attemptId: 'attempt-a',
    revision: 2, nextIndex: 1, text: 'visible partial', reasoning: 'working'
  });
  assert.throws(() => model.apply({
    type: 'end', attemptId: 'attempt-a', revision: 3, index: 1,
    outcomeKind: 'committed', committedEventType: 'assistant/message', committedSeq: -1
  }), /Invalid stream end/);
  assert.equal(model.streamText, 'visible partial');
  assert.equal(model.streamReasoning, 'working');
  assert.equal(model.activityAttemptId(), 'attempt-a');
  assert.equal(model.activityRevision(), 2);
  assert.equal(model.activityNextIndex(), 1);
  assert.equal(model.settlementPending(), false);
});

test('client request allowlist and gateway native routes stay in parity', async () => {
  const calls = [];
  const streamTask = () => {
    const handlers = {};
    return {
      on(event, callback) { handlers[event] = callback; },
      async requestInStream(url, options) {
        calls.push({ url, options });
        const bytes = new TextEncoder().encode('{}');
        handlers.dataReceive?.(bytes.buffer);
        handlers.dataEnd?.();
        return 200;
      },
      async request(url, options) {
        calls.push({ url, options });
        return { responseCode: 200, header: {}, result: '{}' };
      },
      destroy() {}
    };
  };
  const network = {
    http: {
      RequestMethod: { GET: 'GET', POST: 'POST' },
      HttpDataType: { STRING: 'string' },
      createHttp: streamTask
    },
    webSocket: { createWebSocket: () => { throw Error('unexpected websocket'); } }
  };
  const clientModule = load('NativeHarnessClient', {
    '@kit.NetworkKit': network,
    '@kit.ArkWeb': { webview: { WebCookieManager: {
      fetchCookie: async () => '', configCookie: async () => {}, saveCookieAsync: async () => {}
    } } },
    '@kit.ArkTS': { util: {
      generateRandomUUID: () => 'request-id',
      TextDecoder: { create: () => ({ decodeToString: value => new TextDecoder().decode(value) }) },
      TextEncoder: { create: () => ({ encodeInto: value => new TextEncoder().encode(value) }) }
    } },
    '@kit.BasicServicesKit': { BusinessError: class {} },
    '@kit.CryptoArchitectureKit': {
      cryptoFramework: {
        createMd: () => ({
          update: async () => {},
          digest: async () => ({ data: new Uint8Array(32) }),
        }),
      },
    },
    './NativeSessionModel': {
      NativeFrame: class {}, NativeSession: class {}, NativeSessionList: class {},
      NativeSessionModel: class {}, NativeWorkspaceSnapshot: class {}
    },
    './NativeHostSettings': { NativeHostSettings: class {} },
    './NativeModelDirectory': { NativeModelDirectory: class {} },
    './NativeFileWindow': { nativeFileWindowMetadata: () => ({}) },
    './NativeWorkspaceTarget': {
      nativeResolvedWorkspaceTarget: () => null, NativeWorkspaceTarget: class {}
    },
    './NativeModeSubagent': {
      NativeProjectionSnapshot: class {}, NativeSessionAddress: class {},
      nativeSessionAddress: () => ({}), nativeSessionAddressKey: () => ''
    }
  });
  const client = new clientModule.NativeHarnessClient('https://dsh.example.com');
  assert.ok(clientModule.nativeHarnessRequestRoutes.includes('/pocket/api/native/changes/summary'));
  await client.request('/pocket/api/native/changes/summary?sessionId=session-a&seq=7');
  assert.match(calls[0].url, /\/native\/changes\/summary\?sessionId=session-a&seq=7$/);
  const before = calls.length;
  await assert.rejects(
    () => client.request('/pocket/api/native/export?sessionId=session-a&format=markdown'),
    /Unsupported endpoint/
  );
  await assert.rejects(() => client.request('/pocket/api/state?redirect=https://example.invalid'),
    /Unsupported endpoint/);
  assert.equal(calls.length, before);

  const clientSource = readFileSync(new URL('NativeHarnessClient.ets', services), 'utf8');
  const requestLiterals = [...clientSource.matchAll(
    /this\.request\(\s*'(\/pocket\/api\/[^']+)'/g
  )].map(match => match[1]);
  const streamLiterals = [...clientSource.matchAll(
    /requestInStream\(\s*this\.origin\s*\+\s*'(\/pocket\/api\/[^']+)'/g
  )].map(match => match[1]);
  const basePath = path => path.split('?', 1)[0];
  const calledRoutes = new Set([...requestLiterals, ...streamLiterals].map(basePath));
  assert.ok(requestLiterals.length > 0);
  assert.ok(streamLiterals.length > 0);
  for (const route of calledRoutes) {
    assert.ok(clientModule.nativeHarnessClientRoutes.includes(route),
      route + ' is used by the client but absent from its route contract');
  }
  for (const route of requestLiterals) {
    assert.ok(clientModule.nativeHarnessRequestRoutes.includes(basePath(route)),
      route + ' is requested but absent from the request allowlist');
  }

  const gatewaySource = readFileSync(new URL('native-harness.mjs', gateway), 'utf8');
  const gatewayNativeRoutes = [...gatewaySource.matchAll(
    /app\.(?:get|post|put|delete|patch)\(\s*'(\/pocket\/api\/native\/[^']+)'/g
  )].map(match => match[1]);
  const clientNativeRoutes = clientModule.nativeHarnessClientRoutes
    .filter(path => path.startsWith('/pocket/api/native/'));
  assert.deepEqual([...new Set(clientNativeRoutes)].sort(), [...new Set(gatewayNativeRoutes)].sort());
  assert.deepEqual(
    [...calledRoutes].filter(path => path.startsWith('/pocket/api/native/')).sort(),
    [...new Set(gatewayNativeRoutes)].sort()
  );
});

function cursor(rows) {
  let index = -1;
  return {
    goToFirstRow() { index = 0; return rows.length > 0; },
    goToNextRow() { index++; return index < rows.length; },
    getString(column) { return rows[index][column]; },
    getLong(column) { return rows[index][column]; },
    close() {}
  };
}

function workspaceCacheModule(fileIo) {
  return load('NativeWorkspaceCache', {
    '@kit.AbilityKit': {},
    '@kit.CoreFileKit': { fileIo },
    '@kit.ArkData': { relationalStore: {} },
    '@kit.ArkTS': { util: {} },
    './NativeHarnessClient': {
      NativeDirectoryEntry: class {}, NativeDirectoryListing: class {}, NativeFilePage: class {}
    },
    './NativeStorageBudget': {
      NativeStorageCandidate: class {},
      NativeStorageOwner: {
        transcript: 'transcript',
        workspaceDirectory: 'workspace-directory',
        workspaceText: 'workspace-text',
        workspaceBinary: 'workspace-binary',
        attachment: 'attachment',
        navigation: 'navigation'
      }
    }
  });
}

function metadataStore() {
  const rows = [
    { kind: 'text', session: 'session-a', path: 'same.txt', bytes: 600 * 1024 * 1024, updated: 1 },
    ...Array.from({ length: 63 }, (_, index) => ({
      kind: 'text', session: 'session-fill-' + index, path: 'fill-' + index + '.txt',
      bytes: 1, updated: index + 2
    })),
    { kind: 'text', session: 'session-b', path: 'same.txt', bytes: 1, updated: 100 }
  ];
  const deletes = [];
  return {
    rows,
    deletes,
    async querySql(sql) {
      if (sql.includes('COALESCE(SUM(bytes),0) FROM (')) {
        return cursor([[rows.reduce((total, row) => total + row.bytes, 0)]]);
      }
      if (sql.includes('SELECT kind,session_id,path,bytes FROM (')) {
        return cursor([...rows].sort((left, right) => left.updated - right.updated)
          .slice(0, 64).map(row => [row.kind, row.session, row.path, row.bytes]));
      }
      if (sql.includes('SELECT kind,path,bytes FROM (')) {
        return cursor([...rows].sort((left, right) => left.updated - right.updated)
          .slice(0, 64).map(row => [row.kind, row.path, row.bytes]));
      }
      throw Error('Unexpected metadata SQL: ' + sql);
    },
    async executeSql(sql, args) {
      deletes.push({ sql, args });
      for (let index = rows.length - 1; index >= 0; index--) {
        const row = rows[index];
        const kind = sql.includes('text_cache') ? 'text' : 'directory';
        const matches = args.length === 3
          ? row.kind === kind && row.session === args[1] && row.path === args[2]
          : row.kind === kind && row.path === args[1];
        if (matches) rows.splice(index, 1);
      }
    }
  };
}

function binaryStore() {
  const rows = [
    {
      session: 'session-a', path: 'same.bin', file: 'session-a.bin',
      bytes: 3 * 1024 * 1024 * 1024, updated: 1
    },
    ...Array.from({ length: 31 }, (_, index) => ({
      session: 'session-fill-' + index, path: 'fill-' + index + '.bin',
      file: 'session-fill-' + index + '.bin', bytes: 1, updated: index + 2
    })),
    {
      session: 'session-b', path: 'same.bin', file: 'session-b.bin',
      bytes: 1, updated: 100
    }
  ];
  const deletes = [];
  return {
    rows,
    deletes,
    async querySql(sql, args) {
      if (sql.includes('COALESCE(SUM(bytes),0)')) {
        return cursor([[rows.reduce((total, row) => total + row.bytes, 0)]]);
      }
      if (sql.includes('SELECT session_id,path,file_name,bytes FROM binary_cache')) {
        return cursor([...rows].sort((left, right) => left.updated - right.updated)
          .slice(0, 32).map(row => [row.session, row.path, row.file, row.bytes]));
      }
      if (sql.includes('SELECT path,file_name,bytes FROM binary_cache')) {
        return cursor([...rows].sort((left, right) => left.updated - right.updated)
          .slice(0, 32).map(row => [row.path, row.file, row.bytes]));
      }
      if (sql.includes('SELECT file_name FROM binary_cache')) {
        const row = args.length === 3
          ? rows.find(value => value.session === args[1] && value.path === args[2])
          : rows.find(value => value.path === args[1]);
        return cursor(row ? [[row.file]] : []);
      }
      throw Error('Unexpected binary SQL: ' + sql);
    },
    async executeSql(sql, args) {
      deletes.push({ sql, args });
      for (let index = rows.length - 1; index >= 0; index--) {
        const row = rows[index];
        const matches = args.length === 3
          ? row.session === args[1] && row.path === args[2]
          : row.path === args[1];
        if (matches) rows.splice(index, 1);
      }
    }
  };
}

test('workspace LRU eviction isolates equal paths by session for metadata and binaries', async () => {
  const unlinked = [];
  const fileIo = {
    accessSync: () => true,
    mkdirSync() {},
    unlinkSync: path => unlinked.push(path)
  };
  const { NativeWorkspaceCache } = workspaceCacheModule(fileIo);
  const metadata = metadataStore();
  await NativeWorkspaceCache.trimMetadata(metadata, 'scope-a');
  assert.deepEqual(metadata.rows.map(row => row.session), ['session-b']);
  assert.equal(metadata.deletes.length, 64);
  assert.ok(metadata.deletes.every(entry => entry.args.length === 3));
  assert.ok(metadata.deletes.some(entry =>
    entry.args[1] === 'session-a' && entry.args[2] === 'same.txt'));

  const binary = binaryStore();
  await NativeWorkspaceCache.trimBinary(
    binary, { filesDir: '/app/files' }, 'scope-a'
  );
  assert.deepEqual(binary.rows.map(row => row.session), ['session-b']);
  assert.equal(binary.deletes.length, 32);
  assert.ok(binary.deletes.every(entry => entry.args.length === 3));
  assert.ok(binary.deletes.some(entry =>
    entry.args[1] === 'session-a' && entry.args[2] === 'same.bin'));
  assert.ok(unlinked.includes('/app/files/native-workspace-cache/session-a.bin'));
  assert.equal(unlinked.includes('/app/files/native-workspace-cache/session-b.bin'), false);
});
