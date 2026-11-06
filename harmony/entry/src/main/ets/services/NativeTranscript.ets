import { NativeMessage, NativeAssistantSegment, NativeStreamPart } from './NativeSessionModel';
import { NativeChatPreferences } from './NativeHostSettings';
import { NativePlanDocument, nativePlanDiff, nativePlanDocument, nativePlanProgress } from './NativePlan';
import { nativeToolStructured, nativeToolGroupSummary, nativeToolKind } from './NativeToolStructured';

/** Flatten editor, terminal and reasoning text into one width-fillable preview. */
export function nativeOneLinePreview(value: string, limit: number = 160): string {
  const text = (value || '').replace(/\s+/g, ' ').trim();
  return limit > 0 && text.length > limit ? text.slice(0, limit - 1) + '…' : text;
}

// Mirrors Chat's event projection, call-id lifecycle, process boundaries and exact tool-name categories.
export function nativeToolCategory(name: string, argsText: string = ''): string {
  return nativeToolKind(name, argsText);
}
export function nativeActivity(category: string, running: boolean): string {
  if (category === 'command') return running ? '正在执行命令' : '执行了命令';
  if (category === 'jobLifecycle') return running ? '后台任务运行中' : '后台任务已结束';
  const kinds = ['read', 'readImage', 'search', 'write', 'edit', 'commands', 'code', 'webSearch', 'webFetch', 'subagents', 'plan', 'questions', 'tools'];
  const active = ['正在读取文件', '正在读取图片', '正在搜索代码', '正在写入文件', '正在编辑文件', '正在运行命令', '正在运行代码', '正在搜索网页', '正在访问网页', '正在协调子代理', '正在更新计划', '等待你的操作', '正在调用工具'];
  const settled = ['已读取文件', '已读取图片', '已搜索代码', '已写入文件', '修改了文件', '执行了命令', '运行了代码', '已搜索网页', '已访问网页', '已协调子代理', '更新了计划', '向用户提出了问题', '已调用工具'];
  const index = kinds.indexOf(category);
  return index < 0 ? running ? '正在分析请求' : '已完成分析' : (running ? active : settled)[index];
}
export function nativeProcessIcon(category: string): string {
  if (category === 'read' || category === 'readImage' || category === 'webFetch') return 'browse-outline';
  if (category === 'search') return 'search-outline';
  if (category === 'edit' || category === 'write') return 'edit-outline';
  if (category === 'commands') return 'api-outline';
  if (category === 'code') return 'code-outline';
  if (category === 'webSearch') return 'globe-outline';
  if (category === 'subagents') return 'agent-preset-outline';
  if (category === 'plan') return 'plan-outline';
  if (category === 'questions') return 'question-outline';
  if (category === 'command') return 'api-outline';
  if (category === 'jobLifecycle') return 'queue-outline';
  return category === 'tools' ? 'sparkle' : 'think-outline';
}
const toolDetailMemo: Map<string, string> = new Map<string, string>();
function toolMemoSignature(tool: NativeMessage, workspaceRoot: string): string {
  return [tool.id, tool.callId, tool.seq, tool.toolName, tool.phase, tool.status,
    tool.failed ? '1' : '0', tool.outcome, tool.turnKey, workspaceRoot,
    (tool.args || '').length, (tool.metaRaw || '').length, (tool.output || '').length,
    (tool.error || '').length, (tool.errorRaw || '').length, (tool.contentRaw || '').length,
    (tool.authoritativeRaw || '').length, (tool.planDiff || '').length,
    (tool.text || '').length, (tool.blocks || []).length, (tool.images || []).length].join(':');
}
/**
 * Per-paint process previews re-derive tool details for every child. Projection
 * copies share field instances across paints, so an unchanged tool is a memo hit
 * and its repeated args/meta JSON parsing leaves the frame budget.
 */
