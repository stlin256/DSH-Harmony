import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';

const services = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);
const components = new URL('../../harmony/entry/src/main/ets/components/', import.meta.url);

function loadBudget() {
  const source = readFileSync(new URL('NativeStorageBudget.ets', services), 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS }
  });
  const module = { exports: {} };
  vm.runInNewContext(output.outputText, { module, exports: module.exports });
  return module.exports;
}

function loadManager(values = {}) {
  const calls = [];
  const workspace = values.workspace || { directory: 200, text: 300, binary: 400 };
  const budget = loadBudget();
  const candidates = values.candidates || [
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.transcript,
      'transcript-scope', 'current', 'session', values.conversation ?? 100, 1),
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.workspaceDirectory,
      'workspace-scope', 'current', '/a', workspace.directory, 2),
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.workspaceText,
      'workspace-scope', 'current', '/b', workspace.text, 3),
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.workspaceBinary,
      'workspace-scope', 'current', '/c', workspace.binary, 4),
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.attachment,
      'attachment-scope', '', 'image.bin', values.attachments ?? 500, 5),
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.navigation,
      'navigation-scope', '', 'metadata:navigation-scope', values.navigation ?? 600, 6)
  ];
  const dependencies = {
    './NativeStorageBudget': budget,
    './NativeAttachmentCache': {
      NativeAttachmentCache: {
        scopeId(scope) {
          return 'attachment-' + scope;
        },
        async storageCandidates() {
          calls.push(['candidates:attachments']);
          return candidates.filter(value => value.owner === budget.NativeStorageOwner.attachment);
        },
        async evictStorageCandidate(_context, candidate) {
          calls.push(['evict:attachments', candidate.key]);
        },
        async usageScope(_context, scope) {
          calls.push(['usage:attachments', scope]);
          return values.attachments ?? 500;
        },
        async clearScope(_context, scope) {
          calls.push(['clear:attachments', scope]);
          if (values.failAttachments) throw new Error('attachments');
        }
      }
    },
    './NativeMetadataCache': {
      NativeMetadataCache: {
        scopeId(scope) {
          return 'navigation-' + scope;
        },
        storageCandidates() {
          calls.push(['candidates:navigation']);
          return candidates.filter(value => value.owner === budget.NativeStorageOwner.navigation);
        },
        evictStorageCandidate(_context, candidate) {
          calls.push(['evict:navigation', candidate.key]);
        },
        usage(_context, scope) {
          calls.push(['usage:navigation', scope]);
          return values.navigation ?? 600;
        },
        clear(_context, scope) {
          calls.push(['clear:navigation', scope]);
        }
      }
    },
    './NativeTranscriptCache': {
      NativeTranscriptCache: {
        scopeId(scope) {
          return 'transcript-' + scope;
        },
        async storageCandidates() {
          calls.push(['candidates:transcript']);
          return candidates.filter(value => value.owner === budget.NativeStorageOwner.transcript);
        },
        async evictStorageCandidate(_context, candidate) {
          calls.push(['evict:transcript', candidate.sessionId]);
        },
        async usageScope(_context, scope) {
          calls.push(['usage:transcript', scope]);
          return values.conversation ?? 100;
        },
        async clearScope(_context, scope) {
          calls.push(['clear:transcript', scope]);
          if (values.failTranscript) throw new Error('transcript');
        }
      }
    },
    './NativeWorkspaceCache': {
      NativeWorkspaceCacheUsage: class {},
      nativeWorkspaceScopeId(scope) {
        return 'workspace-' + scope;
      },
      NativeWorkspaceCache: {
        async storageCandidates() {
          calls.push(['candidates:workspace']);
          return candidates.filter(value => value.owner.startsWith('workspace-'));
        },
        async evictStorageCandidate(_context, candidate) {
          calls.push(['evict:workspace', candidate.key]);
        },
        async usageScope(_context, scope) {
          calls.push(['usage:workspace', scope]);
          return workspace;
        },
        async clearScope(_context, scope) {
          calls.push(['clear:workspace', scope]);
          if (values.failWorkspace) throw new Error('workspace');
        }
      }
    }
  };
  const source = readFileSync(new URL('NativeStorageManager.ets', services), 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS }
  });
  const module = { exports: {} };
  vm.runInNewContext(output.outputText, {
    module,
    exports: module.exports,
    require: id => {
      if (id === '@kit.AbilityKit') return {};
      if (id in dependencies) return dependencies[id];
      throw Error('Unexpected dependency: ' + id);
    }
  });
  return { exports: module.exports, calls };
}

