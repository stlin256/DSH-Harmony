export class NativeCodeToken {
  text: string = '';
  kind: string = 'plain';
}

const keywords: Set<string> = new Set<string>([
  'as', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'delete',
  'do', 'else', 'enum', 'export', 'extends', 'false', 'finally', 'for', 'from', 'function', 'if',
  'implements', 'import', 'in', 'instanceof', 'interface', 'let', 'new', 'null', 'of', 'private',
  'protected', 'public', 'readonly', 'return', 'static', 'super', 'switch', 'this', 'throw', 'true',
  'try', 'type', 'typeof', 'var', 'void', 'while', 'with', 'yield', 'def', 'elif', 'except', 'lambda',
  'nonlocal', 'pass', 'raise', 'and', 'or', 'not', 'fn', 'pub', 'mut', 'use', 'mod', 'match', 'impl',
  'trait', 'struct', 'package', 'func', 'defer', 'go', 'map', 'chan', 'select', 'val', 'when',
  'object', 'override', 'open', 'data', 'sealed', 'import', 'fun', 'inline', 'suspend', 'namespace',
  'template', 'typename', 'using', 'switch', 'case', 'sizeof', 'typedef', 'auto', 'extern', 'constexpr',
  'SELECT', 'FROM', 'WHERE', 'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER', 'ON', 'GROUP', 'ORDER', 'BY',
  'INSERT', 'UPDATE', 'DELETE', 'CREATE', 'TABLE', 'VALUES', 'INTO', 'SET', 'LIMIT', 'AS', 'AND', 'OR'
]);
const constants: Set<string> = new Set<string>([
  'undefined', 'NaN', 'Infinity', 'None', 'True', 'False', 'nil', 'NULL', 'true', 'false', 'null'
]);
const hashComments: Set<string> = new Set<string>([
  'python', 'shell', 'fish', 'powershell', 'yaml', 'toml', 'ruby', 'ini', 'dotenv',
  'dockerfile', 'make', 'cmake', 'r', 'perl', 'elixir', 'nix', 'graphql', 'hcl'
]);
const slashComments: Set<string> = new Set<string>([
  'javascript', 'typescript', 'arkts', 'tsx', 'jsx', 'go', 'rust', 'java', 'c',
  'cpp', 'csharp', 'kotlin', 'swift', 'php', 'scala', 'dart', 'groovy', 'hcl',
  'scss', 'less', 'system-verilog', 'verilog'
]);
const htmlLike: Set<string> = new Set<string>(['html', 'xml', 'svg']);
const markdownLike: Set<string> = new Set<string>(['markdown']);
const semicolonComments: Set<string> = new Set<string>(['ini']);
const languages: Set<string> = new Set<string>([
  'typescript', 'tsx', 'javascript', 'jsx', 'arkts', 'shell', 'fish', 'json', 'csv',
  'tsv', 'python', 'ruby', 'go', 'rust', 'java', 'c', 'cpp', 'csharp', 'kotlin',
  'swift', 'php', 'yaml', 'toml', 'ini', 'dotenv', 'log', 'text', 'diff', 'http',
  'markdown', 'mdx', 'rst', 'latex', 'bibtex', 'asciidoc', 'html', 'xml', 'svg',
  'css', 'scss', 'less', 'sql', 'lua', 'bat', 'powershell', 'r', 'julia', 'dart',
  'scala', 'clojure', 'erlang', 'elixir', 'haskell', 'fsharp', 'vb', 'perl',
  'verilog', 'system-verilog', 'graphql', 'proto', 'hcl', 'nix', 'vue', 'svelte',
  'make', 'cmake', 'groovy', 'dockerfile', 'plain'
]);
const languageAliases: Map<string, string> = new Map<string, string>([
  ['js', 'javascript'], ['mjs', 'javascript'], ['cjs', 'javascript'],
  ['ts', 'typescript'], ['mts', 'typescript'], ['cts', 'typescript'],
  ['sh', 'shell'], ['bash', 'shell'], ['zsh', 'shell'],
  ['yml', 'yaml'], ['py', 'python'], ['pyw', 'python'], ['pyi', 'python'],
  ['rb', 'ruby'], ['rake', 'ruby'], ['gemspec', 'ruby'], ['rs', 'rust'],
  ['kt', 'kotlin'], ['kts', 'kotlin'], ['cs', 'csharp'], ['htm', 'html'],
  ['md', 'markdown'], ['patch', 'diff'], ['ps1', 'powershell'], ['psm1', 'powershell'],
  ['psd1', 'powershell'], ['conf', 'ini'], ['cfg', 'ini'], ['properties', 'ini'],
  ['env', 'dotenv'], ['txt', 'text'], ['text', 'text'], ['plain', 'text'],
  ['docker', 'dockerfile'], ['makefile', 'make'], ['cmakelists', 'cmake'],
  ['fs', 'fsharp'], ['fsi', 'fsharp'], ['fsx', 'fsharp'], ['v', 'verilog'],
  ['sv', 'system-verilog'], ['svh', 'system-verilog'], ['gql', 'graphql']
]);

function push(tokens: NativeCodeToken[], text: string, kind: string = 'plain'): void {
  if (!text) return;
  if (tokens.length && tokens[tokens.length - 1].kind === kind) {
    tokens[tokens.length - 1].text += text;
  } else {
    const token = new NativeCodeToken();
    token.text = text;
    token.kind = kind;
    tokens.push(token);
  }
}