export function nativeToolDetail(tool: NativeMessage, workspaceRoot: string = ''): string {
  const key = toolMemoSignature(tool, workspaceRoot);
  const cached = toolDetailMemo.get(key);
  if (cached !== undefined) return cached;
  const value = nativeToolDetailUncached(tool, workspaceRoot);
  if (toolDetailMemo.size >= 512) toolDetailMemo.clear();
  toolDetailMemo.set(key, value);
  return value;
}
function nativeToolDetailUncached(tool: NativeMessage, workspaceRoot: string): string {
  if (tool.toolName === 'todo_write') {
    const plan = nativePlanDocument(tool);
    if (plan.parsed) return tool.planDiff || nativePlanProgress(plan);
  }
  const structured = nativeToolStructured(tool, workspaceRoot);
  if (structured.summary) return structured.summary;
  const fields = ['title', 'description', 'objective', 'task', 'task_name', 'name', 'question', 'questions', 'prompt', 'message', 'command', 'cmd', 'queries', 'query', 'pattern', 'url', 'uri', 'file_path', 'path', 'target', 'action', 'status'];
  let values: Record<string, Object> = {};
  try { values = JSON.parse(tool.args) as Record<string, Object>; } catch (_) {}
  for (const field of fields) {
    const value = values?.[field];
    let text = typeof value === 'string' ? value : '';
    if (Array.isArray(value) && value.every((part: Object) => typeof part === 'string')) text = (value as string[]).join(', ');
    if (field === 'questions' && Array.isArray(value)) {
      const questions = value as Record<string, Object>[];
      const first = questions.find((part: Record<string, Object>) => typeof part?.question === 'string' && (part.question as string).trim().length > 0);
      if (first) text = first.question as string;
    }
    if (!text && tool.phase === 'preparing') {
      const match = new RegExp('"' + field + '"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)').exec(tool.args);
      if (match) { try { text = JSON.parse('"' + match[1] + '"') as string; } catch (_) {} }
    }
    text = nativeOneLinePreview(text);
    if (text) return text;
  }
  return tool.phase === 'preparing' ? '' : tool.toolName;
}
export function nativeToolArgumentsVisible(tool: NativeMessage): boolean {
  return nativeToolCategory(tool.toolName, tool.args) !== 'readImage';
}
export function nativeToolOutputVisible(tool: NativeMessage): boolean {
  return nativeToolCategory(tool.toolName, tool.args) !== 'readImage';
}
function copy(value: NativeMessage): NativeMessage {
  const row = new NativeMessage();
  row.id = value.id; row.seq = value.seq; row.role = value.role; row.label = value.label || '';
  row.text = value.text || ''; row.reasoning = value.reasoning || ''; row.blocks = value.blocks || []; row.images = value.images || [];
  row.detail = value.detail || '';
  row.footerCopyText = value.footerCopyText || '';
  row.footerCopyMessageId = value.footerCopyMessageId || '';
  row.footerOutcome = value.footerOutcome || '';
  row.flat = value.flat === true; row.preview = value.preview !== false;
  row.runningTurn = value.runningTurn === true; row.currentTurn = value.currentTurn === true;
  row.groupedProcess = value.groupedProcess === true; row.closed = value.closed !== false;
  row.children = (value.children || []).map((child: NativeMessage): NativeMessage => copy(child));
  row.eventType = value.eventType || ''; row.turn = value.turn ?? -1; row.step = value.step ?? -1; row.time = value.time || 0;
  row.callId = value.callId || ''; row.parentCallId = value.parentCallId || ''; row.rootCallId = value.rootCallId || '';
  row.toolName = value.toolName || ''; row.phase = value.phase || ''; row.failed = value.failed === true;
  row.outcome = value.outcome || ''; row.error = value.error || '';
  row.sourceKind = value.sourceKind || ''; row.sourceForm = value.sourceForm || '';
  row.turnKey = value.turnKey || '';
  row.planDiff = value.planDiff || '';
  row.renderKey = value.renderKey || '';
  row.metaRaw = value.metaRaw || ''; row.contentRaw = value.contentRaw || ''; row.errorRaw = value.errorRaw || '';
  row.authoritativeRaw = value.authoritativeRaw || '';
  return row;
}

