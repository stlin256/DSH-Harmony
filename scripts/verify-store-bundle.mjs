import { readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Verify a signed store .app bundle before uploading it to AppGallery.
 *
 * The AppGallery upload rejects a bundle whose HAP declares a permission the
 * release Profile did not approve (error 7014). That happens when the store
 * variant manifest was not swapped in, which is easy to trigger by calling
 * hvigor directly instead of scripts/build-harmony.ps1. This check reads the
 * permissions out of the packaged HAP so the mistake is caught locally.
 */

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const bundle = resolve(process.argv[2] || join(root, 'harmony/build/outputs/store/harmony-store-signed.app'));

/** Permissions the store release Profile approves. */
const ALLOWED = new Set([
  'ohos.permission.INTERNET',
  'ohos.permission.KEEP_BACKGROUND_RUNNING',
]);
/** Permissions that must never ship in the store variant. */
const FORBIDDEN = new Set([
  'ohos.permission.ACCESS_FIDO2_ONLINEAUTH',
]);

const failures = [];
if (!existsSync(bundle)) {
  console.error('FAIL bundle not found: ' + bundle);
  process.exit(1);
}

const work = mkdtempSync(join(tmpdir(), 'dsh-app-check-'));
try {
  const appZip = join(work, 'app.zip');
  execFileSync('powershell', ['-NoProfile', '-Command',
    `Copy-Item -LiteralPath '${bundle.replace(/'/g, "''")}' -Destination '${appZip.replace(/'/g, "''")}' -Force`]);
  execFileSync('powershell', ['-NoProfile', '-Command',
    `Expand-Archive -LiteralPath '${appZip.replace(/'/g, "''")}' -DestinationPath '${join(work, 'app').replace(/'/g, "''")}' -Force`]);

  const hapName = 'entry-store.hap';
  const hapPath = join(work, 'app', hapName);
  if (!existsSync(hapPath)) {
    console.error('FAIL the bundle does not contain ' + hapName);
    process.exit(1);
  }
  const hapZip = join(work, 'hap.zip');
  execFileSync('powershell', ['-NoProfile', '-Command',
    `Copy-Item -LiteralPath '${hapPath.replace(/'/g, "''")}' -Destination '${hapZip.replace(/'/g, "''")}' -Force`]);
  execFileSync('powershell', ['-NoProfile', '-Command',
    `Expand-Archive -LiteralPath '${hapZip.replace(/'/g, "''")}' -DestinationPath '${join(work, 'hap').replace(/'/g, "''")}' -Force`]);

  const moduleJson = JSON.parse(readFileSync(join(work, 'hap', 'module.json'), 'utf8'));
  const declared = (moduleJson.module?.requestPermissions || []).map((entry) => entry.name);

  for (const name of declared) {
    if (FORBIDDEN.has(name)) {
      failures.push('forbidden permission in the store bundle: ' + name +
        ' (the store variant manifest was not applied; build with -Product store)');
    } else if (!ALLOWED.has(name)) {
      failures.push('permission not approved by the release Profile: ' + name);
    }
  }
  for (const name of ALLOWED) {
    if (!declared.includes(name)) failures.push('expected permission missing: ' + name);
  }

  const pack = JSON.parse(readFileSync(join(work, 'app', 'pack.info'), 'utf8'));
  const summary = pack.summary?.app;
  if (summary?.bundleType !== 'app') failures.push('pack.info bundleType must be "app"');
  const version = summary?.version;
  if (!Number.isSafeInteger(version?.code) || version.code <= 0) failures.push('pack.info version.code is invalid');
  if (typeof version?.name !== 'string' || !version.name) failures.push('pack.info version.name is invalid');

  if (failures.length) {
    for (const failure of failures) console.error('FAIL ' + failure);
    process.exit(1);
  }
  console.log('Store bundle checks passed: ' + declared.length + ' permission(s), version ' +
    version.name + ' (' + version.code + ')');
  console.log('  bundle: ' + bundle);
  console.log('  permissions: ' + declared.join(', '));
} finally {
  rmSync(work, { recursive: true, force: true });
}
