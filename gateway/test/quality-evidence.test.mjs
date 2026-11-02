import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  driverMentionsState,
  validateMockFeatureManifest,
} from '../../scripts/verify-mock-coverage.mjs';
import {
  loadProtocolLock,
  validateEvidence,
} from '../../scripts/verify-evidence.mjs';

const repoRoot = fileURLToPath(new URL('../..', import.meta.url));
const commit = 'a'.repeat(40);
const hapSha256 = 'b'.repeat(64);
const artifactSha256 = 'c'.repeat(64);
const protocolLock = {
  canonicalRevision: commit,
  packageVersion: '0.2.2-alpha.2',
  wireProtocolVersion: 2,
};
const evidenceTime = '2026-11-01T02:00:00.000Z';
const evidenceNow = new Date('2026-11-01T02:10:00.000Z');
const hapRelativePath = '.artifacts/mock/entry-mock-signed.hap';
const artifactRelativePath = 'completed-dark-conversation/layout.json';

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function releaseFixture() {
  const root = mkdtempSync(join(tmpdir(), 'dsh-evidence-'));
  const hapPath = join(root, hapRelativePath);
  const artifactPath = join(root, artifactRelativePath);
  mkdirSync(join(root, '.artifacts', 'mock'), { recursive: true });
  mkdirSync(join(root, 'completed-dark-conversation'), { recursive: true });
  writeFileSync(hapPath, Buffer.concat([
    Buffer.from([0x50, 0x4b, 0x03, 0x04]),
    Buffer.alloc(18),
    Buffer.from([0x50, 0x4b, 0x05, 0x06]),
    Buffer.alloc(18),
  ]));
  writeFileSync(artifactPath, '{"synthetic":"layout"}');
  return {
    root,
    hapSha256: sha256(readFileSync(hapPath)),
    artifactSha256: sha256(readFileSync(artifactPath)),
    options: {
      protocolLock,
      release: true,
      root,
      actualGit: { commit, dirty: false },
      now: evidenceNow,
    },
    cleanup() {
      rmSync(root, { recursive: true, force: true });
    },
  };
}

function releaseOptions(overrides = {}) {
  return {
    protocolLock,
    release: true,
    actualGit: { commit, dirty: false },
    now: evidenceNow,
    ...overrides,
  };
}

function minimalEvidence(overrides = {}) {
  const evidence = {
    schemaVersion: 1,
    runId: 'run-20261101-001',
    generatedAt: evidenceTime,
    git: {
      commit,
      dirty: false,
    },
    upstream: {
      commit,
      version: '0.2.2-alpha.2',
    },
    scope: {
      featureIds: ['conversation.completed-turn'],
      scenarioId: 'completed-dark-conversation',
    },
    product: 'mock',
    hap: {
      path: hapRelativePath,
      sha256: hapSha256,
    },
    device: {
      serial: 'device-1',
      model: 'test-device',
      api: 26,
      orientation: 'portrait',
    },
    status: 'passed',
    steps: [{
      id: 'launch-and-assert-conversation',
      status: 'passed',
      mandatory: true,
      assertions: ['completed conversation and composer are visible'],
      durationMs: 1200,
      metrics: [{
        name: 'startupToReadableMs',
        value: 170,
        unit: 'ms',
        status: 'passed',
        threshold: {
          operator: 'lte',
          value: 200,
        },
      }],
    }],
    metrics: [{
      name: 'coldReadableMs',
      value: 180,
      unit: 'ms',
      status: 'passed',
      threshold: {
        operator: 'lte',
        value: 200,
      },
    }],
    artifacts: [{
      kind: 'layout',
      path: artifactRelativePath,
      sha256: artifactSha256,
    }],
  };
  return { ...evidence, ...overrides };
}