function recordFromJson(raw: string): Record<string, Object> | null {
  if (!raw || !raw.trim()) return null;
  try {
    const value = JSON.parse(raw) as Object;
    if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
    return value as Record<string, Object>;
  } catch (_) {
    return null;
  }
}

/** Merge lifecycle metadata without deleting facts absent from the new record. */
function mergedStructuredMeta(current: string, incoming: string): string {
  const before = recordFromJson(current);
  const after = recordFromJson(incoming);
  if (!before && !after) return current || incoming || '';
  const merged: Record<string, Object> = {};
  if (before) {
    Object.keys(before).forEach((key: string): void => { merged[key] = before[key]; });
  }
  if (after) {
    Object.keys(after).forEach((key: string): void => {
      if (after[key] !== undefined) merged[key] = after[key];
    });
  }
  return JSON.stringify(merged);
}

/** Replace only the existing live Assistant row for text-only deltas. */
export function nativeUpdateLiveAssistant(rows: NativeMessage[], text: string): NativeMessage[] | null {
  if (!text.trim()) return null;
  const index = rows.length - 1;
  const row = rows[index];
  if (!row || row.id !== 'live-assistant' || row.role !== 'assistant') return null;
  const next = copy(row);
  next.text = text;
  next.blocks = [];
  next.runningTurn = true;
  const updated = rows.slice();
  updated[index] = next;
  return updated;
}

/**
 * Reuse the durable projection for text-only stream updates and replace only
 * the live assistant tail row.
 */
export function nativeWithLiveText(rows: NativeMessage[], text: string): NativeMessage[] {
  const result = rows.filter((row: NativeMessage): boolean =>
    row.id !== 'live-assistant');
  if (!text.trim()) return result;
  const reply = new NativeMessage();
  reply.id = 'live-assistant';
  reply.role = 'assistant';
  reply.text = text;
  reply.runningTurn = true;
  for (let index = rows.length - 1; index >= 0; index--) {
    if (rows[index].turnKey) { reply.turnKey = rows[index].turnKey; break; }
  }
  result.push(reply);
  return result;
}
export function nativeProcessLead(group: NativeMessage): string {
  const operation = group.children[0];
  if (!operation) { group.toolName = 'thinking'; return group.closed ? '已完成分析' : '正在分析请求'; }
  if (operation.role === 'tool') {
    const category = nativeToolCategory(operation.toolName, operation.args);
    const active = operation.status === 'running' || operation.status === 'preparing';
    group.toolName = category;
    return nativeActivity(category, active);
  }
  if (operation.role === 'reasoning') {
    group.toolName = 'thinking';
    return '思考过程';
  }
  group.toolName = 'thinking';
  return nativeOneLinePreview(operation.label || operation.text ||
    (group.closed ? '已完成分析' : '正在分析请求'));
}
export function nativeProcessPreview(group: NativeMessage, workspaceRoot: string = ''): string {
  const operation = group.children[0];
  if (!operation) return '';
  if (operation.role === 'tool') return nativeOneLinePreview(nativeToolDetail(operation, workspaceRoot));
  if (operation.role === 'reasoning') {
    return nativeOneLinePreview(nativeReasoningPreview(operation.reasoning || operation.text, !group.closed));
  }
  const lead = nativeProcessLead(group);
  const body = nativeOneLinePreview(operation.label || operation.text || '');
  return body && body !== lead ? body : '';
}
export function nativeOperationLead(operation: NativeMessage): string {
  if (operation.role !== 'tool') {
    return operation.role === 'reasoning' ? '思考过程' :
      nativeOneLinePreview(operation.label || '工作过程');
  }
  return nativeActivity(nativeToolCategory(operation.toolName, operation.args),
    operation.status === 'running' || operation.status === 'preparing');
}
export function nativeOperationPreview(operation: NativeMessage, workspaceRoot: string = ''): string {
  if (operation.role === 'tool' && operation.toolName === 'todo_write') {
    const plan = nativePlanDocument(operation);
    if (plan.parsed) return operation.planDiff || nativePlanProgress(plan);
  }
  if (operation.role === 'tool') return nativeOneLinePreview(nativeToolDetail(operation, workspaceRoot));
  if (operation.role === 'reasoning') {
    return nativeOneLinePreview(nativeReasoningPreview(operation.reasoning || operation.text, false));
  }
  return nativeOneLinePreview(operation.text || operation.label || '');
}
export function nativeProcessGroupPreview(group: NativeMessage, workspaceRoot: string = ''): string {
  const tools = group.children.filter((operation: NativeMessage): boolean =>
    operation.role === 'tool');
  const counts = nativeToolGroupSummary(tools);
  if (counts.label) return counts.label;
  const labels: string[] = [];
  group.children.forEach((operation: NativeMessage): void => {
    const label = nativeOperationLead(operation);
    if (label && !labels.includes(label)) labels.push(label);
  });
  if (!labels.length) return '';
  return nativeOneLinePreview(labels.slice(0, 3).join('、') +
    (group.children.length > 3 ? '等' + group.children.length + '项' : ''));
}
export function nativeProcessTitle(group: NativeMessage, showDetail: boolean = true,
  workspaceRoot: string = ''): string {
  const lead = nativeProcessLead(group);
  const preview = showDetail ? nativeProcessPreview(group, workspaceRoot) : '';
  return lead + (preview ? ' · ' + preview : '');
}

