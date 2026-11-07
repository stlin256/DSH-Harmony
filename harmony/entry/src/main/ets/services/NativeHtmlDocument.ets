export class NativeHtmlAssetReference {
  kind: string = 'binary';
  path: string = '';
}

function normalizePath(value: string): string {
  const parts: string[] = [];
  const clean = value.replace(/\\/g, '/').replace(/^\/+/, '');
  for (const part of clean.split('/')) {
    if (!part || part === '.') continue;
    if (part === '..') {
      if (!parts.length) return '';
      parts.pop();
      continue;
    }
    parts.push(part);
  }
  return parts.join('/');
}

function directoryOf(path: string): string {
  const clean = path.replace(/\\/g, '/').replace(/^\/+/, '');
  const slash = clean.lastIndexOf('/');
  return slash >= 0 ? clean.slice(0, slash) : '';
}

export function nativeHtmlResolveReference(documentPath: string, reference: string): string {
  const clean = reference.trim().replace(/&amp;/g, '&');
  if (!clean || clean.startsWith('#') || /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(clean)) return '';
  const withoutSuffix = clean.split('#')[0].split('?')[0];
  if (!withoutSuffix) return '';
  let decoded = withoutSuffix;
  try { decoded = decodeURIComponent(withoutSuffix); } catch (_) {}
  if (decoded.startsWith('/')) return normalizePath(decoded);
  const directory = directoryOf(documentPath);
  return normalizePath(directory ? directory + '/' + decoded : decoded);
}

export function nativeHtmlMimeType(path: string): string {
  const clean = path.toLowerCase().split('#')[0].split('?')[0];
  const dot = clean.lastIndexOf('.');
  const extension = dot >= 0 ? clean.slice(dot + 1) : '';
  if (extension === 'css') return 'text/css';
  if (extension === 'js' || extension === 'mjs') return 'text/javascript';
  if (extension === 'html' || extension === 'htm') return 'text/html';
  if (extension === 'svg') return 'image/svg+xml';
  if (extension === 'png') return 'image/png';
  if (extension === 'jpg' || extension === 'jpeg') return 'image/jpeg';
  if (extension === 'gif') return 'image/gif';
  if (extension === 'webp') return 'image/webp';
  if (extension === 'woff') return 'font/woff';
  if (extension === 'woff2') return 'font/woff2';
  if (extension === 'ttf') return 'font/ttf';
  if (extension === 'otf') return 'font/otf';
  if (extension === 'mp4') return 'video/mp4';
  if (extension === 'webm') return 'video/webm';
  if (extension === 'mp3') return 'audio/mpeg';
  if (extension === 'ogg') return 'audio/ogg';
  if (extension === 'wav') return 'audio/wav';
  return 'application/octet-stream';
}

function addReference(target: NativeHtmlAssetReference[], kind: string, path: string): void {
  if (!path || target.some((entry: NativeHtmlAssetReference): boolean =>
    entry.kind === kind && entry.path === path)) return;
  const reference = new NativeHtmlAssetReference();
  reference.kind = kind;
  reference.path = path;
  target.push(reference);
}

function attribute(tag: string, name: string): string {
  const match = new RegExp('\\b' + name + '\\s*=\\s*([\"\\\'])(.*?)\\1', 'i').exec(tag);
  return match ? match[2] : '';
}

