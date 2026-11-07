import { spawn, spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import {
  mkdir,
  open,
  rename,
  rm,
  writeFile,
} from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
export const DEFAULT_ROOT = resolve(scriptDir, '..');
export const DEFAULT_ARTIFACT_DIRECTORY = '.artifacts/qa';
export const SCHEMA_VERSION = 1;
export const PROFILES = Object.freeze(['fast', 'pr', 'release']);

const FAST_STEPS = Object.freeze([
  {
    id: 'diff-check',
    label: 'Git diff hygiene',
    command: 'git',
    args: ['diff', '--check'],
    cwd: '.',
  },
  {
    id: 'protocol-lock',
    label: 'Protocol lock',
    command: process.execPath,
    args: ['scripts/verify-protocol-lock.mjs'],
    cwd: '.',
  },
  {
    id: 'mock-coverage',
    label: 'Mock mapping coverage',
    command: process.execPath,
    args: ['scripts/verify-mock-coverage.mjs'],
    cwd: '.',
  },
  {
    id: 'keyboard-avoidance',
    label: 'Keyboard avoidance source contract',
    command: process.execPath,
    args: ['scripts/verify-keyboard-avoidance.mjs'],
    cwd: '.',
  },
  {
    id: 'product-variants',
    label: 'Product variant contracts',
    command: process.execPath,
    args: ['scripts/verify-harmony-product-variants.mjs'],
    cwd: '.',
  },
  {
    id: 'publication-working-tree',
    label: 'Publication working-tree scan',
    command: process.execPath,
    args: ['scripts/check-publication.mjs', '--working-tree'],
    cwd: '.',
  },
  {
    id: 'powershell-encoding',
    label: 'PowerShell script encoding',
    command: process.execPath,
    args: ['scripts/verify-powershell-encoding.mjs'],
    cwd: '.',
  },
]);

const GATEWAY_TESTS_STEP = Object.freeze({
  id: 'gateway-tests',
  label: 'Gateway test suite',
  command: 'npm',
  args: ['test'],
  cwd: 'gateway',
  usesNpm: true,
});

const EVIDENCE_STEP = Object.freeze({
  id: 'release-evidence',
  label: 'Release evidence',
  command: process.execPath,
  args: ['scripts/verify-evidence.mjs', '--release'],
  cwd: '.',
  evidenceArgument: true,
});

export class QaUsageError extends Error {}

export function parseArgs(argv) {
  let profile;
  let evidence;
  let help = false;

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--help' || argument === '-h') {
      help = true;
      continue;
    }
    if (argument === '--evidence' || argument.startsWith('--evidence=')) {
      if (evidence !== undefined) {
        throw new QaUsageError('--evidence may only be specified once');
      }
      if (argument === '--evidence') {
        const value = argv[index + 1];
        if (!value || value.startsWith('-')) {
          throw new QaUsageError('--evidence requires a manifest path');
        }
        evidence = value;
        index += 1;
      } else {
        evidence = argument.slice('--evidence='.length);
        if (!evidence) {
          throw new QaUsageError('--evidence requires a manifest path');
        }
      }
      continue;
    }
    if (argument.startsWith('-')) {
      throw new QaUsageError(`unknown option: ${argument}`);
    }
    if (profile !== undefined) {
      throw new QaUsageError(`unexpected argument: ${argument}`);
    }
    profile = argument;
  }

  if (help) return { help: true, profile: null, evidence: null };
  if (!PROFILES.includes(profile)) {
    throw new QaUsageError(
      `profile must be one of: ${PROFILES.join(', ')}`,
    );
  }
  if (profile === 'release' && !evidence) {
    throw new QaUsageError('release requires --evidence <manifest>');
  }
  if (evidence && profile !== 'release') {
    throw new QaUsageError('--evidence is only valid with the release profile');
  }

  return {
    help: false,
    profile,
    evidence: evidence ? resolve(evidence) : null,
  };
}

export function usage() {
  return [
    'Usage: node scripts/qa.mjs <fast|pr|release> [--evidence <manifest>]',
    '',
    'Profiles:',
    '  fast     Portable static, publication, protocol and mapping checks',
    '  pr       fast checks plus the full gateway test suite',
    '  release  pr checks plus mandatory evidence validation',
  ].join('\n');
}

function cloneStep(step, evidencePath) {
  const args = [...step.args];
  if (step.evidenceArgument) args.push(evidencePath);
  return { ...step, args };
}