test('storage sizes use compact binary units and reject invalid values', () => {
  const { nativeFormatStorageBytes } = loadManager().exports;
  assert.equal(nativeFormatStorageBytes(0), '0 B');
  assert.equal(nativeFormatStorageBytes(-10), '0 B');
  assert.equal(nativeFormatStorageBytes(Number.NaN), '0 B');
  assert.equal(nativeFormatStorageBytes(1023), '1023 B');
  assert.equal(nativeFormatStorageBytes(1024), '1 KiB');
  assert.equal(nativeFormatStorageBytes(1536), '1.5 KiB');
  assert.equal(nativeFormatStorageBytes(10.5 * 1024 * 1024), '10.5 MiB');
  assert.equal(nativeFormatStorageBytes(120.4 * 1024 * 1024), '120 MiB');
});

test('storage usage is a complete current-scope aggregate', async () => {
  const { exports, calls } = loadManager();
  const usage = await exports.NativeStorageManager.usageScope({}, 'scope-current');
  assert.deepEqual({
    conversation: usage.conversation,
    fileBrowser: usage.fileBrowser,
    fileContent: usage.fileContent,
    imageAttachments: usage.imageAttachments,
    navigation: usage.navigation,
    total: usage.total,
    poolTotal: usage.poolTotal,
    limit: usage.limit
  }, {
    conversation: 100,
    fileBrowser: 200,
    fileContent: 700,
    imageAttachments: 500,
    navigation: 600,
    total: 2100,
    poolTotal: 2100,
    limit: 5 * 1024 * 1024 * 1024
  });
  assert.ok(calls.filter(call => call[0].startsWith('usage:')).every(call => call[1] === 'scope-current'));
  assert.deepEqual(calls.filter(call => call[0].startsWith('usage:')).map(call => call[0]),
    ['usage:transcript', 'usage:workspace', 'usage:attachments', 'usage:navigation']);
  assert.deepEqual(calls.filter(call => call[0].startsWith('candidates:')).map(call => call[0]),
    ['candidates:transcript', 'candidates:workspace', 'candidates:attachments', 'candidates:navigation']);
});

test('clear continues through every cache owner and reports partial failure', async () => {
  const { exports, calls } = loadManager({ failTranscript: true, failWorkspace: true });
  await assert.rejects(() => exports.NativeStorageManager.clearScope({}, 'scope-current'),
    /Cache clear failed/);
  assert.deepEqual(calls.map(call => call[0]),
    ['clear:navigation', 'clear:transcript', 'clear:workspace', 'clear:attachments']);
  assert.ok(calls.every(call => call[1] === 'scope-current'));
});