test('comment-only Mock state and commands do not satisfy interaction coverage', () => {
  assert.equal(driverMentionsState(
    "# Launch-Fixture -State 'comment-only'\nWrite-Output 'comment-only'\n",
    'comment-only',
  ), false);
  assert.equal(driverMentionsState(
    "Launch-Fixture -State 'real-state'\n",
    'real-state',
  ), true);
  assert.equal(driverMentionsState(
    "<# State = 'block-comment' #>\n",
    'block-comment',
  ), false);

  const result = validateMockFeatureManifest({
    schemaVersion: 1,
    features: [{
      id: 'new.interactive-feature',
      screens: ['conversation'],
      states: ['new-state'],
      drivers: ['device-ui-mock-suite.ps1', 'new-interaction-e2e.ps1'],
      e2eIds: ['MF-NEW'],
      requiresInteraction: true,
    }],
  }, ['conversation'], ['new-state'], {
    'device-ui-mock-suite.ps1':
      "Screen = 'conversation'; State = 'new-state'",
    'new-interaction-e2e.ps1': [
      "# Launch-Fixture -State 'new-state'",
      '# & $hdc shell "uitest uiInput click 1 2"',
      "# $null = Query-Node $layout 'expected text'",
    ].join('\n'),
  }, '| MF-NEW | Passed |');

  assert.equal(result.ok, false);
  assert.match(
    result.failures.join('\n'),
    /new-interaction-e2e\.ps1 has no interaction command/,
  );
  assert.match(
    result.failures.join('\n'),
    /new-interaction-e2e\.ps1 has no assertion command/,
  );
});

test('a real interaction and assertion command satisfy an interactive feature', () => {
  const result = validateMockFeatureManifest({
    schemaVersion: 1,
    features: [{
      id: 'new.interactive-feature',
      screens: ['conversation'],
      states: ['new-state'],
      drivers: ['device-ui-mock-suite.ps1', 'new-interaction-e2e.ps1'],
      e2eIds: ['MF-NEW'],
      requiresInteraction: true,
    }],
  }, ['conversation'], ['new-state'], {
    'device-ui-mock-suite.ps1':
      "Screen = 'conversation'; State = 'new-state'",
    'new-interaction-e2e.ps1': [
      "Launch-Fixture -State 'new-state'",
      '& $hdc shell "uitest uiInput click 1 2"',
      "$null = Query-Node $layout 'expected text'",
    ].join('\n'),
  }, '| MF-NEW | Passed |');

  assert.equal(result.ok, true, result.failures.join('\n'));

  const unrelated = validateMockFeatureManifest({
    schemaVersion: 1,
    features: [{
      id: 'new.interactive-feature',
      screens: ['conversation'],
      states: ['new-state'],
      drivers: ['device-ui-mock-suite.ps1', 'new-interaction-e2e.ps1'],
      e2eIds: ['MF-NEW'],
      requiresInteraction: true,
    }],
  }, ['conversation'], ['new-state'], {
    'device-ui-mock-suite.ps1':
      "Screen = 'conversation'; State = 'new-state'",
    'new-interaction-e2e.ps1': [
      "Launch-Fixture -State 'other-state'",
      '& $hdc shell "uitest uiInput click 1 2"',
      "$null = Query-Node $layout 'expected text'",
    ].join('\n'),
  }, '| MF-NEW | Passed |');
  assert.equal(unrelated.ok, false);
  assert.match(
    unrelated.failures.join('\n'),
    /does not reference a feature state/,
  );
});

test('unused interaction helper declarations do not count as execution', () => {
  const result = validateMockFeatureManifest({
    schemaVersion: 1,
    features: [{
      id: 'new.interactive-feature',
      screens: ['conversation'],
      states: ['new-state'],
      drivers: ['device-ui-mock-suite.ps1', 'new-interaction-e2e.ps1'],
      e2eIds: ['MF-NEW'],
      requiresInteraction: true,
    }],
  }, ['conversation'], ['new-state'], {
    'device-ui-mock-suite.ps1':
      "Screen = 'conversation'; State = 'new-state'",
    'new-interaction-e2e.ps1': [
      'function Invoke-Click {',
      '  & $hdc shell "uitest uiInput click 1 2"',
      '}',
      'function Query-Node {',
      "  $null = Query-Node $layout 'expected text'",
      '}',
    ].join('\n'),
  }, '| MF-NEW | Passed |');

  assert.equal(result.ok, false);
  assert.match(
    result.failures.join('\n'),
    /new-interaction-e2e\.ps1 has no interaction command/,
  );
  assert.match(
    result.failures.join('\n'),
    /new-interaction-e2e\.ps1 has no assertion command/,
  );
});

