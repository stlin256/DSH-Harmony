import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import {
  lstatSync,
  readFileSync,
  realpathSync,
} from 'node:fs';
import {
  dirname,
  isAbsolute,
  join,
  relative,
  resolve,
  win32,
} from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const defaultRoot = resolve(scriptDir, '..');
const gitCommitPattern = /^[0-9a-f]{40}(?:[0-9a-f]{24})?$/;
const sha256Pattern = /^[0-9a-f]{64}$/;
const isoDateTimePattern =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/;
const defaultMaximumEvidenceAgeMs = 24 * 60 * 60 * 1000;
const futureClockSkewMs = 5 * 60 * 1000;
const overallStatuses = new Set([
  'passed', 'failed', 'pending', 'blocked', 'not_run',
]);
const stepStatuses = new Set([
  'passed', 'failed', 'pending', 'blocked', 'not_run', 'skipped',
]);
const metricStatuses = new Set([
  'passed', 'failed', 'pending', 'blocked', 'not_run', 'skipped',
]);
const releaseBlockingStatuses = new Set([
  'pending', 'blocked', 'not_run', 'failed',
]);
const thresholdOperators = new Set(['lt', 'lte', 'eq', 'gte', 'gt']);
const artifactKinds = new Set([
  'screenshot', 'layout', 'log', 'report', 'metrics', 'video', 'other',
]);

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function isSafeRelativePath(value) {
  if (!isNonEmptyString(value) ||
      /[\u0000-\u001f\u007f]/.test(value) ||
      isAbsolute(value) ||
      win32.isAbsolute(value) ||
      /^[A-Za-z]:/.test(value) ||
      value.includes('\\')) {
    return false;
  }
  const parts = value.split('/');
  return parts.every((part) => part !== '' && part !== '.' && part !== '..');
}

function isStrictDateTime(value) {
  return typeof value === 'string' &&
    isoDateTimePattern.test(value) &&
    !Number.isNaN(Date.parse(value));
}

function rejectUnknownFields(value, allowedFields, path, errors) {
  if (!isObject(value)) return;
  for (const key of Object.keys(value)) {
    if (!allowedFields.has(key)) {
      errors.push(`${path}.${key} is not supported`);
    }
  }
}

function protocolIdentity(lock) {
  return {
    commit: lock?.canonicalRevision ?? lock?.pinnedCommit ?? lock?.commit ??
      lock?.revision ?? lock?.upstream?.commit ?? lock?.releaseTag?.revision,
    version: lock?.packageVersion ?? lock?.dshVersion ?? lock?.version ??
      lock?.upstream?.version,
  };
}

function compareMetric(value, threshold) {
  switch (threshold.operator) {
    case 'lt': return value < threshold.value;
    case 'lte': return value <= threshold.value;
    case 'eq': return value === threshold.value;
    case 'gte': return value >= threshold.value;
    case 'gt': return value > threshold.value;
    default: return false;
  }
}

function validateMetric(metric, path, errors) {
  if (!isObject(metric)) {
    errors.push(`${path} must be an object`);
    return;
  }
  rejectUnknownFields(
    metric,
    new Set(['name', 'value', 'unit', 'status', 'threshold']),
    path,
    errors,
  );
  if (!isNonEmptyString(metric.name)) {
    errors.push(`${path}.name is required`);
  }
  if (typeof metric.value !== 'number' || !Number.isFinite(metric.value)) {
    errors.push(`${path}.value must be a finite number`);
  }
  if (!isNonEmptyString(metric.unit)) {
    errors.push(`${path}.unit is required`);
  }
  if (!metricStatuses.has(metric.status)) {
    errors.push(`${path}.status is invalid`);
  }
  if (metric.threshold !== undefined) {
    if (!isObject(metric.threshold)) {
      errors.push(`${path}.threshold must be an object`);
      return;
    }
    rejectUnknownFields(
      metric.threshold,
      new Set(['operator', 'value']),
      `${path}.threshold`,
      errors,
    );
    if (!thresholdOperators.has(metric.threshold.operator)) {
      errors.push(`${path}.threshold.operator is invalid`);
    }
    if (typeof metric.threshold.value !== 'number' ||
        !Number.isFinite(metric.threshold.value)) {
      errors.push(`${path}.threshold.value must be a finite number`);
    }
    if (metric.status === 'passed' &&
        typeof metric.value === 'number' &&
        typeof metric.threshold.value === 'number' &&
        thresholdOperators.has(metric.threshold.operator) &&
        !compareMetric(metric.value, metric.threshold)) {
      errors.push(`${path} is marked passed but does not satisfy its threshold`);
    }
  }
}

