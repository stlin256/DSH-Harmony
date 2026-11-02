const imageExtensions: Set<string> = new Set<string>([
  'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'ico', 'dng', 'heic', 'heif', 'avif'
]);

const binaryExtensions: Set<string> = new Set<string>([
  'zip', 'gz', 'tgz', 'bz2', 'xz', 'zst', 'lz', 'lz4', '7z', 'rar', 'tar', 'cab',
  'jar', 'war', 'ear', 'whl', 'asar', 'crx', 'xpi', 'nupkg', 'apk', 'apks', 'xapk',
  'hap', 'hsp', 'ipa', 'app', 'msi', 'msix', 'appx', 'deb', 'rpm', 'pkg', 'dmg',
  'iso', 'docx', 'docm', 'dotx', 'dotm', 'xlsx', 'xlsm', 'xltx', 'xltm', 'pptx',
  'pptm', 'potx', 'potm', 'ppsx', 'ppsm', 'doc', 'xls', 'ppt', 'mdb', 'accdb',
  'odt', 'ods', 'odp', 'ott', 'ots', 'otp', 'pages', 'numbers', 'key', 'epub',
  'mobi', 'azw', 'azw3', 'djvu', 'exe', 'dll', 'so', 'dylib', 'bin', 'class', 'pyc',
  'pyo', 'o', 'a', 'lib', 'wasm', 'node', 'appimage', 'ttf', 'ttc', 'otf', 'otc',
  'woff', 'woff2', 'eot', 'mp3', 'wav', 'ogg', 'oga', 'flac', 'aac', 'm4a', 'm4b',
  'opus', 'aiff', 'aif', 'wma', 'amr', 'mid', 'midi', 'mp4', 'mov', 'webm', 'mkv',
  'avi', 'm4v', 'mpeg', 'mpg', 'm2ts', 'vob', 'wmv', 'flv', 'f4v', '3gp', '3g2',
  'asf', 'rm', 'rmvb', 'db', 'sqlite', 'sqlite3', 'realm', 'parquet', 'avro', 'orc',
  'h5', 'hdf5', 'psd', 'xcf', 'fig', 'sketch', 'ai', 'xd', 'svgz', 'tga', 'jxl',
  'tif', 'tiff', 'cr2', 'cr3', 'nef', 'arw', 'raf', 'rw2', 'orf', 'pef', 'srw',
  'webarchive', 'der', 'p12', 'pfx'
]);

const codeLanguages: Map<string, string> = new Map<string, string>([
  ['ts', 'typescript'], ['tsx', 'tsx'], ['mts', 'typescript'], ['cts', 'typescript'],
  ['js', 'javascript'], ['jsx', 'jsx'], ['mjs', 'javascript'], ['cjs', 'javascript'],
  ['ets', 'arkts'], ['sh', 'shell'], ['bash', 'shell'], ['zsh', 'shell'],
  ['fish', 'fish'], ['json', 'json'], ['jsonc', 'json'], ['jsonl', 'json'],
  ['ndjson', 'json'], ['ipynb', 'json'], ['csv', 'csv'], ['tsv', 'tsv'],
  ['py', 'python'], ['pyw', 'python'], ['pyi', 'python'], ['rb', 'ruby'],
  ['rake', 'ruby'], ['gemspec', 'ruby'], ['go', 'go'], ['rs', 'rust'],
  ['java', 'java'], ['c', 'c'], ['h', 'c'], ['cc', 'cpp'], ['cpp', 'cpp'],
  ['cxx', 'cpp'], ['hh', 'cpp'], ['hpp', 'cpp'], ['hxx', 'cpp'], ['cs', 'csharp'],
  ['kt', 'kotlin'], ['kts', 'kotlin'], ['swift', 'swift'], ['php', 'php'],
  ['yaml', 'yaml'], ['yml', 'yaml'], ['toml', 'toml'], ['ini', 'ini'],
  ['conf', 'ini'], ['cfg', 'ini'], ['properties', 'ini'], ['env', 'dotenv'],
  ['log', 'log'], ['diff', 'diff'], ['patch', 'diff'],
  ['http', 'http'], ['md', 'markdown'], ['markdown', 'markdown'], ['mdx', 'mdx'],
  ['rst', 'rst'], ['tex', 'latex'], ['sty', 'latex'], ['cls', 'latex'],
  ['bib', 'bibtex'], ['adoc', 'asciidoc'], ['html', 'html'], ['htm', 'html'],
  ['xhtml', 'html'], ['css', 'css'], ['scss', 'scss'], ['less', 'less'],
  ['sql', 'sql'], ['xml', 'xml'], ['xsd', 'xml'], ['xsl', 'xml'], ['xslt', 'xml'],
  ['plist', 'xml'], ['lua', 'lua'], ['bat', 'bat'], ['cmd', 'bat'],
  ['ps1', 'powershell'], ['psm1', 'powershell'], ['psd1', 'powershell'],
  ['r', 'r'], ['jl', 'julia'], ['dart', 'dart'], ['scala', 'scala'],
  ['clj', 'clojure'], ['cljs', 'clojure'], ['edn', 'clojure'], ['erl', 'erlang'],
  ['hrl', 'erlang'], ['ex', 'elixir'], ['exs', 'elixir'], ['hs', 'haskell'],
  ['fs', 'fsharp'], ['fsi', 'fsharp'], ['fsx', 'fsharp'], ['vb', 'vb'],
  ['pl', 'perl'], ['pm', 'perl'], ['v', 'verilog'], ['sv', 'system-verilog'],
  ['svh', 'system-verilog'], ['graphql', 'graphql'], ['gql', 'graphql'],
  ['proto', 'proto'], ['tf', 'hcl'], ['tfvars', 'hcl'], ['hcl', 'hcl'],
  ['nix', 'nix'], ['vue', 'vue'], ['svelte', 'svelte'], ['makefile', 'make'],
  ['mk', 'make'], ['cmake', 'cmake'], ['gradle', 'groovy'], ['groovy', 'groovy']
]);

