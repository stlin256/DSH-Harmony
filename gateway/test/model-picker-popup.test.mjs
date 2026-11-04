import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const workspace = readFileSync(new URL('harmony/entry/src/main/ets/components/NativeWorkspace.ets', root), 'utf8');
const picker = readFileSync(new URL('harmony/entry/src/main/ets/components/NativeModelPicker.ets', root), 'utf8');
const permission = readFileSync(new URL('harmony/entry/src/main/ets/components/NativePermissionPicker.ets', root), 'utf8');

test('composer owns one popup for both menus using the permission template', () => {
  assert.match(workspace, /\.bindPopup\(this\.composerPopupOpen\(\), \{/);
  assert.match(workspace, /builder: this\.composerPopup,/);
  assert.doesNotMatch(workspace, /bindPopup\(this\.modelPickerOpen/);
  assert.match(workspace, /if \(this\.modelPickerOpen\) \{\s*this\.modelPicker\(\)/);
  // The model sheet reuses the permission popup options, including the mask
  // and the invisible host chrome added by API 26.
  assert.match(workspace, /mask: \{ color: NativeDesign\.mask\(this\.dark\) \}/);
  assert.match(workspace, /outlineWidth: 0,/);
  assert.match(workspace, /borderWidth: 0,/);
});

test('model picker reuses the permission card contract and drops the search box', () => {
  assert.match(picker, /pickerWidth: number = 316;/);
  assert.match(picker, /\.width\(this\.pickerWidth\)/);
  assert.match(picker, /\.id\('model-picker'\)/);
  assert.match(picker, /border\(\{ width: 0\.5, color: NativeDesign\.border\(this\.dark\) \}\)/);
  assert.match(picker, /constraintSize\(\{ maxHeight: 278 \}\)/);
  assert.match(permission, /constraintSize\(\{ maxHeight: 278 \}\)/);
  assert.doesNotMatch(picker, /搜索模型/);
  assert.doesNotMatch(picker, /TextInput\(/);
  assert.doesNotMatch(picker, /this\.query/);
});
