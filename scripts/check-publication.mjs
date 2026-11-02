import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const gitObjectPattern = /^(?:[a-f0-9]{40}|[a-f0-9]{64})$/;
const historicalBaselineReasons = new Set([
  'personal filesystem path',
]);
const placeholderAccounts = new Set([
  'default',
  'defaultuser',
  'example',
  'me',
  'name',
  'placeholder',
  'public',
  'runner',
  'runneradmin',
  'sample',
  'user',
  'username',
  'your-name',
  'yourname',
]);
const safeEnvironmentExamples = /^\.env\.(?:example|sample|template)$/i;
const privateHostSuffixes = [
  '.home.arpa',
  '.internal',
  '.lan',
  '.local',
  '.localhost',
];

function git(args, cwd = repositoryRoot, encoding = 'utf8', options = {}) {
  return execFileSync('git', args, {
    cwd,
    encoding,
    maxBuffer: 64 * 1024 * 1024,
    ...options,
  });
}

export function privateHostsFromEnv(environment = process.env) {
  return String(environment.DSH_PRIVATE_HOSTS || '')
    .split(',')
    .map(value => value.trim().toLowerCase())
    .filter(Boolean);
}

function decodedVariants(text) {
  const variants = new Set([text]);
  const addDecodedVariants = (value) => {
    let current = value;
    for (let pass = 0; pass < 3; pass += 1) {
      // An ordinary literal percent must not disable decoding for the rest of
      // the file. Invalid percent signs become literal percent signs first.
      const repaired = current.replace(/%(?![0-9A-Fa-f]{2})/g, '%25');
      let decoded;
      try {
        decoded = decodeURIComponent(repaired);
      } catch {
        return;
      }
      if (decoded === current) return;
      variants.add(decoded);
      current = decoded;
    }
  };

  addDecodedVariants(text);
  for (const match of text.matchAll(/[^\s"'`<>()[\]{},;]+/g)) {
    if (/%[0-9A-Fa-f]{2}/.test(match[0])) addDecodedVariants(match[0]);
  }
  return [...variants];
}

function normalizedAccount(account) {
  return account
    .trim()
    .replace(/[,;:.)\]}]+$/g, '')
    .replace(/^[<[{$%]+|[>\]}$%]+$/g, '')
    .toLowerCase();
}

function isPlaceholderAccount(account) {
  const normalized = normalizedAccount(account);
  return !normalized ||
    placeholderAccounts.has(normalized) ||
    normalized.includes('${') ||
    normalized.includes('%username%');
}

