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
  name: string = '';
  directory: string = '';
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

export class NativePluginMetric {
  label: string = '';
  value: string = '';
  caption: string = '';
  tone: string = 'default';
}

export class NativePluginItem {
  title: string = '';
  subtitle: string = '';
  trailing: string = '';
  tone: string = 'default';
  selected: boolean = false;
  value: string = '';
}

export class NativePluginTableRow {
  cells: string[] = [];
}

export class NativePluginBlock {
  kind: string = '';
  id: string = '';
  title: string = '';
  text: string = '';
  label: string = '';
  value: string = '';
  caption: string = '';
  tone: string = 'default';
  progress: number = 0;
  selected: string = '';
  multi: boolean = false;
  confirmLabel: string = '';
  cancelLabel: string = '';
  metrics: NativePluginMetric[] = [];
  items: NativePluginItem[] = [];
  columns: string[] = [];
  rows: NativePluginTableRow[] = [];
}

export class NativePluginDocument {
  present: boolean = false;
  valid: boolean = false;
  title: string = '';
  blocks: NativePluginBlock[] = [];
  truncated: boolean = false;
}

export class NativeMediaRequestInfo {
  provider: string = '';
  model: string = '';
  label: string = '';
  aspect: string = '';
  count: number = 0;
  quality: string = '';
  seconds: number = 0;
  resolution: string = '';
  refs: number = 0;
}

export class NativeMediaItem {
  path: string = '';
  display: string = '';
  name: string = '';
  mime: string = '';
  width: number = 0;
  height: number = 0;
  bytes: number = 0;
  duration: number = 0;
  poster: string = '';
  codec: string = '';
}

export class NativeMediaDocument {
  present: boolean = false;
  valid: boolean = false;
  kind: string = '';
  status: string = '';
  rid: string = '';
  job: string = '';
  items: NativeMediaItem[] = [];
  request: NativeMediaRequestInfo = new NativeMediaRequestInfo();
  prompt: string = '';
  revisedPrompt: string = '';
  errorCode: string = '';
  errorText: string = '';
  costEstimate: number = -1;
  costCurrency: string = '';
  visibleMark: boolean = false;
  c2pa: boolean = false;
  implicitLabel: boolean = false;
}

