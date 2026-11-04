import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const materials = readFileSync(new URL('harmony/entry/src/main/ets/services/NativeMaterials.ets', root), 'utf8');
const dock = readFileSync(new URL('harmony/entry/src/main/ets/components/NativeBottomConversationDock.ets', root), 'utf8');
const task = readFileSync(new URL('harmony/entry/src/main/ets/components/NativeTaskDock.ets', root), 'utf8');
const experience = readFileSync(new URL('harmony/entry/src/main/ets/services/NativeExperience.ets', root), 'utf8');
const settings = readFileSync(new URL('harmony/entry/src/main/ets/components/NativeSettings.ets', root), 'utf8');
const entry = readFileSync(new URL('harmony/entry/src/main/ets/entryability/EntryAbility.ets', root), 'utf8');
const index = readFileSync(new URL('harmony/entry/src/main/ets/pages/Index.ets', root), 'utf8');

test('immersive material surfaces are centrally listed and gated', () => {
  assert.match(materials, /NATIVE_MATERIAL_SURFACES/);
  assert.match(materials, /NativeMaterialSurface\.BOTTOM_DOCK/);
  assert.match(materials, /NativeMaterialSurface\.TASK_DOCK/);
  assert.match(materials, /lightEffect:/);
  assert.match(materials, /if \(AppStorage\.get<boolean>\('nativeReduceTransparency'\) === true\) return false;/);
  assert.match(materials, /if \(!NativeMaterials\.supported\(\)\) return undefined;/);
  assert.match(materials, /systemMaterial\(material\)/);
});

test('docks consume the maintained list instead of ad-hoc blur', () => {
  assert.match(dock, /NativeMaterialColumnModifier\([\s\S]{0,90}NativeMaterialSurface\.BOTTOM_DOCK/);
  assert.doesNotMatch(dock, /backgroundBlurStyle\(/);
  assert.match(task, /NativeMaterialColumnModifier\([\s\S]{0,90}NativeMaterialSurface\.TASK_DOCK/);
});

test('reduce transparency defaults to ON to preserve the pre-material shell', () => {
  assert.match(experience, /store\.getSync\('reduceTransparency', true\)/);
  assert.match(settings, /reduceTransparency: boolean = true;/);
  assert.match(settings, /@State private reduceTransparency: boolean = true;/);
  assert.match(entry, /showcaseReduceTransparency === false/);
  assert.match(index, /storeReviewReduceTransparency', true\)/);
});