const binaryNames: Set<string> = new Set<string>([
  '.ds_store', 'thumbs.db'
]);

const textNames: Set<string> = new Set<string>([
  'license', 'licence', 'readme', 'changelog', 'changes', 'notice', 'authors',
  'contributing', 'copying', 'codeowners', 'pkgbuild', 'apkbuild'
]);

export class NativeDocumentDescriptor {
  kind: string = 'unknown';
  language: string = '';
  defaultMode: string = 'code';
  canToggle: boolean = false;
  canPreview: boolean = false;
}

export class NativeSourceLine {
  number: number = 1;
  text: string = '';
}

export class NativeMarkdownBlock {
  kind: string = 'paragraph';
  text: string = '';
  language: string = '';
  level: number = 0;
}

export function nativeDocumentExtension(path: string): string {
  const clean = path.replace(/\\/g, '/');
  const parts = clean.split('/');
  const name = parts[parts.length - 1] || '';
  const dot = name.lastIndexOf('.');
  if (dot < 0 || dot === name.length - 1) return '';
  return name.slice(dot + 1).toLowerCase();
}

export function nativeDocumentName(path: string): string {
  const clean = path.replace(/\\/g, '/');
  const parts = clean.split('/');
  return (parts[parts.length - 1] || '').toLowerCase();
}

function namedLanguage(name: string): string {
  if (name === '.env' || name.startsWith('.env.')) return 'dotenv';
  if (name.startsWith('dockerfile') || name.startsWith('containerfile')) return 'dockerfile';
  if (name.startsWith('.prettierrc') || name.startsWith('.eslintrc') ||
    name.startsWith('.babelrc') || name === '.swcrc' || name === '.stylelintrc') return 'json';
  if (name === '.editorconfig' || name === '.gitconfig' || name === '.gitmodules' ||
    name === '.gitattributes' ||
    name === '.npmrc' || name === '.yarnrc' || name === '.nvrmc' ||
    name === '.npmignore' || name === '.dockerignore' || name === '.gitignore' ||
    name === '.eslintignore' || name === '.prettierignore' || name === '.hgignore' ||
    name === '.ignore' || name === '.rgignore' || name === '.fdignore') return 'ini';
  if (name === 'makefile' || name === 'gnumakefile' || name === 'justfile') return 'make';
  if (name === 'cmakelists.txt') return 'cmake';
  if (name === 'gemfile' || name === 'rakefile' || name === 'vagrantfile' ||
    name === 'brewfile' || name === 'podfile') return 'ruby';
  if (name === 'jenkinsfile') return 'groovy';
  if (name === 'procfile' || name === 'pkgbuild' || name === 'apkbuild') return 'shell';
  return '';
}

