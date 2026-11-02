import { existsSync, readFileSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const repositoryRoot = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const revisionPattern = /^[a-f0-9]{40}$/;
const versionPattern = /^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$/;

function readText(root, relativePath) {
  return readFileSync(path.join(root, relativePath), 'utf8');
}

function parseVersion(value) {
  const match = versionPattern.exec(String(value || ''));
  if (!match) return null;
  return {
    core: match.slice(1, 4).map(Number),
    prerelease: match[4] ? match[4].split('.') : [],
  };
}

function comparePrerelease(left, right) {
  if (left.length === 0 && right.length === 0) return 0;
  if (left.length === 0) return 1;
  if (right.length === 0) return -1;
  for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
    if (left[index] === undefined) return -1;
    if (right[index] === undefined) return 1;
    if (left[index] === right[index]) continue;
    const leftNumeric = /^\d+$/.test(left[index]);
    const rightNumeric = /^\d+$/.test(right[index]);
    if (leftNumeric && rightNumeric) return Number(left[index]) - Number(right[index]);
    if (leftNumeric) return -1;
    if (rightNumeric) return 1;
    return left[index] < right[index] ? -1 : 1;
  }
  return 0;
}

export function compareVersions(left, right) {
  const a = parseVersion(left);
  const b = parseVersion(right);
  if (!a || !b) throw new Error(`Invalid semantic version comparison: ${left}, ${right}`);
  for (let index = 0; index < 3; index += 1) {
    if (a.core[index] !== b.core[index]) return a.core[index] - b.core[index];
  }
  return comparePrerelease(a.prerelease, b.prerelease);
}

export function satisfiesVersionRange(version, range) {
  if (!parseVersion(version) || typeof range !== 'string' || !range.trim()) return false;
  const terms = range.trim().split(/\s+/);
  return terms.every(term => {
    const match = /^(>=|<=|>|<|=)?(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)$/.exec(term);
    if (!match) return false;
    const comparison = compareVersions(version, match[2]);
    switch (match[1] || '=') {
      case '>=': return comparison >= 0;
      case '<=': return comparison <= 0;
      case '>': return comparison > 0;
      case '<': return comparison < 0;
      case '=': return comparison === 0;
      default: return false;
    }
  });
}

export function validateLockSchema(lock) {
  const failures = [];
  if (!lock || typeof lock !== 'object' || Array.isArray(lock)) {
    return ['protocol.lock.json: expected a JSON object'];
  }
  if (lock.schemaVersion !== 1) failures.push('protocol.lock.json: schemaVersion must be 1');
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(lock.repository || '')) {
    failures.push('protocol.lock.json: repository must be owner/name');
  }
  if (!/^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(lock.repositoryUrl || '')) {
    failures.push('protocol.lock.json: repositoryUrl must be a canonical GitHub HTTPS URL');
  } else if (lock.repositoryUrl !== `https://github.com/${lock.repository}`) {
    failures.push('protocol.lock.json: repositoryUrl must match repository');
  }
  if (!revisionPattern.test(lock.canonicalRevision || '')) {
    failures.push('protocol.lock.json: canonicalRevision must be a full lowercase git SHA');
  }
  if (!lock.releaseTag || typeof lock.releaseTag !== 'object') {
    failures.push('protocol.lock.json: releaseTag is required');
  } else {
    if (typeof lock.releaseTag.name !== 'string' || !lock.releaseTag.name.trim()) {
      failures.push('protocol.lock.json: releaseTag.name is required');
    }
    if (!revisionPattern.test(lock.releaseTag.revision || '')) {
      failures.push('protocol.lock.json: releaseTag.revision must be a full lowercase git SHA');
    }
  }
  if (!parseVersion(lock.packageVersion)) {
    failures.push('protocol.lock.json: packageVersion must be semantic version');
  }
  if (!Number.isSafeInteger(lock.wireProtocolVersion) || lock.wireProtocolVersion < 1) {
    failures.push('protocol.lock.json: wireProtocolVersion must be a positive integer');
  }
  if (typeof lock.fixtureDirectory !== 'string' ||
      !lock.fixtureDirectory || path.isAbsolute(lock.fixtureDirectory) ||
      lock.fixtureDirectory.split(/[\\/]/).includes('..')) {
    failures.push('protocol.lock.json: fixtureDirectory must be a safe relative path');
  }
  if (!/^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z)?$/.test(lock.reviewedAt || '') ||
      Number.isNaN(Date.parse(lock.reviewedAt))) {
    failures.push('protocol.lock.json: reviewedAt must be an ISO date or timestamp');
  }
  if (typeof lock.reviewSource !== 'string' || lock.reviewSource.trim().length < 12) {
    failures.push('protocol.lock.json: reviewSource must describe how the pin was verified');
  }
  return failures;
}