export function nativeTranscript(records: NativeMessage[], running: boolean,
  streamTools: NativeMessage[] = [], reasoning: string = '', text: string = '',
  workspaceRoot: string = '', streamParts: NativeStreamPart[] = [],
  pacedToolTexts: Map<string, string> | null = null,
  pacedPartTexts: Map<number, string> | null = null): NativeMessage[] {
  const calls: Map<string, NativeMessage> = new Map<string, NativeMessage>();
  const ordered: NativeMessage[] = [];
  const ends: Map<string, NativeMessage> = new Map<string, NativeMessage>();
  const closedSteps: Set<string> = new Set<string>();
  const authoritativeByCall: Map<string, string> = new Map<string, string>();
  let turnKey = 'legacy:0';
  // The live process strip reveals paced text; durable records keep their own text.
  const pacedTool = (tool: NativeMessage): NativeMessage => {
    const value = copy(tool);
    if (pacedToolTexts && value.callId) {
      const paced = pacedToolTexts.get(value.callId);
      if (paced !== undefined) value.text = paced;
    }
    return value;
  };
  for (const input of records) {
    const row = copy(input);
    if (row.turn >= 0) turnKey = 'turn:' + row.turn;
    else if (row.role === 'user') turnKey = 'legacy:' + row.seq;
    row.turnKey = turnKey;
    if (row.role === 'detail') {
      if (row.eventType === 'deliverables/presented' && row.callId) {
        authoritativeByCall.set(row.callId, row.authoritativeRaw || row.detail || row.metaRaw);
      }
      continue;
    }
    if (row.role === 'user' && row.sourceKind && !['user', 'client', 'steer'].includes(row.sourceKind)) continue;
    if (row.role === 'turn') {
      if (row.eventType !== 'turn/start') ends.set(turnKey, row);
      ordered.push(row); continue;
    }
    if (row.role === 'boundary') { closedSteps.add(turnKey + ':' + row.step); continue; }
    if (row.role === 'tool') {
      const id = row.callId || row.id;
      let tool = calls.get(id);
      if (!tool) {
        tool = row; tool.id = 'call:' + id; tool.children = []; tool.args = ''; tool.output = '';
        calls.set(id, tool); ordered.push(tool);
      }
      if (row.toolName) tool.toolName = row.toolName;
      if (row.parentCallId) tool.parentCallId = row.parentCallId;
      if (row.rootCallId) tool.rootCallId = row.rootCallId;
      const incomingStart = row.phase === 'start' || row.phase === 'preparing';
      const alreadySettled = tool.phase === 'result';
      tool.metaRaw = mergedStructuredMeta(tool.metaRaw, row.metaRaw);
      if (row.authoritativeRaw) tool.authoritativeRaw = row.authoritativeRaw;
      if (incomingStart) {
        if (!alreadySettled) {
          tool.output = '';
          tool.failed = false;
          tool.status = row.phase === 'preparing' ? 'preparing' : 'running';
          tool.phase = row.phase;
          tool.time = row.time;
        }
        tool.args = row.text;
      } else {
        tool.output = row.text; tool.failed = row.failed; tool.status = row.failed ? 'error' : 'success'; tool.phase = 'result'; tool.error = row.error;
        tool.blocks = row.blocks; tool.images = row.images;
        tool.contentRaw = row.contentRaw; tool.errorRaw = row.errorRaw;
        tool.eventType = row.eventType;
      }
      continue;
    }
    if (row.role === 'assistant' && input.segments?.length) {
      input.segments.forEach((segment: NativeAssistantSegment, index: number): void => {
        if (!segment.text.trim() && !segment.images.length) return;
        const part = copy(row); part.id = row.id + ':part:' + index; part.text = segment.kind === 'reasoning' ? '' : segment.text;
        part.reasoning = segment.kind === 'reasoning' ? segment.text : ''; part.role = segment.kind === 'reasoning' ? 'reasoning' : 'assistant';
        part.blocks = segment.kind === 'reasoning' ? [] : segment.blocks; part.images = segment.images;
        ordered.push(part);
      });
      continue;
    }
    if (row.role === 'assistant' && row.reasoning.trim()) {
      const thought = copy(row); thought.id = 'reason:' + row.id; thought.role = 'reasoning'; thought.text = ''; thought.blocks = []; thought.images = [];
      ordered.push(thought); row.reasoning = '';
    }
    if (row.text.trim() || row.images.length) ordered.push(row);
  }
  let liveReasoningIndex = 0;
  const representedTools: Set<string> = new Set<string>();
  if (streamParts.length) {
    for (let partIndex = 0; partIndex < streamParts.length; partIndex++) {
      const part = streamParts[partIndex];
      if (part.kind === 'reasoning' && part.text.trim()) {
        const paced = pacedPartTexts ? pacedPartTexts.get(partIndex) : undefined;
        const thought = new NativeMessage();
        thought.id = liveReasoningIndex === 0 ? 'live-reasoning' : 'live-reasoning:' + liveReasoningIndex;
        thought.role = 'reasoning'; thought.reasoning = paced !== undefined ? paced : part.text;
        thought.turnKey = turnKey;
        ordered.push(thought);
        liveReasoningIndex++;
        continue;
      }
      if (part.kind !== 'tool' || !part.callId || representedTools.has(part.callId) ||
        calls.has(part.callId)) continue;
      const preparing = streamTools.find((item: NativeMessage): boolean => item.callId === part.callId);
      representedTools.add(part.callId);
      if (!preparing) continue;
      const tool = pacedTool(preparing); tool.args = tool.text; tool.status = 'preparing'; tool.turnKey = turnKey;
      tool.id = 'call:' + tool.callId; calls.set(tool.callId, tool); ordered.push(tool);
    }
    for (const preparing of streamTools) {
      if (calls.has(preparing.callId) || representedTools.has(preparing.callId)) continue;
      const tool = pacedTool(preparing); tool.args = tool.text; tool.status = 'preparing'; tool.turnKey = turnKey;
      tool.id = 'call:' + tool.callId; calls.set(tool.callId, tool); ordered.push(tool);
    }
    if (reasoning.trim() && liveReasoningIndex === 0) {
      const thought = new NativeMessage();
      thought.id = 'live-reasoning'; thought.role = 'reasoning'; thought.reasoning = reasoning; thought.turnKey = turnKey;
      ordered.push(thought);
    }
  } else {
    for (const preparing of streamTools) {
      if (calls.has(preparing.callId)) continue;
      const tool = pacedTool(preparing); tool.args = tool.text; tool.status = 'preparing'; tool.turnKey = turnKey;
      tool.id = 'call:' + tool.callId; calls.set(tool.callId, tool); ordered.push(tool);
    }
    if (reasoning.trim()) {
      const thought = new NativeMessage(); thought.id = 'live-reasoning'; thought.role = 'reasoning'; thought.reasoning = reasoning; thought.turnKey = turnKey;
      ordered.push(thought);
    }
  }
  authoritativeByCall.forEach((raw: string, callId: string): void => {
    const tool = calls.get(callId);
    if (tool && tool.toolName === 'present') tool.authoritativeRaw = raw;
  });
  if (text.trim()) {
    const reply = new NativeMessage(); reply.id = 'live-assistant'; reply.role = 'assistant';
    reply.text = text; reply.turnKey = turnKey; reply.runningTurn = running;
    ordered.push(reply);
  }
  let previousPlan = new NativePlanDocument();
  for (const planned of ordered) {
    if (planned.role !== 'tool' || planned.toolName !== 'todo_write') continue;
    const currentPlan = nativePlanDocument(planned);
    if (!currentPlan.parsed) continue;
    planned.planDiff = nativePlanDiff(currentPlan, previousPlan);
    previousPlan = currentPlan;
  }
  for (const tool of calls.values()) {
    if (tool.status === 'running' && (ends.has(tool.turnKey) || closedSteps.has(tool.turnKey + ':' + tool.step))) tool.status = 'interrupted';
    if (tool.parentCallId) {
      const parent = calls.get(tool.parentCallId) || calls.get(tool.rootCallId);
      let cursor = parent;
      const ancestors: Set<string> = new Set<string>();
      while (cursor && cursor !== tool && !ancestors.has(cursor.id)) {
        ancestors.add(cursor.id); cursor = calls.get(cursor.parentCallId);
      }
      if (parent && !cursor) parent.children.push(tool);
      else { tool.parentCallId = ''; tool.rootCallId = ''; }
    }
  }
  const rows: NativeMessage[] = [];
  let processGroup: NativeMessage | null = null;
  const flushProcess = (closed: boolean): void => {
    if (!processGroup) return;
    const group: NativeMessage = processGroup;
    group.closed = closed;
    group.label = '工作过程';
    group.detail = nativeProcessGroupPreview(group, workspaceRoot);
    group.children.forEach((operation: NativeMessage, index: number): void => {
      operation.renderKey = group.id + ':' + operation.seq + ':' + index;
      operation.label = nativeOperationLead(operation);
      operation.detail = nativeOperationPreview(operation, workspaceRoot);
    });
    rows.push(group);
    processGroup = null;
  };
  for (const row of ordered) {
    if (row.role === 'tool' && row.parentCallId &&
      (calls.has(row.parentCallId) || calls.has(row.rootCallId))) continue;
    if (row.role === 'background-notice') {
      flushProcess(ends.has(row.turnKey));
      rows.push(row);
      continue;
    }
    if (row.role === 'tool' || row.role === 'reasoning' || row.role === 'notice') {
      if (processGroup && processGroup.turnKey !== row.turnKey) {
        flushProcess(ends.has(processGroup.turnKey));
      }
      if (!processGroup) {
        processGroup = new NativeMessage();
        processGroup.id = 'process:' + row.id;
        processGroup.role = 'process';
        processGroup.turnKey = row.turnKey;
        processGroup.groupedProcess = true;
      }
      processGroup.children.push(row);
      continue;
    }
    flushProcess(ends.has(row.turnKey));
    if (row.role !== 'turn' || row.eventType !== 'turn/start') rows.push(row);
  }
  if (processGroup) {
    const group: NativeMessage = processGroup;
    flushProcess(ends.has(group.turnKey));
  }
  const finalAssistant: Map<string, NativeMessage> = new Map<string, NativeMessage>();
  for (const row of rows) {
    if (row.role === 'assistant' &&
      (row.text.trim().length > 0 || row.blocks.some((block) => block.text.trim().length > 0))) {
      finalAssistant.set(row.turnKey, row);
    }
  }
  ends.forEach((end: NativeMessage, key: string): void => {
    if (end.outcome === 'completed') {
      const final = finalAssistant.get(key);
      end.footerOutcome = 'completed';
      end.footerCopyText = final ? (final.text ||
        final.blocks.map((block) => block.text).join('\n')) : '';
      end.footerCopyMessageId = final?.id || '';
    } else {
      end.footerOutcome = end.outcome || (end.failed ? 'failed' : '');
    }
  });
  const result: NativeMessage[] = [];
  for (const row of rows) {
    if (row.role === 'turn') row.role = 'turn-footer';
    result.push(row);
  }
  return result;
}