test('Settings exposes confirmed red storage clearing without success feedback', () => {
  const settings = readFileSync(new URL('NativeSettings.ets', components), 'utf8');
  assert.match(settings, /navigationRow\('archive-outline', '存储管理', '缓存占用与清理', 'storage'\)/);
  assert.match(settings, /NativeStorageManager\.usageScope\(context, this\.client\.cacheKey\(\)\)/);
  assert.match(settings, /NativeStorageManager\.clearScope\(context, this\.client\.cacheKey\(\)\)/);
  assert.match(settings, /title: '清空缓存'/);
  assert.match(settings, /message: '仅清除当前账户的本机缓存，不会退出登录或删除远端内容。'/);
  assert.match(settings, /fontColor: NativeDesign\.danger\(this\.dark\)/);
  assert.match(settings, /Text\('清空缓存'\)[\s\S]{0,100}fontColor\(this\.dangerText\(\)\)/);
  assert.match(settings, /this\.settingsPage === 'storage'/);
  assert.match(settings, /storageBreakdownRow\(title: string, kind: string\)/);
  assert.match(settings, /nativeFormatStorageBytes\(this\.storageBreakdownValue\(kind\)\)/);
  assert.match(settings, /storageBreakdownRow\('对话内容', 'conversation'\)/);
  assert.match(settings, /storageBreakdownRow\('文件浏览', 'fileBrowser'\)/);
  assert.match(settings, /Text\('缓存池'\)/);
  assert.match(settings, /nativeFormatStorageBytes\(this\.storageUsage\.limit\)/);
  assert.match(settings, /nativeFormatStorageBytes\(this\.storageUsage\.poolTotal\)/);
  assert.doesNotMatch(settings, /Storage[^\n]*success|缓存已清空|showToast\([\s\S]{0,80}清空/);
});

test('default pool is exactly 5 GiB and LRU eviction protects active work when possible', () => {
  const budget = loadBudget();
  const gib = 1024 * 1024 * 1024;
  assert.equal(budget.NATIVE_DEFAULT_CACHE_LIMIT_BYTES, 5 * gib);
  const exact = [
    new budget.NativeStorageCandidate('transcript', 'a', 'active', 'a', 5 * gib, 20)
  ];
  assert.equal(budget.nativeStorageEvictionPlan(exact, 5 * gib).length, 0,
    'exactly 5 GiB is allowed');

  const old = new budget.NativeStorageCandidate('workspace-binary', 'b', 'old', '/old.pdf', 2 * gib, 10);
  const active = new budget.NativeStorageCandidate('transcript', 'a', 'active', 'a', 4 * gib, 20);
  active.protectedEntry = true;
  const remaining = new budget.NativeStorageCandidate('attachment', 'c', '', 'image.bin', 1024, 30);
  const plan = budget.nativeStorageEvictionPlan([active, old, remaining], 5 * gib);
  assert.deepEqual(Array.from(plan, value => value.key), ['/old.pdf'],
    'unprotected entries are removed oldest first and active work remains');

  const protectedOnly = [
    new budget.NativeStorageCandidate('transcript', 'a', 'active', 'a', 4 * gib, 20),
    new budget.NativeStorageCandidate('transcript', 'b', 'protected', 'b', 2 * gib, 10)
  ];
  protectedOnly.forEach(value => { value.protectedEntry = true; });
  assert.deepEqual(Array.from(budget.nativeStorageEvictionPlan(protectedOnly, 5 * gib), value => value.key),
    ['b'], 'protected entries are a hard-limit fallback in LRU order');
});

test('global coordinator evicts compact candidates across cache owners', async () => {
  const budget = loadBudget();
  const gib = 1024 * 1024 * 1024;
  const candidates = [
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.transcript,
      'transcript-scope-current', 'current', 'active', 3 * gib, 20),
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.workspaceBinary,
      'workspace-scope-current', 'current', '/current.pdf', 1024, 21),
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.workspaceBinary,
      'workspace-scope-old', 'old', '/old.pdf', 2 * gib, 10),
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.attachment,
      'attachment-scope-old', '', 'old-image.bin', gib, 11),
    new budget.NativeStorageCandidate(budget.NativeStorageOwner.attachment,
      'attachment-scope-current', '', 'current-image.bin', gib, 12)
  ];
  const { exports, calls } = loadManager({ candidates });
  const after = await exports.NativeStorageManager.enforceDefaultLimit(
    {}, 'scope-current', 'current', [], true);
  assert.equal(after, 4 * gib + 1024);
  assert.deepEqual(calls.filter(call => call[0] === 'evict:workspace').map(call => call[1]),
    ['/old.pdf']);
  assert.deepEqual(calls.filter(call => call[0] === 'evict:attachments').map(call => call[1]),
    ['old-image.bin']);
});

test('cache owners expose non-mutating usage accounting', () => {
  const transcript = readFileSync(new URL('NativeTranscriptCache.ets', services), 'utf8');
  const workspace = readFileSync(new URL('NativeWorkspaceCache.ets', services), 'utf8');
  const attachments = readFileSync(new URL('NativeAttachmentCache.ets', services), 'utf8');
  const metadata = readFileSync(new URL('NativeMetadataCache.ets', services), 'utf8');
  assert.match(transcript, /static async usageScope[\s\S]{0,900}SUM\(bytes\)/);
  assert.match(workspace, /static async usageScope[\s\S]{0,900}directory_cache/);
  assert.match(workspace, /static async usageScope[\s\S]{0,1800}text_cache/);
  assert.match(workspace, /static async usageScope[\s\S]{0,2200}binary_cache/);
  assert.match(attachments, /static async usageScope[\s\S]{0,700}statSync/);
  assert.match(metadata, /static usage[\s\S]{0,600}routeKey\(origin\)/);
  assert.doesNotMatch(transcript.slice(transcript.indexOf('static async usageScope'),
    transcript.indexOf('static async saveRoute')), /UPDATE .*updated_at/);
  assert.doesNotMatch(workspace.slice(workspace.indexOf('static async usageScope'),
    workspace.indexOf('private static async trimMetadata')), /UPDATE .*updated_at/);
});
