/**
 * Display-only credential masking. Source text and copy values stay untouched.
 * The formats are intentionally high confidence; ordinary key=value prose is
 * not treated as a secret without a recognizable provider shape.
 */
export class NativeSecretSpan {
  start: number = 0;
  end: number = 0;
  masked: string = '';
  kind: string = 'token';
}

class NativeTokenFormat {
  prefix: string = '';
  minimum: number = 0;
  maximum: number = 0;
  charset: string = 'key';
  exact: boolean = false;
  requireDigit: boolean = false;
}

function tokenFormat(prefix: string, minimum: number, maximum: number = 0,
  charset: string = 'key', exact: boolean = false, requireDigit: boolean = false): NativeTokenFormat {
  const value = new NativeTokenFormat();
  value.prefix = prefix;
  value.minimum = minimum;
  value.maximum = maximum;
  value.charset = charset;
  value.exact = exact;
  value.requireDigit = requireDigit;
  return value;
}

const tokenFormats: NativeTokenFormat[] = [
  tokenFormat('sk-', 20, 0, 'key', false, true),
  tokenFormat('AIza', 35, 35, 'key', true),
  tokenFormat('ghp_', 36, 0, 'alnum'),
  tokenFormat('gho_', 36, 0, 'alnum'),
  tokenFormat('ghu_', 36, 0, 'alnum'),
  tokenFormat('ghs_', 36, 0, 'alnum'),
  tokenFormat('ghr_', 36, 0, 'alnum'),
  tokenFormat('github_pat_', 22, 0, 'word'),
  tokenFormat('glpat-', 20, 0, 'key'),
  tokenFormat('npm_', 36, 0, 'alnum'),
  tokenFormat('hf_', 30, 0, 'alnum'),
  tokenFormat('AKIA', 16, 16, 'upper', true),
  tokenFormat('ASIA', 16, 16, 'upper', true),
  tokenFormat('LTAI', 12, 20, 'alnum'),
  tokenFormat('AKID', 28, 36, 'alnum'),
  tokenFormat('xoxa-', 10, 0, 'alnumDash'),
  tokenFormat('xoxb-', 10, 0, 'alnumDash'),
  tokenFormat('xoxp-', 10, 0, 'alnumDash'),
  tokenFormat('xoxr-', 10, 0, 'alnumDash'),
  tokenFormat('xoxs-', 10, 0, 'alnumDash'),
  tokenFormat('sk_live_', 16, 0, 'alnum'),
  tokenFormat('sk_test_', 16, 0, 'alnum'),
  tokenFormat('rk_live_', 16, 0, 'alnum'),
  tokenFormat('rk_test_', 16, 0, 'alnum'),
  tokenFormat('whsec_', 24, 0, 'alnum')
];

function isAsciiAlnum(value: string): boolean {
  return /^[A-Za-z0-9]$/.test(value);
}

function isAsciiUpper(value: string): boolean {
  return /^[A-Z0-9]$/.test(value);
}

function allowed(value: string, charset: string): boolean {
  if (charset === 'alnum') return isAsciiAlnum(value);
  if (charset === 'upper') return isAsciiUpper(value);
  if (charset === 'word') return isAsciiAlnum(value) || value === '_';
  if (charset === 'alnumDash') return isAsciiAlnum(value) || value === '-';
  return isAsciiAlnum(value) || value === '_' || value === '-';
}

function wordBefore(text: string, index: number): boolean {
  if (index <= 0) return false;
  return /^[A-Za-z0-9_]$/.test(text.charAt(index - 1));
}

function runEnd(text: string, start: number, charset: string): number {
  let end = start;
  while (end < text.length && allowed(text.charAt(end), charset)) end++;
  return end;
}

function addSpan(rows: NativeSecretSpan[], start: number, end: number,
  kind: string, masked: string): void {
  if (start < 0 || end <= start || end > masked.length + start) {
    if (start < 0 || end <= start) return;
  }
  const span = new NativeSecretSpan();
  span.start = start;
  span.end = end;
  span.kind = kind;
  span.masked = masked;
  rows.push(span);
}

function marks(text: string, start: number, end: number): string {
  let output = '';
  for (let index = start; index < end; index++) {
    const code = text.charCodeAt(index);
    if (code === 10 || code === 13) {
      output += text.charAt(index);
      continue;
    }
    if (code >= 0xD800 && code <= 0xDBFF && index + 1 < end) {
      const next = text.charCodeAt(index + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) index++;
    }
    output += '*';
  }
  return output;
}

function prefixedMask(text: string, start: number, end: number): string {
  const visible = Math.min(8, end - start);
  return text.substring(start, start + visible) + marks(text, start + visible, end);
}

function privateKeyMask(text: string, start: number, end: number): string {
  const firstBreak = text.indexOf('\n', start);
  const bodyStart = firstBreak >= 0 && firstBreak < end ? firstBreak + 1 : start;
  let bodyEnd = end;
  const endMarker = text.lastIndexOf('-----END ', end);
  if (endMarker >= bodyStart) {
    let lineStart = endMarker;
    while (lineStart > bodyStart && text.charAt(lineStart - 1) !== '\n') lineStart--;
    if (lineStart > bodyStart) bodyEnd = lineStart;
  }
  return text.substring(start, bodyStart) + marks(text, bodyStart, bodyEnd) +
    text.substring(bodyEnd, end);
}