export function buildSteps(profile, { evidencePath = null } = {}) {
  if (!PROFILES.includes(profile)) {
    throw new QaUsageError(`unknown profile: ${profile}`);
  }
  if (evidencePath && profile !== 'release') {
    throw new QaUsageError('evidence can only be added to the release profile');
  }
  if (profile === 'release' && !evidencePath) {
    throw new QaUsageError('the release profile requires an evidence manifest');
  }

  const steps = FAST_STEPS.map((step) => cloneStep(step, evidencePath));
  if (profile === 'pr' || profile === 'release') {
    steps.push(cloneStep(GATEWAY_TESTS_STEP, evidencePath));
  }
  if (profile === 'release' && evidencePath) {
    steps.push(cloneStep(EVIDENCE_STEP, evidencePath));
  }
  return steps;
}

function safeRunId(runId) {
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(runId) || runId.includes('..')) {
    throw new QaUsageError(`invalid run id: ${runId}`);
  }
  return runId;
}

export function createRunId(now = new Date()) {
  const timestamp = now.toISOString()
    .replaceAll('-', '')
    .replaceAll(':', '')
    .replace(/\.\d{3}Z$/, 'Z');
  return `${timestamp}-${randomUUID().slice(0, 8)}`;
}

export function resolveRunLayout(
  root,
  runId,
  artifactDirectory = DEFAULT_ARTIFACT_DIRECTORY,
) {
  const absoluteRoot = resolve(root);
  const safeId = safeRunId(runId);
  const qaRoot = resolve(absoluteRoot, artifactDirectory);
  const runDir = resolve(qaRoot, safeId);
  const relativeQaRoot = relative(absoluteRoot, qaRoot);
  if (relativeQaRoot.startsWith('..') || resolve(absoluteRoot, relativeQaRoot) !== qaRoot) {
    throw new QaUsageError('QA artifact root escapes the repository');
  }
  if (relative(qaRoot, runDir).startsWith('..')) {
    throw new QaUsageError('run directory escapes the QA artifact root');
  }
  return {
    root: absoluteRoot,
    runDir,
    reportPath: join(runDir, 'report.json'),
  };
}

function quoted(argument) {
  return /^[A-Za-z0-9_./:=+-]+$/.test(argument)
    ? argument
    : JSON.stringify(argument);
}

function commandDisplay(step) {
  if (step.command === process.execPath) {
    return ['node', ...step.args.map(quoted)].join(' ');
  }
  return [step.command, ...step.args.map(quoted)].join(' ');
}

function relativeLogPath(runDir, path) {
  return relative(runDir, path).replaceAll('\\', '/');
}

function gitValue(root, args) {
  const result = spawnSync('git', args, {
    cwd: root,
    encoding: 'utf8',
    timeout: 10_000,
    windowsHide: true,
  });
  return result.status === 0 ? result.stdout.trim() : null;
}

export function collectMetadata(root) {
  const status = gitValue(root, ['status', '--porcelain=v1']);
  return {
    node: process.version,
    platform: process.platform,
    arch: process.arch,
    git: {
      head: gitValue(root, ['rev-parse', 'HEAD']),
      branch: gitValue(root, ['branch', '--show-current']),
      dirty: status === null ? null : status.length > 0,
    },
  };
}

function npmCliPath() {
  const candidates = [
    process.env.npm_execpath,
    resolve(dirname(process.execPath), 'node_modules/npm/bin/npm-cli.js'),
    resolve(dirname(process.execPath), '../lib/node_modules/npm/bin/npm-cli.js'),
  ].filter(Boolean);
  return candidates.find((candidate) => existsSync(candidate)) || null;
}

