import { NativeMessage } from './NativeSessionModel';
import { nativeDocumentDescriptor } from './NativeDocumentModel';

export class NativeStructuredField {
  label: string = '';
  value: string = '';
  code: boolean = false;
  tone: string = 'default';
}

export class NativeStructuredReadLine {
  number: number = 0;
  text: string = '';
}

export class NativeStructuredRead {
  valid: boolean = false;
  path: string = '';
  offset: number = 0;
  limit: number = 0;
  totalLines: number = -1;
  language: string = '';
  lines: NativeStructuredReadLine[] = [];
}

export class NativeStructuredSearchLine {
  number: number = 0;
  text: string = '';
}

export class NativeStructuredSearchFile {
  path: string = '';
  display: string = '';
  matches: NativeStructuredSearchLine[] = [];
}

export class NativeStructuredSearch {
  valid: boolean = false;
  pattern: string = '';
  scope: string = '';
  include: string = '';
  total: number = -1;
  truncated: boolean = false;
  paths: NativeStructuredSearchFile[] = [];
  files: NativeStructuredSearchFile[] = [];
}

export class NativeStructuredWebSource {
  url: string = '';
  title: string = '';
  snippet: string = '';
  publishedAt: string = '';
}

export class NativeStructuredPresentedFile {
  path: string = '';
  display: string = '';
  name: string = '';
  description: string = '';
}

export class NativeStructuredImageFacts {
  count: number = 0;
  mediaType: string = '';
  width: number = 0;
  height: number = 0;
  bytes: number = 0;
}

export class NativeToolStructured {
  family: string = 'generic';
  parsed: boolean = false;
  bodyStructured: boolean = false;
  summary: string = '';
  summaryIsCode: boolean = false;
  path: string = '';
  displayPath: string = '';
  fields: NativeStructuredField[] = [];
  read: NativeStructuredRead = new NativeStructuredRead();
  search: NativeStructuredSearch = new NativeStructuredSearch();
  sources: NativeStructuredWebSource[] = [];
  presented: NativeStructuredPresentedFile[] = [];
  image: NativeStructuredImageFacts = new NativeStructuredImageFacts();
  showRawOutput: boolean = true;
  showRawArguments: boolean = false;
}

export class NativeToolGroupSummary {
  commands: number = 0;
  editedFiles: number = 0;
  readFiles: number = 0;
  searches: number = 0;
  web: number = 0;
  agents: number = 0;
  plans: number = 0;
  other: number = 0;
  failed: number = 0;
  total: number = 0;
  label: string = '';
}

function recordValue(value: Object | undefined | null): Record<string, Object> | null {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, Object>;
}

function parseObject(value: string): Record<string, Object> | null {
  if (!value || !value.trim()) return null;
  try {
    return recordValue(JSON.parse(value) as Object);
  } catch (_) {
    return null;
  }
}

function stringValue(value: Object | undefined): string {
  return typeof value === 'string' ? value as string : '';
}

function firstString(record: Record<string, Object> | null, fields: string[]): string {
  if (!record) return '';
  for (const field of fields) {
    const value = stringValue(record[field]).trim();
    if (value) return value;
  }
  return '';
}

function integerValue(value: Object | undefined, allowZero: boolean = true): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value as number)) return -1;
  const number = value as number;
  if (allowZero ? number < 0 : number <= 0) return -1;
  return number;
}

function booleanValue(value: Object | undefined): boolean {
  return value === true;
}

function safeBoolean(record: Record<string, Object> | null, field: string): boolean {
  return !!record && record[field] === true;
}

function preview(value: string, limit: number = 160): string {
  const text = (value || '').replace(/\s+/g, ' ').trim();
  return limit > 0 && text.length > limit ? text.slice(0, limit - 1) + '…' : text;
}

function stringArray(value: Object | undefined): string[] | null {
  if (!Array.isArray(value)) return null;
  const result: string[] = [];
  for (const part of value as Object[]) {
    if (typeof part !== 'string' || !(part as string).trim()) return null;
    result.push(part as string);
  }
  return result;
}

function closedStringArgument(source: string, field: string): string {
  if (!source) return '';
  const match = new RegExp('"' + field + '"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)').exec(source);
  if (!match) return '';
  try {
    return JSON.parse('"' + match[1] + '"') as string;
  } catch (_) {
    return '';
  }
}