export function nativeDocumentDescriptor(path: string): NativeDocumentDescriptor {
  const descriptor = new NativeDocumentDescriptor();
  const extension = nativeDocumentExtension(path);
  const name = nativeDocumentName(path);
  if (extension === 'svg') {
    descriptor.kind = 'svg';
    descriptor.language = 'svg';
    descriptor.defaultMode = 'preview';
    descriptor.canToggle = true;
    descriptor.canPreview = true;
    return descriptor;
  }
  if (extension === 'md' || extension === 'markdown') {
    descriptor.kind = 'markdown';
    descriptor.language = 'markdown';
    descriptor.defaultMode = 'preview';
    descriptor.canToggle = true;
    descriptor.canPreview = true;
    return descriptor;
  }
  if (extension === 'pdf') {
    descriptor.kind = 'pdf';
    descriptor.defaultMode = 'preview';
    descriptor.canPreview = true;
    return descriptor;
  }
  if (extension === 'html' || extension === 'htm') {
    descriptor.kind = 'html';
    descriptor.language = 'html';
    descriptor.defaultMode = 'preview';
    descriptor.canToggle = true;
    descriptor.canPreview = true;
    return descriptor;
  }
  if (extension === 'csv' || extension === 'tsv') {
    descriptor.kind = 'delimited';
    descriptor.language = extension;
    descriptor.defaultMode = 'preview';
    descriptor.canToggle = true;
    descriptor.canPreview = true;
    return descriptor;
  }
  if (imageExtensions.has(extension)) {
    descriptor.kind = 'image';
    descriptor.defaultMode = 'preview';
    descriptor.canPreview = true;
    return descriptor;
  }
  const named = namedLanguage(name);
  if (named) {
    descriptor.kind = 'code';
    descriptor.language = named;
    descriptor.canPreview = true;
    return descriptor;
  }
  if (codeLanguages.has(extension)) {
    descriptor.kind = 'code';
    descriptor.language = codeLanguages.get(extension) || '';
    descriptor.canPreview = true;
    return descriptor;
  }
  if (binaryNames.has(name) || binaryExtensions.has(extension)) {
    descriptor.kind = 'binary';
    return descriptor;
  }
  if (textNames.has(name) || !extension) {
    descriptor.kind = 'text';
    descriptor.language = 'text';
    descriptor.canPreview = true;
    return descriptor;
  }
  descriptor.kind = 'text';
  descriptor.language = 'text';
  descriptor.canPreview = true;
  return descriptor;
}

export function nativeSourceLines(source: string, startNumber: number = 1): NativeSourceLine[] {
  const normalized = source.replace(/\r\n|\r/g, '\n');
  const raw = normalized.split('\n');
  const start = Number.isSafeInteger(startNumber) && startNumber > 0 ? startNumber : 1;
  return raw.map((text: string, index: number): NativeSourceLine => {
    const line = new NativeSourceLine();
    line.number = start + index;
    line.text = text;
    return line;
  });
}

function pushMarkdown(blocks: NativeMarkdownBlock[], kind: string, text: string,
  level: number = 0, language: string = ''): void {
  if (kind !== 'code' && !text.trim()) return;
  const block = new NativeMarkdownBlock();
  block.kind = kind;
  block.text = text;
  block.level = level;
  block.language = language;
  blocks.push(block);
}

function tableDelimiter(line: string): boolean {
  const value = line.trim();
  if (!value.includes('|')) return false;
  return /^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$/.test(value);
}

/** A bounded Markdown block projection for file preview, independent of ArkUI. */
export function nativeMarkdownBlocks(source: string): NativeMarkdownBlock[] {
  const lines = source.replace(/\r\n|\r/g, '\n').split('\n');
  const blocks: NativeMarkdownBlock[] = [];
  let index = 0;
  while (index < lines.length) {
    const line = lines[index];
    if (!line.trim()) {
      index++;
      continue;
    }
    const fence = /^\s*(```+|~~~+)\s*([^ ]*)\s*$/.exec(line);
    if (fence) {
      const marker = fence[1][0];
      const language = fence[2] || '';
      const body: string[] = [];
      index++;
      while (index < lines.length && !new RegExp('^\\s*' + marker + '{3,}\\s*$').test(lines[index])) {
        body.push(lines[index]);
        index++;
      }
      if (index < lines.length) index++;
      pushMarkdown(blocks, 'code', body.join('\n'), 0, language);
      continue;
    }
    const heading = /^(#{1,6})\s+(.+)$/.exec(line);
    if (heading) {
      pushMarkdown(blocks, 'heading', heading[2], heading[1].length);
      index++;
      continue;
    }
    if (/^\s*>/.test(line)) {
      const quoted: string[] = [];
      while (index < lines.length && /^\s*>/.test(lines[index])) {
        quoted.push(lines[index].replace(/^\s*>\s?/, ''));
        index++;
      }
      pushMarkdown(blocks, 'quote', quoted.join('\n'));
      continue;
    }
    if (line.includes('|') && index + 1 < lines.length && tableDelimiter(lines[index + 1])) {
      const table: string[] = [line, lines[index + 1]];
      index += 2;
      while (index < lines.length && lines[index].trim() && lines[index].includes('|')) {
        table.push(lines[index]);
        index++;
      }
      pushMarkdown(blocks, 'table', table.join('\n'));
      continue;
    }
    const paragraph: string[] = [];
    while (index < lines.length && lines[index].trim() &&
      !/^\s*(```+|~~~+)/.test(lines[index]) && !/^(#{1,6})\s+/.test(lines[index]) &&
      !/^\s*>/.test(lines[index]) &&
      !(lines[index].includes('|') && index + 1 < lines.length && tableDelimiter(lines[index + 1]))) {
      paragraph.push(lines[index]);
      index++;
    }
    pushMarkdown(blocks, 'paragraph', paragraph.join('\n'));
  }
  return blocks;
}
