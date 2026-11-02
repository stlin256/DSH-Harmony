// Exercises service logic under kit mocks. This is not an ArkTS/Hvigor build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import ts from 'typescript';
import {
  normalizedHistory,
  normalizeFollow,
  normalizeQueuedState,
  queueFromInbox
} from '../src/native-protocol.mjs';

const services = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);
function load(name, kits, globals = {}) {
  const source = readFileSync(new URL(name + '.ets', services), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS } });
  const module = { exports: {} };
  vm.runInNewContext(output.outputText, { module, exports: module.exports, setTimeout, clearTimeout, require: id => {
    if (!(id in kits) && id.startsWith('./') && existsSync(new URL(id.slice(2) + '.ets', services))) return load(id.slice(2), kits, globals);
    if (!(id in kits)) throw Error('Unexpected dependency: ' + id);
    return kits[id];
  }, ...globals });
  return module.exports;
}
function storage() {
  const disk = new Map();
  const preferences = {
    removePreferencesFromCacheSync() {},
    getPreferencesSync(_ctx, { name }) {
      if (!disk.has(name)) disk.set(name, new Map());
      const file = disk.get(name);
      return { getSync: (key, fallback) => structuredClone(file.has(key) ? file.get(key) : fallback),
        putSync: (key, value) => file.set(key, structuredClone(value)),
        hasSync: key => file.has(key), deleteSync: key => file.delete(key),
        flushSync() {}, flush() { return Promise.resolve(); } };
    }
  };
  return { disk, preferences };
}
const context = { getApplicationContext() { return this; } };

test('widget task-name defaults, opt-out, cross-process restoration, expiry and logout serialization', async () => {
  const { preferences, disk } = storage();
  const deliveries = [];
  let block;
  let now = Date.now();
  class Clock extends Date { static now() { return now; } }
  const kits = { '@kit.AbilityKit': {}, '@kit.ArkData': { preferences }, '@kit.FormKit': {
    formBindingData: { createFormBindingData: data => ({ data }) }, formProvider: {
      async updateForm(id, value) { if (block) await block; deliveries.push({ id, value }); }
    }
  } };
  const { WidgetStore, OverviewSnapshot } = load('WidgetStore', kits, { Date: Clock });
  WidgetStore.register(context, '123');
  WidgetStore.register(context, '123');
  const snapshot = Object.assign(new OverviewSnapshot(), { running: 2, waiting: 1, completed: 3, failed: 0, observedAt: now, generatedAt: now,
    tasks: [
      { sessionId: 'completed-session', title: '完成', state: 'completed', updatedAt: now + 3 },
      { sessionId: 'running-session', title: '运行', state: 'running', updatedAt: now + 2 },
      { sessionId: 'waiting-session', title: '确认', state: 'waiting', updatedAt: now + 1 }
    ] });
  await WidgetStore.update(context, snapshot);
  assert.equal(WidgetStore.data(context).showCounts, true);
  assert.equal(WidgetStore.data(context).primarySessionId, 'waiting-session');
  assert.deepEqual(JSON.parse(WidgetStore.data(context).tasks).map(task => task.state), ['waiting', 'running', 'completed']);
  assert.notEqual(disk.get('pocket-widget-snapshot').get('snapshot'), '');
  assert.equal(deliveries.length, 1, 'duplicate form instance IDs must not duplicate delivery');
  await WidgetStore.update(context, snapshot);
  assert.equal(deliveries.length, 1, 'unchanged card content must not republish');
  await WidgetStore.setDetails(context, false);
  await WidgetStore.update(context, snapshot);
  assert.equal(WidgetStore.data(context).showCounts, true, 'privacy mode keeps anonymous counts');
  assert.equal(WidgetStore.data(context).redacted, true);
  assert.equal(WidgetStore.data(context).showTasks, false);
  assert.equal(JSON.parse(disk.get('pocket-widget-snapshot').get('snapshot')).tasks.length, 0);
  await WidgetStore.setDetails(context, true);
  await WidgetStore.update(context, snapshot);
  assert.equal(WidgetStore.data(context).showCounts, true);
  assert.equal(WidgetStore.data(context).running, '2');
  const restarted = load('WidgetStore', kits, { Date: Clock });
  assert.equal(restarted.WidgetStore.data(context).waiting, '1');
  now += 16 * 60000;
  assert.equal(WidgetStore.data(context).showCounts, true,
    'a stale last-good snapshot keeps anonymous counts');
  assert.equal(WidgetStore.data(context).stale, true);
  assert.equal(WidgetStore.data(context).showTasks, false);
  assert.match(WidgetStore.data(context).detail, /过期/);
  let release;
  block = new Promise(resolve => { release = resolve; });
  const updating = WidgetStore.update(context, snapshot);
  const clearing = WidgetStore.clear(context);
  release(); block = null;
  await Promise.all([updating, clearing]);
  assert.equal(WidgetStore.data(context).headline, '连接工作空间');
  assert.equal(deliveries.at(-1).value.data.showCounts, false);
  assert.equal(disk.get('pocket-widget-snapshot').get('snapshot'), '');
  WidgetStore.remove(context, '123');
  const before = deliveries.length;
  await WidgetStore.update(context, snapshot);
  assert.equal(deliveries.length, before, 'removed form must not receive updates');
});

test('system material guards old runtimes and respects opacity, motion and power policies', () => {
  const { preferences } = storage();
  const state = new Map();
  const AppStorage = { get: key => state.get(key), setOrCreate: (key, value) => state.set(key, value) };
  const deviceInfo = { sdkApiVersion: 23 };
  const uiMaterial = { getMaterialInfo: () => ({ state: 0 }), MaterialState: { DISABLE: 2 }, Material: { empty: { disabled: true } },
    ImmersiveStyle: { THIN: 1 }, ImmersiveMaterial: class { constructor(options) {
      assert.ok(deviceInfo.sdkApiVersion >= 26, 'API-26 constructor reached on old device'); this.options = options;
    } } };
  const power = { getPowerMode: () => 600, DevicePowerMode: { MODE_NORMAL: 600, MODE_PERFORMANCE: 602 } };
  const kits = { '@kit.AbilityKit': {}, '@kit.ArkData': { preferences }, '@kit.BasicServicesKit': { deviceInfo, power },
    '@kit.AccessibilityKit': { accessibility: { isAnimationReduceEnabledSync: () => false } }, '@kit.ArkUI': { uiMaterial } };
  const { NativeExperience, ChromeMaterialModifier } = load('NativeExperience', kits, { AppStorage, canIUse: () => true, BarStyle: { STANDARD: 0 }, Color: { White: '#fff' } });
  NativeExperience.refresh(context);
  assert.equal(NativeExperience.materialsEnabled(), false);
  assert.equal(NativeExperience.titleOptions(false, 0).systemMaterial, undefined);
  let applied;
  new ChromeMaterialModifier(0).applyNormalAttribute({ systemMaterial: value => { applied = value; } });
  assert.equal(applied, undefined);
  deviceInfo.sdkApiVersion = 26;
  assert.equal(NativeExperience.materialsEnabled(), true);
  new ChromeMaterialModifier(1).applyNormalAttribute({ systemMaterial: value => { applied = value; } });
  assert.equal(applied.options.interactive, true);
  state.set('nativeSystemReduceMotion', true);
  new ChromeMaterialModifier(2).applyNormalAttribute({ systemMaterial: value => { applied = value; } });
  assert.equal(applied.options.interactive, false);
  assert.equal(applied.options.lightEffect, null);
  NativeExperience.setPreference(context, 'reduceTransparency', true);
  assert.equal(NativeExperience.materialsEnabled(), false);
  assert.equal(NativeExperience.titleOptions(false, 0).systemMaterial.disabled, true);
  NativeExperience.setPreference(context, 'reduceTransparency', false);
  state.set('nativePowerSaving', true);
  assert.equal(NativeExperience.materialsEnabled(), false);
  state.set('nativePowerSaving', false); state.set('nativeAppActive', false);
  assert.equal(NativeExperience.materialsEnabled(), false);
});

test('semantic motion tokens resolve directly when motion is disabled', () => {
  const state = new Map();
  const calls = [];
  const ui = { animateTo(param, action) { calls.push(param); action(); } };
  const AppStorage = {
    get: key => state.get(key),
    setOrCreate: (key, value) => state.set(key, value)
  };
  const curves = { springMotion: (...args) => ({ kind: 'spring', args }) };
  const transition = (type, value) => ({
    type, value, animationParam: null,
    combine(other) { return transition('combine', { first: this, second: other }); },
    animation(param) { this.animationParam = param; return this; }
  });
  const TransitionEffect = {
    IDENTITY: transition('identity'),
    OPACITY: transition('opacity'),
    translate: value => transition('translate', value),
    scale: value => transition('scale', value),
    asymmetric: (enter, leave) => transition('asymmetric', { enter, leave })
  };
  const kits = {
    '@kit.ArkUI': { curves, uiMaterial: {} },
    '@kit.AbilityKit': {},
    '@kit.ArkData': { preferences: storage().preferences },
    '@kit.BasicServicesKit': {
      deviceInfo: { sdkApiVersion: 23 },
      power: { getPowerMode: () => 600,
        DevicePowerMode: { MODE_NORMAL: 600, MODE_PERFORMANCE: 602 } }
    },
    '@kit.AccessibilityKit': {
      accessibility: { isAnimationReduceEnabledSync: () => false }
    }
  };
  const { NativeMotion } = load('NativeMotion', kits, {
    AppStorage,
    Curve: { FastOutSlowIn: 9 },
    TransitionEffect
  });
  state.set('nativeUserReduceMotion', false);
  state.set('nativeSystemReduceMotion', false);
  state.set('nativePowerSaving', false);
  state.set('nativeAppActive', true);
  assert.equal(NativeMotion.duration('press'), 90);
  assert.equal(NativeMotion.duration('overlay'), 190);
  assert.equal(NativeMotion.duration('brand'), 560);
  let actions = 0;
  NativeMotion.animate(ui, 'navigation', () => { actions++; });
  assert.equal(calls[0].duration, 220);
  NativeMotion.spring(ui, () => { actions++; });
  assert.equal(calls[1].curve.kind, 'spring');
  NativeMotion.disclosure(ui, () => { actions++; });
  assert.equal(calls[2].curve.kind, 'spring');
  assert.deepEqual(calls[2].curve.args, [0.21, 0.9, 0.22]);
  assert.equal(actions, 3);
  const rowTransition = NativeMotion.rowTransition();
  const backwardNavigation = NativeMotion.navigationTransition(-1);
  assert.equal(rowTransition.animationParam.duration, 140);
  assert.equal(backwardNavigation.value.enter.animationParam.duration, 220);
  assert.equal(backwardNavigation.value.leave.animationParam.duration, 180);
  assert.equal(backwardNavigation.value.enter.value.second.value.x, -10);
  state.set('nativeUserReduceMotion', true);
  NativeMotion.animate(ui, 'surface', () => { actions++; });
  NativeMotion.spring(ui, () => { actions++; });
  NativeMotion.disclosure(ui, () => { actions++; });
  assert.equal(calls.length, 3);
  assert.equal(actions, 6);
});

