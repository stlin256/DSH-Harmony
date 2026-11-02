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
