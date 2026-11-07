import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  automationCreateRequest,
  automationEditRequest,
  normalizeAutomationCatalog,
  normalizeAutomationHistory,
  normalizePluginBundle,
  normalizePluginChange,
  normalizePluginInventory,
  normalizePluginInspection,
  normalizePluginVersions,
  pluginSpec
} from '../src/native-admin-protocol.mjs';

test('plugin inventory normalization is bounded and localizes metadata', () => {
  const value = normalizePluginInventory([{
    name: 'dsh.example', official: true, availability: 'profile', enabled: true,
    installed: true, removable: true, updatable: true, optional: false,
    meta: { title: { en: 'Example', zh: '示例' }, description: { en: 'Example bundle' } },
    installTarget: { spec: 'dsh.example@1.0.0', version: '1.0.0' },
    rows: [{ rowId: 'main', moduleName: 'dsh.example/main', meta: { title: 'Main row' } }],
    arbitrarySecret: 'do not forward'
  }, { name: '../bad', availability: 'profile' }], [{
    entryId: 'entry', moduleName: 'dsh.example/main', enabled: true,
    fiberPhase: 'active', meta: { title: 'Main' }, unknown: 'omit'
  }]);
  assert.equal(value.available, true);
  assert.equal(value.bundles.length, 1);
  assert.equal(value.bundles[0].title, '示例');
  assert.equal(value.bundles[0].installVersion, '1.0.0');
  assert.equal(value.bundles[0].rows[0].entryId, undefined);
  assert.equal(Object.hasOwn(value.bundles[0], 'arbitrarySecret'), false);
  assert.equal(value.plugins[0].phase, 'active');
  assert.equal(Object.hasOwn(value.plugins[0], 'unknown'), false);
});

test('malformed plugin bundle and change records are rejected', () => {
  assert.equal(normalizePluginBundle(null), null);
  assert.equal(normalizePluginBundle({ name: 'bundle', availability: 'remote' }), null);
  assert.equal(normalizePluginChange({ application: 'ok', stage: 'install' }), null);
  const changed = normalizePluginChange({
    changed: true, application: 'restart-required', stage: 'enable', target: 'bundle',
    restartReason: 'no-hmr', pendingBuilds: ['native'], error: { code: 'operation-error', diagnostic: 'diagnostic' }
  });
  assert.equal(changed.application, 'restart-required');
  assert.deepEqual(changed.pendingBuilds, ['native']);
  assert.equal(changed.errorCode, 'operation-error');
});

test('plugin inspection and version lists expose only native fields', () => {
  assert.deepEqual(normalizePluginInspection({
    status: 'accepted', kind: 'registry', name: 'bundle', version: '1.0.0',
    bundle: true, registry: 'https://registry.example', token: 'private'
  }), {
    status: 'accepted', kind: 'registry', name: 'bundle', version: '1.0.0',
    description: undefined, bundle: true, registry: 'https://registry.example', host: undefined
  });
  assert.equal(normalizePluginInspection({ status: 'accepted', kind: 'unknown' }), null);
  const versions = normalizePluginVersions({
    status: 'listed', installed: '1.0.0', registry: 'https://registry.example', omitted: 2,
    versions: [{ version: '1.1.0', tags: ['latest'], bundle: true, prerelease: false, secret: 'omit' }]
  });
  assert.equal(versions.versions[0].version, '1.1.0');
  assert.equal(Object.hasOwn(versions.versions[0], 'secret'), false);
});