test('UI fixture launch parameters are bounded and expose explicit running states', () => {
  const { NativeUiFixture } = load('NativeUiFixture', {});
  assert.equal(NativeUiFixture.screen('conversation'), 'conversation');
  assert.equal(NativeUiFixture.screen('preview'), 'preview');
  assert.equal(NativeUiFixture.screen('unknown'), 'conversation');
  assert.equal(NativeUiFixture.state('live-change'), 'live-change');
  assert.equal(NativeUiFixture.state('attachments'), 'attachments');
  assert.equal(NativeUiFixture.state('streaming'), 'streaming');
  assert.equal(NativeUiFixture.state('secret-masked'), 'secret-masked');
  assert.equal(NativeUiFixture.state('stream-repaired'), 'stream-repaired');
  assert.equal(NativeUiFixture.state('settings-search'), 'settings-search');
  assert.equal(NativeUiFixture.state('document-preview'), 'document-preview');
  assert.equal(NativeUiFixture.state('long-history'), 'long-history');
  assert.equal(NativeUiFixture.state('dock-send-idle'), 'dock-send-idle');
  assert.equal(NativeUiFixture.state('dock-queue-pending'), 'dock-queue-pending');
  assert.equal(NativeUiFixture.state('dock-queue-authoritative'), 'dock-queue-authoritative');
  assert.equal(NativeUiFixture.state('dock-queue-many'), 'dock-queue-many');
  assert.equal(NativeUiFixture.state('dock-send-error'), 'dock-send-error');
  assert.equal(NativeUiFixture.state('dock-material-quiet'), 'dock-material-quiet');
  assert.equal(NativeUiFixture.state('dock-material-elevated'), 'dock-material-elevated');
  assert.equal(NativeUiFixture.state('interaction-approval'), 'interaction-approval');
  assert.equal(NativeUiFixture.state('interaction-question'), 'interaction-question');
  assert.equal(NativeUiFixture.state('plan-subagent'), 'plan-subagent');
  assert.equal(NativeUiFixture.state('plan-off-error'), 'plan-off-error');
  assert.equal(NativeUiFixture.state('subagent-continuable'), 'subagent-continuable');
  assert.equal(NativeUiFixture.state('subagent-one-shot'), 'subagent-one-shot');
  assert.equal(NativeUiFixture.state('subagent-unknown'), 'subagent-unknown');
  assert.equal(NativeUiFixture.state('subagent-parent-offline'), 'subagent-parent-offline');
  assert.equal(NativeUiFixture.state('private-path'), 'completed');
  assert.equal(NativeUiFixture.theme('dark'), 'dark');
  assert.equal(NativeUiFixture.theme('sepia'), 'system');

  const entry = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/entryability/EntryAbility.ets', import.meta.url), 'utf8');
  const index = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
  const showcase = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/services/StoreShowcaseClient.ets', import.meta.url), 'utf8');
  assert.match(entry, /storeShowcaseState/);
  assert.match(entry, /NativeUiFixture\.screen/);
  assert.match(entry, /NativeUiFixture\.state/);
  assert.match(entry, /showcaseReduceTransparency/);
  assert.match(index, /if \(AppStorage\.get<boolean>\('storeShowcase'\) === true\)/);
  assert.match(index, /new StoreShowcaseClient\([\s\S]{0,120}storeShowcaseState/);
  assert.match(index, /AppStorage\.setOrCreate<boolean>\('nativeReduceTransparency'/);
  assert.match(index, /showcaseReduceMotion/);
  assert.match(index, /showcaseReduceTransparency/);
  assert.match(index, /command === 'reduceMotion' \|\| command === 'reduceTransparency'/);
  assert.match(index, /showcaseWidgetDetails/);
  assert.match(index, /showcaseBackgroundMonitor/);
  assert.match(index, /command === 'notificationLevels'/);
  assert.match(index, /showcaseNotifyCompleted/);
  assert.match(index, /showcaseNotifyApproval/);
  assert.match(showcase, /showcaseWidgetDetails/);
  assert.match(showcase, /showcaseBackgroundMonitor/);
  assert.match(showcase, /showcaseNotifyConnection/);
  assert.match(showcase, /if \(state === 'live-change'\) return showcaseLiveChangeMessages/);
  assert.match(showcase, /state === 'attachments'/);
  assert.match(showcase, /state === 'long-history'/);
  assert.match(showcase, /if \(state === 'attachments'\) return showcaseLiveChangeMessages/);
  assert.match(showcase, /completedDiff\.diffs\.push\(completedDocs\)/);
  assert.match(showcase, /const seedRunning = this\.fixtureState === 'live-change'/);
  assert.match(showcase, /record\.running = initial\.running/);
  assert.match(showcase, /const plan = target\.prompt\(resolvedRequestId, text, mapped, mode\)/);
  assert.match(showcase, /this\.receiverReady = true/);
  assert.match(showcase, /dock-send-error[\s\S]{0,100}Mock 发送失败/);
  assert.match(showcase, /frame\.interaction = 'approval\/request'/);
  assert.match(showcase, /frame\.interaction = 'user-questions\/request'/);
  assert.match(showcase, /this\.attachments\.set\(SHOWCASE_SESSION, showcaseAttachments\(\)\)/);
  assert.match(showcase, /isSubagentFixtureState/);
  assert.match(showcase, /SHOWCASE_CHILD_EXTERNAL/);
  assert.match(showcase, /operation === 'planOff'/);
  assert.match(showcase, /showcaseProjectionJson/);
  assert.match(showcase, /this\.childInteractions\.get\(id\)/);
  assert.match(showcase,
    /async follow\([\s\S]{0,220}if \(id !== SHOWCASE_SESSION && !child\) return;[\s\S]{0,80}this\.paused = false;/,
    'a new showcase follow must resume after a prior pause');
  const workspace = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeWorkspace.ets', import.meta.url), 'utf8');
  assert.match(workspace,
    /const requestId = util\.generateRandomUUID\(\)[\s\S]{0,600}this\.pendingQueue = this\.pendingQueue\.concat\([\s\S]{0,180}this\.queuedEcho\(requestId, text, attachmentSnapshot\)/,
    'queue latency must not delay the visible pending echo');
  assert.match(workspace,
    /client\.prompt\(\s*id, text, mode, attachmentSnapshot, requestId,/,
    'the optimistic echo and transport must use the same request id');
  assert.match(workspace,
    /if \(!uncertain\) \{[\s\S]{0,220}item\.rpcId !== requestId/,
    'a definitive rejection must remove the optimistic echo');
});

test('interactive showcase inserts idle sends and reconciles queued echoes by rpcId', () => {
  const model = load('NativeSessionModel', {});
  const interaction = load('NativeShowcaseInteraction', {});
  const seed = Object.assign(new model.NativeMessage(), {
    id: 'seed',
    role: 'assistant',
    text: 'Ready',
    seq: 1,
    turn: 1
  });
  const file = Object.assign(new interaction.NativeShowcaseAttachment(), {
    id: 'attachment-a',
    kind: 'file',
    name: 'NativeWorkspace.ets',
    mediaType: 'text/plain',
    bytes: 512,
    receiptId: 'receipt-a'
  });

  const idle = new interaction.NativeShowcaseInteraction([seed], false, 1);
  const idleSnapshot = idle.snapshot();
  const idlePlan = idle.prompt('request-idle', 'dock_send_probe', [file], 'queue');
  assert.equal(idlePlan.accepted, true);
  assert.equal(idlePlan.queued, false);
  assert.equal(idlePlan.admissionFrames[1].message.text, 'dock_send_probe');
  assert.equal(idlePlan.streamFrames[1].text,
    '已收到这条测试消息。Dock、发送与流式状态均已正常更新。');
  const idleModel = new model.NativeSessionModel();
  idleModel.apply(idleSnapshot);
  idlePlan.admissionFrames.forEach(frame => idleModel.apply(frame));
  idlePlan.streamFrames.forEach(frame => idleModel.apply(frame));
  idlePlan.settleFrames.forEach(frame => idleModel.apply(frame));
  assert.equal(idleModel.messages.filter(row => row.role === 'user' &&
    row.text === 'dock_send_probe').length, 1);
  assert.equal(idleModel.messages.filter(row => row.role === 'assistant' &&
    row.text.includes('Dock、发送与流式状态')).length, 1);
  assert.equal(idleModel.running, false);
  const nextPlan = idle.prompt('request-idle-2', 'second stream', [file], 'queue');
  assert.equal(nextPlan.streamFrames.map(frame => frame.revision).join(','), '4,5');
  assert.equal(nextPlan.settleFrames[0].revision, 6);
  nextPlan.admissionFrames.forEach(frame => idleModel.apply(frame));
  nextPlan.streamFrames.forEach(frame => idleModel.apply(frame));
  nextPlan.settleFrames.forEach(frame => idleModel.apply(frame));
  assert.equal(idleModel.messages.filter(row => row.role === 'user' &&
    row.text === 'second stream').length, 1);

  const running = new interaction.NativeShowcaseInteraction([seed], true, 1);
  const first = running.prompt('request-queue', 'queue_probe', [file], 'queue');
  const duplicate = running.prompt('request-queue', 'queue_probe', [file], 'queue');
  assert.equal(first.queued, true);
  assert.equal(duplicate.queued, true);
  assert.equal(running.queue.length, 1);
  assert.equal(running.queue[0].rpcId, 'request-queue');
  assert.equal(running.queue[0].blocks[0].kind, 'file');
  assert.equal(running.queue[0].blocks[1].kind, 'text');
  assert.equal(running.queue[0].blocks[1].text, 'queue_probe');
  assert.equal(running.prompt('', '', [], 'queue').accepted, false);
});

test('double-tap zoom targets the tapped image point and resets from an enlarged view', () => {
  const { NativeImageZoom } = load('NativeImageZoom', {});
  const focused = NativeImageZoom.doubleTap(1, 100, 300, 400, 600, 400, 600);
  assert.equal(focused.zoom, 2.5);
  assert.equal(focused.offsetX, 150);
  assert.equal(focused.offsetY, 0);
  const clamped = NativeImageZoom.doubleTap(1, 1, 1, 400, 600, 400, 600);
  assert.equal(clamped.offsetX, 298.5);
  assert.equal(clamped.offsetY, 448.5);
  const reset = NativeImageZoom.doubleTap(2.5, 100, 300, 400, 600, 400, 600, 150, 0);
  assert.deepEqual({ zoom: reset.zoom, x: reset.offsetX, y: reset.offsetY },
    { zoom: 1, x: 0, y: 0 });
});

test('navigation polish keeps the drawer, uses incremental browsing and guarded returns', () => {
  const workspace=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeWorkspace.ets',
    import.meta.url),'utf8');
  const index=readFileSync(new URL('../../harmony/entry/src/main/ets/pages/Index.ets',
    import.meta.url),'utf8');
  const browser=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeFileBrowser.ets',
    import.meta.url),'utf8');
  assert.match(workspace,/accessibilityText\('应用设置'\)\.onClick\(\(\) => \{\s*this\.onSettings\(\);/);
  assert.doesNotMatch(workspace,/accessibilityText\('应用设置'\)[\s\S]{0,100}this\.closeDrawer\(\)/);
  assert.match(workspace,/scrollEdge\(Edge\.Bottom, \{ velocity: 6000 \}\)/);
  assert.match(workspace,/!this\.taskPlan\.items\.length && plan\.items\.length[\s\S]{0,140}NativeMotion\.disclosure/);
  assert.match(workspace,/\.transition\(NativeMotion\.disclosureTransition\(\)\)[\s\S]{0,100}\.animation\(NativeMotion\.disclosureParam\(\)\)/);
  assert.match(workspace,/Text\(this\.title\)/);
  assert.match(workspace,/LoadingProgress\(\)\.width\(NativeDesign\.spinnerInline\)/);
  assert.doesNotMatch(workspace,/if \(\(this\.connectionPhase === 'opening'[\s\S]{0,180}Text\('正在加载会话…'\)/);
  assert.doesNotMatch(workspace,/},\s*320\);/);
  assert.match(workspace,/onScrollStop\(\(\) => \{[\s\S]{0,140}settleScrollTail/);
  assert.match(index,/再次返回退出App/);
  assert.match(browser,/generation !== this\.requestGeneration/);
  assert.match(browser,/const preserveContent = this\.hasLoaded/);
  assert.match(browser,/this\.navigating = true/);
  assert.match(browser,/this\.loading && !this\.hasLoaded/);
  assert.match(browser,/再次返回退出文件浏览/);
  assert.match(browser,/private back\(confirmAtRoot: boolean = false\): void/);
  assert.match(browser,/if \(!confirmAtRoot\) \{[\s\S]{0,100}this\.onClose\(\)/);
  assert.match(browser,/private systemBack\(\): void \{\s*this\.back\(true\);/);
  assert.match(browser,/NativeIconButton\(\{\s*glyph: 'chevron-left-outline',\s*label: '返回',[\s\S]{0,120}onPressed: \(\): void => \{ this\.back\(false\); \}/);
  assert.match(browser,/@Prop previewOnly: boolean = false/);
  assert.match(browser,/if \(!this\.previewOnly\) this\.history\.push\('directory', this\.navigationPath\)/);
  assert.match(browser,/if \(this\.previewOnly\) \{[\s\S]{0,100}this\.onClose\(\)/);
  const diff=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeDiffBlock.ets',
    import.meta.url),'utf8');
  assert.doesNotMatch(diff,/drag-handle-outline/);
  assert.doesNotMatch(diff,/自动换行/);
  assert.match(diff,/accessibilityText\(this\.showLineNumbers \? '隐藏行号' : '显示行号'\)/);
  assert.match(diff,/accessibilityText\(this\.copied \? '已复制 Diff' : '复制 Diff'\)/);
});

test('About reads the installed bundle version instead of a source constant', () => {
  const kits = { '@kit.AbilityKit': { bundleManager: {
    BundleFlag: { GET_BUNDLE_INFO_DEFAULT: 0 },
    getBundleInfoForSelfSync: flag => {
      assert.equal(flag, 0);
      return { versionName: '9.8.7' };
    }
  } } };
  const { BuildInfo } = load('BuildInfo', kits);
  const pluginVersion = JSON.parse(readFileSync(new URL(
    '../../plugins/dsh-harmony/package.json', import.meta.url), 'utf8')).version;
  assert.equal(BuildInfo.version, '9.8.7');
  assert.equal(BuildInfo.pluginReleaseTag, 'plugin-v' + pluginVersion);
  assert.equal(BuildInfo.pluginArtifact,
    'https://github.com/stlin256/DSH-Harmony/releases/download/plugin-v' + pluginVersion +
    '/dsh-harmony-plugin-' + pluginVersion + '.tgz');
  assert.match(BuildInfo.pluginInstallPrompt, /@dsh-harmony\/plugin/);
  assert.match(BuildInfo.pluginInstallPrompt, /PLUGIN-INSTALL\.md/);
  assert.ok(BuildInfo.pluginInstallPrompt.includes('plugin-v' + pluginVersion));
  const guide = readFileSync(new URL('../../docs/PLUGIN-INSTALL.md', import.meta.url), 'utf8');
  assert.ok(guide.includes('plugin-v' + pluginVersion));
  assert.ok(guide.includes('dsh-harmony-plugin-' + pluginVersion + '.tgz'));
});

test('launch flow separates restoration, onboarding, guided setup and workspace', () => {
  const { NativeLaunchFlow, NativeLaunchPhase } = load('NativeLaunchFlow', {});
  assert.equal(NativeLaunchFlow.afterPreferences(false, false), NativeLaunchPhase.intro);
  assert.equal(NativeLaunchFlow.afterPreferences(true, false), NativeLaunchPhase.intro);
  assert.equal(NativeLaunchFlow.afterPreferences(true, true), NativeLaunchPhase.restoring);
  assert.equal(NativeLaunchPhase.install, 'install');
  assert.equal(NativeLaunchFlow.needsLogin('请输入访问密钥'), true);
  assert.equal(NativeLaunchFlow.needsLogin('登录失败，请检查访问密钥'), true);
  assert.equal(NativeLaunchFlow.needsLogin('网络请求超时'), false);
  assert.equal(NativeLaunchFlow.safeMessage(new Error('x'.repeat(700)), 'fallback').length, 500);

  const source = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
  assert.match(source, /launchPhase: string = NativeLaunchPhase\.booting/);
  assert.match(source, /this\.launchPhase !== NativeLaunchPhase\.hidden/);
  assert.match(source, /this\.launchPhase === NativeLaunchPhase\.entering/);
  assert.match(source, /NativeLaunchSurface\(\{/);
  assert.match(source, /putSync\('onboardingSeen', false\)/);
  assert.match(source, /onCloseGuide/);
  assert.doesNotMatch(source, /Column\(\{ space: 16 \}\) \{\s*Text\('DSH Harmony'\)/s);
  const surface = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeLaunchSurface.ets', import.meta.url), 'utf8');
  assert.match(surface, /phase === NativeLaunchPhase\.guide/);
  assert.doesNotMatch(surface, /\.scale\(\{ x: this\.logoScale\(\)/);
  assert.match(surface, /private installDetails\(\)/);
  assert.match(surface, /private connectionProgressSurface\(\)/);
  assert.doesNotMatch(surface, /正在恢复连接/);
  assert.match(surface, /\.onClick\(this\.onOpenInstall\)/);
  assert.doesNotMatch(surface, /this\.status = '已复制'/);
  assert.doesNotMatch(surface, /this\.open\(BuildInfo\.pluginInstallGuide\)/);
  assert.match(surface, /BuildInfo\.pluginInstallPrompt/);
  assert.match(surface, /复制错误/);
  assert.match(surface, /Pocket ID · Passkey/);
});

test('workspace interaction recency is account scoped and cleared on logout', () => {
  const { preferences } = storage();
  const { NativeMetadataCache } = load('NativeMetadataCache', {
    '@kit.AbilityKit': {},
    '@kit.ArkData': { preferences }
  });
  const first = NativeMetadataCache.rememberInteraction(
    context, 'https://one.example.invalid', 'session-a');
  assert.equal(first.has('session-a'), true);
  assert.equal(NativeMetadataCache.interactions(context,
    'https://one.example.invalid').get('session-a'), first.get('session-a'));
  assert.equal(NativeMetadataCache.interactions(context,
    'https://two.example.invalid').has('session-a'), false);
  NativeMetadataCache.clear(context, 'https://one.example.invalid');
  assert.equal(NativeMetadataCache.interactions(context,
    'https://one.example.invalid').size, 0);
});

test('form metadata resolves actual static card pages and resources', () => {
  const base = new URL('../../harmony/entry/src/main/', import.meta.url);
  const manifest = JSON.parse(readFileSync(new URL('module.json5', base), 'utf8'));
  const forms = JSON.parse(readFileSync(new URL('resources/base/profile/form_config.json', base), 'utf8')).forms;
  assert.equal(manifest.module.extensionAbilities[0].type, 'form');
  assert.equal(manifest.module.abilities[0].launchType, 'singleton');
  assert.equal(forms.filter(form => form.isDefault).length, 1);
  assert.deepEqual(forms.map(form => form.defaultDimension), ['2*2', '2*4']);
  for (const form of forms) {
    assert.ok(form.supportDimensions.includes(form.defaultDimension));
    assert.equal(form.isDynamic, false);
    assert.ok(existsSync(fileURLToPath(new URL(form.src, base))));
    const source = readFileSync(new URL(form.src, base), 'utf8');
    assert.match(source, /FormLink/);
    assert.doesNotMatch(source, /fetch\(|Web\(|INTERNET|cookie|serverOrigin/);
  }
});

test('native session reducer restores streams, deduplicates replay and replaces history', () => {
  const {NativeSessionModel}=load('NativeSessionModel',{});
  const model=new NativeSessionModel();
  model.apply({type:'snapshot',cursor:1,messages:[{id:'event-1',seq:1,text:'old'}],hasMore:false,attemptId:'attempt',nextIndex:2,text:'hel',reasoning:''});
  model.apply({type:'delta',attemptId:'attempt',revision:1,index:2,text:'lo',reasoning:''});
  assert.throws(()=>model.apply({type:'delta',attemptId:'attempt',revision:1,index:2,text:'DUPLICATE',reasoning:''}));
  assert.equal(model.streamText,'hello');
  assert.throws(()=>model.apply({type:'delta',attemptId:'attempt',revision:2,index:4,text:'gap'}));
  const replay = JSON.stringify({seq:2,text:'new'});
  model.apply({type:'event',seq:2,replaceStart:1,replaceEnd:1,message:{id:'event-2',seq:2,text:'new'},
    journal:[{seq:2,raw:replay}]});
  model.apply({type:'event',seq:2,replaceStart:-1,replaceEnd:-1,message:{id:'event-2',seq:2,text:'new'},
    journal:[{seq:2,raw:replay}]});
  assert.throws(()=>model.apply({type:'event',seq:2,replaceStart:-1,replaceEnd:-1,
    message:{id:'event-2',seq:2,text:'conflict'},
    journal:[{seq:2,raw:JSON.stringify({seq:2,text:'conflict'})}]}),/Conflicting durable event/);
  assert.equal(model.messages.length,1);assert.equal(model.messages[0].text,'new');
  model.apply({type:'state',running:true,waiting:true});assert.equal(model.waiting,true);
  model.apply({type:'end',attemptId:'attempt',revision:2,index:3,outcomeKind:'abandoned'});assert.equal(model.streamText,'');
  model.prepend({messages:[{seq:0,id:'event-0',text:'older'},{seq:2,id:'event-2',text:'new'}],hasMore:false});
  assert.equal(model.messages.length,2);
});

test('queue wire preserves ordered user content, rejects malformed rows and restores from cache', () => {
  const image = { attachmentId: 'image-a', mediaType: 'image/png', bytes: 8, width: 2, height: 4, name: 'a.png' };
  const file = { attachmentId: 'file-a', name: 'notes.txt', bytes: 12 };
  const queue = normalizeQueuedState([
    { id: 'queued-a', placement: 'queued', rpcId: 'request-a', content: [
      { type: 'file', attachment: file },
      { type: 'text', text: 'inspect this' },
      { type: 'image', attachment: image }
    ] },
    { id: 'context-a', placement: 'context', rpcId: 'request-b', content: [{ type: 'text', text: 'hidden' }] },
    { id: 'queued-no-request', placement: 'queued', content: [{ type: 'text', text: 'without rpc id' }] },
    { id: 'bad-a', placement: 'queued', rpcId: 'request-c', content: [
      { type: 'image', attachment: { ...image, mediaType: 'text/html' } }
    ] }
  ]);
  assert.deepEqual(queue, [
    {
      id: 'queued-a', placement: 'queued', rpcId: 'request-a', blocks: [
        { kind: 'file', file },
        { kind: 'text', text: 'inspect this' },
        { kind: 'image', image }
      ]
    },
    {
      id: 'queued-no-request', placement: 'queued',
      blocks: [{ kind: 'text', text: 'without rpc id' }]
    }
  ]);
  assert.deepEqual(queueFromInbox({ 'next-turn': [
    { id: 'queued-b', source: { kind: 'user', rpcId: 'request-b' }, content: [{ type: 'text', text: 'next' }] },
    { id: 'queued-no-request', source: { kind: 'user' }, content: [{ type: 'text', text: 'without rpc id' }] },
    { id: 'notice', source: { kind: 'tool-jobs', form: 'notice' }, content: [{ type: 'text', text: 'background job finished' }] },
    { id: 'runtime-b', source: { kind: 'runtime', rpcId: 'request-c' }, content: [{ type: 'text', text: 'hidden' }] }
  ], 'next-step': [] }), [
    { id: 'queued-b', placement: 'queued', rpcId: 'request-b', sourceKind: 'user',
      blocks: [{ kind: 'text', text: 'next' }] },
    { id: 'queued-no-request', placement: 'queued', sourceKind: 'user',
      blocks: [{ kind: 'text', text: 'without rpc id' }] },
    { id: 'notice', placement: 'queued', sourceKind: 'tool-jobs', sourceForm: 'notice',
      blocks: [{ kind: 'text', text: 'background job finished' }] }
  ]);

  const { NativeSessionModel } = load('NativeSessionModel', {});
  const model = new NativeSessionModel();
  model.apply({ type: 'state', running: true, waiting: false, queueKnown: true, queue });
  model.apply({ type: 'state', running: false, waiting: true });
  assert.deepEqual(model.queue, queue, 'status-only state must retain the authoritative queue');
  const restored = new NativeSessionModel();
  restored.restore(model.capture());
  assert.deepEqual(restored.queue, queue);
  restored.apply({ type: 'state', running: false, waiting: false, queueKnown: true, queue: [] });
  assert.deepEqual(restored.queue, []);
});

test('structured lifecycle rows merge by stable identity and never regress', () => {
  const types = load('NativeSessionModel', {});
  const { nativeTranscript } = load('NativeTranscript', {
    './NativeSessionModel': types,
    './NativeHostSettings': load('NativeHostSettings', {'./NativeSessionModel': types}),
    './NativePlan': load('NativePlan', {}),
    './NativeToolStructured': load('NativeToolStructured', {
      './NativeSessionModel': types,
      './NativeDocumentModel': load('NativeDocumentModel', {})
    })
  });
  const message = (id, role, seq, fields = {}) => Object.assign(
    new types.NativeMessage(), { id, role, seq, turn: 1, step: 1, ...fields });
  const lifecycle = nativeTranscript([
    message('done', 'tool', 2, {
      callId: 'cmd-1', toolName: 'slash_command', phase: 'result', status: 'success',
      text: 'Compacted 9 messages.', eventType: 'command/done',
      metaRaw: JSON.stringify({ commandId: 'cmd-1', kind: 'success', text: 'Compacted 9 messages.' })
    }),
    message('run', 'tool', 1, {
      callId: 'cmd-1', toolName: 'slash_command', phase: 'start', status: 'running',
      text: '', eventType: 'command/run',
      metaRaw: JSON.stringify({ commandId: 'cmd-1', name: 'compact', args: '' })
    })
  ], false);
  const command = lifecycle.find(row => row.role === 'process').children[0];
  assert.equal(command.phase, 'result');
  assert.equal(command.status, 'success');
  assert.equal(command.output, 'Compacted 9 messages.');
  assert.equal(JSON.parse(command.metaRaw).name, 'compact');
  assert.equal(JSON.parse(command.metaRaw).kind, 'success');

  const jobs = nativeTranscript([
    message('settled', 'tool', 4, {
      callId: 'job-1', toolName: 'job_lifecycle', phase: 'result', status: 'success',
      text: 'exit code: 0', eventType: 'job/settled',
      metaRaw: JSON.stringify({ jobId: 'job-1', kind: 'bash', label: 'npm test',
        status: 'completed', detail: 'exit code: 0' })
    }),
    message('registered', 'tool', 3, {
      callId: 'job-1', toolName: 'job_lifecycle', phase: 'start', status: 'running',
      text: 'npm test', eventType: 'job/registered',
      metaRaw: JSON.stringify({ jobId: 'job-1', kind: 'bash', label: 'npm test' })
    })
  ], false);
  const job = jobs.find(row => row.role === 'process').children[0];
  assert.equal(job.phase, 'result');
  assert.equal(job.status, 'success');
  assert.equal(job.output, 'exit code: 0');
  assert.equal(JSON.parse(job.metaRaw).status, 'completed');
  assert.equal(JSON.parse(job.metaRaw).label, 'npm test');
});

test('authoritative deliverables attach without adding a duplicate row', () => {
  const types = load('NativeSessionModel', {});
  const { nativeTranscript } = load('NativeTranscript', {
    './NativeSessionModel': types,
    './NativeHostSettings': load('NativeHostSettings', {'./NativeSessionModel': types}),
    './NativePlan': load('NativePlan', {}),
    './NativeToolStructured': load('NativeToolStructured', {
      './NativeSessionModel': types,
      './NativeDocumentModel': load('NativeDocumentModel', {})
    })
  });
  const message = (id, role, seq, fields = {}) => Object.assign(
    new types.NativeMessage(), { id, role, seq, turn: 1, step: 1, ...fields });
  const authoritative = JSON.stringify({ turn: 1, callId: 'present-1',
    files: [{ path: 'out/report.pdf', description: 'Final' }] });
  const rows = nativeTranscript([
    message('result', 'tool', 1, {
      callId: 'present-1', toolName: 'present', phase: 'result', status: 'success',
      text: 'presented', metaRaw: JSON.stringify({})
    }),
    message('delivery', 'detail', 2, {
      callId: 'present-1', eventType: 'deliverables/presented',
      authoritativeRaw: authoritative, detail: authoritative
    })
  ], false);
  assert.equal(rows.some(row => row.role === 'detail'), false);
  const present = rows.find(row => row.role === 'process').children[0];
  assert.equal(present.authoritativeRaw, authoritative);
});

test('structured tools render command, job, editor and authoritative present records', () => {
  const types = load('NativeSessionModel', {});
  const structured = load('NativeToolStructured', {
    './NativeSessionModel': types,
    './NativeDocumentModel': load('NativeDocumentModel', {})
  });
  const tool = fields => Object.assign(new types.NativeMessage(), {
    role: 'tool', phase: 'result', status: 'success', toolName: '',
    args: '', metaRaw: '', output: '', error: '', failed: false, outcome: ''
  }, fields);

  const command = structured.nativeToolStructured(tool({
    toolName: 'slash_command',
    metaRaw: JSON.stringify({
      commandId: 'cmd-1', name: 'compact', args: 'keep recent', kind: 'error',
      text: 'Command failed safely.'
    })
  }));
  assert.equal(command.family, 'command');
  assert.equal(command.summary, '/compact keep recent');
  assert.equal(command.showRawArguments, false);
  assert.equal(command.fields.find(x => x.label === '状态').value, '失败');
  assert.equal(command.fields.find(x => x.label === '结果').value, 'Command failed safely.');

  const job = structured.nativeToolStructured(tool({
    toolName: 'job_lifecycle',
    metaRaw: JSON.stringify({
      jobId: 'job-1', kind: 'video', label: 'Render clip', status: 'killed',
      detail: 'cancelled by owner', cause: 'user',
      toolCall: { callId: 'call-1', rootCallId: 'root-1' }
    })
  }));
  assert.equal(job.family, 'jobLifecycle');
  assert.equal(job.fields.find(x => x.label === '类型').value, 'video');
  assert.equal(job.fields.find(x => x.label === '状态').tone, 'danger');
  assert.equal(job.fields.find(x => x.label === '调用').value, 'call-1');
  assert.equal(job.fields.find(x => x.label === '根调用').value, 'root-1');

  const editor = fields => structured.nativeToolStructured(tool(Object.assign({
    toolName: 'str_replace_editor', phase: 'start', status: 'running'
  }, fields)));
  const read = editor({args: JSON.stringify({command: 'view', path: 'src/view.ts'})});
  assert.equal(read.family, 'read');
  assert.equal(read.displayName, 'view.ts');
  assert.equal(read.displayDirectory, 'src/');
  assert.equal(editor({args: JSON.stringify({command: 'create', path: 'src/create.ts'})}).family, 'file');
  assert.equal(editor({args: JSON.stringify({
    command: 'str_replace', path: 'src/replace.ts'
  })}).family, 'file');
  assert.equal(editor({args: JSON.stringify({command: 'insert', path: 'src/insert.ts'})}).family, 'file');
  const search = structured.nativeToolStructured(tool({
    toolName: 'grep',
    args: JSON.stringify({pattern: 'headerHeight'}),
    metaRaw: JSON.stringify({matches: [{
      path: '/workspace/project/src/theme/layout.ts',
      matches: [{lineNumber: 12, line: 'export const headerHeight = 52;'}]
    }]})
  }), '/workspace/project');
  assert.equal(search.family, 'search');
  assert.equal(search.search.files[0].display, 'src/theme/layout.ts');
  assert.equal(search.search.files[0].name, 'layout.ts');
  assert.equal(search.search.files[0].directory, 'src/theme/');

  const authoritative = JSON.stringify({
    turn: 3, callId: 'present-1',
    files: [{path: 'out/final.pdf', description: 'Final delivery'}]
  });
  const present = structured.nativeToolStructured(tool({
    toolName: 'present', callId: 'present-1',
    args: JSON.stringify({files: [{path: 'out/inferred.pdf'}]}),
    authoritativeRaw: authoritative
  }), '/workspace/project');
  assert.equal(present.family, 'present');
  assert.deepEqual(Array.from(present.presented, file => file.display), ['out/final.pdf']);
  assert.equal(present.presented[0].description, 'Final delivery');
  assert.equal(present.fields[0].label, '权威交付');
});

test('plugin view parser is bounded, read-only and groups metric rows', () => {
  const types = load('NativeSessionModel', {});
  const { nativeToolStructured } = load('NativeToolStructured', {
    './NativeSessionModel': types,
    './NativeDocumentModel': load('NativeDocumentModel', {})
  });
  const card = {
    type: 'stack',
    title: 'Workspace health',
    children: [
      {type: 'row', children: [
        {type: 'metric', label: 'Tests', value: '42', caption: 'passed', tone: 'good'},
        {type: 'metric', label: 'Failures', value: '0', tone: 'info'}
      ]},
      {type: 'progress', label: 'Coverage', value: 75, max: 100, tone: 'warn'},
      {type: 'callout', text: 'Read-only summary', tone: 'info'},
      {type: 'list', items: [{title: 'Gateway', subtitle: 'healthy', trailing: '1'}]},
      {type: 'table', columns: ['Name', 'State'], rows: [['sync', 'idle']]},
      {type: 'options', selected: 'all', options: [
        {label: 'All', value: 'all'}, {label: 'Errors', value: 'errors'}
      ]},
      {type: 'confirm', label: 'Apply', action: 'apply'},
      {type: 'actions', items: [{label: 'Delete', action: 'delete'}]},
      {type: 'image', src: 'https://tracker.invalid/image.png', alt: 'Remote'}
    ]
  };
  const document = nativeToolStructured(Object.assign(new types.NativeMessage(), {
    role: 'tool', toolName: 'plugin_tool', phase: 'result', status: 'success',
    args: '{}', output: 'ok', metaRaw: JSON.stringify({'dsh-go/view': card})
  }));
  assert.equal(document.plugin.present, true);
  assert.equal(document.plugin.valid, true);
  assert.equal(document.plugin.title, 'Workspace health');
  assert.equal(document.plugin.blocks[0].kind, 'metrics');
  assert.deepEqual(Array.from(document.plugin.blocks[0].metrics, x => x.label), ['Tests', 'Failures']);
  assert.equal(document.plugin.blocks.some(x => x.kind === 'options'), true);
  assert.equal(document.plugin.blocks.find(x => x.kind === 'options').items[0].selected, true);
  assert.equal(document.plugin.blocks.some(x => x.kind === 'confirm' || x.kind === 'actions'), false);
  assert.equal(document.plugin.blocks.find(x => x.kind === 'image').text, '图像未加载');
  assert.equal(document.bodyStructured, true);
  assert.equal(document.showRawArguments, false);
  assert.equal(document.showRawOutput, false);

  const invalid = nativeToolStructured(Object.assign(new types.NativeMessage(), {
    role: 'tool', toolName: 'plugin_tool', phase: 'result', status: 'success',
    args: '{}', output: 'raw output',
    metaRaw: JSON.stringify({'dsh-go/view': {title: 'missing type'}})
  }));
  assert.equal(invalid.plugin.present, true);
  assert.equal(invalid.plugin.valid, false);
  assert.equal(invalid.bodyStructured, true);
  assert.equal(invalid.showRawArguments, true);
  assert.equal(invalid.showRawOutput, true);

  const oversized = nativeToolStructured(Object.assign(new types.NativeMessage(), {
    role: 'tool', toolName: 'plugin_tool', phase: 'result', status: 'success',
    args: '{}', output: 'raw output',
    metaRaw: JSON.stringify({'dsh-go/view': {type: 'text', text: 'x'.repeat(9000)}})
  }));
  assert.equal(oversized.plugin.valid, false);
  assert.equal(oversized.showRawArguments, true);

  let nested = {type: 'text', text: 'deep'};
  for (let index = 0; index < 10; index++) nested = {type: 'stack', children: [nested]};
  const depth = nativeToolStructured(Object.assign(new types.NativeMessage(), {
    role: 'tool', toolName: 'plugin_tool', phase: 'result', status: 'success',
    args: '{}', output: '',
    metaRaw: JSON.stringify({'dsh-go/view': nested})
  }));
  assert.equal(depth.plugin.valid, true);
  assert.equal(depth.plugin.truncated, true);

  const unknownRoot = nativeToolStructured(Object.assign(new types.NativeMessage(), {
    role: 'tool', toolName: 'plugin_tool', phase: 'result', status: 'success',
    args: '{}', output: 'raw output',
    metaRaw: JSON.stringify({'dsh-go/view': {type: 'future-root', text: 'future'}})
  }));
  assert.equal(unknownRoot.plugin.present, true);
  assert.equal(unknownRoot.plugin.valid, false);
  assert.equal(unknownRoot.showRawOutput, true);

  const running = nativeToolStructured(Object.assign(new types.NativeMessage(), {
    role: 'tool', toolName: 'plugin_tool', phase: 'start', status: 'running',
    args: '{}', output: '',
    metaRaw: JSON.stringify({'dsh-go/view': {type: 'text', text: 'not ready'}})
  }));
  assert.equal(running.plugin.present, false);
});

test('assistant dsh-ui fences use the larger interactive model profile', () => {
  const types = load('NativeSessionModel', {});
  const { nativeDshUiDocument } = load('NativeToolStructured', {
    './NativeSessionModel': types,
    './NativeDocumentModel': load('NativeDocumentModel', {})
  });
  const source = `{
    // comments and a trailing comma are repaired once
    "type": "stack",
    "title": "Workspace health",
    "children": [
      {"type": "metric", "label": "Tests", "value": "42"},
      {"type": "options", "id": "scope", "multi": true, "options": [
        {"label": "All", "value": "all"},
        {"label": "Failures", "value": "failures"},
      ]},
      {"type": "confirm", "id": "apply", "confirmLabel": "Apply"},
    ],
  }`;
  const document = nativeDshUiDocument(source);
  assert.equal(document.valid, true);
  assert.equal(document.title, 'Workspace health');
  assert.equal(document.blocks[0].kind, 'metric');
  const options = document.blocks.find(block => block.kind === 'options');
  assert.equal(options.multi, true);
  assert.deepEqual(Array.from(options.items, item => item.value), ['all', 'failures']);
  assert.equal(document.blocks.find(block => block.kind === 'confirm').confirmLabel, 'Apply');

  const array = nativeDshUiDocument('[{"type":"text","text":"one"},{"type":"text","text":"two"}]');
  assert.equal(array.valid, true);
  assert.deepEqual(Array.from(array.blocks, block => block.text), ['one', 'two']);

  const unknownRoot = nativeDshUiDocument('{"type":"future-root","text":"future"}');
  assert.equal(unknownRoot.present, true);
  assert.equal(unknownRoot.valid, false);

  const tooLarge = nativeDshUiDocument(JSON.stringify({
    type: 'text', text: 'x'.repeat(17000)
  }));
  assert.equal(tooLarge.valid, false);

  const children = Array.from({length: 18}, (_value, index) => ({
    type: 'text', text: 'row-' + index
  }));
  const bounded = nativeDshUiDocument(JSON.stringify({type: 'stack', children}));
  assert.equal(bounded.valid, true);
  assert.equal(bounded.blocks.length, 16);
  assert.equal(bounded.truncated, true);
});

test('dsh-ui replies contain visible labels and are available only for the latest idle view', () => {
  const types = load('NativeSessionModel', {});
  const {
    nativeDshUiChoiceReply,
    nativeDshUiConfirmReply,
    nativeDshUiReply,
    nativeDshUiReplyLabel,
    nativeDshUiCanReply
  } = load('NativeDshUi', { './NativeSessionModel': types });

  const choice = nativeDshUiChoiceReply('Choose scope', ['All', 'Failures']);
  assert.equal(choice, '[dsh-ui reply] Choose scope\n选择：All、Failures');
  assert.equal(nativeDshUiReplyLabel(choice), '已选择：All、Failures');
  assert.equal(nativeDshUiReply(choice).title, 'Choose scope');

  const confirmed = nativeDshUiConfirmReply('Apply changes', true, 'Apply');
  assert.equal(confirmed, '[dsh-ui reply] Apply changes\n确认：Apply');
  assert.equal(nativeDshUiReplyLabel(confirmed), '已确认：Apply');
  assert.equal(nativeDshUiReplyLabel('[dsh-ui reply]\nCancel'), '已取消');

  const rows = [
    Object.assign(new types.NativeMessage(), {id: 'assistant', role: 'assistant', text: 'card'}),
    Object.assign(new types.NativeMessage(), {id: 'process', role: 'process', text: ''})
  ];
  assert.equal(nativeDshUiCanReply(rows, 'assistant', false, false), true);
  assert.equal(nativeDshUiCanReply(rows, 'assistant', true, false), false);
  rows.push(Object.assign(new types.NativeMessage(), {id: 'reply', role: 'user', text: choice}));
  assert.equal(nativeDshUiCanReply(rows, 'assistant', false, false), false);
});

test('media metadata validates running, completed and failed generated media', () => {
  const types = load('NativeSessionModel', {});
  const { nativeToolStructured } = load('NativeToolStructured', {
    './NativeSessionModel': types,
    './NativeDocumentModel': load('NativeDocumentModel', {})
  });
  const tool = (meta, failed = false) => Object.assign(new types.NativeMessage(), {
    role: 'tool', toolName: 'generate_image', phase: 'result',
    status: failed ? 'error' : 'success', failed,
    args: '{}', output: failed ? 'provider rejected request' : 'generated',
    metaRaw: JSON.stringify({'dsh-go/media': meta})
  });

  const imageMeta = {
    v: 1, rid: 'rid-image', kind: 'image', status: 'done',
    items: [{path: 'generated/one.png', mime: 'image/png', width: 1024, height: 1024, bytes: 2048}],
    request: {
      provider: 'provider', model: 'model-image', label: 'Image Model',
      aspect: '1:1', n: 1, quality: 'high', seconds: 4
    },
    prompt: 'A quiet test card',
    provenance: {visibleMark: true, c2pa: true, implicitLabel: true},
    cost: {estimate: 0.6, currency: 'CNY'}
  };
  const image = nativeToolStructured(tool(imageMeta), '/workspace/project');
  assert.equal(image.media.valid, true);
  assert.equal(image.media.items[0].display, 'generated/one.png');
  assert.equal(image.media.request.label, 'Image Model');
  assert.equal(image.media.request.count, 1);
  assert.equal(image.media.implicitLabel, true);
  assert.equal(image.media.costEstimate, 0.6);
  assert.equal(image.media.costCurrency, 'CNY');
  assert.equal(image.showRawOutput, false);

  const running = nativeToolStructured(tool({
    v: 1, rid: 'rid-video', job: 'job-video', kind: 'video', status: 'running',
    items: [], request: {label: 'Video Model', aspect: '16:9', seconds: 5},
    prompt: 'A slow camera move'
  }));
  assert.equal(running.media.valid, true);
  assert.equal(running.media.kind, 'video');
  assert.equal(running.media.status, 'running');

  const failed = nativeToolStructured(tool({
    v: 1, rid: 'rid-failed', kind: 'image', status: 'failed', items: [],
    request: {label: 'Image Model'}, prompt: 'Rejected',
    error: {code: 'policy', text: 'Input was rejected'}
  }, true));
  assert.equal(failed.media.valid, true);
  assert.equal(failed.media.status, 'failed');
  assert.equal(failed.media.errorText, 'Input was rejected');

  const emptyDone = nativeToolStructured(tool({
    v: 1, rid: 'rid-empty', kind: 'image', status: 'done', items: []
  }));
  assert.equal(emptyDone.media.present, true);
  assert.equal(emptyDone.media.valid, false);

  const badDimension = nativeToolStructured(tool(Object.assign({}, imageMeta, {
    items: [{path: 'generated/bad.png', width: 0}]
  })));
  assert.equal(badDimension.media.valid, true);
  assert.equal(badDimension.media.items[0].width, 0);

  const oversized = nativeToolStructured(tool(Object.assign({}, imageMeta, {
    prompt: 'x'.repeat(9000)
  })));
  assert.equal(oversized.media.valid, false);

  const inferred = nativeToolStructured(tool({
    items: [{path: 'generated/video.mp4', mime: 'video/mp4', bytes: -1}],
    request: {n: 'bad', provider: 7},
    status: 'unknown'
  }));
  assert.equal(inferred.media.valid, true);
  assert.equal(inferred.media.kind, 'video');
  assert.equal(inferred.media.status, 'done');
  assert.equal(inferred.media.items[0].bytes, 0);
  assert.equal(inferred.media.request.count, 0);

  const future = nativeToolStructured(tool(Object.assign({}, imageMeta, {
    v: 2,
    cost: {estimate: -1, currency: 'CNY'}
  })));
  assert.equal(future.media.valid, true);
  assert.equal(future.media.costEstimate, -1);

  const emptyVideoDone = nativeToolStructured(tool({
    v: 1, kind: 'video', status: 'done', items: []
  }));
  assert.equal(emptyVideoDone.media.valid, false);
});

test('process structure detection ignores streaming values and identifies new direct operations', () => {
  const { nativeProcessStructureChange } = load('NativeSessionModel', {});
  const child = (id, text) => ({ id, renderKey: id, role: 'tool', text });
  const previous = [{ id: 'process:one', role: 'process', children: [child('call:a', 'same')] }];
  assert.equal(nativeProcessStructureChange(previous, [
    { id: 'process:one', role: 'process', children: [child('call:a', 'changed output')] }
  ]).changed(), false);
  const growing = nativeProcessStructureChange(previous, [
    { id: 'process:one', role: 'process', children: [child('call:a', 'same'), child('call:b', 'new')] }
  ]);
  assert.deepEqual(Array.from(growing.growingGroupIds), ['process:one']);
  const added = nativeProcessStructureChange(previous, previous.concat([
    { id: 'process:two', role: 'process', children: [child('call:c', 'new group')] }
  ]));
  assert.deepEqual(Array.from(added.addedGroupIds), ['process:two']);
});

test('structured interaction copy formats complete JSON without changing ordinary prose', () => {
  const { nativeStructuredText } = load('NativeInteractionFormat', {});
  assert.equal(nativeStructuredText('Choose an action'), 'Choose an action');
  assert.equal(nativeStructuredText('{"project":"DSH","items":["one","two"],"enabled":true}'),
    'project: DSH\nitems: one · two\nenabled: true');
  assert.equal(nativeStructuredText('{"question":{"title":"Scope","detail":"Read only"}}'),
    'question:\n  title: Scope\n  detail: Read only');
  assert.equal(nativeStructuredText('{not valid json'), '{not valid json');
});

test('queue dock and compact interactions are wired into the native shell', () => {
  const interaction = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeInteraction.ets', import.meta.url), 'utf8');
  const queue = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeQueueDock.ets', import.meta.url), 'utf8');
  const workspace = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeWorkspace.ets', import.meta.url), 'utf8');
  const process = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeProcessView.ets', import.meta.url), 'utf8');
  assert.doesNotMatch(interaction, /交给其他客户端处理|交给其他程序处理/);
  assert.match(interaction, /currentQuestion\(\)/);
  assert.match(interaction, /nativeStructuredText/);
  assert.match(interaction, /'跳过'/);
  assert.match(queue, /nativeQueueEditable\(item\)/);
  assert.match(queue, /发送中…/);
  assert.match(queue, /kind === 'edit'/);
  assert.match(workspace, /NativeQueueDock\(\{/);
  assert.match(workspace, /scheduleProcessTailSettle\(\)/);
  assert.match(workspace, /nativeProcessStructureChange/);
  assert.match(workspace, /suppressProcessEntrance/);
  assert.match(workspace, /processEntranceBaselinePending/);
  assert.match(process, /NativeMotion\.processEntranceTransition\(\)/);
});

test('latest DSH stream keeps dense revisions, durable gaps and committed settlement', () => {
  const {NativeSessionModel}=load('NativeSessionModel',{});
  const normalized=normalizeFollow({type:'assistant-stream',frame:{type:'start',attemptId:'attempt',
    revision:1,startedAfterSeq:0,turn:2,step:3}});
  assert.deepEqual(normalized,{type:'start',attemptId:'attempt',nextIndex:0,revision:1,
    startedAfterSeq:0,turn:2,step:3});
  const ended=normalizeFollow({type:'assistant-stream',frame:{type:'end',attemptId:'attempt',
    revision:3,index:1,outcome:{kind:'committed',eventType:'assistant/message',seq:2}}});
  assert.deepEqual(ended,{type:'end',attemptId:'attempt',revision:3,index:1,
    outcomeKind:'committed',committedEventType:'assistant/message',committedSeq:2});

  const model=new NativeSessionModel();
  model.apply({type:'snapshot',cursor:0,messages:[],attemptId:'attempt',nextIndex:1,
    revision:2,text:'partial',reasoning:''});
  model.apply({type:'delta',attemptId:'attempt',revision:3,index:1,text:' answer',reasoning:''});
  model.apply({type:'end',attemptId:'attempt',revision:4,index:2,outcomeKind:'committed',
    committedEventType:'assistant/message',committedSeq:2});
  assert.equal(model.streamText,'partial answer','committed end must retain partial until durable settlement');
  assert.equal(model.settlementPending(),true);
  model.apply({type:'event',seq:1,replaceStart:-1,replaceEnd:-1,
    message:{id:'event-1',seq:1,role:'tool',eventType:'tool/result',text:'tool'}});
  assert.equal(model.streamText,'partial answer');
  model.apply({type:'event',seq:2,replaceStart:-1,replaceEnd:-1,
    message:{id:'event-2',seq:2,role:'assistant',eventType:'assistant/message',text:'partial answer'}});
  assert.equal(model.settlementPending(),false);
  assert.equal(model.streamText,'');

  const gap=new NativeSessionModel();
  gap.apply({type:'snapshot',cursor:4,messages:[],attemptId:'',nextIndex:0,revision:0});
  assert.throws(()=>gap.apply({type:'event',seq:6,replaceStart:-1,replaceEnd:-1,
    message:{id:'event-6',seq:6,text:'gap'},journal:[{seq:6,raw:'{}'}]}),/Stream gap/);
  assert.equal(gap.journal.has(6),false,'a rejected gap must not enter the durable journal');
  gap.apply({type:'start',attemptId:'a',revision:1,nextIndex:0});
  assert.throws(()=>gap.apply({type:'delta',attemptId:'a',revision:3,index:0,text:'gap'}),
    /Stream gap/);
});

test('assistant revisions remain dense from a zero snapshot baseline through a new attempt', () => {
  const { NativeSessionModel } = load('NativeSessionModel', {});
  const model = new NativeSessionModel();
  model.apply({ type: 'snapshot', cursor: 4, messages: [], revision: 0 });
  assert.throws(() => model.apply({ type: 'start', attemptId: 'first' }));
  model.apply({ type: 'start', attemptId: 'first', revision: 1 });
  assert.throws(() => model.apply({ type: 'delta', attemptId: 'first', revision: 1, index: 0, text: 'duplicate' }));
  assert.throws(() => model.apply({ type: 'delta', attemptId: 'first', revision: 3, index: 0, text: 'gap' }));
  model.apply({ type: 'delta', attemptId: 'first', revision: 2, index: 0, text: 'A' });
  model.apply({ type: 'end', attemptId: 'first', revision: 3, index: 1, outcomeKind: 'abandoned' });
  assert.equal(model.streamText, '');
  model.apply({ type: 'start', attemptId: 'second', revision: 4 });
  model.apply({ type: 'delta', attemptId: 'second', revision: 5, index: 0, reasoning: 'plan' });
  model.apply({ type: 'end', attemptId: 'second', revision: 6, index: 1, outcomeKind: 'abandoned' });
  assert.equal(model.activityRevision(), 6);
});

test('stream health separates link, delivery and assistant progress while ignoring waits', () => {
  const {
    nativeAssistantProgressKey,
    nativeAssistantProgressAdvanced,
    nativeDeliveryMismatchResolved,
    nativeStreamHealthRepairReason
  } = load('NativeSessionModel', {});
  assert.equal(nativeAssistantProgressKey('', 4, 2, 8), '');
  assert.equal(nativeAssistantProgressKey('attempt', 4, 2, 8), 'attempt\n4\n2\n8');
  assert.equal(nativeAssistantProgressAdvanced('', 'attempt\n4\n2\n8'), true);
  assert.equal(nativeAssistantProgressAdvanced(
    'attempt\n4\n2\n8', 'attempt\n4\n2\n8'), false);
  assert.equal(nativeAssistantProgressAdvanced('old', ''), false);
  assert.equal(nativeDeliveryMismatchResolved('gateway-tuple', 'gateway-tuple'), true);
  assert.equal(nativeDeliveryMismatchResolved('gateway-tuple', 'older-tuple'), false);
  assert.equal(nativeDeliveryMismatchResolved('', ''), false);
  assert.equal(nativeStreamHealthRepairReason(20001, 1, 15000, 0,
    false, false, false, false, false, ''), 'link_timeout');
  assert.equal(nativeStreamHealthRepairReason(15000, 14999, 5000, 14000,
    true, false, true, true, false, ''), '');
  assert.equal(nativeStreamHealthRepairReason(16000, 15999, 1000, 13000,
    true, false, true, true, false, ''), 'delivery_mismatch');
  assert.equal(nativeStreamHealthRepairReason(17000, 16999, 5000, 0,
    true, false, true, true, false, 'attempt'), 'assistant_progress_timeout');
  assert.equal(nativeStreamHealthRepairReason(50000, 49999, 5000, 0,
    true, false, true, true, false, ''), '');
  assert.equal(nativeStreamHealthRepairReason(50000, 49999, 5000, 0,
    true, false, true, true, true, 'attempt'), '');
  assert.equal(nativeStreamHealthRepairReason(43000, 42999, 5000, 0,
    true, true, true, true, false, 'attempt'), 'assistant_progress_timeout');
});

test('heartbeat generations are bound to one follow and repair starts remain single-flight', () => {
  const workspace = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeWorkspace.ets', import.meta.url), 'utf8');
  const accept = workspace.slice(workspace.indexOf('private acceptHeartbeat('),
    workspace.indexOf('private trackAppliedProgress('));
  assert.ok(accept.indexOf('this.followConnectionGeneration !== frame.generation') <
    accept.indexOf('this.touchFollow(id)'));
  assert.match(workspace,
    /if \(!this\.liveAllowed\(id\) \|\| this\.reconnectInFlight\) return;[\s\S]{0,80}this\.reconnectInFlight = true/);
  assert.match(workspace,
    /private touchFollow\(id: string\): void \{[\s\S]{0,180}this\.followActivityAt = Date\.now\(\);[\s\S]{0,120}this\.scheduleFollowHealth\(id\)/);
  assert.match(workspace,
    /if \(frame\.type === 'heartbeat'\) \{[\s\S]{0,120}this\.acceptHeartbeat\(id, frame\);[\s\S]{0,40}return/);
  assert.match(workspace,
    /nativeAssistantProgressAdvanced\(this\.followProgressKey, gatewayKey\)/);
  assert.match(workspace,
    /nativeDeliveryMismatchResolved\(this\.deliveryMismatchKey, reducerKey\)/);
});

test('committed settlement survives cache restoration until the durable event arrives', () => {
  const { NativeSessionModel } = load('NativeSessionModel', {});
  const model = new NativeSessionModel();
  model.apply({type:'snapshot',cursor:0,messages:[{id:'event-0',seq:0,text:'seed'}],
    attemptId:'attempt',nextIndex:1,revision:2,text:'partial'});
  model.apply({type:'end',attemptId:'attempt',revision:3,index:1,outcomeKind:'committed',
    committedEventType:'assistant/message',committedSeq:1});
  assert.equal(model.settlementPending(),true);
  const restored = new NativeSessionModel();
  restored.restore(model.capture());
  assert.equal(restored.settlementPending(),true);
  assert.equal(restored.streamText,'partial');
  restored.apply({type:'event',seq:1,replaceStart:-1,replaceEnd:-1,
    message:{id:'event-1',seq:1,role:'assistant',eventType:'assistant/message',text:'durable answer'}});
  assert.equal(restored.settlementPending(),false);
  assert.equal(restored.streamText,'');
  assert.equal(restored.messages.at(-1).text,'durable answer');

  const committedFirst = new NativeSessionModel();
  committedFirst.apply({type:'snapshot',cursor:0,messages:[],attemptId:'attempt',nextIndex:1,
    revision:2,text:'partial'});
  committedFirst.apply({type:'event',seq:1,replaceStart:-1,replaceEnd:-1,
    message:{id:'event-1',seq:1,role:'assistant',eventType:'assistant/message',
      text:'durable answer'},journal:[{seq:1,raw:'{"seq":1}'}]});
  assert.equal(committedFirst.streamText,'partial');
  committedFirst.apply({type:'end',attemptId:'attempt',revision:3,index:1,
    outcomeKind:'committed',committedEventType:'assistant/message',committedSeq:1});
  assert.equal(committedFirst.settlementPending(),false);
  assert.equal(committedFirst.streamText,'');
  assert.equal(committedFirst.messages.at(-1).text,'durable answer');
});

test('file windows derive exact EOF when HarmonyOS omits the custom header', () => {
  const { nativeFileWindowMetadata } = load('NativeFileWindow', {});
  const small = nativeFileWindowMetadata('version-a', 280 * 1024, 0, 280 * 1024, 2 * 1024 * 1024);
  assert.equal(small.eof, true);
  const exact = nativeFileWindowMetadata('version-a', 2 * 1024 * 1024, 0, 2 * 1024 * 1024, 2 * 1024 * 1024);
  assert.equal(exact.eof, true, 'an exact final window must not require a trailing empty request');
  const first = nativeFileWindowMetadata('version-a', 3 * 1024 * 1024, 0, 2 * 1024 * 1024, 2 * 1024 * 1024);
  assert.equal(first.eof, false);
  const last = nativeFileWindowMetadata('version-a', 3 * 1024 * 1024, 2 * 1024 * 1024,
    1024 * 1024, 2 * 1024 * 1024);
  assert.equal(last.eof, true);
  const empty = nativeFileWindowMetadata('version-a', 0, 0, 0, 2 * 1024 * 1024);
  assert.equal(empty.eof, true);
});

test('native transcript hides protocol bookkeeping across snapshots, live events and history', () => {
  const { NativeSessionModel } = load('NativeSessionModel', {});
  const model = new NativeSessionModel();
  model.apply({type:'snapshot',cursor:2,beforeSeq:0,messages:[
    {id:'event-1',seq:1,role:'assistant',text:'answer'},
    {id:'event-2',seq:2,role:'detail',label:'step/end',text:'{"turn":1}'}
  ]});
  model.apply({type:'event',seq:3,message:{id:'event-3',seq:3,role:'detail',label:'workspace/changes'}});
  model.apply({type:'event',seq:4,message:{id:'event-4',seq:4,role:'notice',label:'执行失败',text:'task failed'}});
  model.prepend({messages:[{id:'event-0',seq:0,role:'detail',label:'session/start'}],hasMore:false,beforeSeq:0});
  assert.equal(model.messages.map(x => x.id).join(','),'event-1,event-4');
});

test('empty session filtering uses the explicit DSH flag and preserves untitled content and active work', () => {
  const { nativeSessionVisible, NativeSessionModel } = load('NativeSessionModel', {});
  assert.equal(nativeSessionVisible({title:'named empty',blank:true},undefined),false);
  assert.equal(nativeSessionVisible({title:'新会话',blank:false},undefined),true);
  assert.equal(nativeSessionVisible({title:'',blank:false},undefined),true);
  assert.equal(nativeSessionVisible({title:'新会话',blank:true,running:true},undefined),true);
  assert.equal(nativeSessionVisible({title:'新会话'},undefined),false);
  const cached = new NativeSessionModel(); cached.messages = [{role:'user',text:'hello'}];
  assert.equal(nativeSessionVisible({title:'新会话',blank:true},cached),true);
});

test('Workspace projection isolates pins, sorts by interaction and keeps drag contracts stable',()=>{
  const {nativeWorkspaceSessions,nativeWorkspaceRows,nativeToolsParent,nativeWorkspaceDragOrder,
    nativeBackToBottomAvailable,nativeBackToBottomHasNewContent}=load('NativeSessionModel',{});
  const rows=[
    {id:'a',title:'Alpha',blank:false,updatedAt:5,cwd:'/workspace/project'},
    {id:'b',title:'Beta',blank:false,updatedAt:6},
    {id:'c',title:'Gamma',blank:false,updatedAt:8},
    {id:'d',title:'Delta',blank:false,updatedAt:7},
    {id:'empty',title:'New',blank:true,updatedAt:9},
    {id:'archived',title:'Archived',blank:false,updatedAt:10}
  ];
  const snapshot={items:[
    {workspaceId:'project',title:'Project',sessionIds:['b','a','empty']},
    {workspaceId:'lab',title:'Lab',sessionIds:['d','c']}
  ],archivedSessionIds:['archived'],pinnedSessionIds:['a']};
  assert.equal(nativeWorkspaceSessions(rows,snapshot,'project','',new Map()).map(x=>x.id).join(','),'b');
  assert.equal(nativeWorkspaceSessions(rows,snapshot,'project','alpha',new Map()).length,0);
  const recent=new Map([['b',20]]);
  assert.equal(nativeWorkspaceSessions(rows,snapshot,'project','',new Map(),'',recent).map(x=>x.id).join(','),'b');
  const projected=nativeWorkspaceRows(rows,snapshot,'','',new Map(),'',[],new Map());
  assert.equal(projected[0].section,'pinnedHeader');
  assert.equal(projected[1].session.id,'a');
  assert.equal(projected[1].workspaceTitle,'Project');
  const workspaceSessionIds=projected.filter(x=>!x.group).map(x=>x.session.id);
  assert.equal(workspaceSessionIds.filter(id=>id==='a').length,1);
  assert.equal(workspaceSessionIds.join(','),'a,b,c,d');
  const unpinned={...snapshot,pinnedSessionIds:[]};
  assert.equal(nativeWorkspaceSessions(rows,unpinned,'project','',new Map()).map(x=>x.id).join(','),'b,a');
  const unpinnedRows=nativeWorkspaceRows(rows,unpinned,'','',new Map(),'',[],new Map());
  assert.equal(unpinnedRows.some(x=>x.section==='pinnedHeader'),false);
  assert.equal(unpinnedRows.filter(x=>x.session.id==='a').length,1);
  assert.equal(unpinnedRows.find(x=>x.session.id==='a').workspaceId,'project');
  const blankPinned={...snapshot,pinnedSessionIds:['empty']};
  const blankPinnedRows=nativeWorkspaceRows(rows,blankPinned,'','',new Map(),'empty',[],new Map());
  assert.equal(blankPinnedRows.some(x=>x.section==='pinnedHeader'),false);
  assert.equal(blankPinnedRows.find(x=>x.session.id==='empty').section,'workspaceSession');
  assert.equal(nativeBackToBottomAvailable(true,true,false),false);
  assert.equal(nativeBackToBottomAvailable(false,false,false),false);
  assert.equal(nativeBackToBottomAvailable(false,true,true),false);
  assert.equal(nativeBackToBottomAvailable(false,true,false),true);
  assert.equal(nativeBackToBottomHasNewContent(true,'delta'),false);
  assert.equal(nativeBackToBottomHasNewContent(false,'state'),false);
  assert.equal(nativeBackToBottomHasNewContent(false,'delta'),true);
  const localRecent=new Map([['a',30]]);
  assert.equal(nativeWorkspaceSessions(rows,unpinned,'project','',new Map(),'',localRecent).map(x=>x.id).join(','),'a,b');
  const tied=[
    {id:'z',title:'Z',blank:false,updatedAt:4},
    {id:'y',title:'Y',blank:false,updatedAt:4}
  ];
  const tiedSnapshot={...unpinned,items:[{workspaceId:'project',title:'Project',sessionIds:['z','y']}]};
  assert.equal(nativeWorkspaceSessions(tied,tiedSnapshot,'project','',new Map()).map(x=>x.id).join(','),'y,z');
  assert.equal(rows.map(x=>x.id).join(','),'a,b,c,d,empty,archived');
  assert.equal(nativeToolsParent('queueEdit'),'queue');assert.equal(nativeToolsParent('efforts'),'modelsRoot');
  assert.equal(nativeToolsParent('models'),'modelsRoot');assert.equal(nativeToolsParent('modelsRoot'),'');
  assert.equal(nativeToolsParent('rename'),'');
  const complete = ['a','b','c'];
  assert.deepEqual(Array.from(nativeWorkspaceDragOrder(complete,'a','c',false)),['b','a','c']);
  assert.deepEqual(Array.from(nativeWorkspaceDragOrder(complete,'a','c',true)),['b','c','a']);
  assert.equal(nativeWorkspaceDragOrder(complete,'missing','c',false),null);
  assert.deepEqual(Array.from(complete),['a','b','c']);
});

test('native inline markdown preserves literal code and malformed text while styling nested runs', () => {
  const { nativeInlineMarkdown, nativeInlineFileReference, nativeInlineExternalLink } =
    load('NativeInlineMarkdown', {});
  const runs = nativeInlineMarkdown('**bold and `a_*b`** · [readme](</workspace/docs/readme.md>) · [web](https://example.com/a_(b))');
  assert.equal(runs.map(x => x.text).join(''),'bold and a_*b · readme · web');
  assert.equal(runs.find(x => x.code).text,'a_*b');
  assert.equal(runs.find(x => x.code).bold,true);
  assert.equal(runs.find(x => x.text === 'readme').href,'/workspace/docs/readme.md');
  assert.equal(runs.find(x => x.text === 'web').href,'https://example.com/a_(b)');
  assert.equal(nativeInlineMarkdown('**unfinished').map(x => x.text).join(''),'**unfinished');
  assert.equal(nativeInlineMarkdown('`**literal**`').map(x => x.text).join(''),'**literal**');
  const image = nativeInlineMarkdown('![preview](</workspace/docs/image.png>)').at(0);
  assert.equal(image.text, 'preview');
  assert.equal(image.href, '/workspace/docs/image.png');
  assert.equal(image.isImage, true);
  assert.equal(image.alt, 'preview');
  assert.equal(nativeInlineFileReference('src/app.ts:42'), 'src/app.ts:42');
  assert.equal(nativeInlineFileReference('/workspace/docs/readme.md'), '/workspace/docs/readme.md');
  assert.equal(nativeInlineFileReference('npm run test'), '');
  assert.equal(nativeInlineFileReference('object.value'), '');
  const fileCode = nativeInlineMarkdown('see `src/app.ts:42`').find(x => x.code);
  assert.equal(fileCode.href, 'src/app.ts:42');
  assert.equal(nativeInlineExternalLink('https://example.com/docs'), true);
  assert.equal(nativeInlineExternalLink('http://example.com'), true);
  assert.equal(nativeInlineExternalLink('mailto:author@example.com'), true);
  assert.equal(nativeInlineExternalLink('tel:+123456789'), true);
  assert.equal(nativeInlineExternalLink('/workspace/docs/readme.md'), false);
  assert.equal(nativeInlineExternalLink('#section'), false);
  assert.equal(nativeInlineExternalLink('ordinary text'), false);
  const plain = nativeInlineMarkdown('ordinary streaming prose without syntax');
  assert.equal(plain.length, 1);
  assert.equal(plain[0].text, 'ordinary streaming prose without syntax');
  assert.equal(plain[0].bold || plain[0].italic || plain[0].code || plain[0].strike, false);
});

test('external inline links use a themed clickable SVG image span', () => {
  const inlineText = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeInlineText.ets', import.meta.url), 'utf8');
  assert.match(inlineText, /nativeInlineExternalLink\(run\.href\)/);
  assert.match(inlineText, /ImageSpan\(\$rawfile\('dsh-icons\/external-link-outline\.svg'\)\)/);
  assert.match(inlineText, /\.colorFilter\(this\.externalIconFilter\(\)\)/);
  assert.match(inlineText, /\.onClick\(\(\): void => \{ this\.open\(run\); \}\)/);
});

test('native links resolve workspace files relative to the session cwd', () => {
  const { nativeFileTarget, nativeLinkKind, nativeBareFileName } = load('NativeLinkResolver', {});
  assert.equal(nativeLinkKind('https://example.com/image.png'), 'http');
  assert.equal(nativeLinkKind('mailto:author@example.com'), 'external');
  assert.equal(nativeLinkKind('docs/readme.md'), 'file');
  assert.equal(
    nativeFileTarget('docs/README.md#L12', '/workspace/project'),
    '/workspace/project/docs/README.md'
  );
  assert.equal(
    nativeFileTarget('../packages/a.ts', '/workspace/project/src'),
    '/workspace/project/packages/a.ts'
  );
  assert.equal(
    nativeFileTarget('dsh-resource://file/session/session-a/docs/view.ts', '/workspace/project'),
    '/workspace/project/docs/view.ts'
  );
  assert.equal(
    nativeFileTarget('file:///workspace/project/docs/view.ts#L20', '/workspace/project'),
    '/workspace/project/docs/view.ts'
  );
  assert.equal(
    nativeFileTarget('src/app.ts:42:7', '/workspace/project'),
    '/workspace/project/src/app.ts'
  );
  assert.equal(
    nativeFileTarget('docs\\view.ts', 'C:\\workspace\\project'),
    'C:/workspace/project/docs/view.ts'
  );
  assert.equal(nativeFileTarget('../../../outside.md', '/workspace/project'), '/outside.md');
  assert.equal(nativeFileTarget('/workspace/shared.md', '/workspace/project'), '/workspace/shared.md');
  assert.equal(nativeBareFileName('check_repo.py:42'), 'check_repo.py');
  assert.equal(nativeBareFileName('scripts/check_repo.py'), '');
  assert.equal(nativeBareFileName('notes with spaces.md'), '');
});

test('native diff renders only explicit or applied edits and honors null old text', () => {
  const { nativeDiff, nativeDiffText } = load('NativeDiff', {});
  const message = fields => Object.assign({
    args: '', metaRaw: '', output: '', error: '', failed: false, status: '', outcome: ''
  }, fields);

  const created = nativeDiff(message({
    args: JSON.stringify({ path: 'src/new.ts', oldText: null, newText: 'one\ntwo\n' })
  }));
  assert.equal(created.matched, true);
  assert.equal(created.added, 2);
  assert.equal(created.removed, 0);
  assert.equal(created.rows.filter(row => row.kind === 'add').length, 2);
  assert.equal(created.rows.filter(row => row.kind === 'del').length, 0);
  assert.deepEqual(Array.from(created.rows.filter(row => row.kind === 'add')
    .map(row => [row.oldLine, row.newLine])), [[0, 1], [0, 2]]);
  assert.equal(nativeDiffText(created.rows), 'src/new.ts\n+ one\n+ two');

  const multiple = nativeDiff(message({
    args: JSON.stringify({ diffs: [
      { path: 'a.ts', oldText: 'old', newText: 'new' },
      { path: 'b.ts', oldText: null, newText: 'created' }
    ] })
  }));
  assert.equal(multiple.matched, true);
  assert.equal(multiple.path, 'a.ts');
  assert.equal(multiple.added, 2);
  assert.equal(multiple.removed, 1);
  assert.deepEqual(Array.from(multiple.rows.filter(row => row.kind === 'path')
    .map(row => row.text)), ['a.ts', 'b.ts']);

  const patch = '*** Begin Patch\n*** Update File: src/a.ts\n@@ -10,1 +20,1 @@\n-old\n+new\n*** End Patch';
  const patched = nativeDiff(message({ output: patch }));
  assert.deepEqual(Array.from(patched.rows.map(row => row.kind)), ['path', 'del', 'add']);
  assert.deepEqual(Array.from(patched.rows.filter(row => row.kind === 'del')
    .map(row => [row.oldLine, row.newLine])), [[10, 0]]);
  assert.deepEqual(Array.from(patched.rows.filter(row => row.kind === 'add')
    .map(row => [row.oldLine, row.newLine])), [[0, 20]]);
  assert.equal(patched.added, 1);
  assert.equal(patched.removed, 1);
  assert.equal(nativeDiff(message({ output: patch, failed: true })).matched, false);
  assert.equal(nativeDiff(message({ output: patch, status: 'interrupted' })).matched, false);
  assert.equal(nativeDiff(message({ output: patch, output: 'AUTO_REVIEW_DENIED\n' + patch })).matched,
    false);
  assert.equal(nativeDiff(message({ output: 'old\n+new' })).matched, false);
});

test('native diff understands current write, edit and str_replace_editor arguments', () => {
  const { nativeDiff } = load('NativeDiff', {});
  const message = fields => Object.assign({
    args: '', metaRaw: '', output: '', error: '', failed: false, status: '', outcome: '',
    phase: '', toolName: ''
  }, fields);

  const write = nativeDiff(message({
    toolName: 'write', phase: 'preparing', status: 'preparing',
    args: JSON.stringify({ file_path: 'src/new.ts', content: 'one\ntwo\n' })
  }));
  assert.equal(write.matched, true);
  assert.equal(write.path, 'src/new.ts');
  assert.equal(write.added, 2);
  assert.equal(write.removed, 0);

  const edit = nativeDiff(message({
    toolName: 'edit', phase: 'start', status: 'running',
    args: JSON.stringify({ file_path: 'src/edit.ts', old_string: 'before', new_string: 'after' })
  }));
  assert.equal(edit.matched, true);
  assert.equal(edit.added, 1);
  assert.equal(edit.removed, 1);

  const create = nativeDiff(message({
    toolName: 'str_replace_editor', phase: 'start', status: 'running',
    args: JSON.stringify({ command: 'create', path: 'src/create.ts', file_text: 'created' })
  }));
  assert.equal(create.matched, true);
  assert.equal(create.added, 1);

  const replace = nativeDiff(message({
    toolName: 'str_replace_editor', phase: 'start', status: 'running',
    args: JSON.stringify({ command: 'str_replace', path: 'src/replace.ts', old_str: 'a', new_str: 'b' })
  }));
  assert.equal(replace.matched, true);
  assert.equal(replace.added, 1);
  assert.equal(replace.removed, 1);

  const insert = nativeDiff(message({
    toolName: 'str_replace_editor', phase: 'start', status: 'running',
    args: JSON.stringify({ command: 'insert', path: 'src/insert.ts',
      insert_line: 12, new_str: 'first\nsecond' })
  }));
  assert.equal(insert.matched, true);
  assert.equal(insert.path, 'src/insert.ts');
  assert.equal(insert.added, 2);
  assert.equal(insert.removed, 0);
  assert.deepEqual(Array.from(insert.rows.filter(row => row.kind === 'add')
    .map(row => row.text)), ['first', 'second']);

  const applied = nativeDiff(message({
    toolName: 'write', phase: 'result', status: 'success',
    args: JSON.stringify({ file_path: 'src/new.ts', content: 'all-new\ncontent\n' }),
    metaRaw: JSON.stringify({ diffs: [{ path: 'src/new.ts', oldText: 'old', newText: 'all-new\n' }] })
  }));
  assert.equal(applied.added, 1);
  assert.equal(applied.removed, 1, 'settled metadata overrides the provisional whole-file write');
});

test('turn file changes aggregate only settled explicit mutations by stable path', () => {
  const types = load('NativeSessionModel', {});
  const difference = load('NativeDiff', {});
  const turnChanges = load('NativeTurnChanges', {
    './NativeSessionModel': types,
    './NativeDiff': difference
  });
  const tool = (callId, turnKey, name, fields = {}) => Object.assign(
    new types.NativeMessage(), {
      id: callId, callId, turnKey, role: 'tool', toolName: name,
      phase: 'result', status: 'success', toolName: name,
      args: '', metaRaw: '', output: '', error: '', failed: false, outcome: ''
    }, fields);
  const footer = (turnKey, outcome = 'completed') => Object.assign(
    new types.NativeMessage(), {
      id: 'end-' + turnKey, role: 'turn-footer', turnKey,
      footerOutcome: outcome, outcome
    });

  const first = tool('call-a', 'turn:1', 'write', {
    args: JSON.stringify({ path: 'src/a.ts', oldText: 'old', newText: 'new' })
  });
  const second = tool('call-b', 'turn:1', 'apply_patch', {
    output: '*** Begin Patch\n*** Update File: src/a.ts\n@@ -1,1 +1,2 @@\n-old\n+new\n+more\n' +
      '*** Add File: src/b.ts\n@@ -0,0 +1,1 @@\n+created\n*** End Patch'
  });
  const failed = tool('call-failed', 'turn:1', 'edit', {
    failed: true,
    args: JSON.stringify({ path: 'src/failed.ts', oldText: 'a', newText: 'b' })
  });
  const preparing = tool('call-preparing', 'turn:1', 'edit', {
    phase: 'start', status: 'preparing',
    args: JSON.stringify({ path: 'src/preparing.ts', oldText: 'a', newText: 'b' })
  });
  const prose = tool('call-read', 'turn:1', 'read', {
    output: 'diff --git a/src/fake.ts b/src/fake.ts\n+fake'
  });
  const process = Object.assign(new types.NativeMessage(), {
    id: 'process-one', role: 'process', turnKey: 'turn:1',
    children: [first, failed, preparing, second, prose]
  });
  const rows = [process, footer('turn:1')];
  const summaries = turnChanges.nativeTurnChanges(rows);
  assert.equal(summaries.length, 1);
  assert.equal(summaries[0].running, false);
  assert.equal(summaries[0].outcome, 'completed');
  assert.equal(summaries[0].fileCount, 2);
  assert.deepEqual(Array.from(summaries[0].files, file => ({
    path: file.path, added: file.added, removed: file.removed
  })), [
    { path: 'src/a.ts', added: 3, removed: 2 },
    { path: 'src/b.ts', added: 1, removed: 0 }
  ]);
  assert.equal(summaries[0].added, 4);
  assert.equal(summaries[0].removed, 2);
  assert.equal(turnChanges.nativeTurnChangeFor(summaries, 'turn:1'), summaries[0]);
  assert.equal(turnChanges.nativeTurnChangeFor(summaries, 'turn:missing'), null);
});

test('turn change file presentation keeps a workspace-relative directory and prioritizes the filename', () => {
  const types = load('NativeSessionModel', {});
  const difference = load('NativeDiff', {});
  const turnChanges = load('NativeTurnChanges', {
    './NativeSessionModel': types,
    './NativeDiff': difference
  });
  const posix = turnChanges.nativeTurnFilePresentation(
    '/workspace/project/harmony/entry/NativeFileBrowser.ets',
    '/workspace/project/',
    'NativeFileBrowser.ets'
  );
  assert.equal(posix.relativePath, 'harmony/entry/NativeFileBrowser.ets');
  assert.equal(posix.directory, 'harmony/entry/');
  assert.equal(posix.name, 'NativeFileBrowser.ets');

  const windows = turnChanges.nativeTurnFilePresentation(
    'C:\\Users\\me\\project\\src\\features\\editor.ts',
    'c:\\users\\me\\project',
    'editor.ts'
  );
  assert.equal(windows.relativePath, 'src/features/editor.ts');
  assert.equal(windows.directory, 'src/features/');
  assert.equal(windows.name, 'editor.ts');

  const relative = turnChanges.nativeTurnFilePresentation(
    'harmony/entry/NativeWorkspace.ets',
    '/workspace/project',
    'NativeWorkspace.ets'
  );
  assert.equal(relative.relativePath, 'harmony/entry/NativeWorkspace.ets');
  assert.equal(relative.directory, 'harmony/entry/');

  const outsideRoot = turnChanges.nativeTurnFilePresentation(
    '/opt/private/build/output.bin',
    '/workspace/project',
    'src/generated.ts'
  );
  assert.equal(outsideRoot.relativePath, 'src/generated.ts');
  assert.equal(outsideRoot.directory, 'src/');
  assert.equal(outsideRoot.name, 'generated.ts');

  const filenameOnly = turnChanges.nativeTurnFilePresentation(
    '/opt/private/build/output.bin',
    '/workspace/project',
    'output.bin'
  );
  assert.equal(filenameOnly.relativePath, 'output.bin');
  assert.equal(filenameOnly.directory, '');
  assert.equal(filenameOnly.name, 'output.bin');
  assert.equal(filenameOnly.relativePath.includes('/opt/private'), false);
});

test('live turn file changes require an active unfinished turn and ignore malformed diffs', () => {
  const types = load('NativeSessionModel', {});
  const difference = load('NativeDiff', {});
  const turnChanges = load('NativeTurnChanges', {
    './NativeSessionModel': types,
    './NativeDiff': difference
  });
  const runningTool = Object.assign(new types.NativeMessage(), {
    id: 'call-live', callId: 'call-live', role: 'tool', turnKey: 'turn:2',
    toolName: 'edit', phase: 'result', status: 'success',
    args: JSON.stringify({ diffs: [
      { path: 'dir\\same.ts', oldText: 'a', newText: 'b' },
      { path: 'dir/same.ts', oldText: 'b', newText: 'c' },
      { path: 'bad.ts', oldText: 4, newText: 'nope' }
    ] }),
    metaRaw: '', output: '', error: '', failed: false, outcome: ''
  });
  const preparingTool = Object.assign(new types.NativeMessage(), {
    id: 'call-preparing', callId: 'call-preparing', role: 'tool', turnKey: 'turn:2',
    toolName: 'write', phase: 'preparing', status: 'preparing',
    args: JSON.stringify({ file_path: 'dir/live.ts', content: 'live\n' }),
    metaRaw: '', output: '', error: '', failed: false, outcome: ''
  });
  const denied = Object.assign(new types.NativeMessage(), {
    id: 'call-denied', callId: 'call-denied', role: 'tool', turnKey: 'turn:2',
    toolName: 'apply_patch', phase: 'result', status: 'success',
    args: JSON.stringify({ path: 'denied.ts', oldText: null, newText: 'x' }),
    metaRaw: '', output: 'AUTO_REVIEW_DENIED', error: '', failed: false, outcome: ''
  });
  const running = Object.assign(new types.NativeMessage(), {
    id: 'process-live', role: 'process', turnKey: 'turn:2',
    children: [runningTool, preparingTool, denied]
  });
  const rows = [running];
  const live = turnChanges.nativeLiveTurnChange(rows, true);
  assert.ok(live);
  assert.equal(live.running, true);
  assert.equal(live.fileCount, 1, 'preparing mutations are intent, not confirmed changes');
  assert.equal(live.files[0].path, 'dir\\same.ts');
  assert.equal(live.files[0].added, 2);
  assert.equal(live.files[0].removed, 2);
  assert.equal(live.files.some(file => file.path === 'dir/live.ts'), false);
  assert.equal(turnChanges.nativeLiveTurnChange(rows, false), null);
  assert.equal(turnChanges.nativeTurnChanges([running, Object.assign(
    new types.NativeMessage(), {
      id: 'end-live', role: 'turn-footer', turnKey: 'turn:2',
      footerOutcome: 'cancelled', outcome: 'cancelled'
    })])[0].outcome, 'cancelled');
  const baseSignature = turnChanges.nativeTurnChangeInputSignature(rows, []);
  const streamedText = Object.assign(new types.NativeMessage(), {
    id: 'stream-text', role: 'assistant', text: 'streaming prose',
    turnKey: 'turn:2'
  });
  assert.equal(turnChanges.nativeTurnChangeInputSignature(rows.concat([streamedText]), []),
    baseSignature, 'ordinary text-only stream updates must not reparse turn diffs');
  const streamingMutation = Object.assign(new types.NativeMessage(), {
    id: 'stream-mutation', callId: 'stream-mutation', role: 'tool',
    turnKey: 'turn:2', toolName: 'edit', phase: 'preparing',
    args: '{"path":"live.ts",'
  });
  assert.notEqual(turnChanges.nativeTurnChangeInputSignature(rows, [streamingMutation]),
    baseSignature, 'streamed mutation arguments must invalidate the aggregate');
});

test('turn change references use durable event sequence and official summary totals', () => {
  const types = load('NativeSessionModel', {});
  const difference = load('NativeDiff', {});
  const turnChanges = load('NativeTurnChanges', {
    './NativeSessionModel': types,
    './NativeDiff': difference
  });
  const journal = [
    JSON.stringify({ seq: 8, type: 'workspace/changes', data: { turn: 2 } }),
    JSON.stringify({ seq: 12, type: 'workspace/changes', data: { turn: 2 } }),
    JSON.stringify({ seq: 13, type: 'workspace/changes', data: { turn: 9 } }),
    JSON.stringify({ seq: 14, type: 'workspace/changes', data: { turn: 0 } }),
    '{"seq":15,"type":"workspace/changes","data":',
    JSON.stringify({ seq: 16, type: 'turn/end', data: { turn: 9 } })
  ];
  const references = turnChanges.nativeTurnChangeReferences(journal);
  assert.deepEqual(Array.from(references, value => ({
    turnKey: value.turnKey, turn: value.turn, seq: value.seq
  })), [
    { turnKey: 'turn:2', turn: 2, seq: 12 },
    { turnKey: 'turn:9', turn: 9, seq: 13 }
  ]);
  const summary = turnChanges.nativeTurnChangeSummaryFromJson(JSON.stringify({
    turn: 2, total: 4, added: 18, deleted: 7,
    files: [
      { path: 'src/a.ts', display: 'a.ts', added: 10, deleted: 4 },
      { path: 'assets/icon.bin', display: 'icon.bin', added: 0, deleted: 0, binary: true },
      { path: 'docs/large.md', display: 'large.md', added: 8, deleted: 3, oversized: true }
    ]
  }), 'turn:2', 'completed');
  assert.ok(summary);
  assert.equal(summary.fileCount, 4);
  assert.equal(summary.files.length, 3);
  assert.equal(summary.files[1].display, 'icon.bin');
  assert.equal(summary.files[1].binary, true);
  assert.equal(summary.files[2].oversized, true);
  assert.equal(summary.outcome, 'completed');
  assert.equal(turnChanges.nativeTurnChangeSummaryFromJson('{"total":1}', 'turn:2'), null);
  assert.equal(turnChanges.nativeTurnChangeSummaryFromJson(JSON.stringify({
    turn: 1, total: 1, added: 1, deleted: 0,
    files: [{ path: 'a', display: 'a', added: 1, deleted: 0, binary: false }]
  }), 'turn:1'), null);
  assert.equal(turnChanges.nativeTurnChangeSummaryFromJson(JSON.stringify({
    turn: 2, total: 1, added: 1, deleted: 0,
    files: [{ path: 'a', display: 'a', added: 1, deleted: 0 }]
  }), 'turn:1'), null);
});

test('turn change card and bottom live control keep compact ownership and motion contracts', () => {
  const view = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeTurnChangesView.ets',
    import.meta.url), 'utf8');
  const workspace = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeWorkspace.ets',
    import.meta.url), 'utf8');
  const dock = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeBottomConversationDock.ets',
    import.meta.url), 'utf8');
  assert.match(view, /已编辑 ' \+ this\.summary\.fileCount \+ ' 个文件/);
  assert.match(view, /this\.summary\.files\.slice\(0, 3\)/);
  assert.match(view, /再显示 ' \+ \(this\.summary\.files\.length - 3\) \+ ' 个文件/);
  assert.match(view, /onOpenFile: \(path: string\) => void/);
  assert.match(view, /nativeTurnFilePresentation/);
  assert.match(view, /Text\(this\.fileDirectory\(file\)\)/);
  assert.match(view, /Text\(this\.fileName\(file\)\)/);
  const filename = view.indexOf('Text(this.fileName(file))');
  const directory = view.indexOf('Text(this.fileDirectory(file))');
  const metrics = view.indexOf("Text('+' + formattedCount(file.added))");
  assert.ok(filename >= 0 && directory > filename && metrics > directory,
    'the filename is the primary row and fixed metrics follow the secondary directory');
  assert.match(view, /\.layoutWeight\(1\)\.constraintSize\(\{ minWidth: 0 \}\)/);
  assert.doesNotMatch(view, /layoutWeight\(this\.fileDirectory\(file\) \? 2 : 1\)/);
  assert.match(view, /\.width\('100%'\)\.clip\(true\)\.borderRadius\(NativeDesign\.radiusGroup\)/);
  assert.match(view, /\.backgroundColor\(NativeDesign\.raised\(this\.dark\)\)/);
  assert.match(view, /NativeMotion\.duration\('micro'\) \+ 30/);
  assert.match(view, /translate\(\{ y: -7 \* this\.progress \}\)/);
  assert.match(view, /!NativeMotion\.enabled\(\)/);
  assert.doesNotMatch(view, /撤销|查看变更/);
  assert.match(workspace, /NativeTurnChangesCard\(\{[\s\S]{0,500}onOpenFile:[\s\S]{0,180}this\.openTurnChangeFile/);
  assert.match(workspace, /NativeTurnChangesCard\(\{[\s\S]{0,180}workspaceRoot: this\.workspaceRootFor\(this\.selected\)/);
  assert.match(workspace, /request\.previewOnly = true/);
  assert.match(workspace, /previewOnly: this\.fileView\.previewOnly/);
  assert.match(workspace, /NativeTurnChangePill\(\{[\s\S]{0,180}liveTurnChanges/);
  assert.match(workspace,
    /private paint\(\): void \{[\s\S]{0,260}this\.running = this\.model\.running;[\s\S]{0,180}this\.renderTranscript\(\)/);
  assert.match(workspace, /nativeLiveTurnChange\(rows, this\.model\.running \|\| this\.model\.waiting\)/);
  assert.doesNotMatch(workspace,
    /nativeLiveTurnChange\(rows,[\s\S]{0,120}this\.running \|\| this\.waiting/);
  assert.match(workspace, /Activity can change without a tool\/footer signature change[\s\S]{0,900}liveTurnChangesVisible = false/);
  assert.match(workspace, /NativeMotion\.disclosure\(this\.getUIContext\(\)[\s\S]{0,180}liveTurnChangesVisible = true/);
  assert.match(workspace, /NativeMotion\.disclosure\(this\.getUIContext\(\)[\s\S]{0,180}liveTurnChangesVisible = false/);
  assert.match(workspace, /nativeTurnChangeSummaryFromJson/);
  assert.match(workspace, /officialTurnChangeSequences\.get\(reference\.turnKey\)/);
  assert.match(workspace, /NativeBottomConversationDock\(\{[\s\S]{0,260}horizontalBleed: 12/);
  assert.match(workspace,
    /elevated: this\.liveTurnChangesVisible \|\| this\.attachments\.length > 0 \|\|[\s\S]{0,120}this\.error\.length > 0/);
  assert.doesNotMatch(workspace, /bottomDockContentHeight|bottomDockOverlayInset|translate\(\{ y: -\(this\.bottomDock/);
  assert.match(workspace, /if \(this\.error\)[\s\S]{0,1200}Text\(this\.error\)[\s\S]{0,500}关闭错误/);
  assert.match(workspace, /if \(this\.error && !this\.selected\)/);
  assert.match(workspace, /if \(this\.liveTurnChangesVisible\)[\s\S]{0,360}NativeTurnChangePill/);
  assert.match(workspace, /if \(this\.attachments\.length\)[\s\S]{0,260}NativeAttachmentDraft/);
  assert.match(dock, /@Prop elevated: boolean = false/);
  assert.match(dock, /if \(this\.elevated && NativeExperience\.materialsEnabled\(\)\)/);
  assert.match(dock, /\.width\('100%'\)\.height\(this\.measuredHeight\)/);
  assert.doesNotMatch(dock, /\.width\('100%'\)\.height\('100%'\)/);
  assert.match(dock, /\.backgroundBlurStyle\(BlurStyle\.COMPONENT_ULTRA_THIN/);
  assert.doesNotMatch(dock, /\.linearGradientBlur\(/,
    'foreground blur on an empty material layer cannot create a gradient backdrop blur');
  assert.match(dock, /Component material performs the actual backdrop blur/);
  assert.match(dock, /\.linearGradient\(\{[\s\S]{0,300}angle: 180/);
  assert.match(dock,
    /NativeDesign\.blurScrimTop\(false\)[\s\S]{0,180}NativeDesign\.blurScrimBottom\(false\)/);
  assert.match(dock,
    /NativeDesign\.blurScrimTop\(true\)[\s\S]{0,180}NativeDesign\.blurScrimBottom\(true\)/);
  assert.match(dock, /else if \(this\.elevated\)[\s\S]{0,260}\.backgroundColor\(NativeDesign\.subtleSurface\(this\.dark\)\)/);
  assert.doesNotMatch(dock, /\.backgroundColor\((?:Color\.)?(?:Black|'#000000')\)/);
  assert.match(dock, /margin\(\{ left: -this\.horizontalBleed, right: -this\.horizontalBleed \}\)/);
  assert.match(dock, /nativeSafeBottom/);
  assert.match(dock, /top: 8, bottom: Math\.ceil\(this\.safeBottom \* 1\.2\) \+ 8/);
  assert.match(workspace, /hitTestBehavior\(HitTestMode\.Transparent\)\.zIndex\(6\)/);
  assert.match(workspace, /this\.liveTurnChangesVisible = false/);
});

test('non-edit tools never enter diff projection and malformed diff data is inert', () => {
  const { nativeDiff } = load('NativeDiff', {});
  const plan = Object.assign({
    args: 'null', metaRaw: 'null', output: '{"ok":true}', error: '',
    failed: false, status: 'success', outcome: ''
  });
  const inert = nativeDiff(plan);
  assert.equal(inert.matched, false);
  assert.deepEqual(Array.from(inert.rows), []);
  plan.args = JSON.stringify({ diffs: [null, 42, { path: 'x', oldText: 'a', newText: 'b' }] });
  const mixed = nativeDiff(plan);
  assert.equal(mixed.matched, true);
  assert.equal(mixed.added, 1);
  const view = readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeToolCallView.ets', import.meta.url), 'utf8');
  assert.match(view,
    /const category = nativeToolCategory\(this\.message\.toolName, this\.message\.args\);/);
  assert.match(view, /\['edit', 'write'\]\.includes\(category\) \? nativeDiff\(this\.message\)/);
});

test('todo_write projects structured status rows and the newest replacement plan', () => {
  const types=load('NativeSessionModel',{});
  const {NativePlanDocument,nativePlanDocument,nativeLatestPlan,nativePlanProgress,nativePlanDiff}=load(
    'NativePlan',{'./NativeSessionModel':types});
  const tool=Object.assign(new types.NativeMessage(),{
    role:'tool',toolName:'todo_write',
    args:JSON.stringify({todos:[
      {content:'完成协议解析',status:'completed'},
      {content:'补齐移动端界面',status:'in_progress'},
      {content:'执行真机验收',status:'pending'},
      {content:'保留旧状态',status:'unknown'},
      {content:'',status:'pending'},
      42
    ]})
  });
  const plan=nativePlanDocument(tool);
  assert.equal(plan.parsed,true);
  assert.deepEqual(Array.from(plan.items,item=>item.content),
    ['完成协议解析','补齐移动端界面','执行真机验收','保留旧状态']);
  assert.equal(plan.items[3].status,'pending');
  assert.equal(nativePlanProgress(plan),'已完成 1 · 进行中 1 · 待处理 2');

  const repeated=Object.assign(new types.NativeMessage(),{
    role:'tool',toolName:'todo_write',args:'',
    output:JSON.stringify({items:[{title:'从结果回退解析',status:'completed'}]})
  });
  assert.equal(nativePlanDocument(repeated).items[0].content,'从结果回退解析');
  const empty=Object.assign(new types.NativeMessage(),{
    role:'tool',toolName:'todo_write',args:'{"todos":[]}'
  });
  const malformed=Object.assign(new types.NativeMessage(),{
    role:'tool',toolName:'todo_write',args:'{"todos":['
  });
  assert.equal(nativeLatestPlan([tool,malformed]).items.length,4,
    'partial JSON cannot replace the last complete plan');
  assert.equal(nativeLatestPlan([tool,empty]).items.length,0,
    'an explicit empty replacement clears the current plan');

  const planFrom=todos=>nativePlanDocument(Object.assign(new types.NativeMessage(),{
    role:'tool',toolName:'todo_write',args:JSON.stringify({todos})
  }));
  const initial=planFrom([
    {content:'保留',status:'pending'},
    {content:'将要完成',status:'pending'}
  ]);
  const emptyBaseline=Object.assign(new NativePlanDocument(),{parsed:false,items:[]});
  assert.equal(nativePlanDiff(initial,emptyBaseline),'创建 2');
  assert.equal(nativePlanDiff(planFrom([
    {content:'保留',status:'pending'},
    {content:'新完成',status:'completed'}
  ]),emptyBaseline),'创建 2',
    'a newly-created completed item is created rather than double-counted as completed');
  const changed=planFrom([
    {content:'保留',status:'in_progress'},
    {content:'将要完成',status:'completed'},
    {content:'新增一',status:'pending'},
    {content:'新增二',status:'completed'}
  ]);
  assert.equal(nativePlanDiff(changed,initial),'创建 2 · 完成 1 · 更新 1');
  assert.equal(nativePlanDiff(planFrom([{content:'保留',status:'in_progress'}]),changed),
    '移除 3');
  assert.equal(nativePlanDiff(changed,changed),'无变化');

  const {nativeToolDetail}=load('NativeTranscript',{
    './NativeSessionModel':types,'./NativeHostSettings':{NativeChatPreferences:class {}},
    './NativePlan':{NativePlanDocument:class {
      parsed=false;items=[];
    },nativePlanDiff,nativePlanDocument,nativePlanProgress}
  });
  assert.equal(nativeToolDetail(tool),'已完成 1 · 进行中 1 · 待处理 2');
  const planTool=(callId,args)=>Object.assign(new types.NativeMessage(),{
    id:callId,seq:callId==='plan-a'?10:20,role:'tool',callId,toolName:'todo_write',
    phase:'start',turn:1,step:1,text:args
  });
  const {nativeTranscript}=load('NativeTranscript',{
    './NativeSessionModel':types,'./NativeHostSettings':{NativeChatPreferences:class {}},
    './NativePlan':{NativePlanDocument:class {
      parsed=false;items=[];
    },nativePlanDiff,nativePlanDocument,nativePlanProgress}
  });
  const projected=nativeTranscript([
    planTool('plan-a',JSON.stringify({todos:[{content:'A',status:'pending'}]})),
    planTool('plan-b',JSON.stringify({todos:[
      {content:'A',status:'completed'},{content:'B',status:'pending'}
    ]})),
    planTool('plan-c','{"todos":[')
  ],false);
  const projectedTools=projected.find(row=>row.role==='process').children;
  assert.deepEqual(Array.from(projectedTools,row=>row.planDiff),
    ['创建 1','创建 1 · 完成 1',''],
    'malformed streaming JSON neither receives nor replaces the diff baseline');
  assert.equal(nativeToolDetail(projectedTools[1]),'创建 1 · 完成 1');
  const toolView=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeToolCallView.ets',
    import.meta.url),'utf8');
  assert.match(toolView,/this\.message\.toolName === 'todo_write'[\s\S]{0,180}NativePlanView/);
  assert.match(toolView,/this\.message\.toolName !== 'todo_write'/);
  const workspaceView=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeWorkspace.ets',
    import.meta.url),'utf8');
  const conversationStart=workspaceView.indexOf('private conversation()');
  const interactionStart=workspaceView.indexOf('ForEach(this.interactions.concat(this.continued)',
    conversationStart);
  const conversation=workspaceView.slice(conversationStart,interactionStart);
  const transcriptStackIndex=conversation.indexOf('Stack({ alignContent: Alignment.TopStart })');
  const transcriptListIndex=conversation.indexOf("List({ space: 12, scroller: this.scroller })");
  const taskDockIndex=conversation.indexOf('NativeTaskDock({ document: this.taskPlan');
  assert.ok(conversationStart >= 0 && interactionStart > conversationStart);
  assert.ok(transcriptStackIndex >= 0 &&
    transcriptStackIndex < transcriptListIndex &&
    transcriptListIndex < taskDockIndex,
    'task-plan dock must be an overlay after the transcript List in the same Stack');
  assert.doesNotMatch(conversation.slice(0,transcriptStackIndex),
    /NativeConversationDock|NativeTaskDock/,
    'task-plan dock must not reserve a sibling row above the transcript');
  assert.match(conversation,
    /Column\(\) \{\s*NativeConversationDock\(\) \{[\s\S]{0,120}NativeTaskDock[\s\S]{0,180}\}\s*\}\.width\('100%'\)\s*\.hitTestBehavior\(HitTestMode\.Transparent\)\s*\.zIndex\(5\)/);
  assert.match(conversation,/Stack\(\{ alignContent: Alignment\.Bottom \}\)/);
  assert.doesNotMatch(workspaceView,/conversationDockHeight/);
  assert.doesNotMatch(workspaceView,/contentStartOffset\(/);
  assert.match(workspaceView,/\.width\('100%'\)\.height\('100%'\)\.clip\(true\)\.cachedCount\(6\)/);
  assert.match(workspaceView,/glyph: 'chevron-down-outline'/);
  assert.match(workspaceView,/\.width\(39\)\.height\(39\)\.borderRadius\(19\.5\)/);
  assert.match(workspaceView,/\.opacity\(this\.backToBottomPressed \? 0\.85 : 0\.6\)/);
  assert.match(workspaceView,/TouchType\.Down/);
  assert.doesNotMatch(workspaceView,/7A8AB4FF|663964FE/);
  assert.match(workspaceView,/hitTestBehavior\(HitTestMode\.Transparent\)\.zIndex\(6\)/);
  const dockGroup=readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeConversationDock.ets', import.meta.url),'utf8');
  assert.match(dockGroup,/@BuilderParam content: \(\) => void;/);
  const taskDock=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeTaskDock.ets',
    import.meta.url),'utf8');
  assert.match(taskDock,/constraintSize\(\{ maxHeight: 180 \}\)/);
  assert.match(taskDock,/NativeMotion\.disclosure\(this\.getUIContext\(\)/);
  assert.match(taskDock,/\.height\(NativeDesign\.compactControl\)/);
  assert.match(taskDock,/\.backgroundColor\(NativeDesign\.raised\(this\.dark\)\)/);
  const showcase=readFileSync(new URL('../../harmony/entry/src/main/ets/services/StoreShowcaseClient.ets',
    import.meta.url),'utf8');
  assert.match(showcase,/release-plan-refresh/);
  assert.match(showcase,/'todo_write'/);
});

test('model directory paints per-session cache before refresh and updates the shared caption', async () => {
  const { NativeModelDirectory } = load('NativeModelDirectory', {});
  const calls = [];
  let revisions = 0;
  const directory = new NativeModelDirectory(async body => {
    const value = JSON.parse(body);
    calls.push(value);
    if (value.operation === 'modelCatalog') {
      return JSON.stringify({ default: { provider: 'deepseek', model: 'flash', reasoningEffort: 'high' },
        groups: [{ id: 'deepseek', name: 'DeepSeek', models: [
          { id: 'flash', name: 'Flash', reasoning: { defaultEffort: 'high',
            efforts: [{ id: 'high', name: 'High', description: '' }] } }
        ] }], failures: [] });
    }
    if (value.operation === 'projections') {
      return JSON.stringify({ values: { modelSelection: { next: { provider: 'deepseek', model: 'flash', reasoningEffort: 'high' } } } });
    }
    if (value.operation === 'selectModel') {
      return JSON.stringify({ selected: { provider: value.provider, model: value.model, reasoningEffort: value.reasoningEffort || 'high' } });
    }
    throw Error('Unexpected operation: ' + value.operation);
  }, () => { revisions++; });

  const loaded = await directory.load('session-a');
  assert.equal(directory.state('session-a'), loaded, 'the popover must receive the same cached state instance');
  assert.equal(directory.caption('session-a'), 'Flash · High');
  assert.equal(calls.length, 2);
  assert.equal(revisions, 1);
  const cachedCalls = calls.length;
  assert.equal(directory.state('session-a').selected.model, 'flash');
  assert.equal(calls.length, cachedCalls, 'reading cached state must not issue network calls');
});

test('native GFM tables preserve escaped pipes, alignment and uneven rows', () => {
  const { nativeMarkdownTable } = load('NativeMarkdownTable', {});
  assert.equal(nativeMarkdownTable('ordinary prose'), null);
  assert.equal(nativeMarkdownTable('| only one line |'), null);
  const table = nativeMarkdownTable('| Name | Result | Notes |\n| :--- | ---: | :---: |\n| `a|b` | 12\\|34 | **ok** |\n| short |');
  assert.equal(table.headers.join('|'),'Name|Result|Notes');
  assert.equal(table.aligns.join(','),'left,right,center');
  assert.deepEqual(Array.from(table.rows[0]),['`a|b`','12|34','**ok**']);
  assert.deepEqual(Array.from(table.rows[1]),['short','','']);
  assert.equal(nativeMarkdownTable('plain | not a table'),null);
  assert.equal(nativeMarkdownTable('a | b\n-- | x'),null);
});

test('native syntax highlighting preserves source and completed turns own one footer copy action', () => {
  const { nativeHighlightCode } = load('NativeCodeHighlight', {});
  const source = 'export const value = "a\\n";\r\nfunction run() { return 42; }';
  const tokens = nativeHighlightCode(source, 'typescript');
  assert.equal(tokens.map(token => token.text).join(''), source);
  assert.ok(tokens.some(token => token.kind === 'keyword'));
  assert.ok(tokens.some(token => token.kind === 'string'));
  assert.equal(nativeHighlightCode(source, 'unknown').map(token => token.text).join(''), source);

  const model = load('NativeSessionModel', {});
  const transcript = load('NativeTranscript', {});
  const start = Object.assign(new model.NativeMessage(), {
    id: 'start', role: 'turn', eventType: 'turn/start', turn: 1, turnKey: 'turn:1'
  });
  const final = Object.assign(new model.NativeMessage(), {
    id: 'answer', role: 'assistant', text: '最终答复', turn: 1, turnKey: 'turn:1'
  });
  const end = Object.assign(new model.NativeMessage(), {
    id: 'end', role: 'turn', eventType: 'turn/end', outcome: 'completed',
    label: '已完成', turn: 1, turnKey: 'turn:1'
  });
  const rows = transcript.nativeTranscript([start, final, end], false);
  const footer = rows.find(row => row.role === 'turn-footer');
  assert.equal(footer.footerCopyText, '最终答复');
  assert.equal(footer.footerCopyMessageId, 'answer');
});

test('foreground navigation wins over width changes and the session menu keeps the official action order', () => {
  const {nativeCanGoBack,nativeSessionMenu,nativeForkTitle,nativeUtilityMenu}=load('NativeNavigation',{});
  assert.equal(nativeCanGoBack({wide:true,drawerOpen:false,picker:true}),true);
  assert.equal(nativeCanGoBack({wide:true,drawerOpen:false,tools:true}),true);
  assert.equal(nativeCanGoBack({wide:false,drawerOpen:true,menu:true}),true);
  assert.equal(nativeCanGoBack({wide:false,drawerOpen:true}),true);
  assert.equal(nativeCanGoBack({wide:false,drawerOpen:false,imagePreview:true}),true);
  assert.equal(nativeCanGoBack({wide:false,drawerOpen:false,filePreview:true}),true);
  assert.equal(nativeCanGoBack({wide:true,drawerOpen:false}),false);
  assert.equal(nativeSessionMenu(false).map(x=>x.id).join(','),'pin,rename,fork,archive,copyId');
  assert.equal(nativeSessionMenu(true,true).map(x=>x.id).join(','),'rename,fork,unarchive,copyId');
  assert.equal(nativeForkTitle('task (99999999999999999999)'),'task (100000000000000000000)');
  assert.equal(nativeForkTitle('任务（009）'),'任务（10）');
  assert.equal(nativeForkTitle('task'),'task (1)');
  assert.equal(nativeUtilityMenu(false,false,false,false,false).map(x=>x.title).join(','),
    '文件浏览,复制 Markdown,下载日志');
  assert.equal(nativeUtilityMenu(true,true,false,false,false).map(x=>x.id).join(','),'files,copy');
  assert.equal(nativeUtilityMenu(true,false,false,false,false).map(x=>x.id).join(','),'files');
});

test('workspace document model distinguishes previewable images, SVG and Markdown from source files', () => {
  const document = load('NativeDocumentModel', {});
  assert.equal(document.nativeDocumentDescriptor('assets/photo.PNG').kind, 'image');
  assert.equal(document.nativeDocumentDescriptor('assets/photo.png').defaultMode, 'preview');
  assert.equal(document.nativeDocumentDescriptor('diagram.svg').kind, 'svg');
  assert.equal(document.nativeDocumentDescriptor('diagram.svg').defaultMode, 'preview');
  assert.equal(document.nativeDocumentDescriptor('diagram.svg').language, 'svg');
  assert.equal(document.nativeDocumentDescriptor('README.MD').kind, 'markdown');
  assert.equal(document.nativeDocumentDescriptor('README.MD').canToggle, true);
  assert.equal(document.nativeDocumentDescriptor('manual.pdf').kind, 'pdf');
  assert.equal(document.nativeDocumentDescriptor('manual.pdf').canPreview, true);
  assert.equal(document.nativeDocumentDescriptor('manual.pdf').canToggle, false);
  assert.equal(document.nativeDocumentDescriptor('site/index.html').kind, 'html');
  assert.equal(document.nativeDocumentDescriptor('site/index.html').language, 'html');
  assert.equal(document.nativeDocumentDescriptor('site/index.html').defaultMode, 'preview');
  assert.equal(document.nativeDocumentDescriptor('site/index.html').canToggle, true);
  assert.equal(document.nativeDocumentDescriptor('src/main.ets').kind, 'code');
  assert.equal(document.nativeDocumentDescriptor('src/main.ets').language, 'arkts');
  assert.equal(document.nativeDocumentDescriptor('LICENSE').kind, 'unknown');
  assert.equal(document.nativeDocumentExtension('archive.tar.gz'), 'gz');
});

test('document preview/source mode uses one title-row icon action', () => {
  const preview = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeFilePreview.ets', import.meta.url), 'utf8');
  const mode = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeDocumentModeSwitch.ets', import.meta.url), 'utf8');
  const mockScript = readFileSync(new URL(
    '../../scripts/device-ui-mock.ps1', import.meta.url), 'utf8');
  const mockSuite = readFileSync(new URL(
    '../../scripts/device-ui-mock-suite.ps1', import.meta.url), 'utf8');
  const headerStart = preview.indexOf('private header()');
  const headerEnd = preview.indexOf('private imageBody()', headerStart);
  const header = preview.slice(headerStart, headerEnd);
  const screenSet = mockScript.match(/\[ValidateSet\(([\s\S]*?)\)\]\s*\[string\]\$Screen/);
  const stateSet = mockScript.match(/\[ValidateSet\(([\s\S]*?)\)\]\s*\[string\]\$State/);
  assert.ok(screenSet && screenSet[1].includes("'preview'"));
  assert.ok(stateSet && stateSet[1].includes("'document-preview'"));
  assert.match(mockSuite,
    /Screen = 'preview'; State = 'document-preview'/);
  assert.match(header, /private header\(\) \{\s*Row\(\{ space: 4 \}\)/);
  assert.equal((header.match(/NativeDocumentModeSwitch/g) || []).length, 1);
  const modePosition = header.indexOf('NativeDocumentModeSwitch');
  const copyPosition = header.indexOf("glyph: 'copy-outline'");
  assert.ok(modePosition >= 0 && modePosition < copyPosition);
  assert.doesNotMatch(header, /Row\(\) \{\s*NativeDocumentModeSwitch/);
  assert.match(mode, /NativeIconButton\(\{/);
  assert.match(mode,
    /glyph: this\.mode === 'preview' \? 'code-outline' : 'eye-outline'/);
  assert.match(mode,
    /label: this\.mode === 'preview' \? '切换到源码' : '切换到渲染预览'/);
  assert.doesNotMatch(mode, /modeButton|NativeDesign\.hitTarget \* 2|translate\(/);
});

test('browser history stores only compact paths at arbitrary depth', () => {
  const { NativeBrowserHistory } = load('NativeBrowserHistory', {});
  const history = new NativeBrowserHistory();
  for (let index = 0; index < 40; index++) {
    history.push(index % 2 ? 'file' : 'directory', 'src/' + index);
  }
  assert.equal(history.size(), 40);
  assert.deepEqual({ ...history.peek() }, { kind: 'file', path: 'src/39' });
  assert.deepEqual({ ...history.pop() }, { kind: 'file', path: 'src/39' });
  assert.deepEqual({ ...history.pop() }, { kind: 'directory', path: 'src/38' });
  assert.equal(history.size(), 38);
  assert.deepEqual(Object.keys(history.peek()).sort(), ['kind', 'path']);
});

test('HTML resolution, references and inlining stay workspace scoped', () => {
  const html = load('NativeHtmlDocument', {});
  assert.equal(html.nativeHtmlResolveReference('site/pages/index.html', '../img/a.png'), 'site/img/a.png');
  assert.equal(html.nativeHtmlResolveReference('site/pages/index.html', '/shared/b.css'), 'shared/b.css');
  assert.equal(html.nativeHtmlResolveReference('site/index.html', '../../secret'), '');
  assert.equal(html.nativeHtmlResolveReference('site/index.html', 'https://example.test/a.css'), '');
  assert.equal(html.nativeHtmlResolveReference('site/index.html', 'data:text/css,a'), '');
  const source = `<link rel="stylesheet" href="app.css"><script src="app.js"></script>` +
    `<img src="../img/logo.png" srcset="../img/logo.png 1x, ../img/logo@2x.png 2x">` +
    `<style>.hero{background:url('../img/hero.webp')}</style><a href="guide.md">guide</a>`;
  assert.deepEqual(Array.from(html.nativeHtmlReferences(source, 'site/index.html'), row =>
    `${row.kind}:${row.path}`), [
    'style:site/app.css', 'script:site/app.js', 'binary:img/logo.png',
    'binary:img/logo@2x.png', 'binary:img/hero.webp'
  ]);
  const assets = new Map([
    ['site/app.css', '.hero{background:url("data:image/webp;base64,AA==")}'],
    ['site/app.js', 'data:text/javascript;base64,AA=='],
    ['img/logo.png', 'data:image/png;base64,AA=='],
    ['img/logo@2x.png', 'data:image/png;base64,AA=='],
    ['img/hero.webp', 'data:image/webp;base64,AA==']
  ]);
  const output = html.nativeHtmlInline(source, 'site/index.html', assets);
  assert.match(output, /<style>\.hero\{background:url/);
  assert.match(output, /src="data:text\/javascript;base64,AA=="/);
  assert.match(output, /srcset="data:image\/png;base64,AA== 1x,data:image\/png;base64,AA== 2x"/);
  assert.match(output, /href="dshharmony:\/\/file\?path=site%2Fguide\.md"/);
  assert.match(output, /Content-Security-Policy/);
  assert.match(output, /connect-src http: https:/);
  const cspSource = '<meta http-equiv="Content-Security-Policy" content="img-src none">' +
    '<html><head></head><body><img src="a.png"></body></html>';
  const cspOutput = html.nativeHtmlInline(cspSource, 'site/index.html', new Map());
  assert.doesNotMatch(cspOutput, /img-src none/);
  assert.match(cspOutput, /default-src 'none'/);
});

test('PDF and HTML preview source contracts use bounded native surfaces', () => {
  const preview = readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeFilePreview.ets', import.meta.url), 'utf8');
  const html = readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeHtmlPreview.ets', import.meta.url), 'utf8');
  assert.match(preview, /previewPdfLimit: number = 64 \* 1024 \* 1024/);
  assert.match(preview, /NativeFileTransfer\.readComplete\([\s\S]{0,180}previewPdfLimit/);
  assert.match(preview, /from '@kit\.PDFKit'/);
  assert.match(preview, /PdfView\(\{[\s\S]{0,220}controller: this\.pdfController/);
  assert.match(preview, /loadDocument\(target\)/);
  assert.match(preview, /releaseDocument\(\)/);
  assert.match(preview, /fileIo\.unlinkSync\(this\.pdfUri\)/);
  assert.doesNotMatch(preview, /filePreview\.openPreview/);
  assert.doesNotMatch(preview, /setRenderMode|PresetRenderMode/);
  assert.match(preview, /\.backgroundColor\(NativeDesign\.subtleSurface\(this\.dark\)\)/);
  assert.match(preview, /NativeHtmlPreview\(\{ client: this\.client, sessionId: this\.sessionId/);
  assert.match(preview, /NativeMarkdownPreview\(\{ client: this\.client, sessionId: this\.sessionId/);
  assert.match(preview, /scrollBar\(BarState\.Auto\)[\s\S]{0,160}align\(Alignment\.TopStart\)/);
  assert.match(preview, /private markdownViewportHeight: number/);
  assert.match(preview,
    /constraintSize\(\{ minHeight: this\.markdownViewportHeight \}\)[\s\S]{0,180}justifyContent\(FlexAlign\.Start\)/);
  assert.match(preview, /this\.markdownViewportHeight = Math\.max\(1, Number\(area\.height\)\)/);
  assert.match(html, /htmlAssetLimit: number = 32 \* 1024 \* 1024/);
  assert.doesNotMatch(html, /htmlAssetCountLimit/);
  assert.match(html, /while \(queue\.length && bytes < htmlAssetLimit\)/);
  assert.match(html, /onInterceptRequest\([\s\S]{0,260}previewResponse\(\)/);
  assert.match(html, /setResponseData\(this\.prepared\)/);
  assert.match(html, /setResponseEncoding\('UTF-8'\)/);
  assert.match(html, /setResponseMimeType\('text\/html'\)/);
  assert.match(html, /awaitingPage = true;[\s\S]{0,180}controller\.loadUrl\(this\.previewUrl\(\)\)/);
  assert.doesNotMatch(html, /loadData\([^\n]*about:blank/);
  assert.doesNotMatch(html, /loadData\([^\n]*dshharmony:\/\//);
  assert.doesNotMatch(html, /controller\.loadData\(/);
  assert.match(html, /dsh-html-preview-base[\s\S]{0,300}color-scheme:/);
  assert.match(html, /\.metaViewport\(true\)/);
  assert.match(html, /dsh-html-preview-layout[\s\S]{0,800}max-width:100vw!important/);
  assert.match(html, /env\(safe-area-inset-bottom,0px\)/);
  assert.match(html, /::\-webkit\-scrollbar[\s\S]{0,160}display:none/);
  assert.match(html, /onBusyChange: \(busy: boolean\)/);
  assert.doesNotMatch(html, /if \(this\.loading\)[\s\S]{0,180}正在读取/);
  assert.match(html, /\.overScrollMode\(OverScrollMode\.NEVER\)/);
  assert.match(html, /\.onPageEnd\([\s\S]{0,220}this\.awaitingPage/);
  assert.match(html, /\.onErrorReceive\([\s\S]{0,260}event\.request\.isMainFrame\(\)/);
  assert.match(html, /\.fileAccess\(false\)/);
  assert.match(html, /onLoadIntercept\(\(event\): boolean => this\.intercept/);
  assert.match(preview, /LoadingProgress\(\)\.width\(NativeDesign\.spinnerInline\)\.height\(NativeDesign\.spinnerInline\)/);
  assert.match(preview, /this\.loading \|\| this\.previewBusy/);
  assert.match(preview, /onBusyChange: \(busy: boolean\)[\s\S]{0,180}this\.previewBusy = busy/);
  assert.match(preview, /NativeHtmlPreview\(\{[\s\S]{0,260}layoutWeight\(1\)/);
  const htmlDocument = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/services/NativeHtmlDocument.ets', import.meta.url), 'utf8');
  assert.match(htmlDocument, /img-src data: blob: http: https:/);
  assert.match(htmlDocument, /style-src[\s\S]{0,100}http: https:/);
  assert.match(htmlDocument, /connect-src http: https:/);
  assert.match(htmlDocument, /viewport-fit=cover/);
});

test('short Markdown preview pins blocks to the top of the reader', () => {
  const markdown = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeMarkdownPreview.ets', import.meta.url), 'utf8');
  assert.match(markdown,
    /\.width\('100%'\)\.justifyContent\(FlexAlign\.Start\)\.alignItems\(HorizontalAlign\.Start\)[\s\S]{0,80}align\(Alignment\.TopStart\)/);
  assert.doesNotMatch(markdown, /\.justifyContent\(FlexAlign\.Center\)/);
});

test('workspace document projections preserve source offsets and Markdown block order', () => {
  const document = load('NativeDocumentModel', {});
  assert.deepEqual(JSON.parse(JSON.stringify(
    document.nativeSourceLines('a\r\nb\r', 500).map(line => [line.number, line.text]))),
  [[500, 'a'], [501, 'b'], [502, '']]);
  const blocks = document.nativeMarkdownBlocks([
    '# Title',
    '',
    '| A | B |',
    '| --- | --- |',
    '| 1 | 2 |',
    '',
    '> quote',
    '',
    '```ts',
    'const value = 1;',
    '```'
  ].join('\n'));
  assert.deepEqual(JSON.parse(JSON.stringify(blocks.map(block => block.kind))),
    ['heading', 'table', 'quote', 'code']);
  assert.equal(blocks[0].level, 1);
  assert.equal(blocks[3].language, 'ts');
  assert.equal(blocks[3].text, 'const value = 1;');
});

test('Host profile mirror serializes writes with the latest revision and restores authority after conflicts', async () => {
  const {NativeHostSettings}=load('NativeHostSettings',{});
  let revision=4, values={transcriptView:'standard'}, fail=false;
  const writes=[];
  const mirror=new NativeHostSettings(async raw=>{
    const request=JSON.parse(raw);
    if(request.operation==='settingsDescribe') return JSON.stringify({writable:true,namespaces:[{ns:'ui-chat',value:values,revision}]});
    writes.push(request);
    if(fail) { values={transcriptView:'compact'};revision++;throw Error('conflict'); }
    assert.equal(request.revision,revision,'queued write must take its revision when it executes');
    values={...values,[request.field]:request.value};return JSON.stringify({ns:'ui-chat',value:values,revision:++revision});
  });
  await mirror.refresh();
  await Promise.all([mirror.set('ui-chat','transcriptView','detailed'),mirror.set('ui-chat','foldedReplies','final')]);
  assert.equal(writes.map(x=>x.revision).join(','),'4,5');
  assert.equal(mirror.chat().mode,'detailed');assert.equal(mirror.chat().foldedReplies,'final');
  fail=true;await assert.rejects(()=>mirror.set('ui-chat','transcriptView','verbose'));
  assert.equal(mirror.chat().mode,'compact');
  assert.equal(mirror.description.namespaces[0].revision,7);
});

test('Host chat settings project every supported ArkUI selector value', () => {
  const { nativeChatPreferences } = load('NativeHostSettings', {});
  const projected = nativeChatPreferences([
    { ns: 'ui-chat', value: { transcriptView: 'compact', collapseTiming: 'next-input',
      foldedReplies: 'final' }, revision: 3 },
    { ns: 'ui-conversation', value: { busyEnter: 'steer' }, revision: 2 }
  ]);
  assert.equal(projected.mode, 'compact');
  assert.equal(projected.collapseTiming, 'next-input');
  assert.equal(projected.foldedReplies, 'final');
  assert.equal(projected.busyEnter, 'steer');
  const detailed = nativeChatPreferences([
    { ns: 'ui-chat', value: { transcriptView: 'detailed' }, revision: 4 }
  ]);
  assert.equal(detailed.mode, 'detailed');
});

test('presentation policies keep direct operations visible while handling four modes, deferred collapse and final-only replies', () => {
  const types=load('NativeSessionModel',{}), preferences=load('NativeHostSettings',{});
  const {nativeTranscript,nativePresentTranscript,nativeReasoningPreview}=load('NativeTranscript',{'./NativeSessionModel':types});
  const message=(id,role,seq,rest={})=>Object.assign(new types.NativeMessage(),{id,role,seq,turn:1,step:1,...rest});
  const records=[message('human','user',1,{sourceKind:'user',text:'hello'}),
    message('tool','tool',2,{phase:'start',callId:'call',toolName:'read',text:'{"file_path":"src/app.ts"}'}),
    message('intermediate','assistant',3,{text:'progress'}),message('think','assistant',4,{reasoning:'Thought\n\nmore'}),
    message('answer','assistant',5,{text:'answer'}),message('end','turn',6,{eventType:'turn/end',outcome:'completed'})];
  for(const mode of ['compact','standard','detailed','verbose']) {
    const prefs=Object.assign(new preferences.NativeChatPreferences(),{mode});
    const visible=nativePresentTranscript(nativeTranscript(records,false),prefs,new Map());
    assert.equal(visible.filter(x=>x.role==='process').length,2);
    const open=nativePresentTranscript(nativeTranscript(records,false),prefs,new Map([['turn:1',true]]));
    assert.equal(open.filter(x=>x.role==='process').length,2);
    assert.equal(open.find(x=>x.role==='process').flat,mode==='verbose');
    assert.equal(open.find(x=>x.role==='process').preview,true);
    assert.ok(open.filter(x=>x.role==='process').every(x=>x.groupedProcess));
  }
  for(const mode of ['compact','standard','detailed','verbose']) {
    const thoughtPrefs=Object.assign(new preferences.NativeChatPreferences(),{mode});
    const thought=nativePresentTranscript(nativeTranscript(records,false),thoughtPrefs,new Map())
      .find(x=>x.role==='process'&&x.children.some(y=>y.role==='reasoning'));
    const tool=nativePresentTranscript(nativeTranscript(records,false),thoughtPrefs,new Map())
      .find(x=>x.role==='process'&&x.children.some(y=>y.role==='tool'));
    const reasoning=thought.children.find(x=>x.role==='reasoning');
    const operation=tool.children.find(x=>x.role==='tool');
    assert.equal(thought.label,'工作过程');
    assert.equal(tool.label,'工作过程');
    assert.equal(reasoning.label,'思考过程',`${mode} reasoning keeps a separate activity lead`);
    assert.equal(reasoning.detail,'Thought more',`${mode} reasoning keeps its flattened single-line preview`);
    assert.equal(reasoning.detail.includes('\n'),false,`${mode} reasoning preview has one line`);
    assert.equal(operation.label,'已读取文件',`${mode} tool keeps a separate activity lead`);
    assert.equal(operation.detail,'src/app.ts',`${mode} tool keeps its operation preview`);
  }
  const prefs=Object.assign(new preferences.NativeChatPreferences(),{collapseTiming:'next-input',foldedReplies:'final'});
  assert.equal(nativePresentTranscript(nativeTranscript(records,false),prefs,new Map()).filter(x=>x.role==='process').length,2);
  const collapsed=nativePresentTranscript(nativeTranscript(records,false),prefs,new Map(),6);
  assert.equal(collapsed.some(x=>x.id==='intermediate'),false);assert.equal(collapsed.some(x=>x.id==='answer'),true);
  const live=nativePresentTranscript(nativeTranscript(records.slice(0,-1),true),prefs,new Map());
  assert.equal(live.find(x=>x.role==='process').flat,true);
  const activeRecords = records.concat([
    message('human-next','user',7,{turn:2,sourceKind:'user',text:'next'}),
    message('tool-next','tool',8,{turn:2,phase:'start',callId:'next',toolName:'read',
      text:'{"file_path":"src/next.ts"}'})
  ]);
  const active = nativePresentTranscript(nativeTranscript(activeRecords,true),
    Object.assign(new preferences.NativeChatPreferences(),{mode:'standard'}),new Map());
  const activeGroups = active.filter(x=>x.role==='process');
  assert.equal(activeGroups.length,3);
  assert.equal(activeGroups.filter(x=>x.currentTurn).length,1);
  assert.equal(activeGroups.find(x=>x.currentTurn).turnKey,'turn:2');
  const ended = nativePresentTranscript(nativeTranscript(records,false),
    Object.assign(new preferences.NativeChatPreferences(),{mode:'standard'}),new Map());
  assert.equal(ended.filter(x=>x.role==='process').some(x=>x.currentTurn),false);
  assert.equal(nativeReasoningPreview('unfinished line',true),'unfinished line');
  assert.equal(nativeReasoningPreview('**First**\nmore\n\nSecond\nnot complete',true),
    'First more Second not complete');
  assert.equal(nativeReasoningPreview('**First**\nbody',false),'First body');
  const noAnswer=nativeTranscript(records.filter(x=>x.role!=='assistant'),false);
  assert.equal(noAnswer.some(x=>x.role==='turn-control'),false);
  assert.deepEqual(nativeTranscript(records,false).filter(x=>x.role==='process').map(x=>x.id),
    nativeTranscript(records,false).filter(x=>x.role==='process').map(x=>x.id),
    'operation disclosure identities remain stable across projections');
});

test('the journal retains hidden context and raw tool metadata without resurfacing it in Chat', () => {
  const {NativeSessionModel}=load('NativeSessionModel',{}), model=new NativeSessionModel();
  const frames=[
    {type:'event',event:{seq:1,type:'user/message',data:{source:{kind:'runtime'},content:[{type:'text',text:'injected context'}]}}},
    {type:'event',event:{seq:2,type:'tool/result',data:{meta:{path:'/workspace/a.ts',offset:1,lines:[]},message:{source:{callId:'read'},content:[{type:'text',text:'result'}]}}}}
  ];
  model.apply({type:'snapshot',cursor:2,...normalizedHistory(frames)});
  assert.equal(model.messages.some(x=>x.text==='injected context'),false);
  assert.equal(JSON.parse(model.journal.get(1)).data.source.kind,'runtime');
  assert.equal(JSON.parse(model.messages[0].metaRaw).path,'/workspace/a.ts');
  assert.equal(JSON.parse(model.messages[0].contentRaw)[0].text,'result');
});

test('native Chat groups contiguous operations and keeps nested PTC calls in a bounded summary tree', () => {
  const types = load('NativeSessionModel', {});
  const { nativeTranscript } = load('NativeTranscript', {'./NativeSessionModel':types});
  const event = (seq,type,data) => ({type:'event',event:{seq,time:1000+seq*100,type,data:{turn:1,step:1,...data}}});
  const history = normalizedHistory([
    event(0,'turn/start',{}),
    event(1,'user/message',{source:{kind:'user'},content:[{type:'text',text:'hello'}]}),
    event(2,'assistant/message',{message:{content:[{type:'reasoning',text:'think'},{type:'tool-call',id:'root',name:'run_code',arguments:'{}'}]}}),
    event(3,'tool/call',{callId:'root',name:'run_code',arguments:'{"code":"read()"}'}),
    event(4,'tool/ptc-dispatch-start',{rootCallId:'root',parentCallId:'root',subCallId:'child',name:'read',arguments:{file_path:'src/app.ts'}}),
    event(5,'tool/ptc-dispatch',{rootCallId:'root',parentCallId:'root',subCallId:'child',name:'read',content:[{type:'text',text:'source'}]}),
    event(6,'tool/result',{message:{source:{callId:'root'},content:[{type:'text',text:'done'}]}}),
    event(7,'assistant/message',{message:{content:[{type:'text',text:'progress'}]}}),
    event(8,'tool/call',{step:2,callId:'shell',name:'exec_command',arguments:'{"cmd":"echo ok"}'}),
    event(9,'tool/result',{step:2,message:{source:{callId:'shell'},content:[{type:'text',text:'ok'}]}}),
    event(10,'assistant/message',{step:2,message:{content:[{type:'text',text:'answer'}]}}),
    event(11,'turn/end',{reason:{kind:'completed'}})
  ]);
  const rows = nativeTranscript(history.messages,false);
  const groups = rows.filter(x=>x.role==='process');
  assert.equal(groups.length,2,JSON.stringify(rows.map(x=>({id:x.id,role:x.role,turn:x.turnKey,children:x.children.map(y=>y.id)}))));
  const rootGroup=groups.find(x=>x.children.some(y=>y.callId==='root'));
  const root=rootGroup.children.find(x=>x.role==='tool');
  assert.equal(root.toolName,'run_code'); assert.equal(root.status,'success');
  assert.equal(root.args,'{"code":"read()"}'); assert.equal(root.output,'done');
  assert.equal(root.children.length,1); assert.equal(root.children[0].toolName,'read');
  assert.equal(root.children[0].output,'source');
  assert.equal(groups.filter(x=>x.children.some(y=>y.role==='reasoning')).length,1);
  assert.equal(rows.filter(x=>x.role==='turn-control').length,0);
  assert.ok(groups.every(x=>x.foldable===false&&x.groupedProcess));
  assert.equal(groups.map(x=>x.id).join(','),'process:event-2:part:0,process:call:shell');
  assert.equal(nativeTranscript(history.messages,false).filter(x=>x.role==='process').map(x=>x.id).join(','),
    groups.map(x=>x.id).join(','));
  assert.equal(rows.filter(x=>x.role==='assistant').map(x=>x.text).join(','),'progress,answer');
  assert.equal(rows.filter(x=>x.role==='turn-footer').length,1);
  const mixed=nativeTranscript(normalizedHistory([
    event(12,'assistant/message',{message:{content:[{type:'text',text:'first'},{type:'reasoning',text:'thought'},{type:'text',text:'second'}]}})
  ]).messages,false);
  assert.equal(mixed.map(x=>x.role).join(','),'assistant,process,assistant','finalized assistant blocks retain their source order');
});

test('process operations receive unique stable render keys and preview content loads eagerly', () => {
  const types = load('NativeSessionModel', {});
  const { nativeTranscript } = load('NativeTranscript', {'./NativeSessionModel':types});
  const operation = (seq,callId) => Object.assign(new types.NativeMessage(), {
    id:'repeated-id', seq, role:'tool', turn:1, step:1, callId, toolName:'todo_write',
    phase:'start', text:'{"todos":[]}'
  });
  const base = [
    Object.assign(new types.NativeMessage(), {id:'user',seq:0,role:'user',turn:1,step:1,text:'plan'}),
    operation(1,'plan-a'),
    operation(2,'plan-b')
  ];
  const before = nativeTranscript(base,true).find(row=>row.role==='process');
  assert.equal(before.children.length,2);
  assert.equal(new Set(before.children.map(row=>row.renderKey)).size,2);
  assert.ok(before.children.every(row=>row.renderKey.startsWith(before.id + ':')));
  const after = nativeTranscript(base.concat(operation(3,'plan-c')),true).find(row=>row.role==='process');
  assert.deepEqual(Array.from(after.children.slice(0,2),row=>row.renderKey),
    Array.from(before.children,row=>row.renderKey),
    'appending another operation cannot move an existing disclosure');

  const processSource=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeProcessView.ets', import.meta.url),'utf8');
  assert.match(processSource,/child\.renderKey \|\| child\.id/);
  const sourceModel=readFileSync(new URL('../../harmony/entry/src/main/ets/services/NativeListSource.ets', import.meta.url),'utf8');
  assert.match(sourceModel,/base \+ '#' \+ occurrence/);

  const previewSource=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeFilePreview.ets', import.meta.url),'utf8');
  const loadBody=previewSource.slice(previewSource.indexOf('private async load('),previewSource.indexOf('private async loadMetadata('));
  assert.match(loadBody,/this\.loadMetadata\(generation\)/);
  assert.match(loadBody,/loadImageWithRetry\(generation, false\)/);
  assert.doesNotMatch(loadBody,/await this\.client\.statFile/);
  assert.match(previewSource,/setTimeout\(resolve, 120\)/);
  const clientSource=readFileSync(new URL('../../harmony/entry/src/main/ets/services/NativeHarnessClient.ets', import.meta.url),'utf8');
  assert.match(clientSource,/private fileStats: Map<string, Promise<NativeFileStat>>/);
  const byteBody=clientSource.slice(clientSource.indexOf('async readFileBytes('),clientSource.indexOf('async uploadAttachment('));
  assert.match(byteBody,/if \(!resolvedVersion\) \{[\s\S]{0,160}this\.statFile\(id, path\)/);
  assert.match(byteBody,/nativeFileWindowMetadata\(resolvedVersion, resolvedBytes/);

  const listKeys=(length)=>Array.from({length},(_,index)=>'same'+(index===1?'#1':''));
  assert.deepEqual(listKeys(2),['same','same#1'],
    'duplicate caller keys receive the same deterministic suffix used by NativeListSource');
});

test('live process and terminal file-card motion contracts stay bounded', () => {
  const processSource=readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeProcessView.ets', import.meta.url),'utf8');
  const resolveBody=processSource.slice(processSource.indexOf('private resolveExpanded('),
    processSource.indexOf('private toggle()'));
  assert.ok(resolveBody.indexOf('this.disclosures.has(key)') <
    resolveBody.indexOf('return this.message.currentTurn'));
  assert.match(processSource,/this\.currentTurnApplied !== this\.message\.currentTurn/);

  const card=readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeTurnChangesView.ets', import.meta.url),'utf8');
  const toggle=card.slice(card.indexOf('private toggle()'),card.indexOf('private shownFiles()'));
  assert.ok(toggle.indexOf('this.expanded = !this.expanded') <
    toggle.indexOf('this.onExpandedChange(this.expanded)'));

  const workspace=readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeWorkspace.ets', import.meta.url),'utf8');
  assert.match(workspace,/terminalCardNearBottom\(message: NativeMessage\)/);
  assert.match(workspace,/scrollEdge\(Edge\.Bottom, \{ velocity: 5200 \}\)/);
  assert.match(workspace,/frame\.type === 'delta' \? \(this\.scrollMotionActive \? 64 : 32\) : 0/);
  assert.match(workspace,/nativeWithLiveText\(this\.transcriptBaseRows, this\.model\.streamText\)/);
  assert.match(workspace,/private streamTextPatchDirty: boolean = false/);
  assert.match(workspace,/if \(frame\.type === 'delta'\) \{[\s\S]{0,120}frame\.text\.length > 0/);
  assert.match(workspace,/!forceFull && this\.streamTextPatchDirty \?/);
  assert.match(workspace,/if \(tailOnlyTextUpdate\) \{[\s\S]{0,120}this\.source\.setTail\(visible, 2\)/);
  const titleFrame=workspace.indexOf("if (frame.type === 'title')");
  const modelApply=workspace.indexOf('this.model.apply(frame)',titleFrame);
  assert.ok(titleFrame >= 0 && modelApply > titleFrame);
  assert.match(workspace,/if \(typeof value !== 'string'\) return/);
  assert.match(workspace,/next\.blank = false/);
});

test('streaming scroll yields to direct manipulation and dock expansion shares one spring',()=>{
  const workspace=readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeWorkspace.ets',import.meta.url),'utf8');
  const dock=readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeBottomConversationDock.ets',import.meta.url),'utf8');
  const queue=readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeQueueDock.ets',import.meta.url),'utf8');

  assert.match(workspace,
    /frame\.type === 'delta' \? \(this\.scrollMotionActive \? 64 : 32\) : 0/);
  assert.match(workspace,
    /private scheduleTailScroll\(velocity: number = 0\): void \{[\s\S]{0,520}this\.tailScrollGuardUntil = Date\.now\(\) \+ 180;[\s\S]{0,260}this\.scroller\.scrollEdge/);
  assert.match(workspace,
    /private scheduleScrollMotionSettle\(\): void \{[\s\S]{0,320}this\.scrollMotionActive = false;[\s\S]{0,180}this\.paint\(\);[\s\S]{0,80}this\.updateScrollTail\(\)/);
  assert.match(workspace,/\.onScroll\(\(\) => \{ this\.markScrollActivity\(\); \}\)/);
  assert.match(workspace,
    /scrollMotionActive \|\| this\.scrollTailTimer >= 0\) return/);
  assert.doesNotMatch(workspace,
    /if \(this\.followTail && !this\.returningToBottom\) \{\s*setTimeout/);

  assert.match(dock,
    /\.transition\(TransitionEffect\.OPACITY\.animation\(\s*NativeMotion\.disclosureParam\(\)\)\)/);
  assert.match(dock,/\.animation\(NativeMotion\.disclosureParam\(\)\)/);
  assert.doesNotMatch(dock,/NativeMotion\.rowTransition\(\)/);
  assert.match(queue,/\.transition\(NativeMotion\.disclosureTransition\(\)\)/);
  assert.doesNotMatch(queue,/NativeMotion\.rowTransition\(\)/);
});

test('running activity uses latest still-running start time and exact upstream tool-name categories', () => {
  const types=load('NativeSessionModel',{});
  const {nativeTranscript,nativeProcessGroupPreview,nativeToolArgumentsVisible,nativeToolCategory,
    nativeToolDetail,nativeOneLinePreview,nativeToolOutputVisible,nativeProcessIcon}=load(
    'NativeTranscript',{'./NativeSessionModel':types});
  const rows=[
    {id:'a',seq:1,turn:1,step:1,role:'tool',callId:'a',toolName:'exec_command',phase:'start',time:10,text:'{"cmd":"test","description":"Run checks"}'},
    {id:'b',seq:2,turn:1,step:1,role:'tool',callId:'b',toolName:'read',phase:'start',time:20,text:'{"file_path":"src/app.ts"}'},
    {id:'c',seq:3,turn:1,step:1,role:'tool',callId:'b',phase:'result',time:30,text:'contents'}
  ];
  const group=nativeTranscript(rows,true)[0];
  assert.equal(group.label,'工作过程');
  assert.equal(group.groupedProcess,true);
  assert.equal(group.children.map(x=>x.label).join(','),'正在运行命令,已读取文件');
  assert.equal(group.detail,'执行 1 条命令 · 读取 1 个文件');
  const many = new types.NativeMessage();
  many.children = Array.from({length:11},(_,index)=>Object.assign(new types.NativeMessage(),{
    role:'tool', toolName:'read', status:'success', callId:'read-'+index,
    args:JSON.stringify({path:'src/file-'+index+'.ts'})
  }));
  assert.equal(nativeProcessGroupPreview(many),'读取 11 个文件');
  assert.equal(nativeToolCategory('functions.read'),'tools');
  assert.equal(nativeToolCategory('terminal_inspect'),'search');
  assert.equal(nativeToolCategory('subagent_codex'),'subagents');
  assert.equal(nativeToolCategory('job_output'),'job');
  assert.equal(nativeToolCategory('job_lifecycle'),'jobLifecycle');
  assert.equal(nativeToolCategory('slash_command'),'command');
  assert.equal(nativeProcessIcon('jobLifecycle'),'queue-outline');
  assert.equal(nativeProcessIcon('command'),'api-outline');
  assert.equal(nativeToolCategory('str_replace_editor'),'tools');
  assert.equal(nativeToolCategory('str_replace_editor',
    '{"command":"view","path":"src/app.ts"}'),'read');
  assert.equal(nativeToolCategory('str_replace_editor',
    '{"command":"create","path":"src/app.ts"}'),'write');
  assert.equal(nativeToolCategory('str_replace_editor',
    '{"command":"str_replace","path":"src/app.ts"}'),'edit');
  assert.equal(nativeToolCategory('str_replace_editor',
    '{"command":"insert","path":"src/app.ts"}'),'edit');
  assert.equal(nativeToolCategory('workflow'),'subagents');
  assert.equal(nativeToolCategory('skill'),'subagents');
  assert.equal(nativeToolDetail({args:'{"questions":[{"question":"Choose scope"}]}',phase:'start',toolName:'request_user_input'}),'Choose scope');
  assert.equal(nativeToolDetail({args:'{"command":"first\\nsecond"}',phase:'start',toolName:'exec_command'}),
    'first second');
  assert.equal(nativeOneLinePreview('abc\ndef',4),'abc…');
  const ended=nativeTranscript(rows.concat([{id:'end',seq:4,turn:1,step:1,role:'boundary'}]),true)[0];
  assert.equal(ended.children.find(x=>x.callId==='a').status,'interrupted');

  const imageAttachment=(id,name)=>({attachmentId:id,mediaType:'image/png',bytes:69,width:80,height:60,name});
  const imageHistory=normalizedHistory([
    {type:'event',event:{seq:10,time:40,type:'tool/call',data:{turn:2,step:1,callId:'images',
      name:'read_image',arguments:'{"file_path":"docs/preview.png"}'}}},
    {type:'event',event:{seq:11,time:50,type:'tool/result',data:{turn:2,step:1,
      message:{source:{callId:'images'},content:[
        {type:'text',text:'# Preview\n\n> authenticated image\n\n```ts\nconst width = 80;\n```'},
        {type:'image',attachment:imageAttachment('image-a','a.png')},
        {type:'image',attachment:imageAttachment('image-b','b.png')}
      ]}}}}
  ]);
  const imageTool=nativeTranscript(imageHistory.messages,false)[0].children
    .find(row=>row.callId==='images');
  assert.equal(nativeToolCategory(imageTool.toolName),'readImage');
  assert.equal(nativeToolArgumentsVisible(imageTool),false);
  assert.equal(nativeToolOutputVisible(imageTool),false);
  assert.deepEqual(Array.from(imageTool.images,x=>x.attachmentId),['image-a','image-b']);
  assert.deepEqual(Array.from(imageTool.blocks,x=>x.kind),['heading','quote','code']);
  assert.equal(imageTool.blocks[2].language,'ts');
});

test('interleaved human input keeps per-group disclosure rather than whole-turn folding', () => {
  const types=load('NativeSessionModel',{});
  const {nativeTranscript}=load('NativeTranscript',{'./NativeSessionModel':types});
  const rows=nativeTranscript([
    {id:'call',seq:1,turn:1,role:'tool',callId:'a',toolName:'read',phase:'start',text:'{}'},
    {id:'steer',seq:2,turn:1,role:'user',sourceKind:'user',text:'different scope'},
    {id:'answer',seq:3,turn:1,role:'assistant',text:'done'},
    {id:'end',seq:4,turn:1,role:'turn',eventType:'turn/end',outcome:'completed'}
  ],false);
  assert.equal(rows.some(x=>x.role==='turn-control'),false);
  assert.equal(rows.find(x=>x.role==='process').foldable,false);
  assert.equal(rows.find(x=>x.role==='process').groupedProcess,true);
});

test('streamed tool argument fragments settle once and never become assistant placeholder text', () => {
  const {NativeSessionModel}=load('NativeSessionModel',{});
  const model=new NativeSessionModel();
  model.apply({type:'snapshot',cursor:0,messages:[],attemptId:'a',nextIndex:0});
  for (const [offset,chunk] of [
    {type:'tool-call-delta',id:'call',name:'exec_command',argumentsDelta:'{"cmd":'},
    {type:'tool-call-delta',id:'call',argumentsDelta:'"echo ok"}'},
    {type:'block-end',block:{type:'tool-call',id:'call',name:'exec_command',arguments:'{"cmd":"echo ok"}'}}
  ].entries()) model.apply(normalizeFollow({type:'assistant-stream',frame:{type:'chunk',attemptId:'a',
    revision:offset + 1,index:offset,chunk}}));
  assert.equal(model.streamTools.length,1);
  assert.equal(model.streamTools[0].text,'{"cmd":"echo ok"}');
  assert.equal(model.streamText,'');
  model.apply({type:'end',attemptId:'a',revision:4,index:3,outcomeKind:'abandoned'});
  assert.equal(model.streamTools.length,0);
});

test('live stream timeline keeps reasoning above later tools and survives cache restore', () => {
  const types = load('NativeSessionModel', {});
  const { NativeSessionModel } = types;
  const model = new NativeSessionModel();
  model.apply({ type: 'snapshot', cursor: 1, messages: [], revision: 0, nextIndex: 0 });
  model.apply({ type: 'start', attemptId: 'attempt', revision: 1, nextIndex: 0,
    startedAfterSeq: 1, turn: 1, step: 1 });
  for (const [revision,index,chunk] of [
    [2,0,{type:'reasoning-delta',text:'先检查结构'}],
    [3,1,{type:'tool-call-delta',id:'call-read',name:'read',argumentsDelta:'{"path":"a.ts"}'}],
    [4,2,{type:'reasoning-delta',text:'再汇总结论'}],
  ]) {
    model.apply(normalizeFollow({ type:'assistant-stream', frame:{
      type:'chunk', attemptId:'attempt', revision, index, chunk
    }}));
  }
  assert.deepEqual(Array.from(model.streamParts, part => part.kind),
    ['reasoning', 'tool', 'reasoning']);
  assert.deepEqual(Array.from(model.streamParts.filter(part => part.kind === 'reasoning'),
    part => part.text), ['先检查结构', '再汇总结论']);

  const restored = new NativeSessionModel();
  restored.restore(JSON.parse(JSON.stringify(model.capture())));
  assert.deepEqual(Array.from(restored.streamParts, part => part.kind),
    ['reasoning', 'tool', 'reasoning']);

  const { nativeTranscript } = load('NativeTranscript', {'./NativeSessionModel': types});
  const rows = nativeTranscript(restored.messages, true, restored.streamTools,
    restored.streamReasoning, '', '', restored.streamParts);
  const process = rows.find(row => row.role === 'process');
  assert.deepEqual(Array.from(process.children, child => child.role),
    ['reasoning', 'tool', 'reasoning']);
  assert.equal(process.children[0].reasoning, '先检查结构');
  assert.equal(process.children[1].callId, 'call-read');
  assert.equal(process.children[2].reasoning, '再汇总结论');

  const legacyCache = JSON.parse(JSON.stringify(model.capture()));
  delete legacyCache.streamParts;
  const legacyRestored = new NativeSessionModel();
  legacyRestored.restore(legacyCache);
  assert.equal(legacyRestored.streamParts.length, 0);
  const legacyRows = nativeTranscript(legacyRestored.messages, true,
    legacyRestored.streamTools, legacyRestored.streamReasoning,
    legacyRestored.streamText, '', []);
  const legacyProcess = legacyRows.find(row => row.role === 'process');
  assert.deepEqual(Array.from(legacyProcess.children, child => child.role),
    ['tool', 'reasoning']);
  assert.equal(legacyProcess.children[0].callId, 'call-read');
});

test('native transport shares only gateway cookies, disables redirects and never retries prompts', async () => {
  const calls = [], configured = [];
  let code = 200, made = 0, streamBody = '{}';
  let cookie = Promise.resolve('other=hidden; pocket=' + 'a'.repeat(43));
  const socketCallbacks = new Map();
  const socket = { on: (event, callback) => socketCallbacks.set(event, callback), off: event => socketCallbacks.delete(event),
    connect: async (_url, options) => {
      assert.equal(options.supportOriginPort,true,'the Harmony stack must retain the gateway port in Origin');
      socketCallbacks.get('open')(null);
      return true;
    }, close: async () => true };
  const network = { http: { RequestMethod: { GET:'GET',POST:'POST' }, HttpDataType:{STRING:'string'}, createHttp:()=>({
    on(event, callback) { this[event] = callback; },
    async requestInStream(url, options) { calls.push({url,options}); const encoded = new TextEncoder().encode(streamBody); this.dataReceive(encoded.buffer); this.dataEnd(); return code; },
    async request(url, options) { calls.push({url,options}); return {responseCode:code,header:{'set-cookie':'pocket='+'b'.repeat(43)+'; Path=/; Secure; HttpOnly'},result:streamBody}; }, destroy(){} }) },
    webSocket:{createWebSocket:()=>{made++;return socket;}} };
  const {NativeHarnessClient}=load('NativeHarnessClient',{
    '@kit.NetworkKit':network,'@kit.ArkWeb':{webview:{WebCookieManager:{fetchCookie:()=>cookie,configCookie:async(...args)=>configured.push(args),saveCookieAsync:async()=>{}}}},
    '@kit.ArkTS':{util:{generateRandomUUID:()=> 'request-id',TextDecoder:{create:()=>({decodeToString: buffer => new TextDecoder().decode(buffer)})},TextEncoder:{create:()=>({encodeInto:value=>new TextEncoder().encode(value)})}}},
    '@kit.BasicServicesKit':{},'@kit.CryptoArchitectureKit':{cryptoFramework:{createMd:()=>({update:async()=>{},digest:async()=>({data:new Uint8Array(32)})})}},'./NativeSessionModel':{}
  });
  const client=new NativeHarnessClient('https://dsh.example.com');
  await client.request('/pocket/api/state');
  assert.equal(calls[0].options.header.Cookie,'pocket='+'a'.repeat(43));
  assert.equal(calls[0].options.maxRedirects,0);
  assert.equal(calls[0].options.extraData,undefined);
  assert.equal(configured.length,0,'ordinary responses must not overwrite the shared login cookie');
  streamBody = JSON.stringify({ type: 'page', messages: [], hasMore: false });
  const beforePages = calls.length;
  await Promise.all([client.page('session-a', 42, 84), client.page('session-a', 42, 84)]);
  assert.equal(calls.length, beforePages + 1, 'identical in-flight history pages must be coalesced');
  streamBody = '{}';
  await client.request('/pocket/api/auth/none','POST','{}');
  assert.equal(configured[0][2],false);assert.equal(configured[0][3],true);
  streamBody = JSON.stringify({text:'完整😀'.repeat(400000)});
  assert.equal(await client.operation('{}'),streamBody,'native HTTP must not clip responses above the old 2MB ceiling');
  streamBody = '{}';
  code=502;
  const before=calls.length;
  await assert.rejects(()=>client.prompt('session','hello'));
  assert.equal(calls.length,before+1,'a failed prompt must never be automatically replayed');
  assert.equal(client.uncertain.has('session'),true);
  code=401;
  await assert.rejects(()=>client.prompt('session','hello'));
  assert.equal(client.uncertain.has('session'),false,'a gateway authentication rejection never admitted the prompt');
  await assert.rejects(()=>client.request('/pocket/api/../../other'));
  code=200;
  streamBody=JSON.stringify({ok:true,value:{receiptId:'receipt-one',file:{attachmentId:'a',name:'note.txt',bytes:4}}});
  const uploaded=await client.uploadAttachment('session','note.txt',new Uint8Array([1,2,3,4]));
  assert.equal(uploaded.receiptId,'receipt-one');
  assert.match(calls.at(-1).url,/\/pocket\/api\/native\/upload\?sessionId=session&name=note\.txt$/);
  assert.ok(calls.at(-1).options.extraData instanceof ArrayBuffer);
  assert.equal(calls.at(-1).options.header['Content-Length'],'4');
  assert.equal(calls.at(-1).options.readTimeout,45000);
  streamBody='{}';
  const {NativeAttachmentDraft}=load('NativeHarnessClient',{
    '@kit.NetworkKit':network,'@kit.ArkWeb':{webview:{WebCookieManager:{fetchCookie:()=>cookie,configCookie:async()=>{},saveCookieAsync:async()=>{}}}},
    '@kit.ArkTS':{util:{generateRandomUUID:()=> 'request-id',TextDecoder:{create:()=>({decodeToString: buffer => new TextDecoder().decode(buffer)})},TextEncoder:{create:()=>({encodeInto:value=>new TextEncoder().encode(value)})}}},
    '@kit.BasicServicesKit':{},'@kit.CryptoArchitectureKit':{cryptoFramework:{createMd:()=>({update:async()=>{},digest:async()=>({data:new Uint8Array(32)})})}},'./NativeSessionModel':{}
  });
  const ready=new NativeAttachmentDraft();ready.status='ready';ready.receiptId='receipt-one';
  const uploading=new NativeAttachmentDraft();uploading.status='uploading';
  const explicitRequestId=await client.prompt(
    'session','hello','queue',[ready,uploading],'request-explicit');
  assert.equal(explicitRequestId,'request-explicit',
    'the caller-owned request id must survive the transport round trip');
  const prompt=JSON.parse(calls.at(-1).options.extraData);
  assert.equal(prompt.requestId,'request-explicit');
  assert.deepEqual(prompt.attachments,[{type:'file',receiptId:'receipt-one'}],
    'only ready receipts may reach prompt content');
  let release;
  cookie=new Promise(resolve=>{release=resolve;});
  const pending=client.follow('session',()=>{},()=>{});
  client.pause();release('pocket='+'a'.repeat(43));await pending;
  assert.equal(made,0,'paused generation must not create a late socket');
  cookie=Promise.resolve('pocket='+'a'.repeat(43));
  let delivered=0;
  await client.follow('session',()=>{delivered++;},()=>{});
  const old=socketCallbacks.get('message');
  client.pause();old(null,JSON.stringify({type:'state',running:true}));
  assert.equal(delivered,0,'retired socket callbacks must not update the new interface');
});

test('composer source contract uses intrinsic model width, natural dock height and native image/file actions', () => {
  const source=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeWorkspace.ets', import.meta.url),'utf8');
  const modelSource=readFileSync(new URL('../../harmony/entry/src/main/ets/services/NativeSessionModel.ets', import.meta.url),'utf8');
  const clientSource=readFileSync(new URL('../../harmony/entry/src/main/ets/services/NativeHarnessClient.ets', import.meta.url),'utf8');
  assert.match(source,/enableArrow:\s*false/);
  assert.doesNotMatch(source,/Text\(this\.modelCaption\)[^\n]*layoutWeight\(1\)/);
  assert.match(source,/accessibilityText\(this\.attaching \? '读取中' : '添加图片'\)/);
  assert.match(source,/accessibilityText\('添加文件'\)[\s\S]{0,180}onClick\(\(\)\s*=>\s*\{\s*this\.attachFiles\(\);/);
  assert.doesNotMatch(source,/accessibilityText\('更多附件'\)\s*[\s\S]{0,120}\.onClick\(this\.onCompatibility\)/);
  assert.match(source,/symbol|glyph: 'image-outline'/);
  assert.match(source,/glyph: 'file-outline'/);
  assert.match(clientSource,/requestInStream\(this\.origin \+ '\/pocket\/api\/native\/upload'/);
  assert.match(source,/this\.attaching = false;[\s\S]{0,180}added\.forEach/);
  assert.match(source,/NativeBottomConversationDock\(\{/);
  assert.doesNotMatch(source,/translate\(\{ y: -\(this\.composerHeight \+ 8\) \}\)/);
  const liveChange = source.indexOf('NativeTurnChangePill({');
  const queue = source.indexOf('NativeQueueDock({');
  assert.ok(liveChange >= 0 && queue > liveChange,
    'the current turn state must remain above queued input');
  assert.match(source,/if \(this\.attachments\.length\)[\s\S]{0,260}NativeAttachmentDraft/);
  assert.doesNotMatch(source,/if \(this\.attachments\.length\) \{\s*Scroll\(\)/);
  assert.match(source,/nativeStreamHealthRepairReason/);
  assert.match(source,/backgrounded,[\s\S]{0,120}this\.followStateKnown/);
  assert.match(modelSource,/opened \? \(backgrounded \? 45000 : 15000\) : \(backgrounded \? 45000 : 20000\)/);
  assert.match(clientSource,/profile=background/);
});

test('lightbox zoom keeps translation and does not treat drag release as a background tap', () => {
  const source=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeImageLightbox.ets', import.meta.url),'utf8');
  assert.match(source,/\.onTouch\(\(event: TouchEvent\): void => \{ this\.handleTouch\(event\); \}\)/);
  assert.match(source,/this\.pinchStartZoom \* distance \/ this\.pinchStartDistance/);
  assert.match(source,/this\.offsetX \+ dx/);
  assert.match(source,/\.translate\(\{ x: this\.offsetX, y: this\.offsetY \}\)/);
  assert.match(source,/Date\.now\(\) < this\.suppressClickUntil/);
  assert.match(source,/this\.touchMode === 'pinch' \|\| Date\.now\(\) - this\.lastPinchEndedAt < 450/);
  assert.match(source,/NativeImageZoom\.doubleTap\(/);
  assert.match(source,/this\.toggleDoubleTapZoom\(this\.touchStartX, this\.touchStartY\)/);
  assert.match(source,/NativeMotion\.spring\(this\.getUIContext\(\)/);
  assert.doesNotMatch(source,/Scroll\(\) \{[\s\S]{0,500}Image\(this\.bitmap\)/);
});

test('workspace image preview uses the same retained pinch and pan interaction', () => {
  const source=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeFilePreview.ets', import.meta.url),'utf8');
  assert.match(source,/\.onTouch\(\(event: TouchEvent\): void => \{ this\.handleImageTouch\(event\); \}\)/);
  assert.match(source,/this\.pinchStartZoom \* distance \/ this\.pinchStartDistance/);
  assert.match(source,/this\.offsetX \+ dx/);
  assert.match(source,/\.translate\(\{ x: this\.offsetX, y: this\.offsetY \}\)/);
  assert.match(source,/this\.touchMode === 'pinch' \|\| Date\.now\(\) - this\.lastPinchEndedAt < 450/);
  assert.match(source,/NativeImageZoom\.doubleTap\(/);
  assert.match(source,/this\.toggleImageDoubleTapZoom\(this\.touchStartX, this\.touchStartY\)/);
  assert.match(source,/NativeMotion\.spring\(this\.getUIContext\(\)/);
  assert.doesNotMatch(source,/Scroll\(\) \{[\s\S]{0,500}Image\(this\.imageMap\)/);
});

test('DSH settings source consumes and displays the connected plugin version', () => {
  const settings=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeSettings.ets', import.meta.url),'utf8');
  const client=readFileSync(new URL('../../harmony/entry/src/main/ets/services/NativeHarnessClient.ets', import.meta.url),'utf8');
  const plugin=readFileSync(new URL('../../plugins/dsh-harmony/index.mjs', import.meta.url),'utf8');
  assert.match(client,/pluginVersion: string = ''/);
  assert.match(settings,/this\.pluginVersion = state\.pluginVersion/);
  assert.match(settings,/Text\('插件版本'\)/);
  assert.match(settings,/this\.pluginVersion \? 'v' \+ this\.pluginVersion : '未报告'/);
  assert.match(plugin,/createRequire\(import\.meta\.url\)\('\.\/package\.json'\)\.version/);
});

test('UI mode is native-only and repairs legacy compatibility preferences once', () => {
  const { UiModePreference } = load('UiModePreference', {});
  const fresh = UiModePreference.resolve('', false);
  assert.equal(fresh.mode, 'native');
  assert.equal(fresh.shouldMigrate, true);
  assert.equal(fresh.shouldPersist, true);

  const legacyDefault = UiModePreference.resolve('compatibility', false);
  assert.equal(legacyDefault.mode, 'native');
  assert.equal(legacyDefault.shouldMigrate, true);

  const migratedCompatibility = UiModePreference.resolve('compatibility', true);
  assert.equal(migratedCompatibility.mode, 'native');
  assert.equal(migratedCompatibility.shouldMigrate, false);
  assert.equal(migratedCompatibility.shouldPersist, true);

  const migratedNative = UiModePreference.resolve('native', true);
  assert.equal(migratedNative.mode, 'native');
  assert.equal(migratedNative.shouldPersist, false);

  const invalid = UiModePreference.resolve('web', true);
  assert.equal(invalid.mode, 'native');
  assert.equal(invalid.shouldPersist, true);

  const index = readFileSync(new URL('../../harmony/entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
  const bridge = readFileSync(new URL('../../harmony/entry/src/main/ets/services/PocketBridge.ets', import.meta.url), 'utf8');
  const settings = readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeSettings.ets', import.meta.url), 'utf8');
  assert.match(index, /@StorageLink\('uiMode'\) @Watch\('modeChanged'\) private uiMode: string = 'native'/);
  assert.match(index, /UiModePreference\.resolve\(savedMode/);
  assert.match(index, /UiModePreference\.MIGRATED_KEY, false\) === true/);
  assert.doesNotMatch(index, /getSync\('uiMode',\s*'compatibility'\)/);
  assert.doesNotMatch(index, /兼容模式|private modeSheet|modePicker/);
  assert.doesNotMatch(settings, /界面模式|原生或兼容网页/);
  assert.match(bridge, /AppStorage\.get<string>\('uiMode'\) \|\| 'native'/);
});

test('UI mode bridge accepts native only and JavaScript cannot switch it from another origin', async () => {
  const {preferences,disk}=storage();
  const state=new Map();
  const AppStorage={get:key=>state.get(key),setOrCreate:(key,value)=>state.set(key,value)};
  const original=preferences.getPreferencesSync;
  preferences.getPreferencesSync=(...args)=>({...original(...args),flush:async()=>{}});
  const {PocketBridge}=load('PocketBridge',{
    '@kit.AbilityKit':{},'@kit.ArkWeb':{},'@kit.NotificationKit':{},'@kit.PushKit':{},
    '@kit.ArkData':{preferences},'@kit.ArkTS':{util:{generateRandomUUID:()=> 'device-id'}},
    './WindowAppearance':{WindowAppearance:{}},'./NativeExperience':{NativeExperience:{state:()=> '{}'}},
    './WidgetStore':{WidgetStore:{detailsEnabled:()=>false}},
    'entry/PushKitAdapter':{PushKitAdapter:{supported:false}},
    './BackgroundMonitor':{BackgroundMonitor:{}}
  },{AppStorage});
  const controller={getLastJavascriptProxyCallingFrameUrl:()=> 'https://other.example.com/',getUrl:()=> 'https://dsh.example.com/',runJavaScript:async()=>{}};
  const bridge=new PocketBridge(context,controller,'https://dsh.example.com',async()=>{});
  await bridge.performNative('uiMode','native');
  assert.equal(state.get('uiMode'),'native');assert.equal(disk.get('dsh-pocket').get('uiMode'),'native');
  await assert.rejects(()=>bridge.performNative('uiMode','compatibility'));
  await assert.rejects(()=>bridge.performNative('uiMode','unknown'));
  bridge.request('request','uiMode','native');
  await Promise.resolve();assert.equal(state.get('uiMode'),'native');
  await bridge.performNative('themeMode','dark');assert.equal(state.get('nativeThemeMode'),'dark');
});

test('local notification tiers migrate legacy booleans and preserve off/quiet/standard filtering', async () => {
  const {preferences,disk}=storage();
  const state=new Map();
  const AppStorage={get:key=>state.get(key),setOrCreate:(key,value)=>state.set(key,value)};
  const original=preferences.getPreferencesSync;
  preferences.getPreferencesSync=(...args)=>({...original(...args),flush:async()=>{}});
  const delivered=[];
  const notificationManager={requestEnableNotification:async()=>{},
    isNotificationEnabled:async()=>true,ContentType:{NOTIFICATION_CONTENT_BASIC_TEXT:0}};
  const {PocketBridge}=load('PocketBridge',{
    '@kit.AbilityKit':{},'@kit.ArkWeb':{},'@kit.NotificationKit':{notificationManager},
    '@kit.ArkData':{preferences},'@kit.ArkTS':{util:{generateRandomUUID:()=> 'device-id'}},
    './WindowAppearance':{WindowAppearance:{}},'./NativeExperience':{NativeExperience:{state:()=> '{}'}},
    './WidgetStore':{WidgetStore:{detailsEnabled:()=>true}},
    'entry/PushKitAdapter':{PushKitAdapter:{supported:false}},
    './BackgroundMonitor':{BackgroundMonitor:{
      notificationId:(session,kind)=>session.length + kind.length,
      notify:async(session,title,body,id,level)=>delivered.push({session,title,body,id,level})
    }}
  },{AppStorage});
  const bridge=new PocketBridge(context,{},'https://dsh.example.com',async()=>{});
  disk.set('dsh-notifications',new Map([['levels',JSON.stringify({completed:false,failed:true,approval:false})]]));
  const saved=JSON.parse(await bridge.performNative('nativeState',''));
  assert.equal(saved.notifyCompleted,'off');
  assert.equal(saved.notifyFailed,'standard');
  assert.equal(saved.notifyApproval,'off');
  await bridge.performNative('backgroundMonitor','true');
  await assert.rejects(()=>bridge.performNative('notificationLevels',
    JSON.stringify({completed:'loud',failed:'standard',approval:'standard',connection:'off'})));
  assert.equal(delivered.length,0);
  await bridge.performNative('notificationLevels',
    JSON.stringify({version:1,completed:'quiet',failed:'standard',approval:'off',connection:'standard'}));
  await bridge.performNative('publishLocalNotification',
    JSON.stringify({sessionId:'session-a',title:'Task',state:'completed'}));
  await bridge.performNative('publishLocalNotification',
    JSON.stringify({sessionId:'session-a',title:'Task',state:'waiting'}));
  await bridge.performNative('publishLocalNotification',
    JSON.stringify({sessionId:'session-a',title:'Task',state:'connection'}));
  assert.deepEqual(delivered.map(item=>item.level),['quiet','standard']);
  assert.deepEqual(delivered.map(item=>item.body),['任务已完成','服务连接中断']);
});

test('native history grows past former limits and retains older pages on reconnect', () => {
  const { NativeSessionModel } = load('NativeSessionModel', {});
  const model = new NativeSessionModel();
  const rows = Array.from({length:2000}, (_,seq)=>({seq,id:'event-'+seq,text:'row '+seq}));
  model.apply({type:'snapshot',cursor:1999,beforeSeq:1000,messages:rows.slice(1000),hasMore:true});
  model.prepend({messages:rows.slice(0,1000),beforeSeq:0,hasMore:false});
  model.apply({type:'event',seq:2000,message:{id:'event-2000',seq:2000,text:'new'}});
  assert.equal(model.messages.length,2001);
  model.apply({type:'snapshot',cursor:2000,beforeSeq:1900,messages:model.messages.slice(1900),hasMore:true,replacements:[]});
  assert.equal(model.messages.length,2001);
  assert.equal(model.hasMore,false);
  assert.equal(model.historyBefore,0);
  model.apply({type:'start',attemptId:'a',revision:1});
  model.apply({type:'delta',attemptId:'a',revision:2,index:0,text:'😀'.repeat(100000),reasoning:'思考'.repeat(100000)});
  assert.equal(model.streamText.length,200000);
  assert.equal(model.streamReasoning.length,200000);
});

test('history prefetch keeps retrying with bounded backoff and rejects no-progress pages', () => {
  const { NativeHistoryRetryPolicy, nativeHistoryPageAdvanced } =
    load('NativeHistoryPrefetch', {});
  const retry = new NativeHistoryRetryPolicy();
  assert.deepEqual(Array.from({length:8},()=>retry.nextDelay()),[600,1200,2400,4800,8000,8000,8000,8000]);
  retry.succeed();
  assert.equal(retry.failureCount(),0);
  assert.equal(retry.nextDelay(),600);
  assert.equal(nativeHistoryPageAdvanced(100,90,20,32,true),true);
  assert.equal(nativeHistoryPageAdvanced(100,100,20,20,true),false);
  assert.equal(nativeHistoryPageAdvanced(100,100,20,20,false),true);
});

test('workspace history drain autocancels stale work and restarts after live recovery', () => {
  const source=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeWorkspace.ets', import.meta.url),'utf8');
  assert.match(source,/frame\.type === 'snapshot'[\s\S]{0,500}startHistoryDrain\(true\)/);
  assert.match(source,/private select\(id: string/);
  assert.match(source,/this\.stopHistoryDrain\(\)/);
  assert.match(source,/private scheduleReconnect\(id: string\): void \{[\s\S]{0,150}this\.pauseHistoryDrain\(\)/);
  assert.match(source,/await this\.older\(true\)[\s\S]{0,1200}this\.historyRetry\.nextDelay\(\)/);
  assert.match(source,/nativeHistoryPageAdvanced\(historyBefore/);
});

test('first native navigation gates launch dismissal on restored workspace readiness', () => {
  const index=readFileSync(new URL('../../harmony/entry/src/main/ets/pages/Index.ets', import.meta.url),'utf8');
  const workspace=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeWorkspace.ets', import.meta.url),'utf8');
  assert.match(index,/NativeWorkspace\(\{[\s\S]{0,1800}onWorkspaceReady: \(\): void => \{ this\.finishLaunch\(\); \}/);
  assert.match(index,/this\.uiMode === 'native' && !this\.authSurface &&[\s\S]{0,120}this\.launchPhase === NativeLaunchPhase\.restoring/);
  assert.match(index,/this\.uiMode !== 'native' \|\| this\.authSurface[\s\S]{0,80}this\.finishLaunch\(\)/);
  assert.match(workspace,/onWorkspaceReady: \(\) => void/);
  assert.match(workspace,/this\.requestedSession \|\|[\s\S]{0,260}NativeTranscriptCache\.loadRoute[\s\S]{0,900}if \(!this\.selected\) this\.openDrawer\(false\)[\s\S]{0,260}this\.notifyWorkspaceReady\(generation\)/);
  assert.match(workspace,/private notifyWorkspaceReady[\s\S]{0,700}generation === this\.generation[\s\S]{0,500}NativeStorageManager\.enforceDefaultLimit[\s\S]{0,180}this\.onWorkspaceReady\(\)/);
});

test('encrypted transcript persistence splits large JSON without cutting surrogate pairs', () => {
  const kits={'@kit.AbilityKit':{},'@kit.ArkData':{relationalStore:{SecurityLevel:{S3:1}}}};
  const { nativeTranscriptChunks, nativeCodePointLength } = load('NativeTranscriptCache',kits);
  const payload='a'.repeat(2047)+'😀'+'正文'.repeat(200000);
  assert.equal(nativeCodePointLength('a😀正文'),4);
  assert.equal(nativeCodePointLength('a😀正文'),Array.from('a😀正文').length);
  const chunks=nativeTranscriptChunks(payload,2048);
  assert.equal(chunks.join(''),payload);
  assert.ok(chunks.every(part=>part.length<=2048));
  assert.ok(chunks.every(part=>{
    const end=part.charCodeAt(part.length-1);
    const start=part.charCodeAt(0);
    return !(end>=0xD800&&end<=0xDBFF)&&!(start>=0xDC00&&start<=0xDFFF);
  }));
  const source=readFileSync(new URL('../../harmony/entry/src/main/ets/services/NativeTranscriptCache.ets', import.meta.url),'utf8');
  assert.match(source,/CREATE TABLE IF NOT EXISTS transcript_chunk/);
  assert.match(source,/ORDER BY chunk_index ASC/);
  assert.match(source,/SELECT substr\(payload,\?,\?\) FROM transcript_cache/);
  assert.match(source,/NativeTranscriptCache\.saveSession\(context, scope, sessionId, restored\)/);
  const loadBody=source.slice(source.indexOf('static async loadSession'),source.indexOf('static clearSession'));
  assert.doesNotMatch(loadBody,/clearSession\(/);
});

test('user message copy is a long-press action and does not add a footer row', () => {
  const source=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeMessageView.ets', import.meta.url),'utf8');
  assert.match(source,/LongPressGesture\(\{ repeat: false \}\)/);
  assert.match(source,/if \(this\.hasCopyableText\(\)\) this\.copyMessage\(\)/);
  assert.match(source,/this\.message\.role === 'user' && \(!!this\.message\.text \|\| this\.message\.blocks\.length > 0\)/);
  assert.doesNotMatch(source,/if \(this\.message\.role === 'user' && this\.message\.text\) \{\s*Row\(\)/);
});

test('sent-image lightbox exposes the shared download and close actions', () => {
  const source=readFileSync(new URL('../../harmony/entry/src/main/ets/components/NativeImageLightbox.ets', import.meta.url),'utf8');
  assert.match(source,/glyph: 'download-outline'[\s\S]{0,240}accessibilityText\('下载图片'\)[\s\S]{0,80}saveToGallery\(\)/);
  assert.match(source,/DSHIcon\(\{ glyph: 'close-outline',[\s\S]{0,260}accessibilityText\('关闭图片预览'\)/);
});

test('virtual native text windows reconstruct complete Unicode without splitting surrogate pairs', () => {
  const { NativeTextSource } = load('NativeTextSource', {});
  const { nativeSecretSpans } = load('NativeSecretMask', {});
  const source = new NativeTextSource();
  const text = 'x'.repeat(4095) + '😀' + '正文😀'.repeat(100000);
  const token = ['sk-', 'demo', '0123456789ABCDEFGHIJ'].join('');
  const withSecret = 'x'.repeat(4087) + ' ' + token + text;
  source.set(withSecret, nativeSecretSpans(withSecret));
  const parts = Array.from({length:source.totalCount()}, (_,index)=>source.getData(index));
  assert.equal(parts.join(''),withSecret);
  assert.ok(parts.some(part=>part.includes(token)),
    'a protected credential must not straddle render windows');
  assert.ok(parts.every(part=>!/^\p{Surrogate}/u.test(part)&&!/\p{Surrogate}$/u.test(part)));
});
test('older pages cannot resurrect history removed by a newer replacement', () => {
  const { NativeSessionModel } = load('NativeSessionModel', {});
  const model = new NativeSessionModel();
  model.apply({type:'snapshot',cursor:100,beforeSeq:90,messages:[{seq:100,id:'event-100',text:'replacement'}],hasMore:true,replacements:[{start:1,end:50}]});
  model.prepend({messages:[{seq:1,id:'event-1',text:'removed'},{seq:51,id:'event-51',text:'kept'}],beforeSeq:1,hasMore:false});
  assert.deepEqual(Array.from(model.messages,row=>row.seq),[51,100]);
});

test('encrypted transcript snapshots restore messages, replacement state and stream checkpoints', () => {
  const { NativeSessionModel } = load('NativeSessionModel', {});
  const model = new NativeSessionModel();
  model.apply({
    type: 'snapshot', cursor: 10, historyCut: 10, beforeSeq: 5, hasMore: true,
    messages: [{ seq: 6, id: 'six', role: 'assistant', text: 'cached' }],
    replacements: [{ start: 1, end: 2 }],
    attemptId: 'attempt', nextIndex: 2, text: 'partial', reasoning: 'plan'
  });
  model.expandedTurns.add('turn:1');
  model.turnDisclosure.set('turn:1', true);
  model.disclosures.set('turn:1|call:1', true);
  model.collapseThrough = 9;
  const restored = new NativeSessionModel();
  restored.restore(JSON.parse(JSON.stringify(model.capture())));
  assert.deepEqual(Array.from(restored.messages, row => row.id), ['six']);
  assert.equal(restored.historyBefore, 5);
  assert.equal(restored.historyCut, 10);
  assert.equal(restored.hasMore, true);
  assert.equal(restored.streamText, 'partial');
  assert.equal(restored.streamReasoning, 'plan');
  assert.equal(restored.expandedTurns.has('turn:1'), true);
  assert.equal(restored.turnDisclosure.get('turn:1'), true);
  assert.equal(restored.disclosures.get('turn:1|call:1'), true);
  assert.equal(restored.collapseThrough, 9);
  assert.throws(() => restored.restore({ version: 99, messages: [] }));
});

test('stable transcript sources publish bounded tail updates instead of reloading long histories', () => {
  const { NativeListSource } = load('NativeListSource', {});
  const source = new NativeListSource();
  const events = [];
  source.registerDataChangeListener({
    onDataReloaded: () => events.push('reload'),
    onDataAdded: index => events.push('add:' + index),
    onDataChange: index => events.push('change:' + index),
    onDataDeleted: index => events.push('delete:' + index),
    onDataMoved: (from, to) => events.push('move:' + from + ':' + to)
  });
  const initial = Array.from({ length: 2000 },
    (_, index) => ({ id: 'row-' + index, text: 'stable' }));
  source.set(initial, row => row.id);
  events.length = 0;
  const changed = initial.map(row => ({ ...row }));
  changed[changed.length - 1].text = 'streamed';
  source.set(changed, row => row.id);
  assert.deepEqual(events, ['change:1999']);
  changed.push({ id: 'row-new', text: 'appended' });
  source.set(changed, row => row.id);
  assert.deepEqual(events, ['change:1999', 'add:2000']);
  events.length = 0;
  const streamed = changed.map(row => ({ ...row }));
  streamed[streamed.length - 1].text = 'next token';
  source.setTail(streamed, 1);
  assert.deepEqual(events, ['change:2000']);
});

test('text-only stream projection patches the live answer without rebuilding history', () => {
  const types = load('NativeSessionModel', {});
  const { nativeUpdateLiveAssistant, nativeWithLiveText } =
    load('NativeTranscript', { './NativeSessionModel': types });
  const history = Array.from({ length: 5000 },
    (_, index) => Object.assign(new types.NativeMessage(), {
      id: 'event-' + index, role: 'assistant', text: 'stable', turnKey: 'turn:1'
    }));
  const updated = nativeWithLiveText(history, 'hello');
  assert.equal(updated.length, history.length + 1);
  assert.equal(updated.at(-1).text, 'hello');
  assert.equal(updated.at(-1).runningTurn, true);
  assert.equal(updated.at(-1).turnKey, 'turn:1');
  assert.equal(history.length, 5000, 'durable source rows remain untouched');
  assert.equal(history.some(row => row.id === 'live-assistant'), false);
  const live = Object.assign(new types.NativeMessage(), {
    id: 'live-assistant', role: 'assistant', text: 'old', turnKey: 'turn:11'
  });
  const patched = nativeUpdateLiveAssistant(updated.concat([live]), 'new');
  assert.equal(patched.at(-1).text, 'new');
  assert.equal(patched.at(-1).runningTurn, true);
  assert.equal(live.text, 'old', 'tail patch must not mutate the rendered source row');
});

test('display-only secret masking covers synthetic provider credentials and preserves raw copy source', () => {
  const { nativeSecretSpans, nativeMaskSecrets, nativeHasSecrets } = load('NativeSecretMask', {});
  const syntheticToken = ['sk-', 'demo', '0123456789ABCDEFGHIJ'].join('');
  const pem = [
    '-----BEGIN DEMO PRIVATE KEY-----',
    'SYNTHETICBODY1234567890',
    '-----END DEMO PRIVATE KEY-----'
  ].join('\n');
  const raw = [
    'token ' + syntheticToken,
    'google AIza' + 'A'.repeat(35),
    'github ghp_' + 'B'.repeat(36),
    'jwt eyJdemoHeader123.eyJdemoPayload456.eyJdemoSignature789',
    'url https://demo-user:DemoPassword123@example.invalid/path',
    pem
  ].join('\n');
  const spans = nativeSecretSpans(raw);
  const masked = nativeMaskSecrets(raw, spans);
  assert.equal(raw.includes(syntheticToken), true);
  assert.equal(masked.includes(syntheticToken), false);
  assert.equal(masked.includes('DemoPassword123'), false);
  assert.equal(masked.includes('SYNTHETICBODY1234567890'), false);
  assert.match(masked, /sk-demo0\*+/);
  assert.match(masked, /-----BEGIN DEMO PRIVATE KEY-----/);
  assert.match(masked, /-----END DEMO PRIVATE KEY-----/);
  assert.equal(masked.length, raw.length, 'ASCII masks preserve offsets and length');
  assert.deepEqual([...new Set(spans.map(row => row.kind))].sort(),
    ['jwt', 'privateKey', 'token', 'urlPassword']);
  assert.equal(nativeHasSecrets(raw), true);
});

test('secret masking ignores ordinary assignments and enforces token boundaries', () => {
  const { nativeSecretSpans, nativeMaskSecrets } = load('NativeSecretMask', {});
  for (const value of [
    'password=ordinary text',
    'apiKey=not-a-provider-token',
    'sk-short',
    ['x', 'sk-', 'demo', '0123456789ABCDEFGHIJ'].join(''),
    'https://example.invalid/no-credentials',
    'ordinary prose with * and _'
  ]) {
    assert.equal(nativeSecretSpans(value).length, 0, value);
    assert.equal(nativeMaskSecrets(value), value);
  }
  const unicode = '说明 https://用户:秘密密码123@example.invalid/path 后的文字';
  const masked = nativeMaskSecrets(unicode);
  assert.equal(masked.includes('秘密密码123'), false);
  assert.match(masked, /说明 https:\/\/用户:\*+@example\.invalid\/path 后的文字/);
});

test('masked inline runs protect credential geometry from Markdown parsing', () => {
  const { nativeInlineMarkdownMasked } = load('NativeInlineMarkdown', {});
  const token = ['sk-', 'demo', '0123456789ABCDEFGHIJ'].join('');
  const runs = nativeInlineMarkdownMasked('说明 **' + token + '** 已发送');
  const masked = runs.find(row => row.secret);
  assert.ok(masked);
  assert.equal(masked.bold, true, 'surrounding emphasis remains intact');
  assert.match(masked.text, /^sk-demo0\*+$/);
  assert.equal(JSON.stringify(runs).includes(token), false);
  assert.equal(nativeInlineMarkdownMasked('普通 **强调**').map(row => row.text).join(''), '普通 强调');
});

test('streaming Markdown repair closes inline syntax, hides partial tables and converges', () => {
  const { nativeRepairStreamingMarkdown } = load('NativeStreamMarkdown', {});
  assert.equal(nativeRepairStreamingMarkdown('hello **stream'),
    'hello **stream**');
  assert.equal(nativeRepairStreamingMarkdown('hello **stream**'),
    'hello **stream**');
  assert.equal(nativeRepairStreamingMarkdown('~~gone'), '~~gone~~');
  assert.equal(nativeRepairStreamingMarkdown('code `value'), 'code `value`');
  assert.equal(nativeRepairStreamingMarkdown('link [doc](https://exa'),
    'link [doc](#)');
  assert.equal(nativeRepairStreamingMarkdown('image ![alt](https://exa'),
    'image');
  assert.equal(nativeRepairStreamingMarkdown('hello <sp'), 'hello');
  assert.equal(nativeRepairStreamingMarkdown('tail **'), 'tail');
  assert.equal(nativeRepairStreamingMarkdown('#'), '');
  assert.equal(nativeRepairStreamingMarkdown('```typescript'), '');
  assert.equal(nativeRepairStreamingMarkdown('```typescript\nconst x = 1;'),
    '```typescript\nconst x = 1;');
  assert.equal(nativeRepairStreamingMarkdown(
    '流式 Markdown\n\n| 状态 | 结果 |\n| --- | --'), '流式 Markdown');
  assert.equal(nativeRepairStreamingMarkdown(
    '流式 Markdown\n\n| 状态 | 结果 |\n| --- | --- |\n| 完成 | 是 |'),
  '流式 Markdown\n\n| 状态 | 结果 |\n| --- | --- |\n| 完成 | 是 |');
});

test('settings index normalizes full-width text and ranks title before synonym and path', () => {
  const {
    nativeNormalizeSettingsQuery,
    nativeSearchSettings
  } = load('NativeSettingsIndex', {});
  assert.equal(nativeNormalizeSettingsQuery('  ＡＰＩ　Key  '), 'apikey');
  const notification = nativeSearchSettings('通知');
  assert.equal(notification[0].entry.id, 'notifications');
  assert.ok(notification.some(hit => hit.entry.id === 'notifications.approval'));
  const transparency = nativeSearchSettings('透明');
  assert.equal(transparency[0].entry.title, '减少透明效果');
  const material = nativeSearchSettings('material');
  assert.equal(material[0].entry.id, 'appearance.transparency');
  assert.equal(material[0].matchedSynonym, 'material');
  const dark = nativeSearchSettings('dark');
  assert.equal(dark[0].entry.id, 'appearance.theme');
  const cache = nativeSearchSettings('cache');
  assert.equal(cache[0].entry.id, 'storage');
  assert.ok(nativeSearchSettings('storage', 1).length === 1);
  assert.equal(nativeSearchSettings('   ').length, 0);
});

test('frontend hardening source wires masking, stream repair and settings search into production', () => {
  const message = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeMessageView.ets', import.meta.url), 'utf8');
  const text = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeTextContent.ets', import.meta.url), 'utf8');
  const textSource = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/services/NativeTextSource.ets', import.meta.url), 'utf8');
  const settings = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeSettings.ets', import.meta.url), 'utf8');
  assert.match(message, /copyMessage\(\).*?rawMessageText\(\)/s);
  assert.match(message, /text: this\.message\.text, maskSecrets: this\.maskSecrets\(\)/);
  assert.match(message, /secretsRevealed \? '隐藏凭据' : '显示凭据'/);
  assert.match(text, /NativeStreamingMarkdownBuffer/);
  assert.match(text, /nativeRepairStreamingMarkdown\(update\.tail\)/);
  assert.match(text, /this\.streamBuffer\.update\(this\.text\)/);
  assert.match(text, /maskSecrets: this\.maskSecrets/);
  assert.match(text, /nativeSecretSpans\(this\.renderedText\)/);
  assert.match(textSource, /protectedRanges: NativeSecretSpan\[\]/);
  assert.match(text, /pasteboard\.createData\(pasteboard\.MIMETYPE_TEXT_PLAIN, this\.text\)/);
  assert.match(settings, /nativeSearchSettings\(this\.settingsQuery\)/);
  assert.match(settings, /this\.openPage\(hit\.entry\.page\)/);
});