function addCssReferences(target: NativeHtmlAssetReference[], css: string, cssPath: string): void {
  const pattern = /url\(\s*(['"]?)(.*?)\1\s*\)/gi;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(css)) !== null) {
    addReference(target, 'binary', nativeHtmlResolveReference(cssPath, match[2]));
  }
}

export function nativeHtmlCssReferences(css: string, cssPath: string): NativeHtmlAssetReference[] {
  const references: NativeHtmlAssetReference[] = [];
  addCssReferences(references, css, cssPath);
  return references;
}

export function nativeHtmlReferences(source: string, documentPath: string): NativeHtmlAssetReference[] {
  const references: NativeHtmlAssetReference[] = [];
  const link = /<link\b[^>]*>/gi;
  let tag: RegExpExecArray | null;
  while ((tag = link.exec(source)) !== null) {
    if (!/\brel\s*=\s*(['"])[^'"]*stylesheet[^'"]*\1/i.test(tag[0])) continue;
    addReference(references, 'style', nativeHtmlResolveReference(documentPath, attribute(tag[0], 'href')));
  }
  const resource = /<(?:img|source|video|audio|script|embed|object|input)\b[^>]*>/gi;
  while ((tag = resource.exec(source)) !== null) {
    const raw = tag[0];
    const kind = /^<script/i.test(raw) ? 'script' : 'binary';
    ['src', 'poster', 'data'].forEach((name: string): void => {
      addReference(references, kind, nativeHtmlResolveReference(documentPath, attribute(raw, name)));
    });
    attribute(raw, 'srcset').split(',').forEach((entry: string): void => {
      const candidate = entry.trim().split(/\s+/)[0] || '';
      addReference(references, 'binary', nativeHtmlResolveReference(documentPath, candidate));
    });
  }
  const style = /<style\b[^>]*>([\s\S]*?)<\/style>/gi;
  while ((tag = style.exec(source)) !== null) addCssReferences(references, tag[1], documentPath);
  const styleAttribute = /\bstyle\s*=\s*(['"])(.*?)\1/gi;
  while ((tag = styleAttribute.exec(source)) !== null) addCssReferences(references, tag[2], documentPath);
  return references;
}

function remoteUrl(reference: string): string {
  let url = reference.trim().replace(/&amp;/g, '&');
  if (url.startsWith('//')) url = 'https:' + url;
  return /^https?:\/\//i.test(url) ? url : '';
}

/** Absolute HTTP(S) references an author wrote into a CSS text. */
export function nativeHtmlRemoteCssReferences(css: string): string[] {
  const result: string[] = [];
  const pattern = /url\(\s*(['"]?)(.*?)\1\s*\)/gi;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(css)) !== null) {
    const url = remoteUrl(match[2]);
    if (url && !result.includes(url)) result.push(url);
  }
  return result;
}

/**
 * Absolute HTTP(S) subresource URLs the document author declared statically.
 * Only these remote URLs may load in the preview; everything else a script
 * constructs at runtime is blocked by NativeHtmlPreview's request interceptor.
 */
export function nativeHtmlRemoteReferences(source: string): string[] {
  const result: string[] = [];
  const add = (reference: string): void => {
    const url = remoteUrl(reference);
    if (url && !result.includes(url)) result.push(url);
  };
  const link = /<link\b[^>]*>/gi;
  let tag: RegExpExecArray | null;
  while ((tag = link.exec(source)) !== null) {
    if (/\brel\s*=\s*(['"])[^'"]*stylesheet[^'"]*\1/i.test(tag[0])) add(attribute(tag[0], 'href'));
  }
  const resource = /<(?:img|source|video|audio|script|embed|object|input)\b[^>]*>/gi;
  while ((tag = resource.exec(source)) !== null) {
    const raw = tag[0];
    ['src', 'poster', 'data'].forEach((name: string): void => { add(attribute(raw, name)); });
    attribute(raw, 'srcset').split(',').forEach((entry: string): void => {
      add(entry.trim().split(/\s+/)[0] || '');
    });
  }
  const style = /<style\b[^>]*>([\s\S]*?)<\/style>/gi;
  while ((tag = style.exec(source)) !== null) {
    for (const url of nativeHtmlRemoteCssReferences(tag[1])) {
      if (!result.includes(url)) result.push(url);
    }
  }
  const styleAttribute = /\bstyle\s*=\s*(['"])(.*?)\1/gi;
  while ((tag = styleAttribute.exec(source)) !== null) {
    for (const url of nativeHtmlRemoteCssReferences(tag[2])) {
      if (!result.includes(url)) result.push(url);
    }
  }
  return result;
}

export function nativeHtmlInlineCss(css: string, cssPath: string,
  assets: Map<string, string>): string {
  return css.replace(/url\(\s*(['"]?)(.*?)\1\s*\)/gi,
    (whole: string, quote: string, reference: string): string => {
      const path = nativeHtmlResolveReference(cssPath, reference);
      const value = path ? assets.get(path) || '' : '';
      return value ? 'url("' + value + '")' : 'url("data:application/octet-stream;base64,")';
    });
}

function localFileUrl(path: string): string {
  return 'dshharmony://file?path=' + encodeURIComponent(path);
}

function policy(): string {
  // Scripts keep running (the preview is interactive), but nothing the page
  // computes may leave the component: programmatic network, form posts and
  // remote frames/objects are denied, and subresource loads are additionally
  // gated by the authored-URL allowlist in NativeHtmlPreview.
  return '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; ' +
    'img-src data: blob: http: https:; ' +
    'style-src \'unsafe-inline\' data: http: https:; ' +
    'script-src \'unsafe-inline\' data: http: https:; ' +
    'media-src data: blob: http: https:; font-src data: http: https:; ' +
    'connect-src \'none\'; frame-src \'none\'; object-src data:; ' +
    'form-action \'none\'; base-uri \'none\';">' +
    '<meta name="referrer" content="no-referrer"><meta name="viewport" ' +
    'content="width=device-width,initial-scale=1,maximum-scale=5,viewport-fit=cover">';
}

export function nativeHtmlInline(source: string, documentPath: string,
  assets: Map<string, string>): string {
  let output = source;
  // The preview inlines workspace assets as data URLs. Author CSP declarations
  // that predate that rewrite combine with the policy below and can otherwise
  // block those URLs even though the preview itself is sandboxed.
  output = output.replace(
    /<meta\b[^>]*http-equiv\s*=\s*(['"])content-security-policy\1[^>]*>/gi, '');
  output = output.replace(/<link\b[^>]*>/gi, (tag: string): string => {
    if (!/\brel\s*=\s*(['"])[^'"]*stylesheet[^'"]*\1/i.test(tag)) return tag;
    const path = nativeHtmlResolveReference(documentPath, attribute(tag, 'href'));
    return path && assets.has(path) ? '<style>' + assets.get(path) + '</style>' : '';
  });
  output = output.replace(/<(script|img|source|video|audio|embed|object|input)\b[^>]*>/gi,
    (tag: string): string => {
      let next = tag.replace(/\b(src|poster|data)\s*=\s*(['"])(.*?)\2/gi,
        (whole: string, name: string, quote: string, reference: string): string => {
          const path = nativeHtmlResolveReference(documentPath, reference);
          const value = path ? assets.get(path) || '' : '';
          return value ? name + '="' + value + '"' : whole;
        });
      next = next.replace(/\bsrcset\s*=\s*(['"])(.*?)\1/gi,
        (whole: string, quote: string, value: string): string => {
          if (/^(?:data:|https?:|\/\/)/i.test(value.trim())) return whole;
          const rewritten = value.split(',').map((entry: string): string => {
            const pieces = entry.trim().split(/\s+/);
            const path = nativeHtmlResolveReference(documentPath, pieces[0] || '');
            const asset = path ? assets.get(path) || '' : '';
            return asset ? asset + (pieces.length > 1 ? ' ' + pieces.slice(1).join(' ') : '') : '';
          }).filter((entry: string): boolean => !!entry).join(',');
          return 'srcset="' + rewritten + '"';
        });
      return next;
    });
  output = output.replace(/<style\b([^>]*)>([\s\S]*?)<\/style>/gi,
    (_whole: string, attrs: string, css: string): string =>
      '<style' + attrs + '>' + nativeHtmlInlineCss(css, documentPath, assets) + '</style>');
  output = output.replace(/\bstyle\s*=\s*(['"])(.*?)\1/gi,
    (_whole: string, _quote: string, css: string): string =>
      'style="' + nativeHtmlInlineCss(css, documentPath, assets) + '"');
  output = output.replace(/<a\b[^>]*>/gi, (tag: string): string => {
    const href = attribute(tag, 'href');
    if (!href || href.startsWith('#') || /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(href)) return tag;
    const path = nativeHtmlResolveReference(documentPath, href);
    if (!path) return tag;
    return tag.replace(/\bhref\s*=\s*(['"])(.*?)\1/i,
      (_whole: string, _quote: string, _reference: string): string => 'href="' + localFileUrl(path) + '"');
  });
  if (/<\/head>/i.test(output)) return output.replace(/<\/head>/i, policy() + '</head>');
  return policy() + output;
}