/** Presentation policy is independent from event pairing and does not mutate durable records. */
export function nativePresentTranscript(rows: NativeMessage[], preferences: NativeChatPreferences,
  manual: Map<string, boolean>, collapseThrough: number = -1,
  workspaceRoot: string = ''): NativeMessage[] {
  const ended: Set<string> = new Set<string>();
  const lastReply: Map<string, number> = new Map<string, number>();
  const endSeq: Map<string, number> = new Map<string, number>();
  const turnsWithProcess: Set<string> = new Set<string>();
  let exchange = '';
  for (const row of rows) {
    if (row.role === 'turn-footer') { ended.add(row.turnKey); endSeq.set(row.turnKey, row.seq); }
    if (row.role === 'assistant') lastReply.set(row.turnKey, row.seq);
    if (row.role === 'process') turnsWithProcess.add(row.turnKey);
    if (row.role === 'user' && row.sourceKind !== 'steer') exchange = row.turnKey;
  }
  const exchangeIndex = rows.findIndex((row: NativeMessage) => row.turnKey === exchange);
  const deferred: Set<string> = new Set<string>();
  if (preferences.collapseTiming === 'next-input') {
    rows.forEach((row: NativeMessage, index: number): void => {
      if (index >= Math.max(0, exchangeIndex) && (endSeq.get(row.turnKey) || 0) > collapseThrough) deferred.add(row.turnKey);
    });
  }
  const open = (key: string): boolean => preferences.mode === 'verbose' || (manual.has(key) ? manual.get(key) === true : deferred.has(key));
  let currentProcessId = '';
  rows.forEach((row: NativeMessage): void => {
    if (row.role === 'process' && !ended.has(row.turnKey)) currentProcessId = row.id;
  });
  return rows.filter((row: NativeMessage): boolean => {
    if (row.role === 'turn-control') return false;
    if (row.role === 'process') {
      row.runningTurn = !ended.has(row.turnKey) || deferred.has(row.turnKey);
      row.currentTurn = row.id === currentProcessId;
      row.flat = preferences.mode === 'verbose' || (preferences.mode === 'detailed' && row.runningTurn);
      row.preview = true;
      row.label = '工作过程';
      row.detail = nativeProcessGroupPreview(row, workspaceRoot);
      row.children.forEach((operation: NativeMessage): void => {
        operation.label = nativeOperationLead(operation);
        operation.detail = nativeOperationPreview(operation, workspaceRoot);
      });
      return true;
    }
    if (row.role === 'assistant' && preferences.foldedReplies === 'final' &&
      turnsWithProcess.has(row.turnKey) &&
      row.seq !== lastReply.get(row.turnKey)) return open(row.turnKey);
    return true;
  });
}

export function nativeReasoningPreview(text: string, running: boolean): string {
  // `running` remains part of the public contract for callers, but every
  // preview now shares the same newline-flattening and width policy.
  return nativeOneLinePreview(text.replace(/\*\*/g, ''), 160);
}