function partialJsonObject(source: string): boolean {
  const value = (source || '').trim();
  if (!value.startsWith('{')) return false;
  let depth = 0;
  let escaped = false;
  let quoted = false;
  for (let index = 0; index < value.length; index++) {
    const character = value[index];
    if (quoted) {
      if (escaped) escaped = false;
      else if (character === '\\') escaped = true;
      else if (character === '"') quoted = false;
      continue;
    }
    if (character === '"') {
      quoted = true;
    } else if (character === '{') {
      depth++;
    } else if (character === '}') {
      depth--;
      if (depth === 0) return false;
    }
  }
  return depth > 0;
}

function argumentString(tool: NativeMessage, args: Record<string, Object> | null, field: string): string {
  if (args) return stringValue(args[field]).trim();
  return partialJsonObject(tool.args) ? closedStringArgument(tool.args, field) : '';
}

function firstArgumentString(tool: NativeMessage, args: Record<string, Object> | null,
  fields: string[]): string {
  for (const field of fields) {
    const value = argumentString(tool, args, field);
    if (value) return value;
  }
  return '';
}

function failedTool(tool: NativeMessage): boolean {
  if (!tool) return false;
  if (tool.failed || tool.status === 'error' || tool.status === 'interrupted' ||
      tool.status === 'cancelled' || tool.status === 'denied') return true;
  if (tool.outcome === 'failed' || tool.outcome === 'error' ||
      tool.outcome === 'interrupted' || tool.outcome === 'cancelled') return true;
  return (tool.output || tool.error || '').includes('AUTO_REVIEW_DENIED');
}

function successfulResult(tool: NativeMessage): boolean {
  return tool.phase === 'result' && !failedTool(tool);
}

function basename(path: string): string {
  const clean = path.replace(/\\/g, '/');
  const parts = clean.split('/');
  return parts[parts.length - 1] || clean;
}

function normalizePath(path: string): string {
  let value = (path || '').trim().replace(/\\/g, '/');
  while (value.startsWith('./')) value = value.slice(2);
  return value;
}

export function nativeStructuredDisplayPath(path: string, workspaceRoot: string = ''): string {
  const normalized = normalizePath(path);
  const root = normalizePath(workspaceRoot).replace(/\/+$/, '');
  if (root && normalized === root) return '.';
  if (root && normalized.startsWith(root + '/')) return normalized.slice(root.length + 1);
  return normalized;
}

function isHttpUrl(value: string): boolean {
  return /^https?:\/\/[^\s]+$/i.test(value);
}

function addField(document: NativeToolStructured, label: string, value: string,
  code: boolean = false, tone: string = 'default'): void {
  const text = (value || '').trim();
  if (!text) return;
  const field = new NativeStructuredField();
  field.label = label;
  field.value = text;
  field.code = code;
  field.tone = tone;
  document.fields.push(field);
}

function setPath(document: NativeToolStructured, path: string, workspaceRoot: string): void {
  document.path = normalizePath(path);
  document.displayPath = nativeStructuredDisplayPath(document.path, workspaceRoot);
}

function genericSummary(tool: NativeMessage, args: Record<string, Object> | null): string {
  const fields = ['title', 'description', 'objective', 'task', 'task_name', 'name', 'question',
    'prompt', 'message', 'command', 'cmd', 'queries', 'query', 'pattern', 'url', 'uri',
    'file_path', 'path', 'target', 'action', 'status'];
  for (const field of fields) {
    const value = args?.[field];
    let text = stringValue(value);
    if (Array.isArray(value) && value.every((part: Object): boolean => typeof part === 'string')) {
      text = (value as string[]).join(', ');
    }
    if (field === 'questions' && Array.isArray(value)) {
      const first = (value as Object[]).find((part: Object): boolean => {
        const item = recordValue(part);
        return !!item && !!stringValue(item['question']).trim();
      });
      const item = recordValue(first);
      if (item) text = stringValue(item['question']);
    }
    text = preview(text);
    if (text) return text;
  }
  for (const field of ['title', 'description', 'objective', 'task', 'name', 'command', 'cmd',
    'query', 'pattern', 'url', 'file_path', 'path']) {
    const text = preview(partialJsonObject(tool.args) ?
      closedStringArgument(tool.args, field) : '');
    if (text) return text;
  }
  return tool.phase === 'preparing' ? '' : tool.toolName;
}

