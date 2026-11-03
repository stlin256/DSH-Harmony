import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const mainManifest = readFileSync(join(root, 'harmony/entry/src/main/module.json5'), 'utf8');
const storeManifest = readFileSync(join(root, 'harmony/variants/store/module.json5'), 'utf8');
const communityCapabilities = readFileSync(
  join(root, 'harmony/entry/src/community/ProductCapabilities.ets'),
  'utf8',
);
const storeCapabilities = readFileSync(
  join(root, 'harmony/entry/src/store/ProductCapabilities.ets'),
  'utf8',
);
const mockCapabilities = readFileSync(
  join(root, 'harmony/entry/src/mock/ProductCapabilities.ets'),
  'utf8',
);
const buildInfo = readFileSync(
  join(root, 'harmony/entry/src/main/ets/services/BuildInfo.ets'),
  'utf8',
);
const appStrings = JSON.parse(
  readFileSync(join(root, 'harmony/AppScope/resources/base/element/string.json'), 'utf8'),
);
const buildScript = readFileSync(join(root, 'scripts/build-harmony.ps1'), 'utf8');
const entryBuildProfile = readFileSync(
  join(root, 'harmony/entry/build-profile.json5'),
  'utf8',
);
const exampleBuildProfile = readFileSync(
  join(root, 'harmony/build-profile.example.json5'),
  'utf8',
);
const appConfig = readFileSync(join(root, 'harmony/AppScope/app.json5'), 'utf8');
const indexSource = readFileSync(
  join(root, 'harmony/entry/src/main/ets/pages/Index.ets'),
  'utf8',
);
const showcaseSource = readFileSync(
  join(root, 'harmony/entry/src/main/ets/services/StoreShowcaseClient.ets'),
  'utf8',
);
const workspaceSource = readFileSync(
  join(root, 'harmony/entry/src/main/ets/components/NativeWorkspace.ets'),
  'utf8',
);
const launchSource = readFileSync(
  join(root, 'harmony/entry/src/main/ets/components/NativeLaunchSurface.ets'),
  'utf8',
);
const reviewDriver = readFileSync(
  join(root, 'scripts/device-ui-store-review-e2e.ps1'),
  'utf8',
);
const nativeExperienceSource = readFileSync(
  join(root, 'harmony/entry/src/main/ets/services/NativeExperience.ets'),
  'utf8',
);
const fileBrowserSource = readFileSync(
  join(root, 'harmony/entry/src/main/ets/components/NativeFileBrowser.ets'),
  'utf8',
);
const pluginsSource = readFileSync(
  join(root, 'harmony/entry/src/main/ets/components/NativePluginsSurface.ets'),
  'utf8',
);
const automationSource = readFileSync(
  join(root, 'harmony/entry/src/main/ets/components/NativeAutomationSurface.ets'),
  'utf8',
);
const settingsSource = readFileSync(
  join(root, 'harmony/entry/src/main/ets/components/NativeSettings.ets'),
  'utf8',
);
const entrySource = readFileSync(
  join(root, 'harmony/entry/src/main/ets/entryability/EntryAbility.ets'),
  'utf8',
);
const layeredImage = JSON.parse(
  readFileSync(
    join(root, 'harmony/AppScope/resources/base/media/app_layered_image.json'),
    'utf8',
  ),
);
const fido = 'ohos.permission.ACCESS_FIDO2_ONLINEAUTH';
const failures = [];
function appDisplayName(source) {
  return source.match(/appDisplayName\s*:\s*string\s*=\s*(['"])(.*?)\1/)?.[2] || '';
}

const communityName = appDisplayName(communityCapabilities);
const storeName = appDisplayName(storeCapabilities);
const mockName = appDisplayName(mockCapabilities);

if (!mainManifest.includes(fido)) {
  failures.push('default manifest must request the FIDO2 ACL');
}
if (storeManifest.includes(fido)) {
  failures.push('store manifest must not request the FIDO2 ACL');
}
for (const required of ['ohos.permission.INTERNET', 'ohos.permission.KEEP_BACKGROUND_RUNNING']) {
  if (!mainManifest.includes(required) || !storeManifest.includes(required)) {
    failures.push(`both manifests must retain ${required}`);
  }
}
if (!/supportsPasskey:\s*boolean\s*=\s*true/.test(communityCapabilities)) {
  failures.push('community product must advertise Passkey support');
}
if (!/supportsPasskey:\s*boolean\s*=\s*false/.test(storeCapabilities)) {
  failures.push('store product must not advertise Passkey support');
}
if (!/supportsMockFixtures:\s*boolean\s*=\s*false/.test(communityCapabilities) ||
    !/supportsMockFixtures:\s*boolean\s*=\s*false/.test(storeCapabilities)) {
  failures.push('community and store products must not auto-select Mock fixtures');
}
if (!/supportsMockFixtures:\s*boolean\s*=\s*true/.test(mockCapabilities)) {
  failures.push('mock product must auto-select Mock fixtures');
}
if (!/supportsStoreReview:\s*boolean\s*=\s*true/.test(storeCapabilities) ||
    !storeCapabilities.includes("storeReviewOrigin: string = 'https://dsh.dshoh.com'") ||
    !storeCapabilities.includes(
      "'121101C4D6652D089DBED9904A2D3C07E9C4DC28503B92027178493696ECC51F'",
    )) {
  failures.push('store product must expose the exact review capability contract');
}
for (const [name, source] of [
  ['community', communityCapabilities],
  ['mock', mockCapabilities],
]) {
  if (!/supportsStoreReview:\s*boolean\s*=\s*false/.test(source) ||
      !/storeReviewOrigin:\s*string\s*=\s*''/.test(source) ||
      !/storeReviewCredentialSha256:\s*string\s*=\s*''/.test(source)) {
    failures.push(`${name} product must not expose the store review path`);
  }
}
if (!indexSource.includes("import { cryptoFramework } from '@kit.CryptoArchitectureKit'") ||
    !indexSource.includes('storeReviewCredentialMatches') ||
    !indexSource.includes("encoder.encodeInto(origin + '\\n' + credential.trim())") ||
    !indexSource.includes("new StoreShowcaseClient('showcase-plan', true)") ||
    !indexSource.includes("putSync('storeReviewMode', true)") ||
    !indexSource.includes("putSync('storeReviewMode', false)")) {
  failures.push('Index must hash, enter and clear the store review path');
}
if (!entrySource.includes('if (ProductCapabilities.supportsMockFixtures)') ||
    entrySource.includes('storeShowcase === true') ||
    !entrySource.includes("AppStorage.setOrCreate<boolean>('storeShowcase', false)")) {
  failures.push('exported Want parameters must not bypass store review credentials');
}
if (!indexSource.includes('this.storeReviewCredentialMatches(next, this.accessKey)') ||
    !indexSource.includes("getSync('storeReviewMode', false) === true") ||
    !indexSource.includes("AppStorage.setOrCreate<boolean>('nativeUserReduceMotion'") ||
    !indexSource.includes("AppStorage.setOrCreate<boolean>('nativeReduceTransparency'") ||
    !indexSource.includes('NativeExperience.refresh(this.context)')) {
  failures.push('Store review restore, runtime presentation and logout reset must be wired');
}
const reviewCheck = indexSource.indexOf('storeReviewCredentialMatches(next, this.accessKey)');
const realClient = indexSource.indexOf('this.nativeClient = new NativeHarnessClient(next)');
if (reviewCheck < 0 || realClient < 0 || reviewCheck > realClient) {
  failures.push('store review credentials must be checked before any real Host client is created');
}
if (!/private reviewMode:\s*boolean/.test(showcaseSource) ||
    !showcaseSource.includes("new NativeHttpError(402, 'insufficient_balance')") ||
    !/setTimeout\(resolve,\s*1200\)/.test(showcaseSource) ||
    !showcaseSource.includes("this.settingsNamespaceJson('ui-chat')") ||
    !showcaseSource.includes("this.settingsNamespaceJson('ui-conversation')") ||
    !showcaseSource.includes("this.settingsNamespaceJson('permission')") ||
    !showcaseSource.includes("settings_revision_conflict") ||
    !showcaseSource.includes('invalid_settings_revision')) {
  failures.push('store showcase client is missing review balance or mutable settings semantics');
}
const showcaseClass = showcaseSource.slice(
  showcaseSource.indexOf('export class StoreShowcaseClient'),
);
if (!/async uploadAttachment\(/.test(showcaseClass) ||
    showcaseClass.includes('super.uploadAttachment') ||
    showcaseClass.includes("this.origin + '/pocket/api/native/upload'") ||
    !showcaseClass.includes('new NativeUploadResult()')) {
  failures.push('store showcase uploads must remain in memory and never inherit network upload');
}
for (const required of [
  'bundle.installed = true',
  'bundle.installed = false',
  'this.pluginInventory.plugins = this.pluginInventory.plugins.filter',
  'this.automationCatalog.items.push(task)',
  'this.automationCatalog.items = this.automationCatalog.items.filter',
  'schedule_conflict',
]) {
  if (!showcaseClass.includes(required)) {
    failures.push(`store showcase admin state is not mutable: ${required}`);
  }
}
if (!workspaceSource.includes("error.status === 402") ||
    !workspaceSource.includes("error.code === 'insufficient_balance'") ||
    !workspaceSource.includes("this.error = '账户余额不足，请充值后重试'")) {
  failures.push('workspace must map the structured insufficient-balance error');
}
if (!launchSource.includes(".id('launch-login-address')") ||
    !launchSource.includes(".id('launch-login-access-key')")) {
  failures.push('store review login inputs need stable device E2E ids');
}
if (!reviewDriver.includes("$FixtureState = 'showcase-plan'") ||
    !reviewDriver.includes('uitest uiInput click') ||
    !reviewDriver.includes('Query-Node') ||
    !reviewDriver.includes('DSH_STORE_REVIEW_ACCESS_KEY') ||
    !reviewDriver.includes('hdc -t $Device file send') ||
    !reviewDriver.includes('$(cat ') ||
    !reviewDriver.includes('finally') ||
    !reviewDriver.includes('Remove-Item -LiteralPath $localSecret') ||
    reviewDriver.includes('inputText $($key.x) $($key.y) $accessKey')) {
  failures.push('store review device driver must cover entry, interaction and secret handoff');
}
for (const command of [
  'file browser directory and preview mutation',
  'plugin open, toggle, install, update and remove',
  'automation run, pause, create, edit and delete',
  'local persistence and in-session DSH settings mutation',
  'settings revision conflict (executable contract)',
  'structured balance error and draft retention',
  'review restore',
  'logout clearing and cold-relaunch rejection',
]) {
  if (!reviewDriver.includes(command)) {
    failures.push(`store review device driver is missing ${command}`);
  }
}
if (!nativeExperienceSource.includes("'nativeUserReduceMotion'") ||
    !nativeExperienceSource.includes("'nativeReduceTransparency'")) {
  failures.push('review runtime presentation keys must be consumed by NativeExperience');
}
for (const [name, source, required] of [
  ['file browser', fileBrowserSource, [
    ".id('file-entry-' + entry.name)",
    "controlId: 'file-browser-close'",
  ]],
  ['plugins', pluginsSource, [
    ".id('plugin-bundle-toggle-' + bundle.name)",
    ".id('plugin-install-' + bundle.name)",
    ".id('plugin-update')",
    ".id('plugin-remove')",
  ]],
  ['automation', automationSource, [
    "controlId: 'automation-create'",
    ".id('automation-active')",
    ".id('automation-run')",
    ".id('automation-delete')",
  ]],
  ['settings', settingsSource, [
    ".id('settings-open-' + page)",
    ".id('settings-notification-' + category + '-' + levelValue)",
    ".id('settings-action-' + command)",
    "controlId: 'settings-back'",
  ]],
]) {
  for (const token of required) {
    if (!source.includes(token)) failures.push(`${name} review driver target is missing: ${token}`);
  }
}
if (communityName !== 'DSH Harmony') {
  failures.push('community product display name must be DSH Harmony');
}
if (mockName !== 'DSH Harmony') {
  failures.push('mock product display name must be DSH Harmony');
}
if (!storeName || /harmony/i.test(storeName)) {
  failures.push('store product display name must be non-empty and must not contain Harmony');
}
if (!buildInfo.includes('ProductCapabilities.appDisplayName') ||
    !/static\s+readonly\s+appName\s*:\s*string\s*=\s*ProductCapabilities\.appDisplayName/.test(buildInfo)) {
  failures.push('BuildInfo must derive the display name from ProductCapabilities');
}
if (!Array.isArray(appStrings.string) ||
    appStrings.string.find((entry) => entry.name === 'app_name')?.value !== 'DSH Harmony') {
  failures.push('source launcher name must remain the default DSH Harmony value');
}
if (!buildScript.includes('appDisplayName') ||
    !buildScript.includes("$capabilityRoot = if ($buildProduct -eq 'default') { 'community' }") ||
    !buildScript.includes('AppScope/resources/base/element/string.json') ||
    !buildScript.includes('restoreAppStrings') ||
    !buildScript.includes('[IO.File]::WriteAllBytes($appStrings, $restoreAppStrings)') ||
    !/try\s*\{[\s\S]*?ReadAllBytes\(\$appStrings\)[\s\S]*?\}\s*finally\s*\{[\s\S]*?WriteAllBytes\(\$appStrings, \$restoreAppStrings\)/s.test(buildScript)) {
  failures.push('build script must sync and restore the launcher name from the selected product');
}
if (!entryBuildProfile.includes('"name": "mock"') ||
    !entryBuildProfile.includes('./src/mock')) {
  failures.push('entry build profile must declare the mock target and source root');
}
if (!exampleBuildProfile.includes('"name": "mock"')) {
  failures.push('example build profile must declare the mock product and target');
}
if (!appConfig.includes('"icon": "$media:app_layered_image"')) {
  failures.push('app config must reference the layered launcher icon');
}
for (const manifest of [mainManifest, storeManifest]) {
  if (!manifest.includes('"icon": "$media:app_layered_image"')) {
    failures.push('entry Ability must reference the layered launcher icon');
  }
}
if (
  layeredImage['layered-image']?.foreground !== '$media:app_icon_foreground' ||
  layeredImage['layered-image']?.background !== '$media:app_icon_background'
) {
  failures.push('layered icon must reference its foreground and background PNGs');
}

if (failures.length) {
  console.error(failures.join('\n'));
  process.exit(1);
}

console.log('HarmonyOS product capability contract passed');