function validateMetrics(metrics, path, errors) {
  if (!Array.isArray(metrics)) {
    errors.push(`${path} must be an array`);
    return;
  }
  metrics.forEach((metric, index) =>
    validateMetric(metric, `${path}[${index}]`, errors));
}

function validateFailure(failure, path, errors) {
  if (failure === undefined) return;
  if (!isObject(failure)) {
    errors.push(`${path} must be an object`);
    return;
  }
  rejectUnknownFields(failure, new Set(['code', 'classification']), path, errors);
  if (!isNonEmptyString(failure.code)) {
    errors.push(`${path}.code is required`);
  }
  if (!['product', 'test', 'infrastructure', 'cancelled']
    .includes(failure.classification)) {
    errors.push(`${path}.classification is invalid`);
  }
}

function validateSteps(steps, errors) {
  if (!Array.isArray(steps) || steps.length === 0) {
    errors.push('steps must be a non-empty array');
    return;
  }
  const ids = new Set();
  steps.forEach((step, index) => {
    const path = `steps[${index}]`;
    if (!isObject(step)) {
      errors.push(`${path} must be an object`);
      return;
    }
    rejectUnknownFields(
      step,
      new Set([
        'id', 'status', 'mandatory', 'assertions', 'durationMs', 'metrics',
        'failure',
      ]),
      path,
      errors,
    );
    if (!isNonEmptyString(step.id)) {
      errors.push(`${path}.id is required`);
    } else if (ids.has(step.id)) {
      errors.push(`duplicate step id: ${step.id}`);
    } else {
      ids.add(step.id);
    }
    if (!stepStatuses.has(step.status)) {
      errors.push(`${path}.status is invalid`);
    }
    if (typeof step.mandatory !== 'boolean') {
      errors.push(`${path}.mandatory must be boolean`);
    }
    if (!Array.isArray(step.assertions) || step.assertions.length === 0 ||
        step.assertions.some((assertion) => !isNonEmptyString(assertion))) {
      errors.push(`${path}.assertions must be a non-empty string array`);
    }
    if (step.durationMs !== undefined &&
        (typeof step.durationMs !== 'number' ||
          !Number.isFinite(step.durationMs) || step.durationMs < 0)) {
      errors.push(`${path}.durationMs must be a non-negative finite number`);
    }
    if (step.metrics !== undefined) {
      validateMetrics(step.metrics, `${path}.metrics`, errors);
    }
    validateFailure(step.failure, `${path}.failure`, errors);
  });
}

function validateArtifacts(artifacts, release, errors, warnings) {
  if (!Array.isArray(artifacts)) {
    errors.push('artifacts must be an array');
    return;
  }
  if (release && artifacts.length === 0) {
    errors.push('release evidence requires at least one artifact');
  }
  const paths = new Set();
  artifacts.forEach((artifact, index) => {
    const path = `artifacts[${index}]`;
    if (!isObject(artifact)) {
      errors.push(`${path} must be an object`);
      return;
    }
    rejectUnknownFields(
      artifact,
      new Set(['kind', 'path', 'sha256']),
      path,
      errors,
    );
    if (!artifactKinds.has(artifact.kind)) {
      errors.push(`${path}.kind is invalid`);
    }
    if (!isSafeRelativePath(artifact.path)) {
      errors.push(`${path}.path must be a safe relative path`);
    } else if (paths.has(artifact.path)) {
      errors.push(`duplicate artifact path: ${artifact.path}`);
    } else {
      paths.add(artifact.path);
    }
    if (artifact.sha256 === null) {
      if (release) {
        errors.push(`${path}.sha256 is required for release evidence`);
      } else {
        warnings.push(`${path}.sha256 is incomplete`);
      }
    } else if (!sha256Pattern.test(artifact.sha256 ?? '')) {
      errors.push(`${path}.sha256 must be a lowercase SHA-256 digest`);
    }
  });
}