function isPlaceholderSecret(value) {
  const normalized = value.trim().replace(/^['"]|['"]$/g, '').toLowerCase();
  return !normalized ||
    /^(?:change[-_]?me|example|placeholder|redacted|replace[-_]?me|your[-_]?|xxx+|<redacted>)$/.test(normalized) ||
    /^\$\{[a-z_][a-z0-9_]*\}$/.test(normalized) ||
    /^\$env:[a-z_][a-z0-9_]*$/.test(normalized) ||
    /^\$[a-z_][a-z0-9_]*$/.test(normalized) ||
    /^%[a-z_][a-z0-9_]*%$/.test(normalized) ||
    /^process\.env\.[a-z_][a-z0-9_]*$/.test(normalized) ||
    /^process\.env\[['"][a-z_][a-z0-9_]*['"]\]$/.test(normalized) ||
    /^system\.getenv\(['"][a-z_][a-z0-9_]*['"]\)$/.test(normalized) ||
    /^\{\{\s*secrets\.[a-z0-9_.-]+\s*\}\}$/.test(normalized);
}

function isPrivateIPv4(value) {
  const octets = value.split('.').map(Number);
  if (octets.length !== 4 ||
      octets.some((octet) => !Number.isInteger(octet) || octet < 0 || octet > 255)) {
    return false;
  }
  const [first, second] = octets;
  return (first === 0 && octets.every((octet) => octet === 0)) ||
    first === 10 ||
    (first === 100 && second >= 64 && second <= 127) ||
    (first === 169 && second === 254) ||
    (first === 172 && second >= 16 && second <= 31) ||
    (first === 192 && second === 168) ||
    (first === 198 && (second === 18 || second === 19)) ||
    first >= 224;
}

function isPrivateIPv6(value) {
  const normalized = value.toLowerCase().replace(/%.*$/, '');
  if (net.isIP(normalized) !== 6) return false;
  const mappedIPv4 = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/.exec(normalized);
  if (mappedIPv4) return isPrivateIPv4(mappedIPv4[1]);
  const firstHextet = Number.parseInt(normalized.split(':')[0] || '0', 16);
  return (firstHextet & 0xfe00) === 0xfc00 ||
    (firstHextet & 0xffc0) === 0xfe80;
}

export function privateNetworkMatches(text) {
  const matches = new Set();
  for (const match of text.matchAll(/\b\d{1,3}(?:\.\d{1,3}){3}\b/g)) {
    if (isPrivateIPv4(match[0])) matches.add(match[0]);
  }
  const ipv6Pattern =
    /(?:\[[0-9A-Fa-f:.%]+\]|(?<![0-9A-Fa-f:])(?:[0-9A-Fa-f]{0,4}:){2,}[0-9A-Fa-f]{0,4}(?:%[A-Za-z0-9_.-]+)?)/g;
  for (const match of text.matchAll(ipv6Pattern)) {
    const value = match[0].replace(/^\[|\]$/g, '');
    if (isPrivateIPv6(value)) matches.add(value);
  }
  const hostMatches = text.toLowerCase().matchAll(/\b[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\b/g);
  for (const match of hostMatches) {
    if (privateHostSuffixes.some((suffix) => match[0].endsWith(suffix))) {
      matches.add(match[0]);
    }
  }
  return [...matches];
}

function containsPrivateNetworkAddress(text) {
  return privateNetworkMatches(text).length > 0;
}

function scanPublicationTextDetailed(text, label, options = {}) {
  const failures = [];
  const forbiddenHosts = options.forbiddenHosts ?? privateHostsFromEnv();
  const seen = new Set();
  const add = reason => {
    const message = `${label}: ${reason}`;
    if (seen.has(message)) return;
    seen.add(message);
    failures.push({ label, reason, message });
  };
  for (const variant of decodedVariants(String(text))) {
    const lower = variant.toLowerCase();
    if (forbiddenHosts.some(host => lower.includes(host))) add('private host');
    if (/-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----/.test(variant)) {
      add('private key material');
    }
    if (/\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|sk-[A-Za-z0-9_-]{24,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,})\b/.test(variant) ||
        /\bBearer\s+[A-Za-z0-9._~+/-]{24,}={0,2}\b/i.test(variant)) {
      add('access token');
    }
    if (containsPrivateNetworkAddress(variant)) add('private network address');
    for (const match of variant.matchAll(
      /\b[A-Za-z]:[\\/]+Users[\\/]+([^\\/\r\n"'<>]+?)(?=[\\/]|$|[\s,;)\]])/gi,
    )) {
      if (!isPlaceholderAccount(match[1])) add('personal filesystem path');
    }
    for (const match of variant.matchAll(
      /(?:^|[\s"'`=(])\/(?:home|Users)\/([^/\r\n"'<>]+?)(?=\/|$|[\s,;)\]])/gi,
    )) {
      if (!isPlaceholderAccount(match[1])) add('personal filesystem path');
    }
    for (const match of variant.matchAll(
      /(?:^|[\s{,;])(?:["']?)(keyPassword|storePassword)(?:["']?)\s*[:=]\s*(?:"([^"]*)"|'([^']*)'|([^\s,;]+))/gim,
    )) {
      const value = match[2] ?? match[3] ?? match[4] ?? '';
      if (!isPlaceholderSecret(value)) add('signing password field');
    }
  }
  return failures;
}

function decodedBufferVariants(buffer) {
  const variants = [];
  if (buffer.length >= 3 &&
      buffer[0] === 0xef && buffer[1] === 0xbb && buffer[2] === 0xbf) {
    return [buffer.subarray(3).toString('utf8')];
  }
  if (buffer.length >= 2 && buffer[0] === 0xff && buffer[1] === 0xfe) {
    return [buffer.subarray(2).toString('utf16le')];
  }
  if (buffer.length >= 2 && buffer[0] === 0xfe && buffer[1] === 0xff) {
    return [decodeUtf16Be(buffer.subarray(2))];
  }

  if (buffer.includes(0)) {
    const pairs = Math.floor(buffer.length / 2);
    let evenZeros = 0;
    let oddZeros = 0;
    for (let index = 0; index < pairs * 2; index += 2) {
      if (buffer[index] === 0) evenZeros += 1;
      if (buffer[index + 1] === 0) oddZeros += 1;
    }
    // UTF-16LE ASCII places NUL bytes in odd positions; UTF-16BE places
    // them in even positions. Random binary data does not meet either ratio.
    if (pairs > 0 && oddZeros / pairs >= 0.3) return [buffer.toString('utf16le')];
    if (pairs > 0 && evenZeros / pairs >= 0.3) return [decodeUtf16Be(buffer)];
    return [];
  }
  variants.push(buffer.toString('utf8'));
  return [...new Set(variants)];
}

function decodeUtf16Be(buffer) {
  const evenLength = buffer.length - (buffer.length % 2);
  const swapped = Buffer.allocUnsafe(evenLength);
  for (let index = 0; index < evenLength; index += 2) {
    swapped[index] = buffer[index + 1];
    swapped[index + 1] = buffer[index];
  }
  return swapped.toString('utf16le');
}

function scanPublicationBufferDetailed(buffer, label, options = {}) {
  const failures = [];
  for (const text of decodedBufferVariants(Buffer.from(buffer))) {
    failures.push(...scanPublicationTextDetailed(text, label, options));
  }
  const seen = new Set();
  return failures.filter((failure) => {
    if (seen.has(failure.message)) return false;
    seen.add(failure.message);
    return true;
  });
}

export function scanPublicationBuffer(buffer, label, options = {}) {
  return scanPublicationBufferDetailed(buffer, label, options)
    .map((failure) => failure.message);
}

export function scanPublicationText(text, label, options = {}) {
  return scanPublicationTextDetailed(text, label, options)
    .map((failure) => failure.message);
}

function scanPublicationPathDetailed(relativePath) {
  const normalized = relativePath.replaceAll('\\', '/');
  const basename = normalized.slice(normalized.lastIndexOf('/') + 1);
  const lower = basename.toLowerCase();
  const forbidden = /\.(?:p12|p7b|jks|keystore|pfx|sqlite|pem)$/i.test(lower) ||
    (/^\.env(?:\..+)?$/i.test(lower) && !safeEnvironmentExamples.test(lower)) ||
    /^(?:credentials(?:\.json)?|id_(?:dsa|ec|ed25519|rsa)|\.envrc|\.netrc|\.npmrc|\.pgpass)$/i.test(lower) ||
    /\.key$/i.test(lower);
  return forbidden
    ? [{ reason: 'forbidden credential/signing artifact' }]
    : [];
}

export function scanPublicationPath(relativePath) {
  return scanPublicationPathDetailed(relativePath)
    .map(() => `${relativePath}: forbidden credential/signing artifact`);
}

export function parseNullTerminatedPathList(value) {
  return Buffer.from(value)
    .toString('utf8')
    .split('\0')
    .filter(Boolean);
}

export function scanWorkingTree({
  root = repositoryRoot,
  forbiddenHosts = privateHostsFromEnv(),
} = {}) {
  const failures = [];
  const files = parseNullTerminatedPathList(git(
    ['ls-files', '-z', '--cached', '--others', '--exclude-standard'],
    root,
    'buffer',
  ));
  for (const file of files) {
    failures.push(...scanPublicationPath(file));
    let buffer;
    try {
      buffer = readFileSync(path.join(root, file));
    } catch (error) {
      failures.push(
        `${file}: working-tree file could not be read ` +
        `(${error.code || error.message})`,
      );
      continue;
    }
    failures.push(...scanPublicationBuffer(buffer, file, { forbiddenHosts }));
  }
  return failures;
}

export const scanTrackedWorkingTree = scanWorkingTree;

function historyFindingKey(commit, object, reason) {
  return `${commit}\0${object}\0${reason}`;
}

function addHistoryFinding(counts, commit, object, reason) {
  const key = historyFindingKey(commit, object, reason);
  const current = counts.get(key);
  counts.set(key, {
    commit,
    object,
    reason,
    count: (current?.count ?? 0) + 1,
  });
}

function readGitBlobBatch(root, objectIds) {
  if (objectIds.length === 0) return new Map();
  const output = git(
    ['cat-file', '--batch'],
    root,
    'buffer',
    {
      input: Buffer.from(`${objectIds.join('\n')}\n`, 'utf8'),
      maxBuffer: 512 * 1024 * 1024,
    },
  );
  const blobs = new Map();
  let offset = 0;
  while (offset < output.length) {
    const headerEnd = output.indexOf(0x0a, offset);
    if (headerEnd < 0) throw new Error('git cat-file returned a truncated batch header');
    const header = output.subarray(offset, headerEnd).toString('utf8');
    const [object, type, sizeText] = header.split(' ');
    const size = Number(sizeText);
    if (!gitObjectPattern.test(object) || !Number.isSafeInteger(size) || size < 0) {
      throw new Error(`git cat-file returned an invalid batch header: ${header}`);
    }
    const contentStart = headerEnd + 1;
    const contentEnd = contentStart + size;
    if (contentEnd > output.length) {
      throw new Error(`git cat-file returned truncated content for ${object}`);
    }
    if (type === 'blob') blobs.set(object, output.subarray(contentStart, contentEnd));
    offset = contentEnd;
    if (output[offset] === 0x0a) offset += 1;
  }
  return blobs;
}

export function collectPublicationHistoryFindings({
  root = repositoryRoot,
  forbiddenHosts = privateHostsFromEnv(),
} = {}) {
  if (git(['rev-parse', '--is-shallow-repository'], root).trim() === 'true') {
    throw new Error('publication history scan requires a non-shallow clone');
  }
  const counts = new Map();
  const trees = [];
  const blobIds = new Set();
  const commits = git(['rev-list', '--all'], root)
    .trim()
    .split('\n')
    .filter(Boolean);

  for (const commit of commits) {
    const metadata = git(
      ['show', '-s', '--format=%B%n%an%n%ae%n%cn%n%ce', commit],
      root,
    );
    for (const failure of scanPublicationTextDetailed(
      metadata,
      `${commit.slice(0, 8)} metadata`,
      { forbiddenHosts },
    )) {
      addHistoryFinding(counts, commit, 'commit-metadata', failure.reason);
    }

    const entries = [];
    const rows = parseNullTerminatedPathList(
      git(['ls-tree', '-r', '-z', commit], root, 'buffer'),
    );
    for (const row of rows) {
      const match = /^\d+ blob ([a-f0-9]+)\t([\s\S]+)$/.exec(row);
      if (!match) continue;
      const [, object, filename] = match;
      entries.push({ object, filename });
      blobIds.add(object);
      for (const failure of scanPublicationPathDetailed(filename)) {
        addHistoryFinding(counts, commit, object, failure.reason);
      }
    }
    trees.push({ commit, entries });
  }

  const blobs = readGitBlobBatch(root, [...blobIds].sort());
  const blobFailures = new Map();
  for (const object of blobIds) {
    const buffer = blobs.get(object);
    if (!buffer) throw new Error(`git cat-file did not return blob ${object}`);
    blobFailures.set(
      object,
      scanPublicationBufferDetailed(buffer, object, { forbiddenHosts }),
    );
  }

  for (const tree of trees) {
    for (const entry of tree.entries) {
      for (const reason of blobFailures.get(entry.object)) {
        addHistoryFinding(counts, tree.commit, entry.object, reason.reason);
      }
    }
  }

  return [...counts.values()].sort((left, right) =>
    historyFindingKey(left.commit, left.object, left.reason)
      .localeCompare(historyFindingKey(right.commit, right.object, right.reason)));
}

function validatePublicationBaseline(baseline) {
  if (!baseline || typeof baseline !== 'object' || Array.isArray(baseline)) {
    throw new Error('publication baseline must be a JSON object');
  }
  if (baseline.schemaVersion !== 1) {
    throw new Error('publication baseline schemaVersion must be 1');
  }
  if (!Array.isArray(baseline.entries)) {
    throw new Error('publication baseline entries must be an array');
  }
  const keys = new Set();
  for (const [index, entry] of baseline.entries.entries()) {
    const path = `publication baseline entries[${index}]`;
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
      throw new Error(`${path} must be an object`);
    }
    if (entry.object !== 'commit-metadata' &&
        !gitObjectPattern.test(entry.object || '')) {
      throw new Error(`${path}.object must be commit-metadata or a full lowercase Git object id`);
    }
    if (entry.commit !== undefined && !gitObjectPattern.test(entry.commit || '')) {
      throw new Error(`${path}.commit must be a full lowercase Git object id when present`);
    }
    if (entry.object === 'commit-metadata' && entry.commit === undefined) {
      throw new Error(`${path}.commit is required for commit-metadata entries`);
    }
    if (typeof entry.reason !== 'string' || !entry.reason.trim()) {
      throw new Error(`${path}.reason is required`);
    }
    if (!historicalBaselineReasons.has(entry.reason)) {
      throw new Error(
        `${path}.reason is not eligible for a historical baseline`,
      );
    }
    if (!Number.isSafeInteger(entry.count) || entry.count < 1) {
      throw new Error(`${path}.count must be a positive integer`);
    }
    const key = entry.commit === undefined
      ? `blob\0${entry.object}\0${entry.reason}`
      : historyFindingKey(entry.commit, entry.object, entry.reason);
    if (keys.has(key)) throw new Error(`${path} duplicates another baseline entry`);
    keys.add(key);
  }
  return baseline;
}

export function loadPublicationBaseline(root = repositoryRoot) {
  const baselinePath = path.join(root, 'scripts', 'publication-baseline.json');
  if (!existsSync(baselinePath)) {
    return validatePublicationBaseline({ schemaVersion: 1, entries: [] });
  }
  return validatePublicationBaseline(JSON.parse(readFileSync(baselinePath, 'utf8')));
}

export function applyPublicationBaseline(findings, baseline) {
  const validated = validatePublicationBaseline(baseline);
  const exactExpected = new Map();
  const blobExpected = new Map();
  for (const entry of validated.entries) {
    if (entry.commit === undefined) {
      blobExpected.set(`${entry.object}\0${entry.reason}`, entry);
    } else {
      exactExpected.set(
        historyFindingKey(entry.commit, entry.object, entry.reason),
        entry,
      );
    }
  }
  const actual = new Map(
    findings.map((finding) => [
      historyFindingKey(finding.commit, finding.object, finding.reason),
      finding,
    ]),
  );
  const failures = [];
  const label = finding => {
    const object = finding.object === 'commit-metadata'
      ? 'metadata'
      : finding.object.slice(0, 8);
    return `history ${finding.commit.slice(0, 8)}:${object}: ${finding.reason}`;
  };

  for (const [key, finding] of actual) {
    const baselineEntry = exactExpected.get(key) ??
      blobExpected.get(`${finding.object}\0${finding.reason}`);
    if (baselineEntry?.count >= finding.count) continue;
    if (!baselineEntry) {
      failures.push(`${label(finding)} (${finding.count} occurrences)`);
    } else {
      failures.push(
        `${label(finding)} baseline count exceeded ` +
        `(${finding.count}/${baselineEntry.count})`,
      );
    }
  }
  for (const [key, entry] of exactExpected) {
    const finding = actual.get(key);
    if (finding && finding.count >= entry.count) continue;
    const object = entry.object === 'commit-metadata'
      ? 'metadata'
      : entry.object.slice(0, 8);
    failures.push(
      `history ${entry.commit.slice(0, 8)}:${object}: ${entry.reason} ` +
      `${finding ? 'baseline is stale or count changed' : 'baseline entry is stale'}`,
    );
  }
  const actualBlobKeys = new Set(
    findings.map((finding) => `${finding.object}\0${finding.reason}`),
  );
  for (const [key, entry] of blobExpected) {
    if (actualBlobKeys.has(key)) continue;
    failures.push(
      `history blob ${entry.object.slice(0, 8)}: ${entry.reason} baseline entry is stale`,
    );
  }
  return failures;
}

export function scanReachableHistory({
  root = repositoryRoot,
  forbiddenHosts = privateHostsFromEnv(),
  baseline,
} = {}) {
  const failures = scanWorkingTree({ root, forbiddenHosts });
  failures.push(...applyPublicationBaseline(
    collectPublicationHistoryFindings({ root, forbiddenHosts }),
    baseline ?? loadPublicationBaseline(root),
  ));
  const stagedFiles = parseNullTerminatedPathList(git(
    ['diff', '--cached', '--name-only', '-z', '--diff-filter=ACMR'],
    root,
    'buffer',
  ));
  for (const file of stagedFiles) {
    failures.push(...scanPublicationPath(file));
    try {
      failures.push(...scanPublicationBuffer(
        git(['show', ':' + file], root, 'buffer'),
        'staged:' + file,
        { forbiddenHosts },
      ));
    } catch (error) {
      failures.push(`staged:${file}: file could not be read (${error.code || error.message})`);
    }
  }
  return failures;
}

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : '';
if (invokedPath === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const unknown = args.filter(arg => arg !== '--working-tree');
  if (unknown.length) {
    console.error(`Unknown argument(s): ${unknown.join(', ')}`);
    process.exitCode = 2;
  } else {
    const workingTreeOnly = args.includes('--working-tree');
    const failures = workingTreeOnly
      ? scanWorkingTree()
      : scanReachableHistory();
    if (failures.length) {
      console.error([...new Set(failures)].join('\n'));
      process.exitCode = 1;
    } else {
      console.log(
        workingTreeOnly
          ? 'Publication checks passed for the working tree'
          : 'Publication checks passed for working tree, reachable history and staged content',
      );
    }
  }
}