test('a complete clean evidence manifest passes normal and release validation', t => {
  const fixture = releaseFixture();
  t.after(fixture.cleanup);
  const evidence = minimalEvidence({
    hap: {
      path: hapRelativePath,
      sha256: fixture.hapSha256,
    },
    artifacts: [{
      kind: 'layout',
      path: artifactRelativePath,
      sha256: fixture.artifactSha256,
    }],
  });
  const normal = validateEvidence(evidence, { protocolLock });
  const release = validateEvidence(evidence, {
    ...fixture.options,
  });

  assert.equal(normal.ok, true, normal.errors.join('\n'));
  assert.deepEqual(normal.errors, []);
  assert.equal(release.ok, true, release.errors.join('\n'));
  assert.deepEqual(release.warnings, []);
  assert.equal(release.summary.api, 26);

  const optionalOnly = validateEvidence(minimalEvidence({
    steps: [{
      id: 'optional-step',
      status: 'skipped',
      mandatory: false,
      assertions: ['optional assertion'],
    }],
    hap: evidence.hap,
    artifacts: evidence.artifacts,
  }), fixture.options);
  assert.equal(optionalOnly.ok, false);
  assert.match(
    optionalOnly.errors.join('\n'),
    /requires at least one mandatory step/,
  );

  writeFileSync(join(fixture.root, hapRelativePath), 'not a HAP container');
  const fakeHap = validateEvidence(minimalEvidence({
    hap: {
      path: hapRelativePath,
      sha256: sha256(readFileSync(join(fixture.root, hapRelativePath))),
    },
    artifacts: evidence.artifacts,
  }), fixture.options);
  assert.equal(fakeHap.ok, false);
  assert.match(fakeHap.errors.join('\n'), /is not a ZIP\/HAP container/);
});

test('evidence identity resolves the checked-in protocol lock shape', t => {
  const lock = loadProtocolLock(repoRoot);
  const fixture = releaseFixture();
  t.after(fixture.cleanup);
  const evidence = minimalEvidence({
    git: {
      commit: lock.canonicalRevision,
      dirty: false,
    },
    upstream: {
      commit: lock.canonicalRevision,
      version: lock.packageVersion,
    },
    hap: {
      path: hapRelativePath,
      sha256: fixture.hapSha256,
    },
    artifacts: [{
      kind: 'layout',
      path: artifactRelativePath,
      sha256: fixture.artifactSha256,
    }],
  });
  const result = validateEvidence(evidence, {
    ...fixture.options,
    protocolLock: lock,
    actualGit: { commit: lock.canonicalRevision, dirty: false },
  });

  assert.equal(result.ok, true, result.errors.join('\n'));
});

test('release validation rejects fabricated file hashes and stale evidence', t => {
  const fixture = releaseFixture();
  t.after(fixture.cleanup);
  const fabricated = minimalEvidence({
    hap: {
      path: hapRelativePath,
      sha256: 'f'.repeat(64),
    },
    artifacts: [{
      kind: 'layout',
      path: artifactRelativePath,
      sha256: 'e'.repeat(64),
    }],
  });
  const result = validateEvidence(fabricated, fixture.options);
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /hap\.path SHA-256 does not match/);
  assert.match(result.errors.join('\n'), /artifacts\[0\]\.path SHA-256 does not match/);

  const stale = validateEvidence(minimalEvidence({
    hap: {
      path: hapRelativePath,
      sha256: fixture.hapSha256,
    },
    artifacts: [{
      kind: 'layout',
      path: artifactRelativePath,
      sha256: fixture.artifactSha256,
    }],
  }), {
    ...fixture.options,
    now: new Date('2026-11-03T02:00:00.000Z'),
  });
  assert.equal(stale.ok, false);
  assert.match(stale.errors.join('\n'), /release evidence is stale/);
});

