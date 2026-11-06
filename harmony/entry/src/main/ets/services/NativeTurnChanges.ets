import { NativeMessage } from './NativeSessionModel';
import { NativeDiffDocument, NativeDiffRow, nativeDiff } from './NativeDiff';

export class NativeTurnFileChange {
  path: string = '';
  display: string = '';
  added: number = 0;
  removed: number = 0;
  binary: boolean = false;
  oversized: boolean = false;
}

export class NativeTurnFilePresentation {
  relativePath: string = '';
  directory: string = '';
  name: string = '';
}

export class NativeTurnChangeSummary {
  turnKey: string = '';
  files: NativeTurnFileChange[] = [];
  fileCount: number = 0;
  added: number = 0;
  removed: number = 0;
  running: boolean = true;
  outcome: string = '';
}

export class NativeTurnChangeReference {
  turnKey: string = '';
  turn: number = 0;
  seq: number = 0;
}

function mutationTool(tool: NativeMessage): boolean {
  return tool.toolName === 'write' || tool.toolName === 'edit' ||
    tool.toolName === 'str_replace_editor' || tool.toolName === 'apply_patch';
}

function countableMutation(tool: NativeMessage): boolean {
  const settled = tool.phase === 'result' || tool.status === 'success';
  if (!settled) return false;
  if (tool.failed || tool.status === 'error' || tool.status === 'interrupted') return false;
  if (tool.outcome === 'failed' || tool.outcome === 'error' ||
      tool.outcome === 'interrupted' || tool.outcome === 'cancelled') return false;
  return !tool.output.includes('AUTO_REVIEW_DENIED');
}

function normalizedPath(path: string): string {
  return (path || '').replace(/\\/g, '/').replace(/\/+/g, '/');
}

function withoutTrailingSlash(path: string): string {
  if (path === '/') return path;
  return path.replace(/\/+$/, '');
}

function absolutePath(path: string): boolean {
  return path.startsWith('/') || /^[A-Za-z]:\//.test(path);
}

function pathName(path: string): string {
  const clean = withoutTrailingSlash(path);
  const slash = clean.lastIndexOf('/');
  return slash >= 0 ? clean.slice(slash + 1) : clean;
}

function workspaceRelative(path: string, workspaceRoot: string): string {
  const normalized = normalizedPath(path).trim();
  const root = withoutTrailingSlash(normalizedPath(workspaceRoot).trim());
  if (!root) return absolutePath(normalized) ? '' : normalized;
  if (root === '/') {
    return normalized.startsWith('/') ? normalized.slice(1) : normalized;
  }
  const windowsRoot = /^[A-Za-z]:\//.test(root);
  const comparablePath = windowsRoot ? normalized.toLowerCase() : normalized;
  const comparableRoot = windowsRoot ? root.toLowerCase() : root;
  if (comparablePath === comparableRoot) return '';
  if (comparablePath.startsWith(comparableRoot + '/')) {
    return normalized.slice(root.length + 1);
  }
  return absolutePath(normalized) ? '' : normalized;
}

/**
 * Present a changed file as workspace-relative directory plus filename.
 * Host paths remain private unless they fall below the current workspace.
 */
export function nativeTurnFilePresentation(path: string, workspaceRoot: string,
  display: string = ''): NativeTurnFilePresentation {
  const shownPath = normalizedPath(display).trim();
  let relativePath = workspaceRelative(path, workspaceRoot).trim();
  if (!relativePath && shownPath && !absolutePath(shownPath)) relativePath = shownPath;
  while (relativePath.startsWith('./')) relativePath = relativePath.slice(2);
  if (absolutePath(relativePath)) relativePath = pathName(relativePath);
  if (!relativePath) relativePath = pathName(normalizedPath(path).trim());
  if (!relativePath) relativePath = pathName(shownPath);
  const shownName = shownPath ? pathName(shownPath) : '';
  const slash = relativePath.lastIndexOf('/');
  const presentation = new NativeTurnFilePresentation();
  presentation.relativePath = relativePath;
  presentation.directory = slash >= 0 ? relativePath.slice(0, slash + 1) : '';
  presentation.name = shownName || relativePath.slice(slash + 1);
  return presentation;
}

function documentFiles(document: NativeDiffDocument): NativeTurnFileChange[] {
  const files: NativeTurnFileChange[] = [];
  const indexes: Map<string, number> = new Map<string, number>();
  let current = document.path || '';
  const addCount = (path: string, added: number, removed: number): void => {
    const display = path.trim();
    const key = normalizedPath(display);
    if (!key) return;
    let index = indexes.get(key);
    if (index === undefined) {
      const file = new NativeTurnFileChange();
      file.path = display;
      file.display = display;
      file.added = added;
      file.removed = removed;
      indexes.set(key, files.length);
      files.push(file);
      return;
    }
    files[index].added += added;
    files[index].removed += removed;
  };
  document.rows.forEach((row: NativeDiffRow): void => {
    if (row.kind === 'path') {
      current = row.text;
      return;
    }
    if (row.kind === 'add') addCount(current, 1, 0);
    else if (row.kind === 'del') addCount(current, 0, 1);
  });
  return files;
}