function parseRead(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, meta: Record<string, Object> | null,
  workspaceRoot: string): void {
  const argumentPath = firstArgumentString(tool, args, ['file_path', 'path']);
  const resultPath = firstString(meta, ['path']);
  setPath(document, resultPath || argumentPath, workspaceRoot);
  document.summary = document.displayPath;
  document.summaryIsCode = true;
  document.parsed = !!document.path;

  const descriptor = nativeDocumentDescriptor(document.path);
  document.read.path = document.path;
  document.read.offset = args ? integerValue(args['offset'], false) : -1;
  if (meta && integerValue(meta['offset'], false) > 0) {
    document.read.offset = integerValue(meta['offset'], false);
  }
  document.read.limit = args ? integerValue(args['limit'], false) : -1;
  document.read.language = firstString(meta, ['lang']) || descriptor.language;
  document.read.totalLines = meta ? integerValue(meta['totalLines']) : -1;
  addField(document, '行号', document.read.offset > 0 ? '从 ' +
    document.read.offset.toString() + ' 开始' : '');
  addField(document, '行数', document.read.limit > 0 ? document.read.limit.toString() : '');
  addField(document, '总行数', document.read.totalLines >= 0 ?
    document.read.totalLines.toString() : '');
  addField(document, '语言', document.read.language);

  if (successfulResult(tool) && meta && Array.isArray(meta['lines'])) {
    const rawLines = meta['lines'] as Object[];
    let previous = 0;
    let valid = true;
    for (const raw of rawLines) {
      const line = recordValue(raw);
      const number = line ? integerValue(line['number'], false) : -1;
      const text = line && typeof line['text'] === 'string' ? line['text'] as string : '';
      if (!line || number <= previous || typeof line['text'] !== 'string') {
        valid = false;
        break;
      }
      previous = number;
      const parsed = new NativeStructuredReadLine();
      parsed.number = number;
      parsed.text = text;
      document.read.lines.push(parsed);
    }
    if (valid && document.read.lines.length) {
      document.read.valid = true;
      document.bodyStructured = true;
      document.showRawOutput = false;
      document.read.offset = document.read.lines[0].number;
      return;
    }
    document.read.lines = [];
  }

  if (successfulResult(tool)) {
    const raw = (tool.output || '').replace(/\r\n?/g, '\n').split('\n');
    let seen = false;
    let previous = 0;
    for (const line of raw) {
      const match = /^(\d+): ?(.*)$/.exec(line);
      if (!match) {
        if (seen) break;
        continue;
      }
      const number = Number(match[1]);
      if (!Number.isSafeInteger(number) || number <= 0 || (seen && number !== previous + 1)) {
        document.read.lines = [];
        return;
      }
      const parsed = new NativeStructuredReadLine();
      parsed.number = number;
      parsed.text = match[2];
      document.read.lines.push(parsed);
      seen = true;
      previous = number;
    }
    if (seen) {
      document.read.valid = true;
      document.read.offset = document.read.lines[0].number;
      document.bodyStructured = true;
      document.showRawOutput = false;
    }
  }
}

