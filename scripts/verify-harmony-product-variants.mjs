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
