import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import ts from 'typescript';
import {
  normalizePlanProjection,
  normalizeSubagentAddress,
  normalizeSubagentCatalog,
  normalizeSubagentIdentity,
  normalizeSubagentTiming,
  planTargetActive
} from '../src/native-protocol.mjs';

const services = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);

function loadModeModel() {
  const source = readFileSync(new URL('NativeModeSubagent.ets', services), 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS }
  });
  const module = { exports: {} };
  vm.runInNewContext(output.outputText, { module, exports: module.exports });
  return module.exports;
}

test('Plan projection uses the host target and rejects malformed values', () => {
  assert.deepEqual(normalizePlanProjection({ active: false, pending: true }), {
    active: false,
    pending: true
  });
  assert.equal(planTargetActive({ active: false, pending: true }), true);
  assert.equal(planTargetActive({ active: true, pending: true }), false);
  assert.equal(planTargetActive({ active: true, pending: false }), true);
  assert.equal(normalizePlanProjection({ active: true }), null);
});

test('subagent projections are bounded, allowlisted and preserve an explicit null identity', () => {
  const catalog = normalizeSubagentCatalog([
    { id: 'child-a', createdAt: 1, mode: 'continuable', label: ' Reviewer ' },
    { id: 'child-a', createdAt: 2, mode: 'one-shot' },
    { id: 'child-b', createdAt: 3, mode: 'external', label: 'External' },
    { id: 'child-c', createdAt: 4, mode: 'unknown' },
    { id: 'bad id', createdAt: 5, mode: 'one-shot' },
    { id: 'child-d', createdAt: 6, mode: 'continuable' },
    { id: 'child-e', createdAt: -1, mode: 'one-shot' }
  ]);
  assert.deepEqual(catalog, [
    { id: 'child-a', createdAt: 1, mode: 'continuable', label: 'Reviewer' },
    { id: 'child-b', createdAt: 3, mode: 'external', label: 'External' },
    { id: 'child-c', createdAt: 4, mode: 'unknown' }
  ]);
  assert.equal(normalizeSubagentIdentity(null), null);
  assert.deepEqual(normalizeSubagentIdentity({
    mode: 'continuable', label: 'Worker', seq: 9
  }), { mode: 'continuable', label: 'Worker', seq: 9 });
  assert.equal(normalizeSubagentIdentity({
    mode: 'continuable', seq: 10
  }), null);
  assert.deepEqual(normalizeSubagentTiming({
    settledMs: 1200,
    active: { since: 20, through: 30 },
    lastTurnCompleted: true
  }), {
    settledMs: 1200,
    active: { since: 20, through: 30 },
    lastTurnCompleted: true
  });
  assert.equal(normalizeSubagentTiming({
    settledMs: 1,
    active: { since: 20, through: 10 }
  }), null);
});

test('subagent addresses reject external, self and malformed modes', () => {
  assert.deepEqual(normalizeSubagentAddress({
    kind: 'subagent',
    parentSessionId: 'parent',
    childSessionId: 'child',
    mode: 'continuable'
  }), {
    kind: 'subagent',
    parentSessionId: 'parent',
    childSessionId: 'child',
    mode: 'continuable'
  });
  for (const value of [
    null,
    { kind: 'subagent', parentSessionId: 'same', childSessionId: 'same', mode: 'one-shot' },
    { kind: 'subagent', parentSessionId: 'parent', childSessionId: 'child', mode: 'external' },
    { kind: 'session', sessionId: 'child' }
  ]) assert.equal(normalizeSubagentAddress(value), null);
});