function readGitState(root) {
  try {
    const commit = execFileSync('git', ['rev-parse', 'HEAD'], {
      cwd: root,
      encoding: 'utf8',
      windowsHide: true,
    }).trim();
    const status = execFileSync(
      'git',
      ['status', '--porcelain=v1', '--untracked-files=normal'],
      {
        cwd: root,
        encoding: 'utf8',
        windowsHide: true,
      },
    );
    return { commit, dirty: status.length > 0 };
  } catch {
    return null;
  }
}

function digestContainedFile(
  root,
  relativePath,
  expected,
  label,
  errors,
  { validateHap = false } = {},
) {
  let absoluteRoot;
  let candidate;
  let metadata;
  let contained;
  try {
    absoluteRoot = realpathSync(root);
    candidate = resolve(absoluteRoot, relativePath);
    metadata = lstatSync(candidate);
    if (metadata.isSymbolicLink() || !metadata.isFile()) {
      errors.push(`${label} must be a regular file, not a symlink or directory`);
      return;
    }
    contained = realpathSync(candidate);
  } catch (error) {
    errors.push(`${label} could not be read (${error.code || error.message})`);
    return;
  }
  const insideRoot = relative(absoluteRoot, contained);
  if (insideRoot.startsWith('..') || isAbsolute(insideRoot)) {
    errors.push(`${label} resolves outside the repository`);
    return;
  }
  let digest;
  let content;
  try {
    content = readFileSync(contained);
    digest = createHash('sha256').update(content).digest('hex');
  } catch (error) {
    errors.push(`${label} could not be hashed (${error.code || error.message})`);
    return;
  }
  if (validateHap) {
    const localHeader = content.length >= 4 &&
      content[0] === 0x50 && content[1] === 0x4b &&
      content[2] === 0x03 && content[3] === 0x04;
    const endOfCentralDirectory = content.indexOf(
      Buffer.from([0x50, 0x4b, 0x05, 0x06]),
    ) >= 0;
    if (!localHeader || !endOfCentralDirectory) {
      errors.push(`${label} is not a ZIP/HAP container`);
    }
  }
  if (sha256Pattern.test(expected ?? '') && digest !== expected) {
    errors.push(`${label} SHA-256 does not match the file`);
  }
}

function validateRelease(evidence, errors, {
  root = defaultRoot,
  actualGit = null,
  now = Date.now(),
  maximumAgeMs = defaultMaximumEvidenceAgeMs,
} = {}) {
  if (evidence.git?.dirty !== false) {
    errors.push('release evidence requires git.dirty=false');
  }
  if (evidence.status !== 'passed') {
    errors.push('release evidence requires status=passed');
  }
  const steps = Array.isArray(evidence.steps) ? evidence.steps : [];
  const mandatorySteps = steps.filter((step) => step?.mandatory === true);
  if (mandatorySteps.length === 0) {
    errors.push('release evidence requires at least one mandatory step');
  } else if (!mandatorySteps.some((step) => step.status === 'passed')) {
    errors.push('release evidence requires a passed mandatory step');
  }
  for (const [index, step] of steps.entries()) {
    if (step?.mandatory !== true || step?.status !== 'passed') {
      if (step?.mandatory === true ||
          releaseBlockingStatuses.has(step?.status)) {
        errors.push(`release evidence step ${step?.id ?? index} is not passed`);
      }
    }
  }
  const topLevelMetrics = Array.isArray(evidence.metrics)
    ? evidence.metrics : [];
  const metricGroups = [
    topLevelMetrics,
    ...steps.map((step) =>
      Array.isArray(step?.metrics) ? step.metrics : []),
  ];
  for (const metrics of metricGroups) {
    for (const metric of metrics) {
      if (releaseBlockingStatuses.has(metric?.status)) {
        errors.push(
          `release evidence metric ${metric?.name ?? 'unknown'} is ${metric.status}`,
        );
      }
    }
  }
  if (!sha256Pattern.test(evidence.hap?.sha256 ?? '')) {
    errors.push('release evidence requires a complete HAP SHA-256');
  }
  if (!isNonEmptyString(evidence.hap?.path)) {
    errors.push('release evidence requires hap.path');
  } else if (!evidence.hap.path.endsWith('.hap')) {
    errors.push('release evidence hap.path must end with .hap');
  }

  const generatedAt = Date.parse(evidence.generatedAt);
  const currentTime = now instanceof Date ? now.getTime() : Number(now);
  if (!Number.isFinite(currentTime)) {
    errors.push('release evidence current time is unavailable');
  } else if (Number.isFinite(generatedAt)) {
    if (generatedAt > currentTime + futureClockSkewMs) {
      errors.push('release evidence generatedAt is in the future');
    }
    if (currentTime - generatedAt > maximumAgeMs) {
      errors.push('release evidence is stale');
    }
  }

  const repositoryState = actualGit ?? readGitState(root);
  if (!repositoryState) {
    errors.push('release evidence cannot read the current Git state');
  } else {
    const currentCommit = repositoryState.commit ?? repositoryState.head;
    if (evidence.git?.commit !== currentCommit) {
      errors.push('release evidence git.commit does not match HEAD');
    }
    if (typeof repositoryState.dirty !== 'boolean') {
      errors.push('release evidence cannot determine the current Git dirty state');
    } else if (evidence.git?.dirty !== repositoryState.dirty) {
      errors.push('release evidence git.dirty does not match the worktree');
    }
  }

  if (isSafeRelativePath(evidence.hap?.path)) {
    digestContainedFile(
      root,
      evidence.hap.path,
      evidence.hap.sha256,
      'hap.path',
      errors,
      { validateHap: true },
    );
  }
  const artifacts = Array.isArray(evidence.artifacts) ? evidence.artifacts : [];
  for (const [index, artifact] of artifacts.entries()) {
    if (isSafeRelativePath(artifact?.path)) {
      digestContainedFile(
        root,
        artifact.path,
        artifact.sha256,
        `artifacts[${index}].path`,
        errors,
      );
    }
  }
}

