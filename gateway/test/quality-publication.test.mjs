import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  applyPublicationBaseline,
  parseNullTerminatedPathList,
  privateNetworkMatches,
  scanPublicationBuffer,
  scanPublicationPath,
  scanPublicationText,
  scanWorkingTree,
} from '../../scripts/check-publication.mjs';
import {
  satisfiesVersionRange,
  validateLockSchema,
  verifyProtocolLock,
} from '../../scripts/verify-protocol-lock.mjs';

const root = path.resolve(fileURLToPath(new URL('../..', import.meta.url)));
const lockPath = path.join(root, 'protocol.lock.json');
const documentPaths = [
  'docs/NATIVE-INTERACTION-SPEC.md',
  'NOTICE',
  'docs/specs/2026-10-31-stream-recovery-composer-attachments.md',
  'docs/requirements/2026-11-01-structured-protocol-completeness.md',
];

function fixtureAccount() {
  return ['test', 'account'].join('-');
}

function windowsPath() {
  return ['C:', 'Users', fixtureAccount(), 'project'].join(String.fromCharCode(92));
}

function windowsHome() {
  return ['C:', 'Users', fixtureAccount()].join(String.fromCharCode(92));
}

function unixPath(rootName) {
  return ['', rootName, fixtureAccount(), 'project'].join('/');
}

function unixHome(rootName) {
  return ['', rootName, fixtureAccount()].join('/');
}

function signingFieldName() {
  return ['store', 'Password'].join('');
}

function utf16Be(text) {
  const littleEndian = Buffer.from(text, 'utf16le');
  const result = Buffer.alloc(littleEndian.length);
  for (let index = 0; index < littleEndian.length; index += 2) {
    result[index] = littleEndian[index + 1];
    result[index + 1] = littleEndian[index];
  }
  return result;
}

test('the repository protocol lock and all public references agree', () => {
  const result = verifyProtocolLock();
  assert.equal(result.ok, true, result.failures.join('\n'));
  assert.equal(result.lock.canonicalRevision,
    'fcc0ad462172522aaf5c93a7b2e01f6b9f0b0159');
  assert.equal(result.lock.packageVersion, '0.2.2-rc.1');
  assert.equal(result.lock.wireProtocolVersion, 2);
});

test('protocol lock rejects malformed identity and incompatible documents', () => {
  const lock = JSON.parse(readFileSync(lockPath, 'utf8'));
  const documents = Object.fromEntries(documentPaths.map(relativePath => [
    relativePath,
    readFileSync(path.join(root, relativePath), 'utf8'),
  ]));
  const malformed = validateLockSchema({
    ...lock,
    canonicalRevision: 'not-a-sha',
    fixtureDirectory: '../private-fixtures',
  });
  assert.match(malformed.join('\n'), /canonicalRevision/);
  assert.match(malformed.join('\n'), /fixtureDirectory/);

  const mismatch = verifyProtocolLock({
    lock: { ...lock, packageVersion: '0.2.1' },
    documents,
    enginesDsh: '>=0.2.2-alpha.2 <0.3.0',
  });
  assert.equal(mismatch.ok, false);
  assert.match(mismatch.failures.join('\n'), /0\.2\.1/);

  assert.equal(satisfiesVersionRange(
    '0.2.2-alpha.2',
    '>=0.2.2-alpha.2 <0.3.0',
  ), true);
  assert.equal(satisfiesVersionRange('0.3.0', '>=0.2.2-alpha.2 <0.3.0'), false);
});

test('publication scanner rejects synthetic personal paths and encoded variants', () => {
  for (const value of [
    windowsPath(),
    encodeURIComponent(windowsPath()),
    encodeURIComponent(encodeURIComponent(windowsPath())),
    unixPath('home'),
    unixPath('Users'),
  ]) {
    assert.ok(
      scanPublicationText(value, 'synthetic-path', { forbiddenHosts: [] })
        .includes('synthetic-path: personal filesystem path'),
      value,
    );
  }
});

test('publication scanner catches unterminated home paths and malformed percent escapes', () => {
  for (const value of [
    windowsHome(),
    unixHome('home'),
    unixHome('Users'),
  ]) {
    assert.ok(
      scanPublicationText(value, 'synthetic-home', { forbiddenHosts: [] })
        .includes('synthetic-home: personal filesystem path'),
      value,
    );
  }

  const malformed = `coverage is 100% complete\n${encodeURIComponent(windowsPath())}`;
  assert.ok(
    scanPublicationText(malformed, 'malformed-percent', { forbiddenHosts: [] })
      .includes('malformed-percent: personal filesystem path'),
  );
});

test('publication scanner decodes UTF-16 text buffers without scanning binary noise', () => {
  const utf16LeBuffer = Buffer.concat([
    Buffer.from([0xff, 0xfe]),
    Buffer.from(windowsPath(), 'utf16le'),
  ]);
  const utf16BeBuffer = Buffer.concat([
    Buffer.from([0xfe, 0xff]),
    utf16Be(windowsPath()),
  ]);
  for (const buffer of [utf16LeBuffer, utf16BeBuffer]) {
    assert.ok(
      scanPublicationBuffer(buffer, 'synthetic-utf16', { forbiddenHosts: [] })
        .includes('synthetic-utf16: personal filesystem path'),
    );
  }
  assert.deepEqual(
    scanPublicationBuffer(Buffer.from([0, 25, 0, 0, 1, 25]), 'binary', {
      forbiddenHosts: [],
    }),
    [],
  );
});

