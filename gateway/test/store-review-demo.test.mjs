import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';
import ts from 'typescript';
import vm from 'node:vm';

const root = new URL('../../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root), 'utf8');
const services = new URL('harmony/entry/src/main/ets/services/', root);

const index = read('harmony/entry/src/main/ets/pages/Index.ets');
const showcase = read('harmony/entry/src/main/ets/services/StoreShowcaseClient.ets');
const workspace = read('harmony/entry/src/main/ets/components/NativeWorkspace.ets');
const experience = read('harmony/entry/src/main/ets/services/NativeExperience.ets');
const entryAbility = read('harmony/entry/src/main/ets/entryability/EntryAbility.ets');
const driver = read('scripts/device-ui-store-review-e2e.ps1');
const community = read('harmony/entry/src/community/ProductCapabilities.ets');
const store = read('harmony/entry/src/store/ProductCapabilities.ets');
const mock = read('harmony/entry/src/mock/ProductCapabilities.ets');
const showcaseClass = showcase.slice(showcase.indexOf('export class StoreShowcaseClient'));

class EmptyModel {}
class NativeFrame extends EmptyModel {
  type = '';
  messages = [];
  cursor = 0;
  running = false;
  waiting = false;
  queue = [];
}
class NativeSessionModel extends EmptyModel {
  restore(record) { this.record = record; }
}
class NativePluginInventory extends EmptyModel {
  available = false;
  bundles = [];
  plugins = [];
}
class NativeAutomationCatalog extends EmptyModel {
  available = false;
  items = [];
}
class NativeUploadResult extends EmptyModel {
  receiptId = '';
}
class NativeHttpError extends Error {
  constructor(status, code = '') {
    super(code || String(status));
    this.status = status;
    this.code = code;
  }
}
class NativeShowcaseInteraction {
  constructor(messages = [], running = false, cursor = 0, queue = []) {
    this.messages = messages;
    this.running = running;
    this.cursor = cursor;
    this.queue = queue;
    this.waiting = false;
  }
  snapshot() {
    const frame = new NativeFrame();
    frame.messages = this.messages;
    frame.cursor = this.cursor;
    frame.running = this.running;
    frame.waiting = this.waiting;
    frame.queue = this.queue;
    return frame;
  }
  prompt() {
    return { accepted: true, admissionFrames: [], streamFrames: [], settleFrames: [] };
  }
  cancel() { return []; }
}
class NativeHarnessClient {
  constructor(origin) {
    this.origin = origin;
    this.models = new Map();
    this.attachments = new Map();
    this.images = new Map();
    this.drafts = new Map();
    this.uncertain = new Set();
    this.selectedId = '';
  }
  cacheKey() { return 'showcase'; }
}

function loadShowcase() {
  const source = readFileSync(new URL('StoreShowcaseClient.ets', services), 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const modelExports = new Proxy({}, {
    get(_target, name) {
      if (name === 'NativeFrame') return NativeFrame;
      if (name === 'NativeSessionModel') return NativeSessionModel;
      if (name === 'NativeSessionList') return class { items = []; };
      if (name === 'NativeWorkspaceSnapshot') return class { items = []; pinnedSessionIds = []; };
      if (name === 'NativeWorkspaceItem') return class { sessionIds = []; };
      if (name === 'NativeQuestion') return class { options = []; };
      return EmptyModel;
    }
  });
  const kits = {
    './NativeHarnessClient': {
      GatewayState: EmptyModel,
      NativeHarnessClient,
      NativeHttpError,
      NativeUploadResult,
      NativeAttachmentDraft: EmptyModel
    },
    './NativeSessionModel': modelExports,
    './NativeModeSubagent': new Proxy({}, { get: () => EmptyModel }),
    './NativeShowcaseInteraction': {
      NativeShowcaseInteraction,
      NativeShowcaseAttachment: EmptyModel,
      nativeShowcaseQueueItem: (rpcId, text, attachments) => ({ rpcId, text, attachments })
    },
    './NativeUiFixture': { NativeUiFixture: { state: value => value } },
    './NativePermissions': { NativePermissionSelection: EmptyModel },
    './NativeAdminModels': new Proxy({}, {
      get(_target, name) {
        if (name === 'NativePluginInventory') return NativePluginInventory;
        if (name === 'NativeAutomationCatalog') return NativeAutomationCatalog;
        return EmptyModel;
      }
    }),
    './BuildInfo': { BuildInfo: { appName: 'DSH Mobile' } },
    '@kit.NetworkKit': { http: { RequestMethod: { GET: 'GET', POST: 'POST' } } }
  };
  const module = { exports: {} };
  const AppStorage = {
    get: () => undefined,
    setOrCreate: () => {}
  };
  vm.runInNewContext(output, {
    module,
    exports: module.exports,
    require: id => {
      if (kits[id]) return kits[id];
      if (id.startsWith('./') && existsSync(new URL(id.slice(2) + '.ets', services))) {
        throw new Error('Unstubbed service dependency: ' + id);
      }
      throw new Error('Unexpected dependency: ' + id);
    },
    setTimeout,
    clearTimeout,
    AppStorage,
    Date,
    Map,
    Set,
    Promise,
    JSON,
    Math,
    Number,
    Array,
    Object,
    String,
    Error,
    Uint8Array,
    ArrayBuffer,
    console
  });
  return new module.exports.StoreShowcaseClient('showcase-plan', true);
}

test('store review capability is store-only and checked before a real Host client exists', () => {
  assert.match(store, /supportsStoreReview:\s*boolean\s*=\s*true/);
  assert.match(store, /storeReviewOrigin:\s*string\s*=\s*'https:\/\/dsh\.dshoh\.com'/);
  assert.match(store, /storeReviewCredentialSha256:\s*string\s*=\s*'[A-F0-9]{64}'/);
  for (const source of [community, mock]) {
    assert.match(source, /supportsStoreReview:\s*boolean\s*=\s*false/);
    assert.match(source, /storeReviewOrigin:\s*string\s*=\s*''/);
    assert.match(source, /storeReviewCredentialSha256:\s*string\s*=\s*''/);
  }
  const credentialCheck = index.indexOf('this.storeReviewCredentialMatches(next, this.accessKey)');
  const realClient = index.indexOf('this.nativeClient = new NativeHarnessClient(next)');
  assert.ok(credentialCheck >= 0 && realClient > credentialCheck);
  assert.match(index, /encoder\.encodeInto\(origin \+ '\\n' \+ credential\.trim\(\)\)/);
  assert.match(index, /getSync\('storeReviewMode', false\) === true/);
  assert.match(index, /putSync\('storeReviewMode', true\)/);
  assert.match(index, /putSync\('storeReviewMode', false\)/);
  assert.match(entryAbility,
    /if \(ProductCapabilities\.supportsMockFixtures\)[\s\S]{0,180}AppStorage\.setOrCreate<boolean>\('storeShowcase', true\)/);
  assert.doesNotMatch(entryAbility, /storeShowcase\s*===\s*true/);
  assert.match(entryAbility,
    /else \{[\s\S]{0,220}AppStorage\.setOrCreate<boolean>\('storeShowcase', false\)/);
});

test('external credential digest matches the store product when supplied in CI', {
  skip: !process.env.DSH_STORE_REVIEW_ACCESS_KEY
}, () => {
  const origin = 'https://dsh.dshoh.com';
  const digest = createHash('sha256')
    .update(origin + '\n' + process.env.DSH_STORE_REVIEW_ACCESS_KEY.trim())
    .digest('hex')
    .toUpperCase();
  assert.ok(store.includes(`'${digest}'`));
});

test('review sends fail with structured balance data and retain the draft', () => {
  assert.match(showcaseClass, /setTimeout\(resolve,\s*1200\)/);
  assert.match(showcaseClass, /new NativeHttpError\(402, 'insufficient_balance'\)/);
  assert.match(workspace, /error\.status === 402/);
  assert.match(workspace, /error\.code === 'insufficient_balance'/);
  assert.match(workspace, /this\.error = '账户余额不足，请充值后重试'/);
  assert.match(workspace, /catch \(error\)[\s\S]*?this\.client\.drafts\.set\(id, text\)/);
  assert.doesNotMatch(workspace, /insufficient_balance[\s\S]{0,200}this\.client\.drafts\.set\(id, ''\)/);
});

test('review settings mutate host values, enforce revisions and reset ordinary runtime keys', () => {
  assert.match(showcaseClass, /chatRevision\+\+/);
  assert.match(showcaseClass, /conversationRevision\+\+/);
  assert.match(showcaseClass, /invalid_settings_revision/);
  assert.match(showcaseClass, /settings_revision_conflict/);
  assert.match(index, /nativeUserReduceMotion/);
  assert.match(index, /nativeReduceTransparency/);
  assert.match(index, /NativeExperience\.refresh\(this\.context\)/);
  assert.match(index, /storeReviewTheme/);
  assert.match(index, /storeReviewReduceMotion/);
  assert.match(index, /storeReviewNotifyCompleted/);
  assert.match(index, /storeReviewWidgetDetails/);
  assert.match(index,
    /NativeExperience\.refresh\(this\.context\);[\s\S]{0,120}this\.nativeThemeMode = AppStorage\.get<string>\('nativeThemeMode'\)/);
  assert.match(experience, /store\.getSync\('reduceMotion', false\)/);
  assert.match(experience, /store\.getSync\('reduceTransparency', true\)/);
  assert.match(experience, /if \(!preservePresentation\)/);
  assert.match(entryAbility,
    /NativeExperience\.refresh\(this\.context,[\s\S]{0,180}storeReviewPresentationActive[\s\S]{0,100}storeShowcase/);
});

test('review uploads and admin operations never escape the in-process showcase', () => {
  assert.match(showcaseClass, /async uploadAttachment\(/);
  assert.match(showcaseClass, /new NativeUploadResult\(\)/);
  assert.doesNotMatch(showcaseClass, /super\.uploadAttachment/);
  assert.doesNotMatch(showcaseClass, /pocket\/api\/native\/upload/);
  assert.match(showcaseClass, /bundle\.installed = true/);
  assert.match(showcaseClass, /bundle\.installed = false/);
  assert.match(showcaseClass, /this\.pluginInventory\.plugins = this\.pluginInventory\.plugins\.filter/);
  assert.match(showcaseClass, /this\.automationCatalog\.items\.push\(task\)/);
  assert.match(showcaseClass, /this\.automationCatalog\.items = this\.automationCatalog\.items\.filter/);
  assert.match(showcaseClass, /schedule_conflict/);
});

test('device driver hands the credential through a private file and covers review flows', () => {
  assert.match(driver, /hdc -t \$Device file send/);
  assert.match(driver, /\$\(cat /);
  assert.doesNotMatch(driver, /inputText \$\(\$key\.x\) \$\(\$key\.y\) \$accessKey/);
  assert.match(driver, /finally/);
  assert.match(driver, /Remove-Item -LiteralPath \$localSecret/);
  for (const label of [
    'file browser directory and preview mutation',
    'plugin open, toggle, install, update and remove',
    'automation run, pause, create, edit and delete',
    'local persistence and in-session DSH settings mutation',
    'settings revision conflict (executable contract)',
    'structured balance error and draft retention',
    'review restore',
    'logout clearing and cold-relaunch rejection'
  ]) {
    assert.ok(driver.includes(label), label);
  }
  for (const id of [
    'file-entry-app.conf',
    'plugin-install-@dsh/markdown-check',
    'automation-task-automation-docs',
    'settings-open-dsh',
    'settings-notification-failed-prominent',
    'settings-action-logout'
  ]) {
    assert.ok(driver.includes(id), id);
  }
  for (const id of [
    'settings-theme-state-dark-selected',
    'settings-toggle-state-reduceMotion-on',
    'settings-toggle-state-reduceTransparency-on'
  ]) {
    assert.ok(driver.includes(id), id);
  }
});

test('executable review client keeps settings, uploads and admin state in process', async () => {
  const client = loadShowcase();
  const operation = body => client.operation(JSON.stringify(body));
  const surfaces = [
    await client.state(),
    await client.sessions(),
    await client.workspaces(),
    JSON.parse(await operation({ operation: 'pluginsList' })),
    JSON.parse(await operation({ operation: 'automationList' })),
    JSON.parse(await operation({ operation: 'settingsDescribe' }))
  ];
  assert.doesNotMatch(JSON.stringify(surfaces), /mock|fixture|synthetic|demo|演示/i);

  const upload = await client.uploadAttachment('showcase-release', 'notes.txt',
    new Uint8Array([1, 2, 3, 4]), 'text/plain');
  assert.match(upload.receiptId, /^showcase-upload-/);

  const started = Date.now();
  await assert.rejects(
    () => client.prompt('showcase-release', 'balance probe'),
    error => error.status === 402 && error.code === 'insufficient_balance'
  );
  assert.ok(Date.now() - started >= 1100, 'review prompt must wait before failing');

  const described = JSON.parse(await operation({ operation: 'settingsDescribe' }));
  const chat = described.namespaces.find(row => row.ns === 'ui-chat');
  const updated = JSON.parse(await operation({
    operation: 'settingsSet',
    ns: 'ui-chat',
    field: 'transcriptView',
    value: 'compact',
    revision: chat.revision
  }));
  assert.equal(updated.value.transcriptView, 'compact');
  assert.equal(updated.revision, chat.revision + 1);
  await assert.rejects(
    () => operation({
      operation: 'settingsSet',
      ns: 'ui-chat',
      field: 'transcriptView',
      value: 'standard',
      revision: chat.revision
    }),
    error => error.status === 409 && error.code === 'settings_revision_conflict'
  );

  const builtIn = JSON.parse(await operation({
    operation: 'automationView', id: 'automation-review'
  }));
  const originalPrompt = builtIn.prompt;
  const editedBuiltIn = JSON.parse(await operation({
    operation: 'automationEdit',
    request: {
      id: builtIn.id,
      expectedUpdatedAt: builtIn.updatedAt,
      patch: { prompt: '更新后的内置任务指令。' }
    }
  }));
  const ranBuiltIn = JSON.parse(await operation({
    operation: 'automationRun', id: builtIn.id
  }));
  const builtInHistory = JSON.parse(await operation({
    operation: 'automationHistory', id: builtIn.id
  }));
  assert.equal(builtInHistory.records.length, 4,
    'running a seeded task before its first history read must retain all seed rows');
  assert.equal(builtInHistory.records[0].prompt, editedBuiltIn.prompt);
  assert.equal(builtInHistory.records[0].deliveredAt, ranBuiltIn.lastDeliveryAt);
  assert.equal(builtInHistory.records[1].prompt, originalPrompt,
    'editing a seeded task must not rewrite its original delivery prompt');

  let plugins = JSON.parse(await operation({ operation: 'pluginsList' }));
  const inspector = plugins.bundles.find(bundle => bundle.name === '@dsh/api-inspector');
  assert.equal(inspector.enabled, true);
  await operation({ operation: 'pluginSetEnabled', name: inspector.name, enabled: false });
  plugins = JSON.parse(await operation({ operation: 'pluginsList' }));
  assert.equal(plugins.bundles.find(bundle => bundle.name === inspector.name).enabled, false);

  await operation({ operation: 'pluginInstall', spec: '@dsh/markdown-check' });
  plugins = JSON.parse(await operation({ operation: 'pluginsList' }));
  assert.equal(plugins.bundles.find(bundle => bundle.name === '@dsh/markdown-check').installed, true);
  const versions = JSON.parse(await operation({
    operation: 'pluginVersions', name: '@dsh/api-inspector'
  }));
  const nextVersion = versions.versions[0].version;
  await operation({
    operation: 'pluginUpdate', name: '@dsh/api-inspector', version: nextVersion
  });
  plugins = JSON.parse(await operation({ operation: 'pluginsList' }));
  assert.equal(plugins.bundles.find(bundle => bundle.name === '@dsh/api-inspector').version, nextVersion);
  await operation({ operation: 'pluginRemove', name: '@dsh/markdown-check' });
  plugins = JSON.parse(await operation({ operation: 'pluginsList' }));
  assert.equal(plugins.bundles.find(bundle => bundle.name === '@dsh/markdown-check').installed, false);

  const created = JSON.parse(await operation({
    operation: 'automationCreate',
    request: {
      title: '审核任务状态',
      prompt: '检查构建与发布状态。',
      timing: { kind: 'daily', daily: { time: '12:00:00', time_zone: 'Asia/Shanghai' } },
      target: { kind: 'new_once', create: { cwd: 'DSH Mobile' } }
    }
  }));
  let catalog = JSON.parse(await operation({ operation: 'automationList' }));
  assert.ok(catalog.items.some(item => item.id === created.id));
  const edited = JSON.parse(await operation({
    operation: 'automationEdit',
    request: {
      id: created.id,
      expectedUpdatedAt: created.updatedAt,
      patch: { title: '审核任务状态（已更新）' }
    }
  }));
  assert.match(edited.title, /已更新/);
  await assert.rejects(
    () => operation({
      operation: 'automationEdit',
      request: {
        id: created.id,
        expectedUpdatedAt: created.updatedAt,
        patch: { title: '过期更新' }
      }
    }),
    error => error.status === 409 && error.code === 'schedule_conflict'
  );

  const run = JSON.parse(await operation({ operation: 'automationRun', id: created.id }));
  const history = JSON.parse(await operation({
    operation: 'automationHistory', id: created.id
  }));
  assert.equal(history.records[0].deliveredAt, run.lastDeliveryAt);
  assert.equal(history.records[0].prompt, edited.prompt);
  await operation({
    operation: 'automationEdit',
    request: {
      id: created.id,
      expectedUpdatedAt: run.updatedAt,
      patch: { prompt: '新的运行指令。' }
    }
  });
  const retained = JSON.parse(await operation({
    operation: 'automationHistory', id: created.id
  }));
  assert.equal(retained.records[0].prompt, '检查构建与发布状态。',
    'editing a task must not rewrite historical delivery prompt');

  const deleted = JSON.parse(await operation({
    operation: 'automationDelete',
    id: created.id,
    expectedUpdatedAt: retained.records.length ? JSON.parse(await operation({
      operation: 'automationView', id: created.id
    })).updatedAt : ''
  }));
  assert.equal(deleted.deleted, true);
  catalog = JSON.parse(await operation({ operation: 'automationList' }));
  assert.equal(catalog.items.some(item => item.id === created.id), false);

  const parts = [];
  await client.exportSession('showcase-release', 'markdown',
    part => parts.push(Buffer.from(part)));
  const markdown = Buffer.concat(parts).toString('utf8');
  assert.match(markdown, /^# DSH Mobile 对话导出/);
  assert.ok(markdown.length > 100);
});