function addSummaryFile(summary: NativeTurnChangeSummary, key: string,
  incoming: NativeTurnFileChange): void {
  let index = -1;
  for (let cursor = 0; cursor < summary.files.length; cursor++) {
    if (normalizedPath(summary.files[cursor].path) === key) {
      index = cursor;
      break;
    }
  }
  if (index < 0) {
    const file = new NativeTurnFileChange();
    file.path = incoming.path;
    file.display = incoming.display || incoming.path;
    file.added = incoming.added;
    file.removed = incoming.removed;
    file.binary = incoming.binary;
    file.oversized = incoming.oversized;
    summary.files.push(file);
  } else {
    summary.files[index].added += incoming.added;
    summary.files[index].removed += incoming.removed;
  }
  summary.fileCount = summary.files.length;
  let added = 0;
  let removed = 0;
  for (let cursor = 0; cursor < summary.files.length; cursor++) {
    added += summary.files[cursor].added;
    removed += summary.files[cursor].removed;
  }
  summary.added = added;
  summary.removed = removed;
}

function visitTool(summaries: Map<string, NativeTurnChangeSummary>,
  calls: Map<string, Set<string>>, tool: NativeMessage): void {
  if (tool.role !== 'tool' || !mutationTool(tool) || !countableMutation(tool)) return;
  const callKey = tool.callId || tool.id || tool.renderKey;
  if (callKey) {
    let seen = calls.get(tool.turnKey);
    if (!seen) {
      seen = new Set<string>();
      calls.set(tool.turnKey, seen);
    }
    if (seen.has(callKey)) return;
    seen.add(callKey);
  }
  const files = documentFiles(nativeDiff(tool));
  if (!files.length) return;
  let summary = summaries.get(tool.turnKey);
  if (!summary) {
    summary = new NativeTurnChangeSummary();
    summary.turnKey = tool.turnKey;
    summaries.set(tool.turnKey, summary);
  }
  files.forEach((file: NativeTurnFileChange): void => {
    addSummaryFile(summary as NativeTurnChangeSummary, normalizedPath(file.path), file);
  });
}

function visit(rows: NativeMessage[], summaries: Map<string, NativeTurnChangeSummary>,
  calls: Map<string, Set<string>>): void {
  rows.forEach((row: NativeMessage): void => {
    if (row.role === 'process') {
      const children: NativeMessage[] = row.children || [];
      visit(children, summaries, calls);
      return;
    }
    if (row.role === 'turn-footer') {
      const summary = summaries.get(row.turnKey);
      if (summary) {
        summary.running = false;
        summary.outcome = row.footerOutcome || row.outcome || '';
      }
      return;
    }
    visitTool(summaries, calls, row);
  });
}

/**
 * Aggregate successful explicit edit/write diffs into stable per-turn file
 * summaries. This is a view projection; it never mutates journal rows.
 */
export function nativeTurnChanges(rows: NativeMessage[]): NativeTurnChangeSummary[] {
  const summaries: Map<string, NativeTurnChangeSummary> =
    new Map<string, NativeTurnChangeSummary>();
  visit(rows || [], summaries, new Map<string, Set<string>>());
  const result: NativeTurnChangeSummary[] = [];
  summaries.forEach((summary: NativeTurnChangeSummary): void => {
    if (summary.files.length) result.push(summary);
  });
  return result;
}

export function nativeLiveTurnChange(rows: NativeMessage[],
  active: boolean): NativeTurnChangeSummary | null {
  if (!active) return null;
  const summaries = nativeTurnChanges(rows);
  for (let index = summaries.length - 1; index >= 0; index--) {
    if (summaries[index].running) return summaries[index];
  }
  return null;
}

/**
 * Live pill projection over the signature-gated summaries. The caller passes
 * the summaries computed for the same rows in the same paint; this keeps the
 * live control O(summaries) instead of reparsing every tool diff per frame.
 */
export function nativeLiveTurnChangeFrom(summaries: NativeTurnChangeSummary[],
  active: boolean): NativeTurnChangeSummary | null {
  if (!active) return null;
  for (let index = summaries.length - 1; index >= 0; index--) {
    if (summaries[index].running) return summaries[index];
  }
  return null;
}

export function nativeTurnChangeFor(rows: NativeTurnChangeSummary[],
  turnKey: string): NativeTurnChangeSummary | null {
  const found = rows.find((summary: NativeTurnChangeSummary): boolean =>
    summary.turnKey === turnKey);
  return found || null;
}