function parseSearch(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, meta: Record<string, Object> | null,
  workspaceRoot: string): void {
  const pattern = argumentString(tool, args, 'pattern');
  const scope = firstArgumentString(tool, args, ['path', 'cwd', 'workdir']);
  const include = argumentString(tool, args, 'include');
  document.search.pattern = pattern;
  document.search.scope = scope;
  document.search.include = include;
  document.search.total = meta ? integerValue(meta['total']) : -1;
  document.search.truncated = safeBoolean(meta, 'truncated');
  document.summary = preview(pattern + (scope ? ' · ' +
    nativeStructuredDisplayPath(scope, workspaceRoot) : ''));
  document.summaryIsCode = true;
  document.parsed = !!pattern;

  if (successfulResult(tool) && meta && Array.isArray(meta['paths'])) {
    const paths = stringArray(meta['paths']);
    if (paths !== null) {
      for (const path of paths) {
        const file = new NativeStructuredSearchFile();
        file.path = normalizePath(path);
        file.display = nativeStructuredDisplayPath(file.path, workspaceRoot);
        document.search.paths.push(file);
      }
      document.search.valid = true;
      document.bodyStructured = true;
      document.showRawOutput = false;
    }
  }

  if (!document.search.valid && successfulResult(tool) && meta && Array.isArray(meta['matches'])) {
    let valid = true;
    const files: NativeStructuredSearchFile[] = [];
    for (const raw of meta['matches'] as Object[]) {
      const item = recordValue(raw);
      const path = item ? stringValue(item['path']).trim() : '';
      if (!item || !path || !Array.isArray(item['matches'])) {
        valid = false;
        break;
      }
      const file = new NativeStructuredSearchFile();
      file.path = normalizePath(path);
      file.display = nativeStructuredDisplayPath(file.path, workspaceRoot);
      for (const rawMatch of item['matches'] as Object[]) {
        const match = recordValue(rawMatch);
        const number = match ? integerValue(match['lineNumber'], false) : -1;
        const line = match ? stringValue(match['line']) : '';
        if (!match || number <= 0 || typeof match['line'] !== 'string') {
          valid = false;
          break;
        }
        const parsed = new NativeStructuredSearchLine();
        parsed.number = number;
        parsed.text = line;
        file.matches.push(parsed);
      }
      if (!valid) break;
      files.push(file);
    }
    if (valid) {
      document.search.files = files;
      document.search.valid = true;
      document.bodyStructured = true;
      document.showRawOutput = false;
    }
  }

  addField(document, '模式', pattern, true);
  addField(document, '范围', nativeStructuredDisplayPath(scope, workspaceRoot), true);
  addField(document, 'Include', include, true);
  if (document.search.total >= 0) addField(document, '结果', document.search.total.toString());
  if (document.search.truncated) addField(document, '状态', '结果已截断', false, 'warning');
}

function terminalFooter(text: string): NativeStructuredField[] {
  const fields: NativeStructuredField[] = [];
  const exit = /(?:^|\n)(?:\[?exit(?: code| status)?\s*[:=]?\s*)(-?\d+)\]?\s*$/i.exec(text.trim());
  if (exit) {
    const field = new NativeStructuredField();
    field.label = '退出码';
    field.value = exit[1];
    field.code = true;
    field.tone = exit[1] === '0' ? 'success' : 'danger';
    fields.push(field);
  }
  const signal = /(?:^|\n)signal\s*[:=]\s*([A-Za-z0-9_+.-]+)\s*$/i.exec(text.trim());
  if (signal) {
    const field = new NativeStructuredField();
    field.label = '信号';
    field.value = signal[1];
    field.code = true;
    field.tone = 'warning';
    fields.push(field);
  }
  return fields;
}

function parseTerminal(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, meta: Record<string, Object> | null,
  workspaceRoot: string): void {
  const command = firstArgumentString(tool, args, ['command', 'cmd', 'text']);
  const description = argumentString(tool, args, 'description');
  const cwd = firstArgumentString(tool, args, ['workdir', 'cwd']);
  const timeout = args ? integerValue(args['timeoutMs'], false) : -1;
  const background = !!args && (args['run_in_background'] === true || args['background'] === true);
  const sessionId = firstArgumentString(tool, args, ['sessionId', 'session_id']) ||
    firstString(meta, ['sessionId', 'session_id']);
  const jobId = firstArgumentString(tool, args, ['job_id', 'jobId']) ||
    firstString(meta, ['jobId', 'job_id']);
  document.summary = preview(command || description);
  document.summaryIsCode = true;
  document.parsed = !!document.summary;
  if (!document.parsed) return;

  document.bodyStructured = true;
  addField(document, '命令', command, true);
  if (description && description !== command) addField(document, '说明', description);
  const recordedCwd = firstString(meta, ['cwd']) || cwd;
  addField(document, '目录', nativeStructuredDisplayPath(recordedCwd, workspaceRoot), true);
  addField(document, '会话', sessionId, true);
  addField(document, '任务', jobId, true);
  if (timeout > 0) addField(document, '超时', (timeout / 1000).toString().replace(/\.0$/, '') + ' 秒');
  if (background) {
    addField(document, '状态', '已启动后台任务', false, 'accent');
    document.showRawOutput = true;
    return;
  }

  let exitCode = meta ? integerValue(meta['exitCode']) : -1;
  let signal = firstString(meta, ['signal']);
  if (exitCode < 0 && !signal) {
    terminalFooter(tool.output || '').forEach((field: NativeStructuredField): void => {
      if (field.label === '退出码') exitCode = Number(field.value);
      if (field.label === '信号') signal = field.value;
    });
  }
  if (exitCode >= 0) addField(document, '退出码', exitCode.toString(), true,
    exitCode === 0 ? 'success' : 'danger');
  addField(document, '信号', signal, true, 'warning');
  if (safeBoolean(meta, 'truncated')) addField(document, '状态', '输出已截断', false, 'warning');
}