export function loadProtocolLock(root = defaultRoot) {
  return JSON.parse(readFileSync(join(root, 'protocol.lock.json'), 'utf8'));
}

export function loadRegisteredFeatureIds(root = defaultRoot) {
  const manifest = JSON.parse(
    readFileSync(join(root, 'docs/testing/mock-feature-manifest.json'), 'utf8'),
  );
  const features = Array.isArray(manifest.features) ? manifest.features : [];
  const ids = new Set(features
    .filter((feature) => feature && typeof feature.id === 'string' && feature.id)
    .map((feature) => feature.id));
  if (!ids.size) throw new Error('mock feature manifest registers no feature ids');
  return ids;
}

export function validateEvidence(
  evidence,
  {
    protocolLock,
    release = false,
    root = defaultRoot,
    actualGit = null,
    now = Date.now(),
    maximumAgeMs = defaultMaximumEvidenceAgeMs,
    registeredFeatureIds = null,
  } = {},
) {
  const errors = [];
  const warnings = [];
  if (!isObject(evidence)) {
    return { ok: false, errors: ['evidence manifest must be an object'], warnings };
  }
  if (evidence.$schema !== undefined && !isNonEmptyString(evidence.$schema)) {
    errors.push('$schema must be a non-empty string when present');
  }
  if (evidence.schemaVersion !== 1) {
    errors.push('schemaVersion must be 1');
  }
  rejectUnknownFields(
    evidence,
    new Set([
      '$schema', 'schemaVersion', 'runId', 'generatedAt', 'git', 'upstream',
      'scope', 'product', 'hap', 'device', 'status', 'steps', 'metrics',
      'artifacts', 'toolchain', 'failure',
    ]),
    'evidence',
    errors,
  );
  if (!isNonEmptyString(evidence.runId)) {
    errors.push('runId is required');
  }
  if (!isStrictDateTime(evidence.generatedAt)) {
    errors.push('generatedAt must be an ISO UTC date-time string');
  }

  if (!isObject(evidence.git)) {
    errors.push('git must be an object');
  } else {
    rejectUnknownFields(evidence.git, new Set(['commit', 'dirty']), 'git', errors);
    if (!gitCommitPattern.test(evidence.git.commit ?? '')) {
      errors.push('git.commit must be a full lowercase Git commit');
    }
    if (typeof evidence.git.dirty !== 'boolean') {
      errors.push('git.dirty must be boolean');
    }
  }

  if (!isObject(protocolLock)) {
    errors.push('protocol lock is unavailable');
  } else {
    const lock = protocolIdentity(protocolLock);
    if (!gitCommitPattern.test(lock.commit ?? '')) {
      errors.push('protocol lock commit is missing or invalid');
    }
    if (!isNonEmptyString(lock.version)) {
      errors.push('protocol lock version is missing');
    }
    if (!isObject(evidence.upstream)) {
      errors.push('upstream must be an object');
    } else {
      rejectUnknownFields(
        evidence.upstream,
        new Set(['commit', 'version']),
        'upstream',
        errors,
      );
      if (evidence.upstream.commit !== lock.commit) {
        errors.push('upstream.commit does not match the protocol lock');
      }
      if (evidence.upstream.version !== lock.version) {
        errors.push('upstream.version does not match the protocol lock');
      }
    }
  }

  if (!isObject(evidence.scope)) {
    errors.push('scope must be an object');
  } else {
    rejectUnknownFields(
      evidence.scope,
      new Set(['featureIds', 'scenarioId']),
      'scope',
      errors,
    );
    if (!Array.isArray(evidence.scope.featureIds) ||
        evidence.scope.featureIds.length === 0 ||
        evidence.scope.featureIds.some((id) => !isNonEmptyString(id))) {
      errors.push('scope.featureIds must be a non-empty string array');
    } else if (new Set(evidence.scope.featureIds).size !==
        evidence.scope.featureIds.length) {
      errors.push('scope.featureIds must contain unique values');
    } else if (registeredFeatureIds) {
      const unknown = evidence.scope.featureIds.filter((id) => !registeredFeatureIds.has(id));
      if (unknown.length) {
        errors.push('scope.featureIds must reference registered features: ' + unknown.join(', '));
      }
    }
    if (!isNonEmptyString(evidence.scope.scenarioId)) {
      errors.push('scope.scenarioId is required');
    }
  }

  if (!['community', 'default', 'store', 'mock'].includes(evidence.product)) {
    errors.push('product must be community, store or mock (legacy default is accepted)');
  }

  if (!isObject(evidence.hap)) {
    errors.push('hap must be an object');
  } else {
    rejectUnknownFields(evidence.hap, new Set(['path', 'sha256']), 'hap', errors);
    if (evidence.hap.path !== undefined && !isSafeRelativePath(evidence.hap.path)) {
      errors.push('hap.path must be a safe relative path');
    }
    if (evidence.hap.sha256 === null) {
      if (release) {
        errors.push('hap.sha256 is required for release evidence');
      } else {
        warnings.push('hap.sha256 is incomplete');
      }
    } else if (!sha256Pattern.test(evidence.hap.sha256 ?? '')) {
      errors.push('hap.sha256 must be a lowercase SHA-256 digest');
    }
  }

  if (!isObject(evidence.device)) {
    errors.push('device must be an object');
  } else {
    rejectUnknownFields(
      evidence.device,
      new Set(['serial', 'model', 'api', 'abi', 'orientation']),
      'device',
      errors,
    );
    if (!isNonEmptyString(evidence.device.serial)) {
      errors.push('device.serial is required');
    }
    if (!isNonEmptyString(evidence.device.model)) {
      errors.push('device.model is required');
    }
    if (!Number.isInteger(evidence.device.api) ||
        evidence.device.api < 1 || evidence.device.api > 1000) {
      errors.push('device.api must be an integer between 1 and 1000');
    }
    if (evidence.device.abi !== undefined &&
        !isNonEmptyString(evidence.device.abi)) {
      errors.push('device.abi must be a non-empty string when present');
    }
    if (evidence.device.orientation !== undefined &&
        !['portrait', 'landscape'].includes(evidence.device.orientation)) {
      errors.push('device.orientation is invalid');
    }
  }

  if (!overallStatuses.has(evidence.status)) {
    errors.push('status is invalid');
  }
  validateSteps(evidence.steps, errors);
  validateMetrics(evidence.metrics, 'metrics', errors);
  validateArtifacts(evidence.artifacts, release, errors, warnings);
  validateFailure(evidence.failure, 'failure', errors);
  if (evidence.toolchain !== undefined) {
    if (!isObject(evidence.toolchain)) {
      errors.push('toolchain must be an object');
    } else {
      rejectUnknownFields(
        evidence.toolchain,
        new Set(['node', 'hvigor', 'sdk']),
        'toolchain',
        errors,
      );
      for (const field of ['node', 'hvigor', 'sdk']) {
        if (evidence.toolchain[field] !== undefined &&
            !isNonEmptyString(evidence.toolchain[field])) {
          errors.push(`toolchain.${field} must be a non-empty string`);
        }
      }
    }
  }

  if (evidence.status === 'passed' && Array.isArray(evidence.steps)) {
    for (const step of evidence.steps) {
      if (step?.mandatory === true && step?.status !== 'passed') {
        errors.push(`passed evidence has mandatory step ${step.id} marked ${step.status}`);
      }
      for (const metric of step?.metrics ?? []) {
        if (metric?.status !== 'passed' && metric?.status !== 'skipped') {
          errors.push(
            `passed evidence has step metric ${metric?.name} marked ${metric?.status}`,
          );
        }
      }
    }
  }
  if (evidence.status === 'passed') {
    const metrics = Array.isArray(evidence.metrics) ? evidence.metrics : [];
    for (const metric of metrics) {
      if (metric?.status !== 'passed' && metric?.status !== 'skipped') {
        errors.push(
          `passed evidence has metric ${metric?.name} marked ${metric?.status}`,
        );
      }
    }
  }
  if (release) {
    validateRelease(evidence, errors, {
      root,
      actualGit,
      now,
      maximumAgeMs,
    });
  }

  return {
    ok: errors.length === 0,
    errors,
    warnings,
    summary: {
      runId: evidence.runId,
      product: evidence.product,
      api: evidence.device?.api,
      status: evidence.status,
      steps: Array.isArray(evidence.steps) ? evidence.steps.length : 0,
      artifacts: Array.isArray(evidence.artifacts) ? evidence.artifacts.length : 0,
    },
  };
}

