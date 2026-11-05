// Exercises the running-tail copy, authoritative clock, text shimmer and
// in-flow placement under the native service loader.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
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

test('running tail uses the Host turn start and a gradient text sweep', () => {
  const tail = readFileSync(new URL('NativeRunningTail.ets', components), 'utf8');
  assert.match(tail, /@Prop startedAt: number = 0/);
  assert.doesNotMatch(tail, /this\.startedAt = Date\.now\(\)/);
  assert.match(tail, /nativeRunningElapsed\(this\.startedAt, this\.now, this\.paused, this\.frozenElapsed\)/);
  assert.match(tail, /new LinearGradientStyle/);
  assert.match(tail, /withAlpha\(NativeDesign\.deepDivingShimmer/);
  assert.match(tail, /private bandGate\(\): number/);
  assert.match(tail, /running_whale_glow_dark/);
  const whale = readFileSync(new URL('NativeRunningWhale.ets', components), 'utf8');
  assert.match(whale, /ImageAnimator\(\)/);
  assert.match(whale, /app\.media\.running_whale_frame_dark_00/);
  assert.match(tail, /NativeRunningWhale\(\{ dark: this\.dark \}\)/);
  assert.match(tail, /shaderStyle\(this\.labelStyle\(\)\)/);
  assert.match(tail, /SWEEP_CYCLE_MS = 2000/);
  assert.match(tail, /SWEEP_INTERVAL_MS = 33/);
  assert.match(tail, /this\.mounted = false/);
  assert.doesNotMatch(tail, /RUNNING_WHALE_PATH/);
  assert.doesNotMatch(tail, /whaleTilt|stepAnimation/);
  const workspace = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeWorkspace.ets', import.meta.url), 'utf8');
  assert.match(workspace, /private runningTurnStartedAt\(\): number/);
  assert.match(workspace, /animateTo\(\{ duration: 190, curve: Curve\.FastOutSlowIn \}, \(\): void => \{ this\.runningTailEnter = 1; \}\);/);
  assert.match(workspace, /this\.model\.runningTurnStartedAt/);
  assert.match(workspace, /private syncRunningTail\(wasRunning: boolean\)/);
  assert.match(workspace, /if \(this\.runningTailVisible && this\.followTail\)/);
  assert.match(workspace, /NativeRunningTail\(\{[\s\S]{0,200}startedAt: this\.runningTurnStartedAt\(\)[\s\S]{0,200}progress: this\.runningTailEnter/);
  assert.doesNotMatch(workspace, /if \(this\.running\) \{\s*NativeRunningTail/);
  for (const name of ['running_whale_dark.webp', 'running_whale_light.webp']) {
    assert.equal(existsSync(new URL(name, media)), false, name + ' must stay removed');
  }
  for (const name of ['running_whale_glow_dark.png', 'running_whale_glow_light.png',
    'running_whale_frame_dark_00.png', 'running_whale_frame_light_14.png']) {
    assert.ok(existsSync(new URL(name, media)), name + ' missing');
  }
});