/** Latest durable `workspace/changes` announcement for each loaded turn. */
export function nativeTurnChangeReferences(journal: string[]): NativeTurnChangeReference[] {
  const byTurn: Map<string, NativeTurnChangeReference> = new Map<string, NativeTurnChangeReference>();
  (journal || []).forEach((raw: string): void => {
    if (!raw) return;
    try {
      const event = JSON.parse(raw) as Record<string, Object>;
      const data = event.data as Record<string, Object>;
      const seq = event.seq;
      const turn = data?.turn;
      if (event.type !== 'workspace/changes' || !Number.isSafeInteger(seq) ||
          !Number.isSafeInteger(turn) || (turn as number) < 1) return;
      const turnKey = 'turn:' + (turn as number);
      const existing = byTurn.get(turnKey);
      if (existing && existing.seq >= (seq as number)) return;
      const reference = new NativeTurnChangeReference();
      reference.turn = turn as number;
      reference.seq = seq as number;
      reference.turnKey = turnKey;
      byTurn.set(turnKey, reference);
    } catch (_) {}
  });
  const result: NativeTurnChangeReference[] = [];
  byTurn.forEach((value: NativeTurnChangeReference): void => { result.push(value); });
  return result.sort((left: NativeTurnChangeReference, right: NativeTurnChangeReference): number =>
    left.seq - right.seq);
}

function nonNegativeInteger(value: Object): boolean {
  return Number.isSafeInteger(value) && (value as number) >= 0;
}

/**
 * Validate the authenticated summary bridged from DSH's
 * `/api/changes.summary`. The official response intentionally omits the Host
 * cwd and snapshot identities; this parser also refuses unknown or oversized
 * records rather than forwarding them into the transcript UI.
 */
export function nativeTurnChangeSummaryFromJson(value: string, turnKey: string,
  outcome: string = ''): NativeTurnChangeSummary | null {
  try {
    const root = JSON.parse(value) as Record<string, Object>;
    const filesValue = root.files;
    const turn = root.turn;
    const total = root.total;
    const added = root.added;
    const removed = root.deleted;
    const prefix = 'turn:';
    if (!Number.isSafeInteger(turn) || (turn as number) < 1 ||
        !turnKey.startsWith(prefix) || Number(turnKey.slice(prefix.length)) !== (turn as number) ||
        !Array.isArray(filesValue) || filesValue.length > 500 ||
        !Number.isSafeInteger(total) || (total as number) < filesValue.length ||
        (total as number) > 1000000 || !nonNegativeInteger(added) ||
        !nonNegativeInteger(removed)) return null;
    const files: NativeTurnFileChange[] = [];
    for (let index = 0; index < filesValue.length; index++) {
      const source = filesValue[index] as Record<string, Object>;
      const path = source?.path;
      const display = source?.display;
      const fileAdded = source?.added;
      const fileRemoved = source?.deleted;
      const binary = source?.binary;
      const oversized = source?.oversized;
      if (typeof path !== 'string' || !path || path.length > 4096 ||
          typeof display !== 'string' || !display || display.length > 8192 ||
          !nonNegativeInteger(fileAdded) || !nonNegativeInteger(fileRemoved) ||
          (binary !== undefined && binary !== true) ||
          (oversized !== undefined && oversized !== true)) return null;
      const file = new NativeTurnFileChange();
      file.path = path;
      file.display = display;
      file.added = fileAdded as number;
      file.removed = fileRemoved as number;
      file.binary = binary === true;
      file.oversized = oversized === true;
      files.push(file);
    }
    const summary = new NativeTurnChangeSummary();
    summary.turnKey = turnKey;
    summary.files = files;
    summary.fileCount = total as number;
    summary.added = added as number;
    summary.removed = removed as number;
    summary.running = false;
    summary.outcome = outcome;
    return summary;
  } catch (_) {
    return null;
  }
}

function appendSignature(row: NativeMessage, parts: string[]): void {
  if (row.role === 'process') {
    (row.children || []).forEach((child: NativeMessage): void => appendSignature(child, parts));
    return;
  }
  if (row.role !== 'tool' && row.role !== 'turn-footer') return;
  // Content participates by length: streamed arguments grow monotonically and
  // the settled durable row lands under a fresh id/seq, so a same-length
  // replacement is still invalidated by identity. Hashing every byte of every
  // tool argument on each paint is the cost this signature exists to avoid.
  parts.push([row.role, row.turnKey, row.callId, row.id, row.renderKey, row.toolName, row.phase,
    row.status, row.outcome, row.footerOutcome, row.failed ? '1' : '0',
    (row.args || '').length, (row.metaRaw || '').length,
    (row.output || '').length, (row.error || '').length,
    (row.errorRaw || '').length].join(':'));
}

/**
 * Cheap change detector for the turn-change projection. Stream text can update
 * every 40ms while tool rows remain unchanged; callers use this signature to
 * avoid reparsing the complete diff history on each text delta.
 */
export function nativeTurnChangeInputSignature(rows: NativeMessage[],
  streamTools: NativeMessage[] = []): string {
  const parts: string[] = [];
  (rows || []).forEach((row: NativeMessage): void => appendSignature(row, parts));
  (streamTools || []).forEach((row: NativeMessage): void => appendSignature(row, parts));
  return parts.join('|');
}
