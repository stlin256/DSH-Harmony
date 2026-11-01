import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const mainManifest = readFileSync(join(root, 'harmony/entry/src/main/module.json5'), 'utf8');
const storeManifest = readFileSync(join(root, 'harmony/variants/store/module.json5'), 'utf8');
const personalCapabilities = readFileSync(
  join(root, 'harmony/entry/src/personal/ProductCapabilities.ets'),
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
if (!/supportsPasskey:\s*boolean\s*=\s*true/.test(personalCapabilities)) {
  failures.push('default product must advertise Passkey support');
}
if (!/supportsPasskey:\s*boolean\s*=\s*false/.test(storeCapabilities)) {
  failures.push('store product must not advertise Passkey support');
}
if (!/supportsMockFixtures:\s*boolean\s*=\s*false/.test(personalCapabilities) ||
    !/supportsMockFixtures:\s*boolean\s*=\s*false/.test(storeCapabilities)) {
  failures.push('default and store products must not auto-select Mock fixtures');
}
if (!/supportsMockFixtures:\s*boolean\s*=\s*true/.test(mockCapabilities)) {
  failures.push('mock product must auto-select Mock fixtures');
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