test('publication scanner rejects synthetic secrets, tokens and private hosts', () => {
  const signingField = ['key', 'Password'].join('');
  const secret = ['not', 'a', 'real', 'secret'].join('-');
  assert.ok(scanPublicationText(
    `${signingField}: ${secret}`,
    'synthetic-secret',
    { forbiddenHosts: [] },
  ).includes('synthetic-secret: signing password field'));

  const privateKeyMarker = ['-----BEGIN', 'PRIVATE KEY-----'].join(' ');
  assert.ok(scanPublicationText(
    privateKeyMarker,
    'synthetic-key',
    { forbiddenHosts: [] },
  ).includes('synthetic-key: private key material'));

  const token = ['ghp', 'A'.repeat(36)].join('_');
  assert.ok(scanPublicationText(
    token,
    'synthetic-token',
    { forbiddenHosts: [] },
  ).includes('synthetic-token: access token'));

  const privateHost = ['private', 'service', 'example'].join('.');
  assert.ok(scanPublicationText(
    `https://${privateHost}/api`,
    'synthetic-host',
    { forbiddenHosts: [privateHost] },
  ).includes('synthetic-host: private host'));
  assert.deepEqual(scanPublicationPath('harmony/build/debug/app.p12'),
    ['harmony/build/debug/app.p12: forbidden credential/signing artifact']);
});

test('publication scanner rejects common credential artifacts and ambiguous secrets', () => {
  for (const value of [
    ['gateway', ['.env', 'local'].join('.')].join('/'),
    'gateway/.env.production',
    'gateway/.envrc',
    'ssh/id_rsa',
    'deploy/credentials.json',
    'harmony/build/app.key',
  ]) {
    assert.ok(
      scanPublicationPath(value).length > 0,
      value,
    );
  }
  assert.deepEqual(scanPublicationPath('gateway/.env.example'), []);
  assert.deepEqual(scanPublicationPath('deploy/secrets.env.sample'), []);

  assert.ok(scanPublicationText(
    `${signingFieldName()}: $ecret-value`,
    'ambiguous-secret',
    { forbiddenHosts: [] },
  ).includes('ambiguous-secret: signing password field'));
  assert.ok(scanPublicationText(
    `${signingFieldName()}: \${STORE_PASSWORD:-literal-secret}`,
    'fallback-secret',
    { forbiddenHosts: [] },
  ).includes('fallback-secret: signing password field'));
  for (const placeholder of [
    '${STORE_PASSWORD}',
    '$env:STORE_PASSWORD',
    '$STORE_PASSWORD',
    '%STORE_PASSWORD%',
    'process.env.STORE_PASSWORD',
    'process.env["STORE_PASSWORD"]',
    '<redacted>',
  ]) {
    assert.deepEqual(
      scanPublicationText(
        `${signingFieldName()}: ${placeholder}`,
        'placeholder-secret',
        { forbiddenHosts: [] },
      ),
      [],
      placeholder,
    );
  }
});

test('publication scanner covers additional private and special-use networks', () => {
  for (const value of [
    ['100', '64', '0', '1'].join('.'),
    ['169', '254', '1', '1'].join('.'),
    ['198', '18', '0', '1'].join('.'),
    ['fd00', '1'].join('::'),
    ['fe80', '1'].join('::'),
    ['service', 'internal'].join('.'),
  ]) {
    assert.ok(privateNetworkMatches(value).length > 0, value);
  }
});

test('historical publication baseline is exact, path-free and does not apply new findings', () => {
  const finding = {
    commit: 'a'.repeat(40),
    object: 'b'.repeat(40),
    reason: 'personal filesystem path',
    count: 2,
  };
  const baseline = {
    schemaVersion: 1,
    entries: [{
      object: finding.object,
      reason: finding.reason,
      count: finding.count,
    }],
  };
  assert.deepEqual(applyPublicationBaseline([finding], baseline), []);
  assert.deepEqual(
    applyPublicationBaseline([{ ...finding, commit: 'c'.repeat(40), count: 1 }], baseline),
    [],
  );
  assert.match(
    applyPublicationBaseline([{ ...finding, count: 3 }], baseline).join('\n'),
    /baseline count exceeded \(3\/2\)/,
  );
  assert.match(
    applyPublicationBaseline([
      finding,
      {
        commit: 'c'.repeat(40),
        object: 'd'.repeat(40),
        reason: 'signing password field',
        count: 1,
      },
    ], baseline).join('\n'),
    /history cccccccc:dddddddd: signing password field/,
  );
  assert.match(
    applyPublicationBaseline([], baseline).join('\n'),
    /baseline entry is stale/,
  );
  assert.doesNotMatch(JSON.stringify(baseline), /[/\\](?:home|Users)[/\\]/i);
  assert.throws(
    () => applyPublicationBaseline([], {
      schemaVersion: 1,
      entries: [{
        object: 'e'.repeat(40),
        reason: 'signing password field',
        count: 1,
      }],
    }),
    /not eligible for a historical baseline/,
  );
});

test('staged path parsing preserves non-ASCII names from NUL-delimited Git output', () => {
  assert.deepEqual(
    parseNullTerminatedPathList(Buffer.from('caf\u00e9.txt\0\u6587\u6863.txt\0', 'utf8')),
    ['caf\u00e9.txt', '\u6587\u6863.txt'],
  );
});

test('publication scanner accepts placeholders, public repositories and the working tree', () => {
  const placeholderPath = ['C:', 'Users', '<name>', 'project']
    .join(String.fromCharCode(92));
  const clean = [
    placeholderPath,
    'https://github.com/deepseek-ai/deepseek-harness',
    'keyPassword: <redacted>',
    'storePassword: ${STORE_PASSWORD}',
  ].join('\n');
  assert.deepEqual(
    scanPublicationText(clean, 'clean-fixture', { forbiddenHosts: [] }),
    [],
  );
  assert.deepEqual(
    scanWorkingTree({ root, forbiddenHosts: [] }),
    [],
  );
});