test('automation normalization sorts active tasks and preserves revision', () => {
  const catalog = normalizeAutomationCatalog([
    {
      id: 'schedule-b', kind: 'every', title: 'Later', prompt: 'work',
      everySeconds: 600, scheduledAt: '2026-11-02T00:10:00.000Z', status: 'active',
      target: { kind: 'session', sessionId: 'session' }, updatedAt: '2026-11-01T00:00:00.000Z'
    },
    {
      id: 'schedule-paused', kind: 'daily', title: 'Paused', prompt: 'work',
      time: '09:00:00.000', timeZone: 'Asia/Shanghai', scheduledAt: '2026-11-03T01:00:00.000Z',
      status: 'paused', target: { kind: 'new', create: {} }, updatedAt: '2026-11-01T02:00:00.000Z'
    },
    {
      id: 'schedule-a', kind: 'cron', title: 'Sooner', prompt: 'work',
      expression: '0 9 * * *', timeZone: 'Asia/Shanghai',
      scheduledAt: '2026-11-02T00:01:00.000Z', status: 'active',
      target: { kind: 'new_once', create: { cwd: '/workspace' } },
      updatedAt: '2026-11-01T00:00:00.000Z'
    }
  ]);
  assert.deepEqual(catalog.items.map(item => item.id), ['schedule-a', 'schedule-b', 'schedule-paused']);
  assert.equal(catalog.items[2].targetCwd, undefined);
});

test('automation history is bounded and cursor remains optional', () => {
  const value = normalizeAutomationHistory({
    id: 'schedule', records: [{
      scheduledAt: '2026-11-01T00:00:00.000Z', deliveredAt: '2026-11-01T00:00:01.000Z',
      messageId: 'message', targetSessionId: 'session', prompt: 'hello'
    }], earlierRecordsUnavailable: false, earlierRecordsPruned: true,
    nextBefore: 'message'
  });
  assert.equal(value.records.length, 1);
  assert.equal(value.nextBefore, 'message');
  assert.equal(value.earlierRecordsPruned, true);
});

test('automation request validation rejects unknown fields and malformed timing', () => {
  assert.equal(pluginSpec('  bundle@1.0.0  '), 'bundle@1.0.0');
  assert.equal(pluginSpec(''), null);
  assert.equal(automationCreateRequest({ title: '', prompt: 'x', timing: { kind: 'every', every_seconds: 60 } }), null);
  assert.equal(automationCreateRequest({
    title: 'Task', prompt: 'Prompt', timing: { kind: 'weekly', weekly: {
      time: '09:00:00', time_zone: 'Asia/Shanghai', weekdays: [1, 1]
    } }, target: { kind: 'new_once' }
  }), null);
  assert.deepEqual(automationEditRequest({
    id: 'schedule-a', action: 'update', expectedUpdatedAt: '2026-11-01T00:00:00.000Z',
    patch: { active: false }
  }), {
    id: 'schedule-a', action: 'update', expectedUpdatedAt: '2026-11-01T00:00:00.000Z',
    patch: { active: false }
  });
  // The phone serializes an absent updatedAt as null; the Host contract is
  // string-or-absent, so null must be dropped exactly like undefined.
  assert.deepEqual(automationEditRequest({ id: 'schedule-a', action: 'delete', expectedUpdatedAt: null }),
    { id: 'schedule-a', action: 'delete' });
  assert.deepEqual(automationEditRequest({ id: 'schedule-a', action: 'delete' }),
    { id: 'schedule-a', action: 'delete' });
});


test('latest open turn start survives a truncated opening window', async () => {
  const { latestOpenTurnStartedAt, latestOpenTurnStartedAtFromRecords } = await import('../src/native-protocol.mjs');
  const open = [
    { eventType: 'turn/start', turn: 1, time: 1000 },
    { eventType: 'user/message', turn: 1, time: 1200 },
    { eventType: 'turn/start', turn: 2, time: 9000 }
  ];
  assert.equal(latestOpenTurnStartedAt(open), 9000);
  assert.equal(latestOpenTurnStartedAt(open.concat([{ eventType: 'turn/end', turn: 2, time: 9500 }])), 0);
  assert.equal(latestOpenTurnStartedAt([{ eventType: 'user/message', turn: 2, time: 9000 }]), 0);
  const records = [
    { event: { type: 'turn/start', seq: 1, time: 7000, data: { turn: 1 } } },
    { event: { type: 'user/message', seq: 2, time: 7100, data: {} } }
  ];
  assert.equal(latestOpenTurnStartedAtFromRecords(records), 7000);
  assert.equal(latestOpenTurnStartedAtFromRecords(records.concat([
    { event: { type: 'turn/end', seq: 3, time: 7200, data: { turn: 1 } } }
  ])), 0);
});