export class NativeToolStructured {
  family: string = 'generic';
  parsed: boolean = false;
  bodyStructured: boolean = false;
  summary: string = '';
  summaryIsCode: boolean = false;
  path: string = '';
  displayPath: string = '';
  displayName: string = '';
  displayDirectory: string = '';
  fields: NativeStructuredField[] = [];
  read: NativeStructuredRead = new NativeStructuredRead();
  search: NativeStructuredSearch = new NativeStructuredSearch();
  sources: NativeStructuredWebSource[] = [];
  presented: NativeStructuredPresentedFile[] = [];
  image: NativeStructuredImageFacts = new NativeStructuredImageFacts();
  plugin: NativePluginDocument = new NativePluginDocument();
  media: NativeMediaDocument = new NativeMediaDocument();
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

function removeStructuredComments(source: string): string {
  let result = '';
  let index = 0;
  let quoted = false;
  let escaped = false;
  while (index < source.length) {
    const character = source.charAt(index);
    const next = source.charAt(index + 1);
    if (quoted) {
      result += character;
      if (escaped) escaped = false;
      else if (character === '\\') escaped = true;
      else if (character === '"') quoted = false;
      index++;
      continue;
    }
    if (character === '"') {
      quoted = true;
      result += character;
      index++;
      continue;
    }
    if (character === '/' && next === '/') {
      index += 2;
      while (index < source.length && source.charAt(index) !== '\n') index++;
      if (index < source.length) result += '\n';
      index++;
      continue;
    }
    if (character === '/' && next === '*') {
      index += 2;
      while (index + 1 < source.length &&
        !(source.charAt(index) === '*' && source.charAt(index + 1) === '/')) {
        if (source.charAt(index) === '\n') result += '\n';
        index++;
      }
      index = Math.min(source.length, index + 2);
      continue;
    }
    result += character;
    index++;
  }
  return result;
}

function removeTrailingCommas(source: string): string {
  let result = '';
  let quoted = false;
  let escaped = false;
  for (let index = 0; index < source.length; index++) {
    const character = source.charAt(index);
    if (quoted) {
      result += character;
      if (escaped) escaped = false;
      else if (character === '\\') escaped = true;
      else if (character === '"') quoted = false;
      continue;
    }
    if (character === '"') {
      quoted = true;
      result += character;
      continue;
    }
    if (character === ',') {
      let cursor = index + 1;
      while (cursor < source.length && /\s/.test(source.charAt(cursor))) cursor++;
      if (cursor < source.length &&
        (source.charAt(cursor) === '}' || source.charAt(cursor) === ']')) {
        continue;
      }
    }
    result += character;
  }
  return result;
}

function parseStructuredJson(source: string): Object | null {
  const input = (source || '').trim();
  if (!input) return null;
  try {
    return JSON.parse(input) as Object;
  } catch (_) {
    const repaired = removeTrailingCommas(removeStructuredComments(input)).trim();
    if (!repaired || repaired === input) return null;
    try {
      return JSON.parse(repaired) as Object;
    } catch (_) {
      return null;
    }
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

function parentDirectory(path: string): string {
  const clean = path.replace(/\\/g, '/');
  const slash = clean.lastIndexOf('/');
  return slash >= 0 ? clean.slice(0, slash + 1) : '';
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
  document.displayName = basename(document.displayPath);
  document.displayDirectory = parentDirectory(document.displayPath);
}

function utf8ByteLength(value: string): number {
  let bytes = 0;
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    if (code < 0x80) bytes += 1;
    else if (code < 0x800) bytes += 2;
    else if (code >= 0xd800 && code <= 0xdbff && index + 1 < value.length &&
      value.charCodeAt(index + 1) >= 0xdc00 && value.charCodeAt(index + 1) <= 0xdfff) {
      bytes += 4;
      index++;
    } else bytes += 3;
  }
  return bytes;
}

function scalarText(value: Object | undefined, limit: number = 240): string {
  let text = '';
  if (typeof value === 'string') text = value as string;
  else if (typeof value === 'number' && Number.isFinite(value as number)) text = value.toString();
  else if (typeof value === 'boolean') return value === true ? 'true' : 'false';
  return text.length > limit ? text.slice(0, Math.max(0, limit - 1)) + '…' : text;
}

function pluginTone(value: Object | undefined): string {
  const tone = scalarText(value, 20);
  if (tone === 'good' || tone === 'success') return 'success';
  if (tone === 'warn' || tone === 'warning') return 'warning';
  if (tone === 'bad' || tone === 'danger') return 'danger';
  if (tone === 'info' || tone === 'accent') return 'accent';
  return 'default';
}

function pluginItem(title: string, subtitle: string = '', trailing: string = '',
  tone: string = 'default', selected: boolean = false, value: string = ''): NativePluginItem {
  const item = new NativePluginItem();
  item.title = title;
  item.subtitle = subtitle;
  item.trailing = trailing;
  item.tone = tone;
  item.selected = selected;
  item.value = value;
  return item;
}

function addPluginBlock(document: NativePluginDocument, kind: string): NativePluginBlock | null {
  const block = new NativePluginBlock();
  block.kind = kind;
  let pushed = false;
  if (document.blocks.length < 30) {
    document.blocks.push(block);
    pushed = true;
  } else document.truncated = true;
  // Null tells the caller nothing was pushed, so an empty-node cleanup must not
  // pop an unrelated block that was already rendered.
  return pushed ? block : null;
}

class NativePluginBudget {
  nodes: number = 0;
  truncated: boolean = false;
}

function parsePluginNode(value: Object, document: NativePluginDocument,
  budget: NativePluginBudget, depth: number, interactive: boolean): void {
  if (budget.nodes >= 40 || depth > 6 || !recordValue(value)) {
    budget.truncated = true;
    return;
  }
  const node = recordValue(value) as Record<string, Object>;
  budget.nodes++;
  const type = stringValue(node['type']).trim();
  if (!type) return;

  if (type === 'row' && Array.isArray(node['children']) &&
    (node['children'] as Object[]).length > 0 &&
    (node['children'] as Object[]).every((child: Object): boolean => {
      const record = recordValue(child);
      return !!record && stringValue(record['type']).trim() === 'metric';
    })) {
    const block = addPluginBlock(document, 'metrics');
    if (!block) return;
    const metricChildren = (node['children'] as Object[]).slice(0, 16);
    if ((node['children'] as Object[]).length > metricChildren.length) budget.truncated = true;
    for (const child of metricChildren) {
      if (budget.nodes >= 40) {
        budget.truncated = true;
        break;
      }
      budget.nodes++;
      const metricNode = recordValue(child) as Record<string, Object>;
      const label = scalarText(metricNode['label'], 120);
      const value = scalarText(metricNode['value'], 120);
      if (!label || !value) continue;
      const metric = new NativePluginMetric();
      metric.label = label;
      metric.value = value;
      metric.caption = scalarText(metricNode['caption'], 160);
      metric.tone = pluginTone(metricNode['tone']);
      block.metrics.push(metric);
    }
    if (!block.metrics.length) document.blocks.pop();
    return;
  }

  if (type === 'stack' || type === 'row') {
    if (Array.isArray(node['children'])) {
      const children = node['children'] as Object[];
      for (let index = 0; index < children.length; index++) {
        if (index >= 16 || budget.nodes >= 40) {
          budget.truncated = true;
          break;
        }
        const child = children[index];
        const record = recordValue(child);
        if (record) parsePluginNode(record, document, budget, depth + 1, interactive);
      }
    }
    return;
  }
  if (type === 'text') {
    const text = scalarText(node['text'], 2000);
    if (!text) return;
    const block = addPluginBlock(document, 'text');
    if (!block) return;
    block.text = text;
    block.tone = pluginTone(node['tone']);
    return;
  }
  if (type === 'metric') {
    const label = scalarText(node['label'], 120);
    const value = scalarText(node['value'], 120);
    if (!label || !value) return;
    const block = addPluginBlock(document, 'metric');
    if (!block) return;
    const metric = new NativePluginMetric();
    metric.label = label;
    metric.value = value;
    metric.caption = scalarText(node['caption'], 160);
    metric.tone = pluginTone(node['tone']);
    block.metrics.push(metric);
    return;
  }
  if (type === 'progress') {
    if (typeof node['value'] !== 'number' || !Number.isFinite(node['value'] as number)) return;
    const value = node['value'] as number;
    const maximum = typeof node['max'] === 'number' && Number.isFinite(node['max'] as number) &&
      (node['max'] as number) > 0 ? node['max'] as number : 100;
    const block = addPluginBlock(document, 'progress');
    if (!block) return;
    block.label = scalarText(node['label'], 120);
    block.caption = scalarText(node['caption'], 160);
    block.value = value.toString() + ' / ' + maximum.toString();
    block.progress = Math.max(0, Math.min(100, Math.round(value / maximum * 100)));
    block.tone = pluginTone(node['tone']);
    return;
  }
  if (type === 'callout') {
    const text = scalarText(node['text'], 2000);
    if (!text) return;
    const block = addPluginBlock(document, 'callout');
    if (!block) return;
    block.text = text;
    block.tone = pluginTone(node['tone']);
    return;
  }
  if (type === 'list') {
    if (!Array.isArray(node['items'])) return;
    const block = addPluginBlock(document, 'list');
    if (!block) return;
    (node['items'] as Object[]).slice(0, 12).forEach((raw: Object): void => {
      const item = recordValue(raw);
      const title = item ? scalarText(item['title'], 160) : '';
      if (!item || !title) return;
      block.items.push(pluginItem(title, scalarText(item['subtitle'], 200),
        scalarText(item['trailing'], 80), pluginTone(item['tone'])));
    });
    if (!block.items.length) document.blocks.pop();
    return;
  }
  if (type === 'keyValue') {
    let items: Object[] = [];
    if (Array.isArray(node['items'])) items = node['items'] as Object[];
    else if (recordValue(node['items'])) {
      const source = recordValue(node['items']) as Record<string, Object>;
      Object.keys(source).forEach((key: string): void => {
        const entry: Record<string, Object> = {};
        entry['label'] = key;
        entry['value'] = source[key];
        items.push(entry);
      });
    }
    const block = addPluginBlock(document, 'keyValue');
    if (!block) return;
    items.slice(0, 16).forEach((raw: Object): void => {
      if (Array.isArray(raw)) {
        const pair = raw as Object[];
        if (pair.length) block.items.push(pluginItem(
          scalarText(pair[0], 120), scalarText(pair[1], 240)));
        return;
      }
      const item = recordValue(raw);
      const label = item ? scalarText(item['label'], 120) : '';
      if (!item || !label) return;
      block.items.push(pluginItem(label, scalarText(item['value'], 240), '', pluginTone(item['tone'])));
    });
    if (!block.items.length) document.blocks.pop();
    return;
  }
  if (type === 'table') {
    if (!Array.isArray(node['columns']) || !Array.isArray(node['rows'])) return;
    const block = addPluginBlock(document, 'table');
    if (!block) return;
    (node['columns'] as Object[]).slice(0, 8).forEach((raw: Object): void => {
      const column = recordValue(raw);
      block.columns.push(column ? scalarText(column['label'], 80) : scalarText(raw, 80));
    });
    (node['rows'] as Object[]).slice(0, 16).forEach((raw: Object): void => {
      if (!Array.isArray(raw)) return;
      const row = new NativePluginTableRow();
      (raw as Object[]).slice(0, 8).forEach((cell: Object): void => {
        row.cells.push(scalarText(cell, 200));
      });
      block.rows.push(row);
    });
    if (!block.columns.length) document.blocks.pop();
    return;
  }
  if (type === 'chart') {
    if (!Array.isArray(node['categories']) || !Array.isArray(node['series'])) return;
    const categories = node['categories'] as Object[];
    const series = node['series'] as Object[];
    const first = recordValue(series[0]);
    const values = first && Array.isArray(first['values']) ? first['values'] as Object[] : [];
    const block = addPluginBlock(document, 'chart');
    if (!block) return;
    categories.slice(0, Math.min(12, values.length)).forEach((raw: Object, index: number): void => {
      block.items.push(pluginItem(scalarText(raw, 100), scalarText(values[index], 80)));
    });
    block.caption = scalarText(node['caption'], 160);
    if (!block.items.length) document.blocks.pop();
    return;
  }
  if (type === 'compare') {
    if (!Array.isArray(node['items'])) return;
    const block = addPluginBlock(document, 'compare');
    if (!block) return;
    (node['items'] as Object[]).slice(0, 8).forEach((raw: Object): void => {
      const item = recordValue(raw);
      if (!item) return;
      const title = scalarText(item['title'], 120);
      if (title) block.items.push(pluginItem(title, scalarText(item['badge'], 80)));
    });
    if (!block.items.length) document.blocks.pop();
    return;
  }
  if (type === 'steps') {
    if (!Array.isArray(node['items'])) return;
    const block = addPluginBlock(document, 'steps');
    if (!block) return;
    (node['items'] as Object[]).slice(0, 12).forEach((raw: Object): void => {
      const item = recordValue(raw);
      const title = item ? scalarText(item['label'], 160) : scalarText(raw, 160);
      if (!title) return;
      block.items.push(pluginItem(title, item ? scalarText(item['detail'], 220) : '',
        item ? scalarText(item['status'], 40) : '',
        item && item['status'] === 'failed' ? 'danger' :
          item && item['status'] === 'done' ? 'success' : 'default'));
    });
    if (!block.items.length) document.blocks.pop();
    return;
  }
  if (type === 'options') {
    if (!Array.isArray(node['options'])) return;
    const selectedValues: string[] = [];
    if (typeof node['selected'] === 'string') selectedValues.push(node['selected'] as string);
    else if (Array.isArray(node['selected'])) {
      (node['selected'] as Object[]).forEach((raw: Object): void => {
        if (typeof raw === 'string') selectedValues.push(raw as string);
      });
    }
    const block = addPluginBlock(document, 'options');
    if (!block) return;
    block.id = scalarText(node['id'], 80);
    block.multi = node['multi'] === true || node['multi'] === 'true';
    (node['options'] as Object[]).slice(0, 12).forEach((raw: Object): void => {
      const item = recordValue(raw);
      const label = item ? scalarText(item['label'], 160) : scalarText(raw, 160);
      const value = item ? scalarText(item['value'], 160) : label;
      if (!label) return;
      block.items.push(pluginItem(label, item ? scalarText(item['description'], 220) : '',
        '', 'default', selectedValues.includes(value), value));
    });
    block.selected = selectedValues.join(', ');
    if (!block.items.length) document.blocks.pop();
    return;
  }
  if (type === 'confirm') {
    if (!interactive) return;
    const block = addPluginBlock(document, 'confirm');
    if (!block) return;
    block.id = scalarText(node['id'], 80);
    block.text = scalarText(node['label'], 240);
    block.confirmLabel = scalarText(node['confirmLabel'], 40);
    block.cancelLabel = scalarText(node['cancelLabel'], 40);
    return;
  }
  if (type === 'image') {
    const src = scalarText(node['src'], 120);
    if (!src) return;
    const block = addPluginBlock(document, 'image');
    if (!block) return;
    block.label = scalarText(node['alt'], 160);
    block.caption = scalarText(node['caption'], 160);
    block.text = src.startsWith('data:image/') ? '内嵌图像' : '图像未加载';
    return;
  }

  // Confirm/actions are intentionally inert in persisted tool cards. Future
  // component types keep the surrounding card valid but show a safe placeholder.
  if (type === 'actions') return;
  const unsupported = addPluginBlock(document, 'unsupported');
  if (!unsupported) return;
  unsupported.text = '此插件组件暂不支持';
}

function knownStructuredType(type: string, interactive: boolean): boolean {
  if (interactive) {
    return ['stack', 'row', 'text', 'metric', 'chart', 'compare', 'steps',
      'callout', 'options', 'confirm'].includes(type);
  }
  return ['stack', 'row', 'text', 'metric', 'chart', 'compare', 'steps',
    'callout', 'options', 'confirm', 'list', 'keyValue', 'progress', 'table',
    'actions', 'image'].includes(type);
}

function parseStructuredDocument(value: Object, limit: number,
  interactive: boolean): NativePluginDocument {
  const document = new NativePluginDocument();
  document.present = true;
  let rootValue = value;
  if (Array.isArray(rootValue)) {
    const wrapped: Record<string, Object> = {};
    wrapped['type'] = 'stack';
    wrapped['children'] = rootValue as Object[];
    rootValue = wrapped;
  }
  const root = recordValue(rootValue);
  if (!root) return document;
  const type = stringValue(root['type']).trim();
  if (!knownStructuredType(type, interactive)) return document;
  const serialized = JSON.stringify(rootValue);
  if (utf8ByteLength(serialized) > limit) return document;
  document.valid = true;
  document.title = scalarText(root['title'], 80);
  const budget = new NativePluginBudget();
  parsePluginNode(rootValue, document, budget, 0, interactive);
  document.truncated = budget.truncated;
  return document;
}

function parsePluginView(document: NativeToolStructured,
  meta: Record<string, Object> | null, tool: NativeMessage): void {
  if (!successfulResult(tool) || !meta || meta['dsh-go/view'] === undefined) return;
  const value = meta['dsh-go/view'];
  if (!value) return;
  document.plugin = parseStructuredDocument(value, 8192, false);
}

/** Parse one assistant `dsh-ui` fence with the larger DSH-Go model budget. */
export function nativeDshUiDocument(source: string): NativePluginDocument {
  const value = parseStructuredJson(source);
  if (!value) {
    const invalid = new NativePluginDocument();
    invalid.present = true;
    return invalid;
  }
  return parseStructuredDocument(value, 16384, true);
}

function optionalString(record: Record<string, Object>, field: string): string {
  const value = record[field];
  return typeof value === 'string' ? value as string : '';
}

function optionalInteger(record: Record<string, Object>, field: string,
  minimum: number = 0): number {
  const value = record[field];
  return typeof value === 'number' && Number.isSafeInteger(value as number) &&
    (value as number) >= minimum ? value as number : minimum === 0 ? 0 : -1;
}

function optionalNumber(record: Record<string, Object>, field: string,
  minimum: number = 0): number {
  const value = record[field];
  return typeof value === 'number' && Number.isFinite(value as number) &&
    (value as number) >= minimum ? value as number : 0;
}

function parseMedia(document: NativeToolStructured, meta: Record<string, Object> | null,
  workspaceRoot: string): void {
  if (!meta || meta['dsh-go/media'] === undefined) return;
  document.media.present = true;
  const raw = recordValue(meta['dsh-go/media']);
  if (!raw) return;
  const version = raw['v'] === undefined ? 1 : optionalInteger(raw, 'v', 1);
  if (version < 1) return;
  if (utf8ByteLength(JSON.stringify(raw)) > 8192) return;
  let kind = stringValue(raw['kind']).trim();
  let status = stringValue(raw['status']).trim();
  if (!['running', 'done', 'failed'].includes(status)) status = 'done';

  const items: NativeMediaItem[] = [];
  if (Array.isArray(raw['items'])) {
    for (const value of (raw['items'] as Object[]).slice(0, 32)) {
      const item = recordValue(value);
      if (!item || typeof item['path'] !== 'string' || !(item['path'] as string).trim()) continue;
      const parsed = new NativeMediaItem();
      parsed.path = normalizePath(item['path'] as string);
      parsed.display = nativeStructuredDisplayPath(parsed.path, workspaceRoot);
      parsed.name = basename(parsed.display);
      parsed.mime = optionalString(item, 'mime');
      parsed.width = optionalInteger(item, 'width');
      parsed.height = optionalInteger(item, 'height');
      parsed.bytes = optionalInteger(item, 'bytes');
      parsed.duration = optionalNumber(item, 'duration');
      parsed.poster = normalizePath(optionalString(item, 'poster'));
      parsed.codec = optionalString(item, 'codec');
      items.push(parsed);
    }
  }
  if (kind !== 'image' && kind !== 'video') {
    kind = items.length && items[0].mime.toLowerCase().startsWith('video/') ? 'video' :
      items.length ? 'image' : '';
  }
  if (!kind || (status === 'done' && !items.length)) return;

  const request = recordValue(raw['request']);
  if (request) {
    document.media.request.provider = optionalString(request, 'provider');
    document.media.request.model = optionalString(request, 'model');
    document.media.request.label = optionalString(request, 'label');
    document.media.request.aspect = optionalString(request, 'aspect');
    document.media.request.count = optionalInteger(request, 'n');
    document.media.request.quality = optionalString(request, 'quality');
    document.media.request.seconds = optionalNumber(request, 'seconds');
    document.media.request.resolution = optionalString(request, 'resolution') ||
      optionalString(request, 'res');
    document.media.request.refs = optionalInteger(request, 'refs');
  }
  const error = recordValue(raw['error']);
  if (error) {
    document.media.errorCode = scalarText(error['code'], 80);
    document.media.errorText = scalarText(error['text'], 400);
  }
  const cost = recordValue(raw['cost']);
  if (cost) {
    const rawEstimate = cost['estimate'];
    if (typeof rawEstimate === 'number' && Number.isFinite(rawEstimate as number) &&
      (rawEstimate as number) >= 0) {
      document.media.costEstimate = rawEstimate as number;
      document.media.costCurrency = scalarText(cost['currency'], 16);
    }
  }
  const provenance = recordValue(raw['provenance']);
  if (provenance) {
    document.media.visibleMark = provenance['visibleMark'] === true;
    document.media.c2pa = provenance['c2pa'] === true;
    document.media.implicitLabel = provenance['implicitLabel'] === true;
  }
  document.media.valid = true;
  document.media.kind = kind;
  document.media.status = status;
  document.media.rid = optionalString(raw, 'rid');
  document.media.job = optionalString(raw, 'job');
  document.media.items = items;
  document.media.prompt = optionalString(raw, 'prompt');
  document.media.revisedPrompt = optionalString(raw, 'revisedPrompt');
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

function addReadFields(document: NativeToolStructured): void {
  document.fields = [];
  addField(document, '行号', document.read.offset > 0 ? '从 ' +
    document.read.offset.toString() + ' 开始' : '');
  addField(document, '行数', document.read.limit > 0 ? document.read.limit.toString() : '');
  addField(document, '总行数', document.read.totalLines >= 0 ?
    document.read.totalLines.toString() : '');
  addField(document, '语言', document.read.language);
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
      addReadFields(document);
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
  addReadFields(document);
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
        file.name = basename(file.display);
        file.directory = parentDirectory(file.display);
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
      file.name = basename(file.display);
      file.directory = parentDirectory(file.display);
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

function parseCommand(document: NativeToolStructured, tool: NativeMessage,
  meta: Record<string, Object> | null): void {
  if (!meta) return;
  const name = firstString(meta, ['name']);
  const args = firstString(meta, ['args']);
  const result = firstString(meta, ['text']);
  const kind = firstString(meta, ['kind']);
  const settled = tool.phase === 'result';
  document.summary = preview((name ? '/' + name : '命令') + (args ? ' ' + args : ''));
  document.summaryIsCode = true;
  document.parsed = !!meta && (!!name || !!tool.output);
  addField(document, '命令', name ? '/' + name : '', true);
  addField(document, '参数', args, true);
  if (settled) {
    addField(document, '状态', kind === 'success' ? '已完成' :
      kind === 'error' || tool.failed ? '失败' : kind, false,
      kind === 'success' ? 'success' : 'danger');
  } else {
    addField(document, '状态', '正在执行', false, 'accent');
  }
  addField(document, '结果', result || tool.output);
  document.bodyStructured = document.fields.length > 0;
  document.showRawArguments = false;
  document.showRawOutput = false;
}

function parseJobLifecycle(document: NativeToolStructured, tool: NativeMessage,
  meta: Record<string, Object> | null): void {
  if (!meta) return;
  const id = firstString(meta, ['jobId']);
  const kind = firstString(meta, ['kind']);
  const label = firstString(meta, ['label']);
  const status = firstString(meta, ['status']);
  const detail = firstString(meta, ['detail']);
  const cause = firstString(meta, ['cause']);
  const toolCall = recordValue(meta['toolCall']);
  document.summary = preview(label || id);
  document.summaryIsCode = !!id;
  document.parsed = !!id;
  addField(document, '任务', id, true);
  addField(document, '类型', kind, true);
  addField(document, '名称', label);
  addField(document, '状态', status || (tool.phase === 'result' ? '已结束' : '运行中'), false,
    status === 'failed' || status === 'killed' || tool.failed ? 'danger' :
      status === 'completed' ? 'success' : 'accent');
  addField(document, '原因', cause);
  addField(document, '详情', detail || tool.output);
  if (toolCall) {
    addField(document, '调用', firstString(toolCall, ['callId']), true);
    addField(document, '根调用', firstString(toolCall, ['rootCallId']), true);
  }
  document.bodyStructured = document.fields.length > 0;
  document.showRawArguments = false;
  document.showRawOutput = false;
}

function parsePresent(document: NativeToolStructured, tool: NativeMessage,
  args: Record<string, Object> | null, workspaceRoot: string): void {
  if (!successfulResult(tool)) return;
  let files: Object[] | null = null;
  let authoritative = false;
  const event = parseObject(tool.authoritativeRaw);
  if (event && integerValue(event['turn'], false) > 0 &&
    typeof event['callId'] === 'string' && (event['callId'] as string).length > 0 &&
    Array.isArray(event['files'])) {
    files = event['files'] as Object[];
    authoritative = true;
  }
  if (!files && args && Array.isArray(args['files'])) files = args['files'] as Object[];
  if (!files) return;
  const names: string[] = [];
  const seen: Set<string> = new Set<string>();
  for (const raw of files) {
    const item = recordValue(raw);
    const path = item ? stringValue(item['path']).trim() : '';
    const descriptionValue = item ? item['description'] : undefined;
    if (!item || !path || (descriptionValue !== undefined && typeof descriptionValue !== 'string')) continue;
    const normalized = normalizePath(path);
    if (seen.has(normalized)) {
      const existing = document.presented.find((file: NativeStructuredPresentedFile): boolean =>
        file.path === normalized);
      if (existing && typeof descriptionValue === 'string') {
        existing.description = (descriptionValue as string).trim();
      }
      continue;
    }
    seen.add(normalized);
    const file = new NativeStructuredPresentedFile();
    file.path = normalized;
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
  addField(document, authoritative ? '权威交付' : '交付',
    document.presented.length.toString() + ' 个文件');
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

/** Exact current tool-name category shared by parsing, grouping and process UI. */
const toolKindMemo: Map<string, Map<string, string>> = new Map<string, Map<string, string>>();
/**
 * Category derivation re-parses editor arguments on every paint. Durable tools
 * share argument string instances across projection copies, so the common path
 * is a map hit.
 */
export function nativeToolKind(name: string, argsText: string = ''): string {
  let byArgs = toolKindMemo.get(name);
  if (!byArgs) {
    byArgs = new Map<string, string>();
    toolKindMemo.set(name, byArgs);
  }
  const cached = byArgs.get(argsText);
  if (cached !== undefined) return cached;
  const value = nativeToolKindUncached(name, argsText);
  if (byArgs.size >= 512) byArgs.clear();
  byArgs.set(argsText, value);
  return value;
}
function nativeToolKindUncached(name: string, argsText: string = ''): string {
  if (name === 'str_replace_editor') {
    const args = parseObject(argsText);
    const command = args ? stringValue(args['command']).trim() : '';
    if (command === 'view') return 'read';
    if (command === 'create') return 'write';
    if (command === 'str_replace' || command === 'insert') return 'edit';
    return 'tools';
  }
  if (name === 'read') return 'read';
  if (name === 'read_image') return 'readImage';
  if (name === 'grep' || name === 'glob' || name.endsWith('_inspect')) return 'search';
  if (name === 'write') return 'write';
  if (name === 'edit' || name === 'apply_patch') return 'edit';
  if (['bash', 'pwsh', 'exec_command', 'write_stdin'].includes(name) ||
    name.startsWith('terminal_')) return 'commands';
  if (name === 'job_output' || name === 'job_kill' || name === 'job_list') return 'job';
  if (name === 'run_code') return 'code';
  if (name === 'web_search') return 'webSearch';
  if (name === 'web_fetch') return 'webFetch';
  if (name === 'subagent' || name.startsWith('subagent_') || name === 'send_message' ||
    name === 'interrupt_agent' || name === 'workflow' || name === 'ralph' ||
    name === 'skill') return 'subagents';
  if (['todo_write', 'create_goal', 'update_goal', 'get_goal'].includes(name)) return 'plan';
  if (['ask_user_question', 'request_user_input'].includes(name)) return 'questions';
  if (name === 'slash_command') return 'command';
  if (name === 'job_lifecycle') return 'jobLifecycle';
  return 'tools';
}

/** Project one merged tool call into a compact, strictly validated view model. */
export function nativeToolStructured(tool: NativeMessage, workspaceRoot: string = ''): NativeToolStructured {
  const document = new NativeToolStructured();
  if (!tool) return document;
  const args = parseObject(tool.args);
  const meta = parseObject(tool.metaRaw);
  const name = tool.toolName || '';
  parsePluginView(document, meta, tool);
  parseMedia(document, meta, workspaceRoot);
  const kind = nativeToolKind(name, tool.args);

  if (kind === 'read') {
    document.family = 'read';
    parseRead(document, tool, args, meta, workspaceRoot);
  } else if (kind === 'readImage') {
    document.family = 'image';
    parseImage(document, tool, args, meta, workspaceRoot);
  } else if (kind === 'search') {
    document.family = 'search';
    parseSearch(document, tool, args, meta, workspaceRoot);
  } else if (kind === 'commands') {
    document.family = 'terminal';
    parseTerminal(document, tool, args, meta, workspaceRoot);
  } else if (kind === 'webSearch' || kind === 'webFetch') {
    document.family = 'web';
    parseWeb(document, tool, args, meta);
  } else if (kind === 'plan' && name !== 'todo_write') {
    document.family = 'goal';
    parseGoal(document, tool, args, meta);
  } else if (kind === 'job') {
    document.family = 'job';
    parseJob(document, tool, args, meta);
  } else if (kind === 'subagents') {
    document.family = 'agent';
    parseAgent(document, tool, args, meta);
  } else if (kind === 'command') {
    document.family = 'command';
    parseCommand(document, tool, meta);
  } else if (kind === 'jobLifecycle') {
    document.family = 'jobLifecycle';
    parseJobLifecycle(document, tool, meta);
  } else if (name === 'present') {
    document.family = 'present';
    parsePresent(document, tool, args, workspaceRoot);
    if (!document.parsed) generic(document, tool, args);
  } else if (name === 'ask_user_question' || name === 'request_user_input') {
    document.family = 'question';
    parseQuestion(document, tool, args);
  } else if (kind === 'write' || kind === 'edit') {
    document.family = 'file';
    parseFileFamily(document, tool, args, workspaceRoot);
  } else if (name === 'todo_write') {
    document.family = 'plan';
    document.summary = '';
    document.parsed = true;
  } else {
    generic(document, tool, args);
  }

  if (document.plugin.present) {
    document.bodyStructured = true;
    document.showRawArguments = !document.plugin.valid;
    document.showRawOutput = !document.plugin.valid;
    if (document.plugin.valid && document.plugin.title) document.summary = document.plugin.title;
  }
  if (document.media.valid) {
    document.bodyStructured = true;
    document.showRawArguments = false;
    document.showRawOutput = false;
    document.summary = preview(document.media.request.label || document.media.request.model ||
      document.media.prompt || (document.media.kind === 'video' ? '生成视频' : '生成图片'));
  }

  if (failedTool(tool)) {
    const preserveFailedMedia = document.media.valid && document.media.status === 'failed';
    if (!preserveFailedMedia) document.bodyStructured = false;
    document.read.valid = false;
    document.search.valid = false;
    document.sources = [];
    document.presented = [];
    document.image = new NativeStructuredImageFacts();
    document.plugin = new NativePluginDocument();
    document.showRawArguments = true;
    document.showRawOutput = true;
    if (preserveFailedMedia) {
      document.bodyStructured = true;
      document.showRawOutput = true;
    }
  }
  if (!document.summary && name !== 'todo_write') {
    const fallback = genericSummary(tool, args);
    document.summary = fallback;
    document.parsed = !!fallback;
  }
  return document;
}

function toolCategory(name: string, argsText: string = ''): string {
  const kind = nativeToolKind(name, argsText);
  if (kind === 'commands') return 'commands';
  if (kind === 'write' || kind === 'edit') return 'edit';
  if (kind === 'read' || kind === 'readImage') return 'read';
  if (kind === 'search') return 'search';
  if (kind === 'webSearch' || kind === 'webFetch') return 'web';
  if (kind === 'subagents') return 'agents';
  if (kind === 'plan') return 'plans';
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
    const category = toolCategory(tool.toolName, tool.args);
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