test('release validation rejects dirty evidence but normal validation records it', () => {
  const evidence = minimalEvidence({
    git: {
      commit,
      dirty: true,
    },
  });
  const normal = validateEvidence(evidence, { protocolLock });
  const release = validateEvidence(evidence, releaseOptions());

  assert.equal(normal.ok, true, normal.errors.join('\n'));
  assert.equal(release.ok, false);
  assert.match(release.errors.join('\n'), /git\.dirty=false/);
});

test('release validation rejects pending steps and incomplete hashes', () => {
  const evidence = minimalEvidence({
    status: 'pending',
    hap: {
      path: '.artifacts/mock/entry-mock-signed.hap',
      sha256: null,
    },
    steps: [{
      id: 'launch-and-assert-conversation',
      status: 'pending',
      mandatory: true,
      assertions: ['completed conversation is visible'],
      metrics: [{
        name: 'startupToReadableMs',
        value: 0,
        unit: 'ms',
        status: 'not_run',
      }],
    }],
    artifacts: [{
      kind: 'layout',
      path: 'completed-dark-conversation/layout.json',
      sha256: null,
    }],
  });
  const normal = validateEvidence(evidence, { protocolLock });
  const release = validateEvidence(evidence, releaseOptions());
  const errors = release.errors.join('\n');

  assert.equal(normal.ok, true, normal.errors.join('\n'));
  assert.ok(normal.warnings.includes('hap.sha256 is incomplete'));
  assert.ok(normal.warnings.includes('artifacts[0].sha256 is incomplete'));
  assert.equal(release.ok, false);
  assert.match(errors, /requires status=passed/);
  assert.match(errors, /step launch-and-assert-conversation is not passed/);
  assert.match(errors, /metric startupToReadableMs is not_run/);
  assert.match(errors, /requires a complete HAP SHA-256/);
  assert.match(errors, /artifacts\[0\]\.sha256 is required for release evidence/);
});

test('evidence validation rejects stale upstream locks and failed metric thresholds', () => {
  const stale = minimalEvidence({
    upstream: {
      commit,
      version: '0.2.1',
    },
  });
  const staleResult = validateEvidence(stale, { protocolLock });
  assert.equal(staleResult.ok, false);
  assert.match(
    staleResult.errors.join('\n'),
    /upstream\.version does not match the protocol lock/,
  );

  const failedMetric = minimalEvidence({
    metrics: [{
      name: 'coldReadableMs',
      value: 260,
      unit: 'ms',
      status: 'passed',
      threshold: {
        operator: 'lte',
        value: 200,
      },
    }],
  });
  const metricResult = validateEvidence(failedMetric, { protocolLock });
  assert.equal(metricResult.ok, false);
  assert.match(
    metricResult.errors.join('\n'),
    /marked passed but does not satisfy its threshold/,
  );
});

test('evidence schema is versioned and contains the release-critical contract', () => {
  const schemaPath = join(
    repoRoot,
    'docs/testing/evidence-manifest.schema.json',
  );
  const schema = JSON.parse(readFileSync(schemaPath, 'utf8'));

  assert.equal(schema.$schema, 'https://json-schema.org/draft/2020-12/schema');
  assert.equal(schema.properties.schemaVersion.const, 1);
  for (const field of [
    'git', 'upstream', 'product', 'hap', 'device', 'steps', 'metrics',
    'artifacts',
  ]) {
    assert.ok(schema.required.includes(field), `${field} must be required`);
  }
  assert.equal(schema.$defs.artifact.required.includes('sha256'), true);
  assert.equal(schema.$defs.metric.required.includes('status'), true);
});
