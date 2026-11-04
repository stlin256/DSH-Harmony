// Exercises the running-tail copy under the native service loader.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import ts from 'typescript';

const services = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);
const components = new URL('../../harmony/entry/src/main/ets/components/', import.meta.url);
const media = new URL('../../harmony/entry/src/main/resources/base/media/', import.meta.url);
function load(name) {
  const source = readFileSync(new URL(name + '.ets', services), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS } });
  const module = { exports: {} };
  vm.runInNewContext(output.outputText, { module, exports: module.exports });
  return module.exports;
}

test('running duration matches the DSH compact duration copy', () => {
  const { nativeRunDuration } = load('NativeRunningStatus');
  assert.equal(nativeRunDuration(0), '1秒');
  assert.equal(nativeRunDuration(1000), '1秒');
  assert.equal(nativeRunDuration(59999), '59秒');
  assert.equal(nativeRunDuration(60000), '1分0秒');
  assert.equal(nativeRunDuration(90000), '1分30秒');
  assert.equal(nativeRunDuration(3661000), '1小时1分');
});

test('running label never guesses a duration before the turn start is known', () => {
  const { nativeRunningLabel, nativeRunningElapsed } = load('NativeRunningStatus');
  assert.equal(nativeRunningLabel(0), '深度求索中');
  assert.equal(nativeRunningLabel(1000), '深度求索中，用时 1秒 ···');
  assert.equal(nativeRunningLabel(65000), '深度求索中，用时 1分5秒 ···');
  assert.equal(nativeRunningElapsed(0, 5000), 0);
  assert.equal(nativeRunningElapsed(1000, 1200), 1000, 'one-second floor');
  assert.equal(nativeRunningElapsed(1000, 5000, true, 2000), 2000, 'paused freezes');
  assert.equal(nativeRunningElapsed(1000, 5000, true, 0), 4000);
});

test('running tail keeps the DSH whale, shimmer and reduced-motion fallback', () => {
  const tail = readFileSync(new URL('NativeRunningTail.ets', components), 'utf8');
  assert.match(tail, /M8\.844 13\.742/);
  assert.match(tail, /running_whale_dark/);
  assert.match(tail, /running_whale_light/);
  assert.match(tail, /this\.whaleTilt = wave \* 12;/);
  assert.match(tail, /this\.whaleScale = 0\.86/);
  assert.match(tail, /setInterval\(\(\): void => \{ this\.stepAnimation\(\); \}, 100\)/);
  assert.match(tail, /NativeDesign\.deepDivingShimmer\(this\.dark\)/);
  assert.match(tail, /Shape\(\) \{[\s\S]{0,200}RUNNING_WHALE_PATH/);
  assert.match(tail, /nativeRunningLabel\(this\.elapsed\(\), this\.paused\)/);
  const workspace = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeWorkspace.ets', import.meta.url), 'utf8');
  assert.match(workspace, /if \(this\.running\) \{[\s\S]{0,120}NativeRunningTail\(/);
  assert.match(workspace, /turnKey: this\.running \? 'running' : ''/);
  for (const name of ['running_whale_dark.webp', 'running_whale_light.webp']) {
    const file = new URL(name, media);
    assert.ok(existsSync(file), name + ' missing');
    const bytes = readFileSync(file);
    assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
    assert.equal(bytes.toString('ascii', 8, 12), 'WEBP');
    assert.ok(bytes.includes(Buffer.from('ANIM')), name + ' must be animated');
  }
});