test('ArkTS mode model resolves Plan target, read-only rules and reliable address stacks', () => {
  const model = loadModeModel();
  const pending = Object.assign(new model.NativePlanProjection(), { active: false, pending: true });
  assert.equal(model.nativePlanTargetActive(pending), true);

  const continuable = model.nativeSubagentAddress('parent', 'child', 'continuable');
  assert.ok(continuable);
  assert.equal(model.nativeSubagentReadOnlyReason(continuable, null), '');
  assert.equal(model.nativeSubagentReadOnlyReason(continuable, null, true), 'unknown');
  assert.equal(model.nativeSubagentReadOnlyReason(continuable, null, true, true), 'unknown');
  assert.equal(model.nativeSubagentReadOnlyReason(continuable, null, false, undefined, false), '');
  assert.equal(model.nativeSubagentReadOnlyReason(continuable, null, false, false, false),
    'parent-unavailable');
  assert.equal(model.nativeSubagentReadOnlyReason(continuable, null, false, false, true), '');
  assert.equal(model.nativeSubagentComposerEnabled(continuable, null, false, false, false), false);
  assert.equal(model.nativeSubagentComposerEnabled(continuable, null, false, false, true), false);
  assert.equal(model.nativeSubagentComposerEnabled(continuable, null, false, true, false), true);
  assert.equal(model.nativeSubagentComposerEnabled(continuable, null, false, undefined, false), true);
  const oneShot = model.nativeSubagentAddress('parent', 'one', 'one-shot');
  assert.equal(model.nativeSubagentReadOnlyReason(oneShot,
    Object.assign(new model.NativeSubagentIdentity(), { mode: 'one-shot' })), 'one-shot');
  const unknown = model.nativeSubagentAddress('parent', 'unknown', 'unknown');
  assert.equal(model.nativeSubagentReadOnlyReason(unknown, null), 'unknown');

  let stack = model.nativeSubagentStackPush([], continuable);
  stack = model.nativeSubagentStackPush(stack, continuable);
  assert.equal(stack.length, 1);
  const nested = model.nativeSubagentAddress('child', 'grandchild', 'continuable');
  stack = model.nativeSubagentStackPush(stack, nested);
  assert.equal(stack.length, 2);
  for (let index = 0; index < 20; index++) {
    stack = model.nativeSubagentStackPush(stack,
      model.nativeSubagentAddress('n' + index, 'n' + (index + 1), 'continuable'));
  }
  assert.equal(stack.length, model.nativeSubagentMaxDepth);
  assert.equal(model.nativeSubagentCanOpen(
    Object.assign(new model.NativeSubagentEntry(), { id: 'external', mode: 'external' })), false);
  assert.equal(model.nativeSubagentDuration(61000, 1000, null), '1分');
});

test('native shell keeps mode UI separate from todo plans and hides child sessions from the root list', () => {
  const workspace = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeWorkspace.ets', import.meta.url), 'utf8');
  const lineage = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeSubagentLineage.ets', import.meta.url), 'utf8');
  const session = readFileSync(new URL('NativeSessionModel.ets', services), 'utf8');
  const showcase = readFileSync(new URL('StoreShowcaseClient.ets', services), 'utf8');
  assert.match(workspace, /nativePlanTargetActive\(this\.planProjection\)/);
  assert.match(workspace, /Text\('计划'\)/);
  assert.match(workspace, /this\.client\.planOff\(this\.selected\)/);
  assert.match(workspace,
    /this\.refreshSelectedProjection\(\);\s*this\.loadSelectedProjections\(\);/);
  assert.ok(workspace.indexOf('NativeTaskDock') !== workspace.lastIndexOf('NativeTaskDock'));
  assert.match(workspace, /NativeSubagentLineage\(\{/);
  assert.match(workspace, /subagentPath/);
  assert.match(lineage, /constraintSize\(\{ maxHeight: this\.maxHeight \}\)/);
  assert.match(lineage, /constraintSize\(\{ minHeight: NativeDesign\.standardRow \}\)/);
  assert.match(lineage, /nativeSubagentCanOpen\(entry\)/);
  assert.match(session, /origin !== 'subagent'/);
  assert.match(showcase,
    /value\.projections = new NativeSubagentProjectionValues\(\);[\s\S]{0,180}value\.projections\.plan = showcasePlanProjection\(planRemoved\)/);
  assert.match(showcase,
    /value\.projections\.subagentCatalog = showcaseNativeSubagentCatalog\(state\)/);
  assert.match(showcase, /value\.items = showcaseSessions\(this\.fixtureState, this\.planRemoved\)/);
});