function parseWeb(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, meta: Record<string, Object> | null): void {
  if (tool.toolName === 'web_search') {
    const query = argumentString(tool, args, 'query');
    const queries = args && Array.isArray(args['queries']) ? stringArray(args['queries']) : null;
    const queryText = queries && queries.length ? queries.join(', ') : query;
    document.summary = preview(queryText);
    document.parsed = !!queryText;
    addField(document, '查询', queryText);
  } else {
    const url = argumentString(tool, args, 'url');
    const resultUrl = firstString(meta, ['url']);
    document.summary = preview((resultUrl || url).replace(/^https?:\/\//i, ''));
    document.parsed = !!(url || resultUrl);
    addField(document, '地址', resultUrl || url, true);
    const status = meta ? integerValue(meta['statusCode']) : -1;
    if (status >= 0) {
      addField(document, 'HTTP', status.toString(), true,
        status >= 200 && status < 400 ? 'success' : 'danger');
    }
  }
  if (!document.parsed) return;

  if (successfulResult(tool) && meta) {
    if (Array.isArray(meta['sources'])) {
      let valid = true;
      for (const raw of meta['sources'] as Object[]) {
        const source = recordValue(raw);
        const url = source ? stringValue(source['url']).trim() : '';
        if (!source || !isHttpUrl(url)) {
          valid = false;
          break;
        }
        const parsed = new NativeStructuredWebSource();
        parsed.url = url;
        parsed.title = stringValue(source['title']).trim();
        parsed.snippet = stringValue(source['snippet']).trim();
        parsed.publishedAt = stringValue(source['publishedAt']).trim();
        document.sources.push(parsed);
      }
      if (!valid) document.sources = [];
    }
    addField(document, '回答', firstString(meta, ['answer']));
    if (safeBoolean(meta, 'truncated')) addField(document, '状态', '结果已截断', false, 'warning');
  }
  document.bodyStructured = true;
}

function parseGoal(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, meta: Record<string, Object> | null): void {
  const result = successfulResult(tool) ? parseObject(tool.output) : null;
  const resultGoal = result ? recordValue(result['goal']) : null;
  const goal = (meta ? recordValue(meta['goal']) : null) || resultGoal ||
    (result && result['objective'] !== undefined ? result : null);
  const source = meta || result;
  const ref = (source ? recordValue(source['ref']) : null) ||
    (goal ? recordValue(goal['ref']) : null);
  const objective = firstString(goal, ['objective']) ||
    firstString(source, ['objective']) ||
    firstArgumentString(tool, args, ['objective', 'goal']);
  const phase = firstString(goal, ['phase', 'status']) ||
    firstString(source, ['phase', 'status']) ||
    argumentString(tool, args, 'status');
  const blocker = firstString(goal, ['blockedReason', 'blocker']);
  const revisionValue: Object | undefined = ref && ref['revision'] !== undefined ?
    ref['revision'] : goal && goal['revision'] !== undefined ? goal['revision'] : undefined;
  const sourceRounds: Object | undefined = source && source['roundsStarted'] !== undefined ?
    source['roundsStarted'] : undefined;
  const revision = integerValue(revisionValue, false);
  const rounds = integerValue(sourceRounds) >= 0 ?
    integerValue(sourceRounds) :
    (goal ? integerValue(goal['roundsStarted']) : -1);
  const goalMaximum: Object | undefined = goal && goal['maxGoalRounds'] !== undefined ?
    goal['maxGoalRounds'] : goal && goal['maxRounds'] !== undefined ? goal['maxRounds'] : undefined;
  const argumentMaximum: Object | undefined = args && args['maxGoalRounds'] !== undefined ?
    args['maxGoalRounds'] : args && args['maxRounds'] !== undefined ? args['maxRounds'] : undefined;
  const maximum = integerValue(goalMaximum !== undefined ? goalMaximum : argumentMaximum);
  document.summary = preview(objective || tool.toolName);
  document.parsed = !!document.summary;
  addField(document, '目标', objective);
  addField(document, '状态', phase);
  addField(document, '阻塞', blocker, false, 'warning');
  if (rounds >= 0) addField(document, '轮次', maximum > 0 ? rounds + ' / ' + maximum : rounds.toString());
  if (revision > 0) addField(document, '修订', revision.toString(), true);
  document.bodyStructured = document.fields.length > 0;
}

function parseJob(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, meta: Record<string, Object> | null): void {
  const id = firstArgumentString(tool, args, ['job_id', 'jobId', 'id']) ||
    firstString(meta, ['jobId', 'id']);
  document.summary = preview(id || tool.toolName);
  document.summaryIsCode = true;
  document.parsed = !!document.summary;
  addField(document, '任务', id, true);
  addField(document, '状态', firstString(meta, ['state', 'status']) ||
    firstArgumentString(tool, args, ['state', 'status']));
  const command = firstArgumentString(tool, args, ['command', 'cmd']) || firstString(meta, ['command']);
  addField(document, '命令', command, true);
  const exitCode = meta ? integerValue(meta['exitCode']) : -1;
  if (exitCode >= 0) addField(document, '退出码', exitCode.toString(), true,
    exitCode === 0 ? 'success' : 'danger');
  addField(document, '信号', firstString(meta, ['signal']), true, 'warning');
  if (safeBoolean(meta, 'truncated')) addField(document, '状态', '输出已截断', false, 'warning');
  document.bodyStructured = document.fields.length > 0;
}

function parseAgent(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, meta: Record<string, Object> | null): void {
  const description = firstArgumentString(tool, args, ['description', 'prompt', 'message', 'label']);
  const id = firstString(meta, ['subagentId', 'agentId', 'id']) ||
    firstArgumentString(tool, args, ['agent_id', 'agentId', 'id']);
  let child = id;
  if (!child) {
    const match = /started subagent ([\w:.-]+)/.exec(tool.output || '');
    if (match) child = match[1];
  }
  const name = firstArgumentString(tool, args, ['name', 'skill', 'workflow', 'ralph']) ||
    firstString(meta, ['name', 'label']);
  document.summary = preview(description || name || child || tool.toolName);
  document.parsed = !!document.summary;
  addField(document, '名称', name);
  addField(document, '子代理', child, true);
  addField(document, '说明', description);
  addField(document, '状态', firstString(meta, ['state', 'status']) ||
    firstArgumentString(tool, args, ['state', 'status']));
  const runs = meta ? integerValue(meta['runs'] ?? meta['childCount']) : -1;
  if (runs >= 0) addField(document, '运行', runs.toString());
  document.bodyStructured = document.fields.length > 0;
}

function parsePresent(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, workspaceRoot: string): void {
  if (!successfulResult(tool) || !args || !Array.isArray(args['files'])) return;
  const names: string[] = [];
  for (const raw of args['files'] as Object[]) {
    const item = recordValue(raw);
    const path = item ? stringValue(item['path']).trim() : '';
    const descriptionValue = item ? item['description'] : undefined;
    if (!item || !path || (descriptionValue !== undefined && typeof descriptionValue !== 'string')) continue;
    const file = new NativeStructuredPresentedFile();
    file.path = normalizePath(path);
    file.display = nativeStructuredDisplayPath(file.path, workspaceRoot);
    file.name = basename(file.display);
    file.description = stringValue(descriptionValue).trim();
    document.presented.push(file);
    names.push(file.name);
  }
  document.summary = preview(names.join('、'));
  document.summaryIsCode = true;
  document.parsed = document.presented.length > 0;
  document.bodyStructured = document.presented.length > 0;
  document.showRawOutput = false;
  addField(document, '交付', document.presented.length.toString() + ' 个文件');
}

function parseQuestion(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null): void {
  const questions = args && Array.isArray(args['questions']) ? args['questions'] as Object[] : [];
  for (const raw of questions) {
    const question = recordValue(raw);
    const text = question ? stringValue(question['question']).trim() : '';
    if (!text) continue;
    document.summary = preview(text);
    addField(document, '问题', text);
    const options = question && Array.isArray(question['options']) ? question['options'] as Object[] : [];
    const labels: string[] = [];
    options.forEach((option: Object): void => {
      const record = recordValue(option);
      const label = record ? firstString(record, ['label', 'value', 'title']) : '';
      if (label) labels.push(label);
    });
    addField(document, '选项', labels.join(' · '));
    break;
  }
  document.summary = document.summary || preview(argumentString(tool, args, 'question'));
  if (!document.summary) {
    document.summary = preview(partialJsonObject(tool.args) ?
      closedStringArgument(tool.args, 'question') : '');
  }
  document.parsed = !!document.summary;
  document.bodyStructured = document.fields.length > 0;
}

function parseFileFamily(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, workspaceRoot: string): void {
  const path = firstArgumentString(tool, args, ['file_path', 'path']);
  setPath(document, path, workspaceRoot);
  document.summary = document.displayPath;
  document.summaryIsCode = true;
  document.parsed = !!document.path;
}

function parseImage(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, meta: Record<string, Object> | null,
  workspaceRoot: string): void {
  const argumentPath = firstArgumentString(tool, args, ['file_path', 'path']);
  setPath(document, firstString(meta, ['path']) || argumentPath, workspaceRoot);
  document.summary = document.displayPath;
  document.summaryIsCode = true;
  document.parsed = !!document.path;
  if (!successfulResult(tool) || !tool.images.length) {
    document.bodyStructured = false;
    document.showRawOutput = true;
    return;
  }

  document.image.count = tool.images.length;
  const mediaTypes: Set<string> = new Set<string>();
  let width = 0;
  let height = 0;
  let bytes = 0;
  tool.images.forEach((image): void => {
    const mediaType = (image.mediaType || '').trim();
    if (mediaType) mediaTypes.add(mediaType);
    if (integerValue(image.width, false) > width) width = image.width;
    if (integerValue(image.height, false) > height) height = image.height;
    if (integerValue(image.bytes) >= 0) bytes += image.bytes;
  });
  document.image.mediaType = mediaTypes.size === 1 ? Array.from(mediaTypes)[0] : '';
  document.image.width = width;
  document.image.height = height;
  document.image.bytes = bytes;
  addField(document, '图片', document.image.count.toString() + ' 张');
  addField(document, '格式', document.image.mediaType);
  addField(document, '尺寸', width > 0 && height > 0 ? width + ' × ' + height : '');
  addField(document, '大小', bytes > 0 ? bytes.toString() + ' B' : '');
  document.bodyStructured = true;
  document.showRawArguments = false;
  document.showRawOutput = false;
}

function generic(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null): void {
  document.summary = genericSummary(tool, args);
  document.parsed = !!document.summary;
  document.bodyStructured = false;
  document.showRawArguments = true;
  document.showRawOutput = true;
}

/** Project one merged tool call into a compact, strictly validated view model. */
export function nativeToolStructured(tool: NativeMessage, workspaceRoot: string = ''): NativeToolStructured {
  const document = new NativeToolStructured();
  if (!tool) return document;
  const args = parseObject(tool.args);
  const meta = parseObject(tool.metaRaw);
  const name = tool.toolName || '';

  if (name === 'read') {
    document.family = 'read';
    parseRead(document, tool, args, meta, workspaceRoot);
  } else if (name === 'read_image') {
    document.family = 'image';
    parseImage(document, tool, args, meta, workspaceRoot);
  } else if (name === 'grep' || name === 'glob' || name.endsWith('_inspect')) {
    document.family = 'search';
    parseSearch(document, tool, args, meta, workspaceRoot);
  } else if (name === 'bash' || name === 'pwsh' || name === 'exec_command' ||
      name === 'write_stdin' || name === 'terminal_send' || name.startsWith('terminal_')) {
    document.family = 'terminal';
    parseTerminal(document, tool, args, meta, workspaceRoot);
  } else if (name === 'web_search' || name === 'web_fetch') {
    document.family = 'web';
    parseWeb(document, tool, args, meta);
  } else if (name === 'create_goal' || name === 'update_goal' || name === 'get_goal') {
    document.family = 'goal';
    parseGoal(document, tool, args, meta);
  } else if (name === 'job_output' || name === 'job_kill' || name === 'job_list') {
    document.family = 'job';
    parseJob(document, tool, args, meta);
  } else if (name === 'subagent' || name === 'subagent_fork' || name === 'send_message' ||
      name === 'interrupt_agent' || name === 'workflow' || name === 'ralph' || name === 'skill') {
    document.family = 'agent';
    parseAgent(document, tool, args, meta);
  } else if (name === 'present') {
    document.family = 'present';
    parsePresent(document, tool, args, workspaceRoot);
    if (!document.parsed) generic(document, tool, args);
  } else if (name === 'ask_user_question' || name === 'request_user_input') {
    document.family = 'question';
    parseQuestion(document, tool, args);
  } else if (name === 'write' || name === 'edit' || name === 'str_replace_editor' || name === 'apply_patch') {
    document.family = 'file';
    parseFileFamily(document, tool, args, workspaceRoot);
  } else if (name === 'todo_write') {
    document.family = 'plan';
    document.summary = '';
    document.parsed = true;
  } else {
    generic(document, tool, args);
  }

  if (failedTool(tool)) {
    document.bodyStructured = false;
    document.read.valid = false;
    document.search.valid = false;
    document.sources = [];
    document.presented = [];
    document.image = new NativeStructuredImageFacts();
    document.showRawArguments = true;
    document.showRawOutput = true;
  }
  if (!document.summary && name !== 'todo_write') {
    const fallback = genericSummary(tool, args);
    document.summary = fallback;
    document.parsed = !!fallback;
  }
  return document;
}

function toolCategory(name: string): string {
  if (name === 'bash' || name === 'pwsh' || name === 'exec_command' ||
      name === 'write_stdin' || name.startsWith('terminal_')) return 'commands';
  if (name === 'write' || name === 'edit' || name === 'apply_patch' ||
      name === 'str_replace_editor') return 'edit';
  if (name === 'read' || name === 'read_image') return 'read';
  if (name === 'grep' || name === 'glob' || name.endsWith('_inspect')) return 'search';
  if (name === 'web_search' || name === 'web_fetch') return 'web';
  if (name === 'subagent' || name.startsWith('subagent_') || name === 'send_message' ||
      name === 'interrupt_agent' || name === 'workflow' || name === 'ralph' ||
      name === 'skill') return 'agents';
  if (name === 'todo_write' || name === 'create_goal' || name === 'update_goal' ||
      name === 'get_goal') return 'plans';
  return 'other';
}

/** Count one process group without claiming failed file operations. */
export function nativeToolGroupSummary(tools: NativeMessage[]): NativeToolGroupSummary {
  const summary = new NativeToolGroupSummary();
  const readPaths: Set<string> = new Set<string>();
  const editedPaths: Set<string> = new Set<string>();
  tools.forEach((tool: NativeMessage): void => {
    if (tool.role !== 'tool') return;
    summary.total++;
    if (failedTool(tool)) summary.failed++;
    const category = toolCategory(tool.toolName);
    const structured = nativeToolStructured(tool);
    const path = structured.path || genericSummary(tool, parseObject(tool.args));
    const happened = !failedTool(tool) && tool.status !== 'cancelled' && tool.status !== 'interrupted' &&
      tool.outcome !== 'cancelled' && tool.outcome !== 'interrupted';
    if (category === 'commands') summary.commands++;
    else if (category === 'edit') {
      if (happened) editedPaths.add(path || '#' + tool.callId);
    } else if (category === 'read') {
      if (happened) readPaths.add(path || '#' + tool.callId);
    } else if (category === 'search') summary.searches++;
    else if (category === 'web') summary.web++;
    else if (category === 'agents') summary.agents++;
    else if (category === 'plans') summary.plans++;
    else summary.other++;
  });
  summary.editedFiles = editedPaths.size;
  summary.readFiles = readPaths.size;
  const parts: string[] = [];
  if (summary.commands) parts.push('执行 ' + summary.commands + ' 条命令');
  if (summary.editedFiles) parts.push('修改 ' + summary.editedFiles + ' 个文件');
  if (summary.readFiles) parts.push('读取 ' + summary.readFiles + ' 个文件');
  if (summary.searches) parts.push('搜索 ' + summary.searches + ' 次');
  if (summary.web) parts.push('访问网页 ' + summary.web + ' 次');
  if (summary.agents) parts.push('协调 ' + summary.agents + ' 个智能体');
  if (summary.plans) parts.push('更新计划');
  if (summary.other) parts.push('调用工具 ' + summary.other + ' 次');
  if (summary.failed) parts.push(summary.failed + ' 失败');
  summary.label = parts.join(' · ');
  return summary;
}