export function spawnCommand({ step, cwd, onStdout, onStderr }) {
  let command = step.command;
  let args = [...step.args];

  if (step.usesNpm) {
    const cli = npmCliPath();
    if (!cli) {
      throw new Error('npm CLI was not found next to Node.js or on PATH');
    }
    command = process.execPath;
    args = [cli, ...args];
  }

  return new Promise((resolveResult) => {
    let settled = false;
    const finish = (exitCode, error = null) => {
      if (settled) return;
      settled = true;
      resolveResult({ exitCode, error });
    };

    let child;
    try {
      child = spawn(command, args, {
        cwd,
        env: process.env,
        windowsHide: true,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch (error) {
      finish(null, error);
      return;
    }

    child.stdout.on('data', (chunk) => {
      void onStdout(chunk);
    });
    child.stderr.on('data', (chunk) => {
      void onStderr(chunk);
    });
    child.on('error', (error) => finish(null, error));
    child.on('close', (code, signal) => {
      if (signal) {
        finish(null, new Error(`step terminated by signal ${signal}`));
      } else {
        finish(code, null);
      }
    });
  });
}

async function writeReport(reportPath, report) {
  const temporary = `${reportPath}.tmp-${process.pid}`;
  await writeFile(temporary, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  await rename(temporary, reportPath);
}

function displayEvidencePath(root, evidencePath) {
  if (!evidencePath) return null;
  const value = relative(root, evidencePath).replaceAll('\\', '/');
  return value.startsWith('..') ? '<external manifest>' : value;
}

export async function runQa({
  profile,
  evidencePath = null,
  root = DEFAULT_ROOT,
  runId = createRunId(),
  runCommand = spawnCommand,
  metadataProvider = collectMetadata,
  log = console.log,
  artifactDirectory = process.env.DSH_QA_ARTIFACT_DIR || DEFAULT_ARTIFACT_DIRECTORY,
} = {}) {
  const layout = resolveRunLayout(root, runId, artifactDirectory);
  const evidence = evidencePath ? resolve(evidencePath) : null;
  const steps = buildSteps(profile, { evidencePath: evidence });
  await mkdir(layout.runDir, { recursive: true });

  const startedAt = new Date();
  const startedMs = Date.now();
  const metadata = await metadataProvider(layout.root);
  const report = {
    schemaVersion: SCHEMA_VERSION,
    runId,
    profile,
    status: 'running',
    exitCode: null,
    startedAt: startedAt.toISOString(),
    finishedAt: null,
    durationMs: null,
    metadata,
    options: {
      evidence: displayEvidencePath(layout.root, evidence),
    },
    steps: [],
  };
  await writeReport(layout.reportPath, report);

  for (const [index, step] of steps.entries()) {
    const stdoutPath = join(layout.runDir, `${step.id}.stdout.log`);
    const stderrPath = join(layout.runDir, `${step.id}.stderr.log`);
    const stdout = await open(stdoutPath, 'w');
    const stderr = await open(stderrPath, 'w');
    const stepStartedAt = new Date();
    const stepStartedMs = Date.now();
    let stdoutQueue = Promise.resolve();
    let stderrQueue = Promise.resolve();
    let stderrBytes = 0;

    log(`[qa] ${index + 1}/${steps.length} ${step.label}`);
    const writeStdout = (chunk) => {
      stdoutQueue = stdoutQueue.then(() => stdout.write(chunk));
    };
    const writeStderr = (chunk) => {
      stderrBytes += chunk.length;
      stderrQueue = stderrQueue.then(() => stderr.write(chunk));
    };

    let result;
    try {
      result = await runCommand({
        step,
        cwd: resolve(layout.root, step.cwd),
        onStdout: writeStdout,
        onStderr: writeStderr,
      });
    } catch (error) {
      result = { exitCode: null, error };
    }

    if (result?.error) {
      const message = `${result.error.stack || result.error}\n`;
      writeStderr(Buffer.from(message));
    }
    await stdoutQueue;
    await stderrQueue;
    await stdout.close();
    await stderr.close();

    const passed = result?.exitCode === 0;
    const stepReport = {
      id: step.id,
      label: step.label,
      command: commandDisplay(step),
      cwd: step.cwd,
      status: passed ? 'passed' : 'failed',
      exitCode: result?.exitCode ?? null,
      startedAt: stepStartedAt.toISOString(),
      finishedAt: new Date().toISOString(),
      durationMs: Date.now() - stepStartedMs,
      stdout: relativeLogPath(layout.runDir, stdoutPath),
      stderr: relativeLogPath(layout.runDir, stderrPath),
      stderrBytes,
    };
    report.steps.push(stepReport);
    report.status = report.steps.some((entry) => entry.status === 'failed')
      ? 'failed'
      : 'running';
    await writeReport(layout.reportPath, report);
    log(`[qa] ${passed ? 'passed' : 'FAILED'}: ${step.label} (${stepReport.durationMs}ms)`);
  }

  const finishedAt = new Date();
  report.status = report.steps.every((step) => step.status === 'passed')
    ? 'passed'
    : 'failed';
  report.exitCode = report.status === 'passed' ? 0 : 1;
  report.finishedAt = finishedAt.toISOString();
  report.durationMs = Date.now() - startedMs;
  await writeReport(layout.reportPath, report);
  log(`[qa] ${report.status}: ${layout.reportPath}`);
  return report;
}

export async function main(argv = process.argv.slice(2), dependencies = {}) {
  let options;
  try {
    options = parseArgs(argv);
  } catch (error) {
    if (!(error instanceof QaUsageError)) throw error;
    console.error(`[qa] ${error.message}\n\n${usage()}`);
    return 2;
  }

  if (options.help) {
    console.log(usage());
    return 0;
  }

  try {
    const report = await runQa({
      profile: options.profile,
      evidencePath: options.evidence,
      ...dependencies,
    });
    return report.exitCode;
  } catch (error) {
    console.error(`[qa] ${error.stack || error}`);
    return 1;
  }
}

if (process.argv[1] &&
    import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  process.exitCode = await main();
}