export function validateEvidenceFile(
  evidencePath,
  { root = defaultRoot, release = false, protocolLock } = {},
) {
  const evidence = JSON.parse(readFileSync(resolve(evidencePath), 'utf8'));
  const lock = protocolLock ?? loadProtocolLock(root);
  return validateEvidence(evidence, {
    protocolLock: lock,
    release,
    root,
    registeredFeatureIds: loadRegisteredFeatureIds(root),
  });
}

function parseArguments(argv) {
  let evidencePath = '';
  let root = defaultRoot;
  let release = false;
  for (let index = 0; index < argv.length; index++) {
    const argument = argv[index];
    if (argument === '--release') {
      release = true;
    } else if (argument === '--root') {
      const value = argv[++index];
      if (value === undefined) throw new Error('--root requires a directory path');
      root = resolve(value);
    } else if (argument.startsWith('--root=')) {
      root = resolve(argument.slice('--root='.length));
    } else if (argument.startsWith('--')) {
      throw new Error(`Unknown option: ${argument}`);
    } else if (!evidencePath) {
      evidencePath = argument;
    } else {
      throw new Error(`Unexpected argument: ${argument}`);
    }
  }
  if (!evidencePath) {
    throw new Error(
      'Usage: node scripts/verify-evidence.mjs <manifest.json> [--release] [--root <repo>]',
    );
  }
  return { evidencePath, root, release };
}

function printResult(result, release) {
  const mode = release ? 'release' : 'validation';
  for (const warning of result.warnings) {
    console.warn(`Warning: ${warning}`);
  }
  if (!result.ok) {
    console.error(`Evidence ${mode} failed:`);
    for (const error of result.errors) console.error(`- ${error}`);
    process.exitCode = 1;
    return;
  }
  console.log(
    `Evidence ${mode} passed: ${result.summary.runId}, ` +
    `${result.summary.product} API ${result.summary.api}, ` +
    `${result.summary.steps} steps, ${result.summary.artifacts} artifacts`,
  );
}

if (process.argv[1] &&
    import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const options = parseArguments(process.argv.slice(2));
    printResult(validateEvidenceFile(options.evidencePath, options), options.release);
  } catch (error) {
    console.error(`Evidence validation failed: ${error.message}`);
    process.exitCode = 1;
  }
}
