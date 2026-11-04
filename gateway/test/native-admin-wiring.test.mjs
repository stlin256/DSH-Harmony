import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../../harmony/entry/src/main/ets/components/', import.meta.url);
const serviceRoot = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');
const readService = path => readFileSync(new URL(path, serviceRoot), 'utf8');

for (const component of ['NativePluginsSurface.ets', 'NativeAutomationSurface.ets']) {
  test(`${component} binds its admin client from the injected harness`, () => {
    const source = read(component);
    assert.match(
      source,
      /aboutToAppear\(\): void \{[\s\S]{0,240}this\.admin = new NativeAdminClient\(this\.client\);[\s\S]{0,80}this\.refresh\(\);/,
      'the injected client must replace the field-initialized empty-URL adapter',
    );
  });
}

test('automation draft conversion accepts raw tasks without optional arrays', () => {
  const source = readService('NativeAdminModels.ets');
  assert.match(source, /intervalSeconds && Number\.isFinite\(intervalSeconds\)/);
  assert.match(source, /task\.weekdays && task\.weekdays\.length/);
});

test('plugin switches refresh in place and the result banner is one compact line', () => {
  const surface = read('NativePluginsSurface.ets');
  assert.match(surface, /this\.applyChange\(value, key, target \? '已启用' : '已关闭'\)/);
  assert.match(surface, /this\.applyChange\(value, key, enabled \? '已启用' : '已关闭'\)/);
  assert.match(surface, /'installed:' \+ bundle\.name \+ ':' \+ \(bundle\.enabled \? 'on' : 'off'\)/);
  assert.match(surface, /row\.rowId \+ ':' \+/);
  assert.match(surface, /height\(NativeDesign\.compactControl\)[\s\S]{0,420}plugin-result-banner/);
  assert.match(surface, /plugin-result-banner[\s\S]{0,220}statusBannerTransition/);
  assert.doesNotMatch(surface, /Text\('DSH 重启后生效'\)\.fontSize/);
  assert.doesNotMatch(surface, /maxLines\(4\)/);
  const automation = read('NativeAutomationSurface.ets');
  assert.doesNotMatch(automation, /minHeight: NativeDesign\.compactHitTarget[\s\S]{0,80}top: 3, bottom: 3/);
  assert.match(automation, /minHeight: NativeDesign\.compactControl[\s\S]{0,420}statusBannerTransition/);
  const settings = read('NativeSettings.ets');
  assert.match(settings, /this\.updateState\(\(\): void => \{ this\.setLocalValue\(command, value\); \}\);/);
});