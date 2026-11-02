import { NativeSecretSpan, nativeSecretSpans } from './NativeSecretMask';

/** Styled runs for ArkUI Text. Malformed markup stays readable and code is literal. */
export class NativeInlineRun {
  text: string = '';
  bold: boolean = false;
  italic: boolean = false;
  code: boolean = false;
  strike: boolean = false;
  href: string = '';
  isImage: boolean = false;
  alt: string = '';
  secret: boolean = false;
}

/**
 * Inline code commonly contains the file references emitted by coding agents.
 * Keep commands and expressions literal; only promote high-confidence paths.
 */
export function nativeInlineFileReference(value: string): string {
  const text = value.trim();
  if (!text || text.length > 500 || /\s/.test(text)) return '';
  if (/^(?:https?:|mailto:|tel:|file:|dsh-resource:\/\/)/i.test(text)) return text;
  if (/^(?:\.{1,2}\/|\/|~\/|[A-Za-z]:[\\/])/.test(text)) return text;
  const extension = text.match(/\.([A-Za-z0-9]{1,16})(?::\d+(?::\d+)?)?(?:#L\d+(?:-L?\d+)?)?$/);
  const known = ['md','mdx','ts','tsx','js','jsx','json','py','svg','png','jpg','jpeg','webp','gif','pdf',
    'html','css','scss','less','yaml','yml','toml','xml','sh','ps1','bat','ets','c','cc','cpp','h','hpp',
    'java','kt','rs','go','rb','php','sql','csv','txt','log','zip','lock','conf','ini','env','vue','astro'];
  if (extension && known.includes(extension[1].toLowerCase())) return text;
  return '';
}

/** Links whose normal action leaves the workspace for another application. */
export function nativeInlineExternalLink(value: string): boolean {
  const text = value.trim();
  return /^(?:https?:|mailto:|tel:)/i.test(text);
}

function run(text: string, style: NativeInlineRun): NativeInlineRun {
  const value = new NativeInlineRun();
  value.text = text; value.bold = style.bold; value.italic = style.italic;
  value.code = style.code; value.strike = style.strike; value.href = style.href;
  value.isImage = style.isImage; value.alt = style.alt; value.secret = style.secret;
  return value;
}

function secretAt(spans: NativeSecretSpan[], offset: number): NativeSecretSpan | null {
  for (let index = 0; index < spans.length; index++) {
    if (spans[index].start === offset) return spans[index];
  }
  return null;
}

function plainSecretRuns(source: string, style: NativeInlineRun,
  spans: NativeSecretSpan[], baseOffset: number): NativeInlineRun[] {
  const rows: NativeInlineRun[] = [];
  let plain = '';
  let index = 0;
  while (index < source.length) {
    const secret = secretAt(spans, baseOffset + index);
    if (secret && secret.end <= baseOffset + source.length) {
      if (plain) { rows.push(run(plain, style)); plain = ''; }
      const masked = run(secret.masked, style);
      masked.secret = true;
      rows.push(masked);
      index += secret.end - secret.start;
      continue;
    }
    plain += source.charAt(index);
    index++;
  }
  if (plain) rows.push(run(plain, style));
  return rows;
}

function scan(source: string, style: NativeInlineRun, depth: number,
  spans: NativeSecretSpan[] = [], baseOffset: number = 0): NativeInlineRun[] {
  if (depth > 6) return plainSecretRuns(source, style, spans, baseOffset);
  const rows: NativeInlineRun[] = [];
  let plain = '';
  let index = 0;
  while (index < source.length) {
    const secret = secretAt(spans, baseOffset + index);
    if (secret && secret.end <= baseOffset + source.length) {
      if (plain) { rows.push(run(plain, style)); plain = ''; }
      const masked = run(secret.masked, style);
      masked.secret = true;
      rows.push(masked);
      index += secret.end - secret.start;
      continue;
    }
    const ch = source.charAt(index);
    if (ch === '\\' && index + 1 < source.length && '\\`*_{}[]()#+-.!~>'.includes(source.charAt(index + 1))) {
      plain += source.charAt(index + 1); index += 2; continue;
    }
    if (ch === '`') {
      let count = 1;
      while (source.charAt(index + count) === '`') count++;
      const marker = '`'.repeat(count);
      const end = source.indexOf(marker, index + count);
      if (end > index + count) {
        if (plain) { rows.push(run(plain, style)); plain = ''; }
        const code = run(source.slice(index + count, end), style); code.code = true;
        rows.push(code); index = end + count; continue;
      }
    }
    if (ch === '[' || (ch === '!' && source.charAt(index + 1) === '[')) {
      const labelStart = index + (ch === '!' ? 2 : 1);
      const close = source.indexOf('](', labelStart);
      if (close >= labelStart) {
        let cursor = close + 2;
        let nesting = 1;
        while (cursor < source.length && nesting > 0) {
          if (source.charAt(cursor) === '\\') { cursor += 2; continue; }
          if (source.charAt(cursor) === '(') nesting++;
          if (source.charAt(cursor) === ')') nesting--;
          if (nesting > 0) cursor++;
        }
        if (nesting === 0) {
          const target = source.slice(close + 2, cursor).trim();
          if (target) {
            if (plain) { rows.push(run(plain, style)); plain = ''; }
            const linked = run('', style);
            linked.href = target.startsWith('<') && target.endsWith('>') ? target.slice(1, -1) : target;
            linked.isImage = ch === '!';
            linked.alt = source.slice(labelStart, close) || '图片';
            rows.push(...scan(source.slice(labelStart, close) || '图片', linked, depth + 1,
              spans, baseOffset + labelStart));
            index = cursor + 1; continue;
          }
        }
      }
    }
    const pair = source.slice(index, index + 2);
    const marker = pair === '**' || pair === '__' || pair === '~~' ? pair : ch === '*' ? '*' : '';
    if (marker) {
      const end = source.indexOf(marker, index + marker.length);
      if (end > index + marker.length) {
        if (plain) { rows.push(run(plain, style)); plain = ''; }
        const nested = run('', style);
        if (marker === '~~') nested.strike = true;
        else if (marker === '*') nested.italic = true;
        else nested.bold = true;
        rows.push(...scan(source.slice(index + marker.length, end), nested, depth + 1,
          spans, baseOffset + index + marker.length));
        index = end + marker.length; continue;
      }
    }
    plain += ch; index++;
  }
  if (plain) rows.push(run(plain, style));
  return rows;
}

export function nativeInlineMarkdownMasked(source: string): NativeInlineRun[] {
  const spans = nativeSecretSpans(source);
  if (!spans.length) return nativeInlineMarkdown(source);
  return scan(source, new NativeInlineRun(), 0, spans, 0);
}

export function nativeInlineMarkdown(source: string): NativeInlineRun[] {
  // Plain prose is the dominant streaming case. Avoid walking and allocating a
  // run for every token when there is no inline Markdown control character.
  if (!/[\\`*_\[\]!~]/.test(source)) {
    const plain = new NativeInlineRun();
    plain.text = source;
    return source ? [plain] : [];
  }
  const rows = scan(source, new NativeInlineRun(), 0);
  rows.forEach((row: NativeInlineRun): void => {
    if (row.code && !row.href) row.href = nativeInlineFileReference(row.text);
  });
  return rows;
}