function lineTokens(source: string, kindForLine: (line: string) => string): NativeCodeToken[] {
  const tokens: NativeCodeToken[] = [];
  const lines = source.split(/(\r\n|\n|\r)/);
  for (const line of lines) {
    if (line === '\r\n' || line === '\n' || line === '\r') push(tokens, line);
    else push(tokens, line, kindForLine(line));
  }
  return tokens;
}

function isWord(value: string): boolean {
  return /^[A-Za-z_$][A-Za-z0-9_$]*$/.test(value);
}

export function nativeHighlightCode(source: string, language: string): NativeCodeToken[] {
  const requested = language.toLowerCase().replace(/^language-/, '');
  const normalized = languageAliases.get(requested) || requested;
  if (!languages.has(normalized) || source.length > 65536 || source.split('\n').length > 1500) {
    return lineTokens(source, (_line: string): string => 'plain');
  }
  if (normalized === 'text' || normalized === 'plain' || normalized === 'log') {
    return lineTokens(source, (_line: string): string => 'plain');
  }
  if (normalized === 'diff' || normalized === 'patch') {
    return lineTokens(source, (line: string): string =>
      line.startsWith('+') && !line.startsWith('+++') ? 'added' :
        line.startsWith('-') && !line.startsWith('---') ? 'removed' :
          line.startsWith('@@') ? 'type' : line.startsWith('diff ') || line.startsWith('index ') ? 'comment' : 'plain');
  }
  if (markdownLike.has(normalized)) {
    return lineTokens(source, (line: string): string =>
      /^\s*#{1,6}\s/.test(line) ? 'keyword' :
        /^\s*>/.test(line) ? 'comment' :
          /^\s*(?:```|~~~)/.test(line) ? 'type' : 'plain');
  }

  const tokens: NativeCodeToken[] = [];
  let index = 0;
  let previous = '';
  while (index < source.length) {
    const rest = source.slice(index);
    if (rest.startsWith('/*')) {
      const end = source.indexOf('*/', index + 2);
      const stop = end < 0 ? source.length : end + 2;
      push(tokens, source.slice(index, stop), 'comment');
      index = stop;
      continue;
    }
    if (slashComments.has(normalized) && rest.startsWith('//')) {
      const end = source.indexOf('\n', index + 2);
      const stop = end < 0 ? source.length : end;
      push(tokens, source.slice(index, stop), 'comment');
      index = stop;
      continue;
    }
    if (normalized === 'sql' && rest.startsWith('--')) {
      const end = source.indexOf('\n', index + 2);
      const stop = end < 0 ? source.length : end;
      push(tokens, source.slice(index, stop), 'comment');
      index = stop;
      continue;
    }
    if (semicolonComments.has(normalized) && rest.startsWith(';') &&
      (index === 0 || source[index - 1] === '\n' || source[index - 1] === '\r')) {
      const end = source.indexOf('\n', index + 1);
      const stop = end < 0 ? source.length : end;
      push(tokens, source.slice(index, stop), 'comment');
      index = stop;
      continue;
    }
    if (hashComments.has(normalized) && rest.startsWith('#')) {
      const end = source.indexOf('\n', index + 1);
      const stop = end < 0 ? source.length : end;
      push(tokens, source.slice(index, stop), 'comment');
      index = stop;
      continue;
    }
    if (htmlLike.has(normalized) && rest.startsWith('<!--')) {
      const end = source.indexOf('-->', index + 4);
      const stop = end < 0 ? source.length : end + 3;
      push(tokens, source.slice(index, stop), 'comment');
      index = stop;
      continue;
    }
    const quote = source[index];
    if (quote === '"' || quote === '\'' || quote === '`') {
      let cursor = index + 1;
      while (cursor < source.length) {
        if (source[cursor] === '\\') { cursor += Math.min(2, source.length - cursor); continue; }
        if (source[cursor] === quote) { cursor++; break; }
        if ((quote !== '`') && (source[cursor] === '\n' || source[cursor] === '\r')) break;
        cursor++;
      }
      push(tokens, source.slice(index, cursor), 'string');
      index = cursor;
      previous = quote;
      continue;
    }
    const number = /^(?:0[xX][0-9A-Fa-f]+|0[bB][01]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/.exec(rest);
    if (number) {
      push(tokens, number[0], 'number');
      index += number[0].length;
      previous = number[0].slice(-1);
      continue;
    }
    const word = /^[A-Za-z_$][A-Za-z0-9_$]*/.exec(rest);
    if (word) {
      const value = word[0];
      const next = source.slice(index + value.length).match(/^\s*\(/);
      const configKey = (normalized === 'ini' || normalized === 'dotenv') &&
        /^\s*(?:=|:)/.test(source.slice(index + value.length));
      const kind = configKey ? 'property' :
        keywords.has(value) || keywords.has(value.toUpperCase()) ? 'keyword' :
        constants.has(value) ? 'constant' :
          next ? 'function' :
            previous === '.' ? 'property' :
              /^[A-Z][A-Za-z0-9_$]*$/.test(value) ? 'type' : 'plain';
      push(tokens, value, kind);
      index += value.length;
      previous = value.slice(-1);
      continue;
    }
    const character = source[index];
    push(tokens, character, '{}[]();,.:+-*/%=<>!&|?'.includes(character) ? 'punctuation' : 'plain');
    if (!/\s/.test(character)) previous = character;
    index++;
  }
  if (tokens.length > 12000) return lineTokens(source, (_line: string): string => 'plain');
  return tokens;
}