function collectTokens(text: string, rows: NativeSecretSpan[]): void {
  tokenFormats.forEach((format: NativeTokenFormat): void => {
    let cursor = 0;
    while (cursor < text.length) {
      const at = text.indexOf(format.prefix, cursor);
      if (at < 0) break;
      cursor = at + format.prefix.length;
      if (wordBefore(text, at)) continue;
      const start = at + format.prefix.length;
      const end = runEnd(text, start, format.charset);
      const length = end - start;
      if (length < format.minimum) continue;
      if (format.maximum > 0 && length > format.maximum) continue;
      if (format.exact && length !== format.minimum) continue;
      if (format.requireDigit) {
        const limit = Math.min(end, start + 256);
        let hasDigit = false;
        for (let index = start; index < limit; index++) {
          if (/^[0-9]$/.test(text.charAt(index))) {
            hasDigit = true;
            break;
          }
        }
        if (!hasDigit) continue;
      }
      if (format.maximum > 0 && end < text.length && /^[A-Za-z0-9_]$/.test(text.charAt(end))) continue;
      addSpan(rows, at, end, 'token', prefixedMask(text, at, end));
    }
  });
}

function collectJwt(text: string, rows: NativeSecretSpan[]): void {
  const pattern = /eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g;
  let match: RegExpExecArray | null = pattern.exec(text);
  while (match) {
    const start = match.index;
    const end = start + match[0].length;
    addSpan(rows, start, end, 'jwt', prefixedMask(text, start, end));
    match = pattern.exec(text);
  }
}

function collectPrivateKeys(text: string, rows: NativeSecretSpan[]): void {
  let cursor = 0;
  while (cursor < text.length) {
    const start = text.indexOf('-----BEGIN ', cursor);
    if (start < 0) break;
    cursor = start + 11;
    const headerLimit = Math.min(text.length, start + 62);
    const headerTail = text.indexOf('PRIVATE KEY-----', start);
    if (headerTail < 0 || headerTail + 16 > headerLimit) continue;
    const firstBreak = text.indexOf('\n', headerTail + 16);
    if (firstBreak < 0) {
      addSpan(rows, start, text.length, 'privateKey',
        privateKeyMask(text, start, text.length));
      break;
    }
    let end = text.length;
    let search = firstBreak + 1;
    while (search < text.length) {
      const endStart = text.indexOf('-----END ', search);
      if (endStart < 0) break;
      const endTail = text.indexOf('PRIVATE KEY-----', endStart);
      if (endTail >= 0 && endTail - endStart < 52) {
        end = Math.min(text.length, endTail + 16);
        const lineBreak = text.indexOf('\n', end);
        if (lineBreak >= 0) end = lineBreak;
        break;
      }
      search = endStart + 9;
    }
    addSpan(rows, start, end, 'privateKey', privateKeyMask(text, start, end));
    cursor = Math.max(cursor, end);
  }
}

function collectUrlPasswords(text: string, rows: NativeSecretSpan[]): void {
  const pattern = /\b[a-z][a-z0-9+.-]{1,15}:\/\/[^\s/:@?#]{0,256}:[^\s/@?#]+@/g;
  let match: RegExpExecArray | null = pattern.exec(text);
  while (match) {
    const value = match[0];
    const scheme = value.indexOf('://');
    const colon = value.indexOf(':', scheme + 3);
    const at = value.lastIndexOf('@');
    if (colon > scheme + 3 && at > colon + 1) {
      const start = match.index + colon + 1;
      const end = match.index + at;
      addSpan(rows, start, end, 'urlPassword', marks(text, start, end));
    }
    match = pattern.exec(text);
  }
}

function orderedSpans(rows: NativeSecretSpan[]): NativeSecretSpan[] {
  rows.sort((left: NativeSecretSpan, right: NativeSecretSpan): number => {
    if (left.start !== right.start) return left.start - right.start;
    return left.end - right.end;
  });
  const result: NativeSecretSpan[] = [];
  rows.forEach((row: NativeSecretSpan): void => {
    const last = result.length ? result[result.length - 1] : null;
    if (!last || row.start >= last.end) {
      result.push(row);
    } else if (row.end > last.end) {
      last.end = row.end;
      last.masked = row.masked;
      last.kind = row.kind;
    }
  });
  return result;
}

export function nativeSecretSpans(text: string): NativeSecretSpan[] {
  if (!text) return [];
  const rows: NativeSecretSpan[] = [];
  collectPrivateKeys(text, rows);
  collectUrlPasswords(text, rows);
  collectTokens(text, rows);
  collectJwt(text, rows);
  return orderedSpans(rows);
}

export function nativeMaskSecrets(text: string, spans: NativeSecretSpan[] = []): string {
  const secrets = spans.length ? spans : nativeSecretSpans(text);
  if (!secrets.length) return text;
  let output = '';
  let cursor = 0;
  secrets.forEach((secret: NativeSecretSpan): void => {
    if (secret.start < cursor || secret.end > text.length) return;
    output += text.substring(cursor, secret.start) + secret.masked;
    cursor = secret.end;
  });
  return output + text.substring(cursor);
}

export function nativeHasSecrets(text: string): boolean {
  return nativeSecretSpans(text).length > 0;
}
