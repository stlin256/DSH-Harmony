import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  QaUsageError,
  buildSteps,
  parseArgs,
  resolveRunLayout,
  runQa,
  spawnCommand,
} from '../../scripts/qa.mjs';

const quiet = () => {};

test('QA profiles select the required checks in deterministic order', () => {
  const fast = buildSteps('fast');
  assert.deepEqual(fast.map((step) => step.id), [
    'diff-check',
    'protocol-lock',
    'mock-coverage',
    'keyboard-avoidance',
    'product-variants',
    'publication-working-tree',
    'powershell-encoding',
  ]);
  assert.deepEqual(fast[5].args, [
    'scripts/check-publication.mjs',
    '--working-tree',
  ]);
  assert.deepEqual(fast[6].args, ['scripts/verify-powershell-encoding.mjs']);

  const pr = buildSteps('pr');
  assert.deepEqual(
    pr.map((step) => step.id),
    [...fast.map((step) => step.id), 'gateway-tests'],
  );
  assert.equal(pr.at(-1).command, 'npm');
  assert.deepEqual(pr.at(-1).args, ['test']);
  assert.equal(pr.at(-1).cwd, 'gateway');

  const evidence = join('evidence', 'run.json');
  const release = buildSteps('release', { evidencePath: evidence });
  assert.deepEqual(
    release.map((step) => step.id),
    [...pr.map((step) => step.id), 'release-evidence'],
  );
  assert.deepEqual(release.at(-1).args.slice(0, 3), [
    'scripts/verify-evidence.mjs',
    '--release',
    evidence,
  ]);
});

test('QA CLI arguments reject unsupported profiles and misplaced evidence', () => {
  assert.deepEqual(parseArgs(['release', '--evidence', 'run.json']), {
    help: false,
    profile: 'release',
    evidence: resolvePath('run.json'),
  });
  assert.throws(
    () => parseArgs(['pr', '--evidence', 'run.json']),
    QaUsageError,
  );
  assert.throws(() => parseArgs(['release']), QaUsageError);
  assert.throws(() => parseArgs(['device']), QaUsageError);
  assert.throws(() => parseArgs(['release', '--evidence']), QaUsageError);
  assert.throws(() => parseArgs(['fast', '--unknown']), QaUsageError);
});

test('QA run paths stay under .artifacts/qa', () => {
  const root = join(tmpdir(), 'qa-root');
  const layout = resolveRunLayout(root, '20261101T010203Z-run');
  assert.equal(
    layout.reportPath,
    join(root, '.artifacts', 'qa', '20261101T010203Z-run', 'report.json'),
  );
  assert.throws(() => resolveRunLayout(root, '../escape'), QaUsageError);
  assert.throws(() => resolveRunLayout(root, 'nested/run'), QaUsageError);
  assert.throws(
    () => resolveRunLayout(root, 'outside-root', '../outside'),
    QaUsageError,
  );
  const ciLayout = resolveRunLayout(root, 'ci-run', 'artifacts/qa');
  assert.equal(
    ciLayout.reportPath,
    join(root, 'artifacts', 'qa', 'ci-run', 'report.json'),
  );
});

test('QA writes per-step logs and an aggregate report', async (t) => {
  const root = await mkdtemp(join(tmpdir(), 'dsh-qa-pass-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const calls = [];

  const report = await runQa({
    profile: 'fast',
    root,
    runId: 'pass-run',
    metadataProvider: async () => ({ node: 'test' }),
    runCommand: async (execution) => {
      calls.push(execution.step.id);
      await execution.onStdout(Buffer.from(`${execution.step.id} stdout`));
      await execution.onStderr(Buffer.from(`${execution.step.id} stderr`));
      return { exitCode: 0, error: null };
    },
    log: quiet,
  });

  assert.equal(report.status, 'passed');
  assert.equal(report.exitCode, 0);
  assert.equal(calls.length, 7);
  assert.equal(report.steps.length, 7);
  assert.equal(report.steps[0].stdout, 'diff-check.stdout.log');
  assert.equal(report.steps[0].stderr, 'diff-check.stderr.log');

  const reportPath = join(root, '.artifacts', 'qa', 'pass-run', 'report.json');
  assert.equal(existsSync(reportPath), true);
  const persisted = JSON.parse(await readFile(reportPath, 'utf8'));
  assert.equal(persisted.profile, 'fast');
  assert.equal(persisted.status, 'passed');
  assert.equal(
    await readFile(
      join(root, '.artifacts', 'qa', 'pass-run', 'diff-check.stdout.log'),
      'utf8',
    ),
    'diff-check stdout',
  );
});

test('QA continues after failure and returns a failing report', async (t) => {
  const root = await mkdtemp(join(tmpdir(), 'dsh-qa-fail-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const calls = [];

  const report = await runQa({
    profile: 'fast',
    root,
    runId: 'fail-run',
    metadataProvider: async () => ({ node: 'test' }),
    runCommand: async (execution) => {
      calls.push(execution.step.id);
      if (execution.step.id === 'protocol-lock') {
        await execution.onStderr(Buffer.from('protocol mismatch'));
        return { exitCode: 7, error: null };
      }
      return { exitCode: 0, error: null };
    },
    log: quiet,
  });

  assert.equal(report.status, 'failed');
  assert.equal(report.exitCode, 1);
  assert.equal(calls.length, 7);
  assert.equal(report.steps[1].status, 'failed');
  assert.equal(report.steps[1].exitCode, 7);
  assert.equal(report.steps[5].status, 'passed');
  assert.equal(
    await readFile(
      join(root, '.artifacts', 'qa', 'fail-run', 'protocol-lock.stderr.log'),
      'utf8',
    ),
    'protocol mismatch',
  );
});

test('QA records command launch errors as failures', async (t) => {
  const root = await mkdtemp(join(tmpdir(), 'dsh-qa-error-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const calls = [];

  const report = await runQa({
    profile: 'fast',
    root,
    runId: 'error-run',
    metadataProvider: async () => ({ node: 'test' }),
    runCommand: async (execution) => {
      calls.push(execution.step.id);
      if (execution.step.id === 'diff-check') {
        throw new Error('spawn unavailable');
      }
      return { exitCode: 0, error: null };
    },
    log: quiet,
  });

  assert.equal(report.status, 'failed');
  assert.equal(report.steps[0].status, 'failed');
  assert.equal(calls.length, 7);
  assert.match(
    await readFile(
      join(root, '.artifacts', 'qa', 'error-run', 'diff-check.stderr.log'),
      'utf8',
    ),
    /spawn unavailable/,
  );
});

test('QA default command runner captures actual process output', async (t) => {
  const root = await mkdtemp(join(tmpdir(), 'dsh-qa-spawn-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const stdout = [];
  const stderr = [];

  const result = await spawnCommand({
    step: {
      command: process.execPath,
      args: ['-e', 'process.stdout.write("out"); process.stderr.write("err")'],
    },
    cwd: root,
    onStdout: (chunk) => stdout.push(Buffer.from(chunk)),
    onStderr: (chunk) => stderr.push(Buffer.from(chunk)),
  });

  assert.equal(result.exitCode, 0);
  assert.equal(Buffer.concat(stdout).toString(), 'out');
  assert.equal(Buffer.concat(stderr).toString(), 'err');
});

function resolvePath(value) {
  return parseArgs(['release', '--evidence', value]).evidence;
}