export function validateProtocolReferences(lock, documents, enginesDsh) {
  const failures = [];
  const required = {
    'docs/NATIVE-INTERACTION-SPEC.md':
      ['protocol.lock.json', lock.canonicalRevision, lock.packageVersion, `wire protocol v${lock.wireProtocolVersion}`],
    'NOTICE':
      [lock.canonicalRevision, lock.packageVersion, `wire protocol ${lock.wireProtocolVersion}`],
    'docs/specs/2026-10-31-stream-recovery-composer-attachments.md':
      ['protocol.lock.json', lock.canonicalRevision, lock.packageVersion, `wire protocol v${lock.wireProtocolVersion}`],
    'docs/requirements/2026-11-01-structured-protocol-completeness.md':
      ['protocol.lock.json', lock.canonicalRevision, lock.packageVersion, `wire protocol v${lock.wireProtocolVersion}`],
  };
  for (const [name, tokens] of Object.entries(required)) {
    const text = documents[name];
    if (typeof text !== 'string') {
      failures.push(`${name}: document could not be read`);
      continue;
    }
    for (const token of tokens) {
      if (!text.includes(token)) failures.push(`${name}: missing protocol lock reference ${token}`);
    }
  }
  if (typeof enginesDsh !== 'string' || !enginesDsh.trim()) {
    failures.push('plugins/dsh-harmony/package.json: engines.dsh is required');
  } else if (!satisfiesVersionRange(lock.packageVersion, enginesDsh)) {
    failures.push(`plugins/dsh-harmony/package.json: engines.dsh ${enginesDsh} excludes ${lock.packageVersion}`);
  }
  return failures;
}

export function verifyProtocolLock({
  root = repositoryRoot,
  lock = null,
  documents = null,
  enginesDsh = null,
} = {}) {
  let resolvedLock = lock;
  let failures = [];
  try {
    if (!resolvedLock) {
      resolvedLock = JSON.parse(readText(root, 'protocol.lock.json'));
    }
    failures = validateLockSchema(resolvedLock);
    if (failures.length === 0) {
      const fixtureDirectory = path.resolve(root, resolvedLock.fixtureDirectory);
      const relativeFixture = path.relative(path.resolve(root), fixtureDirectory);
      if (relativeFixture.startsWith('..') || path.isAbsolute(relativeFixture)) {
        failures.push('protocol.lock.json: fixtureDirectory escapes the repository');
      } else if (!existsSync(fixtureDirectory) ||
          !statSync(fixtureDirectory).isDirectory()) {
        failures.push('protocol.lock.json: fixtureDirectory does not exist');
      }
    }
    if (failures.length === 0) {
      const inputs = documents || {
        'docs/NATIVE-INTERACTION-SPEC.md': readText(root, 'docs/NATIVE-INTERACTION-SPEC.md'),
        'NOTICE': readText(root, 'NOTICE'),
        'docs/specs/2026-10-31-stream-recovery-composer-attachments.md':
          readText(root, 'docs/specs/2026-10-31-stream-recovery-composer-attachments.md'),
        'docs/requirements/2026-11-01-structured-protocol-completeness.md':
          readText(root, 'docs/requirements/2026-11-01-structured-protocol-completeness.md'),
      };
      const pluginPackage = JSON.parse(readText(root, 'plugins/dsh-harmony/package.json'));
      failures = validateProtocolReferences(
        resolvedLock,
        inputs,
        enginesDsh ?? pluginPackage.engines?.dsh,
      );
    }
  } catch (error) {
    failures = [`protocol lock verification failed: ${error.message}`];
  }
  return { ok: failures.length === 0, failures, lock: resolvedLock };
}

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : '';
if (invokedPath === fileURLToPath(import.meta.url)) {
  const result = verifyProtocolLock();
  if (!result.ok) {
    console.error(result.failures.join('\n'));
    process.exitCode = 1;
  } else {
    console.log(
      `Protocol lock passed: ${result.lock.repository}@${result.lock.canonicalRevision.slice(0, 7)} ` +
      `${result.lock.packageVersion}, wire ${result.lock.wireProtocolVersion}`,
    );
  }
}
