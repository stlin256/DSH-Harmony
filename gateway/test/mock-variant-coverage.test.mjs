import test from 'node:test';
import assert from 'node:assert/strict';
import {
  missingCoverage,
  parseDeclaredList,
  validateMockFeatureManifest,
  verifyMockCoverage,
} from '../../scripts/verify-mock-coverage.mjs';

test('every declared frontend fixture has a Mock capture or interaction driver', () => {
  const result = verifyMockCoverage();
  assert.equal(result.ok, true, result.failures.join('\n'));
  assert.equal(result.screens.covered, result.screens.total);
  assert.equal(result.states.covered, result.states.total);
  assert.equal(result.features.covered, result.features.total);
  assert.ok(result.states.total >= 21);
  assert.ok(result.features.total >= 23);
  assert.ok(result.suitePairs >= 40);
  assert.ok(result.interactionDrivers.includes('device-ui-mode-subagent-e2e.ps1'));
  assert.ok(result.interactionDrivers.includes('device-ui-interaction-e2e.ps1'));
});

test('Mock coverage fails closed when a new declared state has no driver', () => {
  assert.deepEqual(
    missingCoverage(['completed', 'new-feature'], ['completed']),
    ['new-feature'],
  );
  assert.deepEqual(
    parseDeclaredList(
      "static readonly states: string[] = ['one', 'two'];",
      'states',
    ),
    ['one', 'two'],
  );
});

test('Mock feature registry fails closed for an unregistered interaction', () => {
  const result = validateMockFeatureManifest({
    schemaVersion: 1,
    features: [{
      id: 'new.interactive-feature',
      screens: ['conversation'],
      states: ['new-state'],
      drivers: ['device-ui-mock-suite.ps1'],
      e2eIds: ['MF-NEW'],
      requiresInteraction: true,
    }],
  }, ['conversation'], ['new-state'], {
    'device-ui-mock-suite.ps1':
      "Screen = 'conversation'; State = 'new-state'",
  }, '| MF-NEW | Pending |');

  assert.equal(result.ok, false);
  assert.match(result.failures.join('\n'),
    /interactive feature has no interaction driver/);
});
