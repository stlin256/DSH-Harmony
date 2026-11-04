import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
import { nativeProjectionChanges, nativeHistoryFailure } from '../src/native-protocol.mjs';

function load(name) {
  const source = readFileSync(new URL(`../../harmony/entry/src/main/ets/services/${name}.ets`, import.meta.url), 'utf8');
  const exports = {};
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS,
  } }).outputText, { exports });
  return exports;
}
const { NativeStreamRecovery } = load('NativeStreamRecovery');
const { NativeStreamPresentation, NativeStreamCadence } = load('NativeStreamPresentation');

test('recovery rejects retired epochs including same-session reopen and bounds snapshot loops', () => {
  const policy = new NativeStreamRecovery();
  const first = policy.begin(1);
  const repair = policy.retire();
  assert.equal(policy.current(first), false);
  const next = policy.begin(2);
  assert.equal(policy.current(repair), false);
  assert.equal(policy.current(next), true);
  assert.equal(policy.openingExpired(30002, false), true);
  policy.opened(30002);
  assert.equal(policy.openingExpired(90000, false), false);
  const delays = [];
  for (let i = 0; i < 7; i++) {
    policy.begin(100000 + i * 100);
    policy.opened(100001 + i * 100);
    delays.push(policy.nextDelay(100002 + i * 100));
  }
  assert.deepEqual(delays, [250, 2000, 4000, 8000, 16000, 30000, -1]);
  policy.reset();
  assert.equal(policy.current(next), false);
  assert.equal(policy.nextDelay(200000), 250);
  policy.begin(200001); policy.opened(200002);
  assert.equal(policy.nextDelay(240000), 250, 'stable connection resets failure budget');
});

test('burst presentation is progressive, bounded and Unicode safe without altering authority', () => {
  const display = new NativeStreamPresentation();
  const authoritative = '中文😀🧪'.repeat(800);
  display.reset('', 1000);
  display.offer(authoritative, 1001);
  assert.equal(display.value(), '');
  let prior = 0;
  for (let now = 1033; now < 1601; now += 32) {
    display.advance(now);
    const text = display.value();
    assert.ok(text.length >= prior && text.length < authoritative.length);
    assert.equal(text.isWellFormed(), true);
    assert.equal(authoritative.startsWith(text), true);
    prior = text.length;
  }
  assert.ok(prior > 0);
  display.advance(1601);
  assert.equal(display.value(), authoritative);
  assert.equal(display.pending(), false);
  assert.equal(NativeStreamCadence.maxLagMs, 600);
});

test('presentation handles irregular arrivals, replacement, snapshot and reduced motion', () => {
  const display = new NativeStreamPresentation();
  let authority = '';
  for (let i = 0; i < 80; i++) {
    const now = 1000 + i * 53;
    authority += i % 3 ? '继续😀' : 'a'.repeat(100);
    display.offer(authority, now);
    display.advance(now + 32);
    assert.ok(authority.startsWith(display.value()));
    assert.ok(display.value().isWellFormed());
  }
  display.offer('replaced', 8000);
  assert.equal(display.value(), 'replaced');
  display.offer('replaced immediately', 8001, true);
  assert.equal(display.value(), 'replaced immediately');
  display.reset('snapshot', 9000);
  assert.equal(display.value(), 'snapshot');
  display.offer('snapshot appended', 9001);
  display.advance(9010, true);
  assert.equal(display.value(), 'snapshot appended');
});

test('projection batches preserve same-sequence keys and reject malformed batches before applying', () => {
  const changes = [{ key: 'plan', val: { active: true } }, { key: 'subagent', val: null }];
  assert.deepEqual(nativeProjectionChanges({ seq: 7, changes }), changes);
  assert.throws(() => nativeProjectionChanges({ seq: 7, changes: [...changes, { key: 'bad' }] }));
  assert.throws(() => nativeProjectionChanges({ seq: 7, changes: [changes[0], changes[0]] }));
  assert.deepEqual(nativeProjectionChanges({ seq: 1, key: 'plan', value: null }), [{ key: 'plan', val: null }]);
});

test('history errors retain only safe classification and never retry permanent child errors', () => {
  for (const code of ['subagent/not-found', 'subagent/unauthorized', 'subagent/catalog-diagnostic',
    'session/not-found', 'gateway/invocation-unavailable', 'gateway/bad-request']) {
    assert.deepEqual(nativeHistoryFailure(code), { type: 'error', code, retryable: false });
  }
  assert.deepEqual(nativeHistoryFailure('arbitrary private detail'),
    { type: 'error', code: 'history-unavailable', retryable: true });
});


test('live stream tail renders from state instead of a value-parameter builder', () => {
  const content = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeTextContent.ets', import.meta.url), 'utf8');
  // NativeArkUI does not refresh a @Builder's value parameters when the argument
  // changes; paced streaming tail must therefore be rendered from component state.
  assert.doesNotMatch(content, /this\.body\(this\.streamTail/);
  assert.match(content, /NativeInlineText\(\{ text: this\.streamTail/);
  assert.match(content, /Text\(this\.streamTail\)/);
});
