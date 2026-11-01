import {
  GatewayState,
  NativeDirectoryEntry,
  NativeDirectoryListing,
  NativeFileBytes,
  NativeFilePage,
  NativeFileStat,
  NativeHarnessClient,
  NativeAttachmentDraft
} from './NativeHarnessClient';
import {
  NativeFrame,
  NativeInteractionRequest,
  NativeLocalized,
  NativeMessage,
  NativeOption,
  NativeQuestion,
  NativeQueueItem,
  NativeSession,
  NativeSessionCacheRecord,
  NativeSessionList,
  NativeSessionModel,
  NativeTextBlock,
  NativeWorkspaceItem,
  NativeWorkspaceSnapshot
} from './NativeSessionModel';
import {
  NativePlanProjection,
  NativeSessionAddress,
  NativeSubagentEntry,
  NativeSubagentIdentity,
  NativeSubagentProjectionValues
} from './NativeModeSubagent';
import {
  NativeShowcaseAttachment,
  NativeShowcaseInteraction,
  nativeShowcaseQueueItem
} from './NativeShowcaseInteraction';
import { NativeUiFixture } from './NativeUiFixture';
import { http } from '@kit.NetworkKit';

const SHOWCASE_SESSION = 'showcase-release';
const SHOWCASE_CHILD_CONTINUABLE = 'showcase-child-continuable';
const SHOWCASE_CHILD_ONE_SHOT = 'showcase-child-one-shot';
const SHOWCASE_CHILD_UNKNOWN = 'showcase-child-unknown';
const SHOWCASE_CHILD_EXTERNAL = 'showcase-child-external';
const SHOWCASE_README = `# DSH Harmony

DeepSeek Harness 的鸿蒙原生客户端。

- 会话与工作区保持同步
- Markdown、代码和文件预览
- 分级通知与桌面卡片
- 亮色、暗色与跟随系统
`;

class ShowcaseFileDiff {
  path: string = '';
  oldText: string = '';
  newText: string = '';
}

class ShowcaseDiffPayload {
  diffs: ShowcaseFileDiff[] = [];
}

class ShowcaseTodo {
  content: string = '';
  status: string = 'pending';
}

class ShowcaseTodoPayload {
  todos: ShowcaseTodo[] = [];
}

class ShowcaseSubagentCatalogRow {
  id: string = '';
  createdAt: number = 0;
  mode: string = 'unknown';
  label: string = '';
}

class ShowcaseModelSelection {
  provider: string = 'deepseek-official';
  model: string = 'deepseek-v4-pro';
  reasoningEffort: string = 'max';
}

class ShowcaseModelSelectionProjection {
  next: ShowcaseModelSelection = new ShowcaseModelSelection();
}

class ShowcaseProjectionEnvelope {
  kind: string = 'sequenced';
  asOfSeq: number = 30;
  values: Record<string, Object> = {};
}

function showcaseTodo(content: string, status: string): ShowcaseTodo {
  const value = new ShowcaseTodo();
  value.content = content;
  value.status = status;
  return value;
}

function showcasePlan(items: ShowcaseTodo[]): string {
  const value = new ShowcaseTodoPayload();
  value.todos = items;
  return JSON.stringify(value);
}

function message(id: string, role: string, seq: number, turn: number, step: number, text: string): NativeMessage {
  const value = new NativeMessage();
  value.id = id;
  value.role = role;
  value.seq = seq;
  value.turn = turn;
  value.turnKey = 'turn:' + turn;
  value.step = step;
  value.time = 1761900000 + seq;
  value.text = text;
  return value;
}

function toolMessage(id: string, callId: string, name: string, args: string, output: string,
  seq: number, turn: number, step: number, result: boolean = false): NativeMessage {
  const value = message(id, 'tool', seq, turn, step, '');
  value.callId = callId;
  value.toolName = name;
  value.phase = result ? 'result' : 'start';
  value.status = result ? 'success' : 'running';
  value.args = args;
  value.output = output;
  value.text = result ? output : args;
  return value;
}

function textBlock(kind: string, text: string): NativeTextBlock {
  const value = new NativeTextBlock();
  value.kind = kind;
  value.text = text;
  return value;
}

function showcaseMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('user-release', 'user', 1, 1, 1,
    '帮我检查这个版本是否达到应用商店上架条件，并整理还需要完成的发布事项。'));

  const reasoning = message('reason-release', 'reasoning', 2, 1, 2,
    '我会先核对产品变体、签名和隐私入口，再检查商店素材与发布说明。');
  reasoning.reasoning = reasoning.text;
  reasoning.text = '';
  rows.push(reasoning);

  rows.push(toolMessage('plan-start', 'release-plan', 'todo_write',
    showcasePlan([
      showcaseTodo('核对 Release 变体', 'pending'),
      showcaseTodo('构建商店版本', 'pending'),
      showcaseTodo('整理商店素材', 'pending')
    ]), '', 3, 1, 2));
  rows.push(toolMessage('plan-result', 'release-plan', 'todo_write',
    '', '', 4, 1, 2, true));

  rows.push(toolMessage('read-build-profile-start', 'read-build-profile', 'read',
    '{"path":"harmony/build-profile.json5"}', '', 5, 1, 2));
  rows.push(toolMessage('read-build-profile-result', 'read-build-profile', 'read',
    '', '已读取 1 个文件：harmony/build-profile.json5', 6, 1, 2, true));
  rows.push(toolMessage('run-build-check-start', 'run-build-check', 'exec_command',
    '{"command":"devecocli build --product store --build-mode release"}', '',
    7, 1, 2));
  rows.push(toolMessage('run-build-check-result', 'run-build-check', 'exec_command',
    '', 'BUILD SUCCESSFUL\nstore: release variant ready', 8, 1, 2, true));

  const completedDiff = new ShowcaseDiffPayload();
  const completedDock = new ShowcaseFileDiff();
  completedDock.path = 'harmony/entry/src/main/ets/components/NativeBottomConversationDock.ets';
  completedDock.oldText = 'height(\'100%\')';
  completedDock.newText = 'height(measuredHeight)\n// natural dock height\n// transcript owns resize\n// anchored bottom';
  completedDiff.diffs.push(completedDock);
  const completedWorkspace = new ShowcaseFileDiff();
  completedWorkspace.path = 'harmony/entry/src/main/ets/components/NativeWorkspace.ets';
  completedWorkspace.oldText = 'renderTranscript();\nrunning = model.running;';
  completedWorkspace.newText = 'running = model.running;\nrenderTranscript();\n' +
    'const live = running || waiting;\n// hide settled controls\n// keep one activity owner';
  completedDiff.diffs.push(completedWorkspace);
  const completedFixture = new ShowcaseFileDiff();
  completedFixture.path = 'harmony/entry/src/main/ets/services/NativeUiFixture.ets';
  completedFixture.oldText = '';
  completedFixture.newText = 'export class NativeUiFixture {\n' +
    '  static screen(value: Object): string { return \'conversation\'; }\n' +
    '  static state(value: Object): string { return \'completed\'; }\n' +
    '  static theme(value: Object): string { return \'system\'; }\n}\n';
  completedDiff.diffs.push(completedFixture);
  const completedDocs = new ShowcaseFileDiff();
  completedDocs.path = 'docs/testing/2026-11-01-device-ui-mock-e2e.md';
  completedDocs.oldText = '';
  completedDocs.newText = '# Device UI Mock and Bottom Dock E2E\n\n' +
    'Fixture screenshots and ArkUI bounds are captured through HDC.\n\n' +
    'No private host, account or transcript content is used.\n';
  completedDiff.diffs.push(completedDocs);
  rows.push(toolMessage('edit-release-start', 'release-files-edit', 'edit',
    JSON.stringify(completedDiff), '', 9, 1, 2));
  rows.push(toolMessage('edit-release-result', 'release-files-edit', 'edit',
    '', '', 10, 1, 2, true));

  rows.push(toolMessage('plan-refresh-start', 'release-plan-refresh', 'todo_write',
    showcasePlan([
      showcaseTodo('核对 Release 变体', 'completed'),
      showcaseTodo('构建商店版本', 'completed'),
      showcaseTodo('整理商店素材', 'pending'),
      showcaseTodo('检查隐私与账户入口', 'in_progress')
    ]), '', 11, 1, 2));
  rows.push(toolMessage('plan-refresh-result', 'release-plan-refresh', 'todo_write',
    '', '', 12, 1, 2, true));

  const assistant = message('assistant-release', 'assistant', 13, 1, 3, '');
  assistant.text = '发布检查完成。当前商店版本已满足构建与功能隔离要求。';
  assistant.blocks = [
    textBlock('heading', '发布检查完成'),
    textBlock('text', '当前商店版本已经满足代码构建与功能隔离要求。'),
    textBlock('text',
      '• 商店变体：已完成\n• 推送能力隔离：已完成\n• 多语言界面：已完成\n• 隐私与账户入口：已完成'),
    textBlock('quote', '上传 HAP 后还需要补充商店截图、隐私政策、内容分级和备案信息。'),
    textBlock('text', '下一步\n1. 上传 Release HAP\n2. 选择 3–10 张 16:9 商店图\n3. 完成审核联系人与自测说明')
  ];
  rows.push(assistant);

  const end = message('turn-release-end', 'turn', 14, 1, 3, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  return rows;
}

function showcaseDockMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('dock-user', 'user', 1, 1, 1,
    '请检查底部工具栏、消息发送和队列状态。'));
  const assistant = message('dock-assistant', 'assistant', 2, 1, 2,
    '底部工具栏布局稳定，可以继续测试发送与排队。');
  rows.push(assistant);
  const end = message('dock-turn-end', 'turn', 3, 1, 2, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  end.label = '已完成';
  rows.push(end);
  return rows;
}

function showcaseLiveChangeMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('user-live-change', 'user', 1, 7, 1,
    '检查底部 Dock 在任务运行时的布局，并修复遮挡问题。'));
  const reasoning = message('reason-live-change', 'reasoning', 2, 7, 2,
    '先核对自然高度与安全区，再验证实时文件变更控件。');
  reasoning.reasoning = reasoning.text;
  reasoning.text = '';
  rows.push(reasoning);
  const fileDiff = new ShowcaseFileDiff();
  fileDiff.path = 'harmony/entry/src/main/ets/components/NativeBottomConversationDock.ets';
  fileDiff.oldText = 'Stack({ alignContent: Alignment.Bottom }) {';
  fileDiff.newText = 'Stack({ alignContent: Alignment.Bottom }) {\n' +
    '  // Keep one natural-height owner for the complete bottom stack.\n' +
    '  // The transcript absorbs live-control and attachment height changes.\n' +
    '  // Composer actions remain inside the measured safe area.\n' +
    '  // The bottom dock never uses a fixed or negative vertical offset.';
  const payload = new ShowcaseDiffPayload();
  payload.diffs.push(fileDiff);
  rows.push(toolMessage('edit-live-change-start', 'dock-layout-edit', 'edit',
    JSON.stringify(payload), '', 3, 7, 2));
  rows.push(toolMessage('edit-live-change-result', 'dock-layout-edit', 'edit',
    '', '', 4, 7, 2, true));
  return rows;
}

function showcaseStreamingMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('user-streaming', 'user', 1, 8, 1,
    '请检查流式输出、标题更新和工作过程的显示。'));
  rows.push(toolMessage('read-streaming', 'stream-read', 'read',
    '{"path":"harmony/entry/src/main/ets/components/NativeWorkspace.ets"}',
    '已读取 1 个文件：NativeWorkspace.ets', 2, 8, 2, true));
  return rows;
}

function showcaseLongHistoryMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  for (let index = 0; index < 40; index++) {
    const seq = index * 2 + 1;
    rows.push(message('history-user-' + index, 'user', seq,
      Math.floor(index / 2) + 1, 1,
      '检查第 ' + (index + 1) + ' 组历史记录是否能够连续滚动和预取。'));
    rows.push(message('history-assistant-' + index, 'assistant', seq + 1,
      Math.floor(index / 2) + 1, 2,
      '第 ' + (index + 1) + ' 组记录已加载，内容保持稳定。'));
  }
  return rows;
}

function showcaseMessagesFor(state: string): NativeMessage[] {
  if (state === 'dock-send-idle' || state === 'dock-send-error' ||
      state === 'dock-material-quiet' || state === 'interaction-approval' ||
      state === 'interaction-question') return showcaseDockMessages();
  if (state === 'dock-queue-pending') return showcaseStreamingMessages();
  if (state === 'dock-queue-authoritative' || state === 'dock-queue-many' ||
      state === 'dock-material-elevated') return showcaseLiveChangeMessages();
  if (state === 'live-change') return showcaseLiveChangeMessages();
  if (state === 'streaming') return showcaseStreamingMessages();
  if (state === 'empty') return [];
  if (state === 'long-history') return showcaseLongHistoryMessages();
  if (state === 'attachments') return showcaseLiveChangeMessages();
  return showcaseMessages();
}

function showcaseQueue(state: string): NativeQueueItem[] {
  const showcaseFile = new NativeShowcaseAttachment();
  showcaseFile.id = 'showcase-queue-file-a';
  showcaseFile.kind = 'file';
  showcaseFile.name = 'NativeBottomConversationDock.ets';
  showcaseFile.mediaType = 'text/plain';
  showcaseFile.bytes = 2048;
  showcaseFile.receiptId = 'showcase-queue-receipt-a';
  if (state === 'dock-queue-authoritative') {
    return [nativeShowcaseQueueItem('showcase-seeded-authoritative',
      '检查权威队列行是否保持紧凑。', [showcaseFile])];
  }
  if (state === 'dock-queue-many') {
    return [
      nativeShowcaseQueueItem('showcase-seeded-1', '第一条排队消息。', []),
      nativeShowcaseQueueItem('showcase-seeded-2', '第二条排队消息。', [showcaseFile]),
      nativeShowcaseQueueItem('showcase-seeded-3', '第三条排队消息。', []),
      nativeShowcaseQueueItem('showcase-seeded-4', '第四条排队消息。', [])
    ];
  }
  if (state === 'dock-material-elevated') {
    return [
      nativeShowcaseQueueItem('showcase-material-1', '检查 Dock 背景材质。', []),
      nativeShowcaseQueueItem('showcase-material-2', '检查渐变与安全区。', [showcaseFile])
    ];
  }
  return [];
}

function showcaseInteractionFrame(state: string): NativeFrame | null {
  if (state !== 'interaction-approval' && state !== 'interaction-question') return null;
  const frame = new NativeFrame();
  frame.type = 'interaction';
  frame.connectionId = SHOWCASE_SESSION;
  frame.callId = 'showcase-' + state;
  frame.eventId = 'showcase-' + state + '-request';
  if (state === 'interaction-approval') {
    frame.interaction = 'approval/request';
    frame.remainingMs = 30000;
    frame.request = new NativeInteractionRequest();
    frame.request.toolName = 'workspace/edit';
    frame.request.reason = '需要写入一次已确认的界面修复。';
    const localized = new NativeLocalized();
    localized.zh = '需要写入一次已确认的界面修复。';
    localized.en = 'Allow one confirmed UI repair.';
    frame.request.displayReason = localized;
    return frame;
  }

  frame.interaction = 'user-questions/request';
  frame.remainingMs = -1;
  frame.request = new NativeInteractionRequest();
  const question = new NativeQuestion();
  question.id = 'showcase-question-choice';
  question.header = '界面偏好';
  question.question = '哪一种底部 Dock 的反馈更清晰？';
  question.detail = '选择后将沿用相同的紧凑布局与动画节奏。';
  question.multiSelect = false;
  ['渐变毛玻璃', '不透明回退'].forEach((name: string): void => {
    const option = new NativeOption();
    option.label = name;
    option.description = name === '渐变毛玻璃' ? '保留背景层次' : '优先可读性';
    question.options.push(option);
  });
  frame.request.questions = [question];
  return frame;
}

function showcaseAttachments(): NativeAttachmentDraft[] {
  const rows: NativeAttachmentDraft[] = [];
  ['NativeWorkspace.ets', 'NativeBottomConversationDock.ets'].forEach((name: string, index: number): void => {
    const value = new NativeAttachmentDraft();
    value.id = 'showcase-attachment-' + index;
    value.kind = 'file';
    value.name = name;
    value.mediaType = 'text/plain';
    value.status = 'ready';
    value.receiptId = 'showcase-receipt-' + index;
    value.bytes = 1024;
    rows.push(value);
  });
  return rows;
}

function isSubagentFixtureState(state: string): boolean {
  return state === 'plan-subagent' || state === 'plan-off-error' ||
    state === 'subagent-continuable' || state === 'subagent-one-shot' ||
    state === 'subagent-unknown' || state === 'subagent-parent-offline';
}

function isPlanFixtureState(state: string): boolean {
  return state === 'plan-subagent' || state === 'plan-off-error';
}

function showcaseSubagentCatalog(): ShowcaseSubagentCatalogRow[] {
  const rows: ShowcaseSubagentCatalogRow[] = [];
  const definitions: string[][] = [
    [SHOWCASE_CHILD_CONTINUABLE, 'continuable', '可继续检查'],
    [SHOWCASE_CHILD_ONE_SHOT, 'one-shot', '一次性检查'],
    [SHOWCASE_CHILD_UNKNOWN, 'unknown', '未知模式记录'],
    [SHOWCASE_CHILD_EXTERNAL, 'external', '外部任务']
  ];
  definitions.forEach((definition: string[], index: number): void => {
    const row = new ShowcaseSubagentCatalogRow();
    row.id = definition[0];
    row.createdAt = 1761900000000 + index;
    row.mode = definition[1];
    row.label = definition[2];
    rows.push(row);
  });
  return rows;
}

function showcaseNativeSubagentCatalog(state: string): NativeSubagentEntry[] {
  return showcaseSubagentCatalog().map((row: ShowcaseSubagentCatalogRow): NativeSubagentEntry => {
    const entry = new NativeSubagentEntry();
    entry.id = row.id;
    entry.createdAt = row.createdAt;
    entry.mode = row.mode;
    entry.label = row.label;
    entry.running = row.id === SHOWCASE_CHILD_CONTINUABLE && state === 'subagent-continuable';
    return entry;
  });
}

function showcaseChildIdentity(id: string): NativeSubagentIdentity {
  const identity = new NativeSubagentIdentity();
  identity.mode = id === SHOWCASE_CHILD_ONE_SHOT ? 'one-shot' :
    id === SHOWCASE_CHILD_UNKNOWN ? 'unknown' : 'continuable';
  identity.label = id === SHOWCASE_CHILD_ONE_SHOT ? '一次性检查' :
    id === SHOWCASE_CHILD_UNKNOWN ? '未知模式记录' : '可继续检查';
  identity.seq = 20;
  return identity;
}

function showcaseChildMessages(id: string): NativeMessage[] {
  const identity = showcaseChildIdentity(id);
  const rows: NativeMessage[] = [];
  rows.push(message('child-user-' + id, 'user', 1, 1, 1,
    '请检查 ' + identity.label + ' 的原生呈现。'));
  const assistant = message('child-assistant-' + id, 'assistant', 2, 1, 2,
    identity.mode === 'continuable' ? '检查完成，可以继续发送消息。' :
      '此记录保持只读，不提供发送入口。');
  rows.push(assistant);
  const end = message('child-end-' + id, 'turn', 3, 1, 2, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  return rows;
}

function showcasePlanProjection(planRemoved: boolean): NativePlanProjection {
  const plan = new NativePlanProjection();
  plan.active = !planRemoved;
  plan.pending = false;
  return plan;
}

function showcaseProjectionJson(state: string, sessionId: string, planRemoved: boolean): string {
  const values: Record<string, Object> = {};
  if (sessionId === SHOWCASE_CHILD_CONTINUABLE || sessionId === SHOWCASE_CHILD_ONE_SHOT ||
      sessionId === SHOWCASE_CHILD_UNKNOWN) {
    values.subagentKnown = true;
    values.subagent = showcaseChildIdentity(sessionId);
    values.subagentCatalog = [];
  } else {
    values.modelSelection = new ShowcaseModelSelectionProjection();
    if (isPlanFixtureState(state)) {
      values.plan = showcasePlanProjection(planRemoved);
    }
    if (isSubagentFixtureState(state)) {
      values.subagentCatalog = showcaseSubagentCatalog();
    }
  }
  const envelope = new ShowcaseProjectionEnvelope();
  envelope.values = values;
  return JSON.stringify(envelope);
}

function showcaseSessions(state: string = 'completed', planRemoved: boolean = false): NativeSession[] {
  const firstTitle = state === 'live-change' ? '底部 Dock 运行态' :
    state === 'streaming' ? '流式输出与标题更新' :
    state === 'dock-send-idle' || state === 'dock-material-quiet' ? 'Dock 空闲与发送' :
    state === 'dock-send-error' ? '发送失败与重试' :
    state === 'dock-queue-pending' ? '发送中与队列确认' :
    state === 'dock-queue-authoritative' ? '权威排队消息' :
    state === 'dock-queue-many' ? '多行排队消息' :
    state === 'dock-material-elevated' ? '渐变材质与实时变更' :
    state === 'interaction-approval' ? '审批卡样式检查' :
    state === 'interaction-question' ? '问题卡样式检查' :
    state === 'plan-subagent' ? '计划与子智能体' :
    state === 'plan-off-error' ? '计划退出失败' :
    state === 'subagent-continuable' ? '可继续子会话' :
    state === 'subagent-one-shot' ? '一次性子会话' :
    state === 'subagent-unknown' ? '未知模式子会话' :
    state === 'subagent-parent-offline' ? '父会话不可用' :
    state === 'empty' ? '空运行态' :
    state === 'long-history' ? '长会话与连续预取' :
    state === 'attachments' ? '附件与实时变更 Dock' :
    '发布准备与商店检查';
  const definitions: string[][] = [
    [SHOWCASE_SESSION, firstTitle, 'workspace-mobile', 'false'],
    ['showcase-files', '工作区文件预览与下载', 'workspace-mobile', 'false'],
    ['showcase-passkey', 'Passkey 登录与远程连接', 'workspace-gateway', 'false'],
    ['showcase-notify', '分级通知与桌面卡片', 'workspace-mobile', 'false'],
    ['showcase-settings', '外观与动效偏好', 'workspace-mobile', 'false'],
    ['showcase-mobile', '手机端交互适配', 'workspace-mobile', 'false']
  ];
  const sessions = definitions.map((row: string[]): NativeSession => {
    const value = new NativeSession();
    value.id = row[0];
    value.title = row[1];
    value.cwd = row[2];
    value.blank = row[3] === 'true';
    value.running = (state === 'live-change' || state === 'attachments' ||
      state === 'streaming' || state === 'empty' || state === 'dock-queue-pending' ||
      state === 'dock-queue-authoritative' || state === 'dock-queue-many' ||
      state === 'dock-material-elevated' || state === 'interaction-approval' ||
      state === 'interaction-question') &&
      row[0] === SHOWCASE_SESSION;
    value.agentAvailable = row[0] === SHOWCASE_SESSION ?
      state !== 'subagent-parent-offline' : undefined;
    value.updatedAt = 1761900000000 - definitions.findIndex((item: string[]) => item[0] === row[0]) * 60000;
    if (row[0] === SHOWCASE_SESSION &&
        (isPlanFixtureState(state) || isSubagentFixtureState(state))) {
      value.projections = new NativeSubagentProjectionValues();
      if (isPlanFixtureState(state)) value.projections.plan = showcasePlanProjection(planRemoved);
      if (isSubagentFixtureState(state)) {
        value.projections.subagentCatalog = showcaseNativeSubagentCatalog(state);
      }
    }
    return value;
  });
  if (isSubagentFixtureState(state)) {
    [SHOWCASE_CHILD_CONTINUABLE, SHOWCASE_CHILD_ONE_SHOT, SHOWCASE_CHILD_UNKNOWN]
      .forEach((id: string, index: number): void => {
        const child = new NativeSession();
        child.id = id;
        child.title = showcaseChildIdentity(id).label;
        child.cwd = 'DSH Harmony';
        child.origin = 'subagent';
        child.parentSessionId = SHOWCASE_SESSION;
        child.running = id === SHOWCASE_CHILD_CONTINUABLE &&
          state === 'subagent-continuable';
        child.agentAvailable = true;
        child.updatedAt = 1761900000000 - (index + 2) * 1000;
        const projections = new NativeSubagentProjectionValues();
        projections.subagentKnown = true;
        projections.subagent = showcaseChildIdentity(id);
        child.projections = projections;
        sessions.push(child);
      });
  }
  return sessions;
}

function showcaseWorkspaces(): NativeWorkspaceSnapshot {
  const value = new NativeWorkspaceSnapshot();
  value.available = true;
  const mobile = new NativeWorkspaceItem();
  mobile.workspaceId = 'workspace-mobile';
  mobile.path = 'DSH Harmony';
  mobile.title = 'DSH Harmony 移动端';
  mobile.sessionIds = ['showcase-release', 'showcase-files', 'showcase-notify', 'showcase-settings', 'showcase-mobile'];
  const gateway = new NativeWorkspaceItem();
  gateway.workspaceId = 'workspace-gateway';
  gateway.path = 'Passkey Gateway';
  gateway.title = 'Passkey Gateway';
  gateway.sessionIds = ['showcase-passkey'];
  value.items = [mobile, gateway];
  value.pinnedSessionIds = ['showcase-release'];
  return value;
}

/**
 * In-memory Host used only when EntryAbility receives `storeShowcase=true`.
 * The normal product never selects this client and never loads these fixtures.
 */
export class StoreShowcaseClient extends NativeHarnessClient {
  private paused: boolean = false;
  private fixtureState: string;
  private interaction: NativeShowcaseInteraction = new NativeShowcaseInteraction([]);
  private receiver: (frame: NativeFrame) => void = (_frame: NativeFrame): void => {};
  private receiverReady: boolean = false;
  private promptSerial: number = 0;
  private timers: number[] = [];
  private childInteractions: Map<string, NativeShowcaseInteraction> =
    new Map<string, NativeShowcaseInteraction>();
  private planRemoved: boolean = false;

  constructor(state: string = 'completed') {
    super('https://showcase.invalid');
    this.fixtureState = NativeUiFixture.state(state);
    const seedMessages = showcaseMessagesFor(this.fixtureState);
    const seedRunning = this.fixtureState === 'live-change' ||
      this.fixtureState === 'attachments' || this.fixtureState === 'streaming' ||
      this.fixtureState === 'empty' || this.fixtureState === 'dock-queue-pending' ||
      this.fixtureState === 'dock-queue-authoritative' ||
      this.fixtureState === 'dock-queue-many' ||
      this.fixtureState === 'dock-material-elevated' ||
      this.fixtureState === 'interaction-approval' ||
      this.fixtureState === 'interaction-question';
    let seedCursor = 0;
    seedMessages.forEach((row: NativeMessage): void => {
      if (Number.isSafeInteger(row.seq) && row.seq > seedCursor) seedCursor = row.seq;
    });
    const seedQueue = showcaseQueue(this.fixtureState);
    this.interaction = new NativeShowcaseInteraction(seedMessages, seedRunning, seedCursor, seedQueue);
    if (isSubagentFixtureState(this.fixtureState)) {
      [SHOWCASE_CHILD_CONTINUABLE, SHOWCASE_CHILD_ONE_SHOT, SHOWCASE_CHILD_UNKNOWN]
        .forEach((id: string): void => {
          const childRunning = id === SHOWCASE_CHILD_CONTINUABLE &&
            this.fixtureState === 'subagent-continuable';
          const childMessages = showcaseChildMessages(id);
          this.childInteractions.set(id,
            new NativeShowcaseInteraction(childMessages, childRunning, 3, []));
        });
    }
    this.interaction.waiting = this.fixtureState === 'interaction-approval' ||
      this.fixtureState === 'interaction-question';
    const initial = this.interaction.snapshot();
    const model = new NativeSessionModel();
    const record = new NativeSessionCacheRecord();
    record.version = 1;
    record.messages = initial.messages;
    record.cursor = initial.cursor;
    record.hasMore = false;
    record.running = initial.running;
    record.waiting = false;
    record.queue = initial.queue;
    record.streamText = this.fixtureState === 'streaming' ?
      '正在输出完整的流式回答，内容会按显示帧更新而不会阻塞底部工具栏。' : '';
    record.streamReasoning = this.fixtureState === 'streaming' ?
      '先检查传输状态，再确认工作过程与底部 Dock 的布局。' : '';
    model.restore(record);
    this.models.set(SHOWCASE_SESSION, model);
    this.selectedId = SHOWCASE_SESSION;
    if (this.fixtureState === 'attachments') {
      this.attachments.set(SHOWCASE_SESSION, showcaseAttachments());
    }
  }

  static initialState(): string {
    const notifyCompleted = AppStorage.get<string>('showcaseNotifyCompleted') || 'quiet';
    const notifyFailed = AppStorage.get<string>('showcaseNotifyFailed') || 'standard';
    const notifyApproval = AppStorage.get<string>('showcaseNotifyApproval') || 'standard';
    const notifyConnection = AppStorage.get<string>('showcaseNotifyConnection') || 'off';
    return JSON.stringify({
      themeMode: 'system',
      reduceMotion: AppStorage.get<boolean>('showcaseReduceMotion') === true,
      reduceTransparency: AppStorage.get<boolean>('showcaseReduceTransparency') === true,
      widgetDetails: AppStorage.get<boolean>('showcaseWidgetDetails') !== false,
      supportsPush: false,
      pushEnabled: false,
      notificationsEnabled: true,
      notificationPermissionKnown: true,
      backgroundMonitor: AppStorage.get<boolean>('showcaseBackgroundMonitor') === true,
      notifyCompleted,
      notifyFailed,
      notifyApproval,
      notifyConnection
    });
  }

  cacheKey(): string {
    return 'store-showcase-v1';
  }

  async prepareCacheKey(): Promise<void> {
  }

  async state(): Promise<GatewayState> {
    const value = new GatewayState();
    value.mode = 'host';
    value.authenticated = true;
    value.pluginVersion = '0.3.7';
    return value;
  }

  async sessions(): Promise<NativeSessionList> {
    const value = new NativeSessionList();
    value.protocol = 2;
    value.items = showcaseSessions(this.fixtureState, this.planRemoved);
    return value;
  }

  sessionCwd(id: string): string {
    return id === 'showcase-passkey' ? 'Passkey Gateway' : 'DSH Harmony';
  }

  async workspaces(): Promise<NativeWorkspaceSnapshot> {
    return showcaseWorkspaces();
  }

  async page(id: string, _before: number, _throughSeq: number = -1): Promise<NativeFrame> {
    const child = this.childInteractions.get(id);
    return child ? child.snapshot() : this.interaction.snapshot();
  }

  async follow(id: string, receive: (frame: NativeFrame) => void, _ended: (reason: string) => void): Promise<void> {
    const child = this.childInteractions.get(id);
    if ((id !== SHOWCASE_SESSION && !child) || this.paused) return;
    this.receiver = receive;
    this.receiverReady = true;
    receive(child ? child.snapshot() : this.interaction.snapshot());
    if (id === SHOWCASE_SESSION) {
      const interaction = showcaseInteractionFrame(this.fixtureState);
      if (interaction) this.emit([interaction], 90);
    }
  }

  pause(): void {
    this.paused = true;
    this.receiverReady = false;
    this.timers.forEach((timer: number): void => { clearTimeout(timer); });
    this.timers = [];
    setTimeout((): void => {
      this.paused = false;
    }, 0);
  }

  private pluginInventoryJson(): string {
    if (this.fixtureState === 'plugins-empty') {
      return '{"available":true,"bundles":[],"plugins":[]}';
    }
    return `{
      "available": true,
      "bundles": [
        {
          "name": "@dsh-harmony/plugin",
          "official": true,
          "availability": "profile",
          "installed": true,
          "enabled": true,
          "removable": false,
          "updatable": true,
          "optional": false,
          "version": "0.4.7",
          "title": "DSH Harmony",
          "localizedDescription": "原生通知、文件预览与移动端能力",
          "source": "Profile",
          "installSpec": "",
          "rows": [
            {
              "rowId": "native-bridge",
              "moduleName": "@dsh-harmony/plugin/native",
              "entryId": "native-bridge",
              "title": "原生桥接",
              "description": "会话、预览与通知"
            },
            {
              "rowId": "push-delivery",
              "moduleName": "@dsh-harmony/plugin/push",
              "entryId": "push-delivery",
              "title": "通知投递",
              "description": "按级别送入系统通知中心"
            }
          ]
        },
        {
          "name": "@dsh/workspace-tools",
          "official": false,
          "availability": "installation",
          "installed": true,
          "enabled": false,
          "removable": true,
          "updatable": true,
          "optional": true,
          "version": "1.8.2",
          "title": "Workspace Tools",
          "localizedDescription": "补充工作区搜索与批量检查",
          "source": "https://registry.example.invalid/workspace-tools",
          "installSpec": "@dsh/workspace-tools",
          "rows": [
            {
              "rowId": "workspace-search",
              "moduleName": "@dsh/workspace-tools/search",
              "entryId": "workspace-search",
              "title": "工作区搜索",
              "description": "索引项目文件"
            }
          ]
        },
        {
          "name": "@dsh/markdown-check",
          "official": false,
          "availability": "installation",
          "installed": false,
          "enabled": false,
          "removable": false,
          "updatable": false,
          "optional": true,
          "version": "2.1.0",
          "title": "Markdown Check",
          "localizedDescription": "检查文档链接与代码块",
          "installSpec": "@dsh/markdown-check",
          "rows": []
        }
      ],
      "plugins": [
        {
          "entryId": "native-bridge",
          "moduleName": "@dsh-harmony/plugin/native",
          "title": "原生桥接",
          "enabled": true,
          "phase": "active"
        },
        {
          "entryId": "push-delivery",
          "moduleName": "@dsh-harmony/plugin/push",
          "title": "通知投递",
          "enabled": true,
          "phase": "active"
        }
      ]
    }`;
  }

  private automationCatalogJson(): string {
    if (this.fixtureState === 'automation-empty') {
      return '{"available":true,"items":[]}';
    }
    return `{
      "available": true,
      "items": [
        {
          "id": "automation-review",
          "kind": "daily",
          "status": "active",
          "title": "每日检查构建状态",
          "prompt": "检查当前工作区的最新构建结果，汇总失败原因并给出下一步。",
          "scheduledAt": "2026-11-02T01:00:00.000Z",
          "timeZone": "Asia/Shanghai",
          "time": "09:00:00",
          "targetKind": "new_once",
          "targetCwd": "DSH Harmony",
          "createdAt": "2026-10-26T02:10:00.000Z",
          "updatedAt": "2026-11-01T02:10:00.000Z",
          "lastDeliveryAt": "2026-11-01T01:00:00.000Z"
        },
        {
          "id": "automation-docs",
          "kind": "weekly",
          "status": "active",
          "title": "整理本周文档变更",
          "prompt": "汇总本周规格、设计与测试文档的变更，列出需要复核的条目。",
          "scheduledAt": "2026-11-03T02:30:00.000Z",
          "timeZone": "Asia/Shanghai",
          "time": "10:30:00",
          "weekdays": [2],
          "targetKind": "session",
          "targetSessionId": "showcase-release",
          "updatedAt": "2026-10-31T08:00:00.000Z"
        },
        {
          "id": "automation-paused",
          "kind": "every",
          "status": "paused",
          "title": "依赖更新巡检",
          "prompt": "检查过期的直接依赖，并说明兼容性风险。",
          "scheduledAt": "2026-11-01T12:00:00.000Z",
          "everySeconds": 21600,
          "timeZone": "Asia/Shanghai",
          "targetKind": "new",
          "targetAgentPreset": "reviewer",
          "updatedAt": "2026-10-30T06:20:00.000Z"
        },
        {
          "id": "automation-ended",
          "kind": "at",
          "status": "ended",
          "title": "发布前检查",
          "prompt": "核对版本号、变更说明和签名配置。",
          "scheduledAt": "2026-10-30T01:00:00.000Z",
          "timeZone": "Asia/Shanghai",
          "targetKind": "session",
          "targetSessionId": "showcase-release",
          "updatedAt": "2026-10-30T01:02:00.000Z",
          "lastDeliveryAt": "2026-10-30T01:02:00.000Z"
        }
      ]
    }`;
  }

  private automationTaskJson(): string {
    return `{
      "id": "automation-review",
      "kind": "daily",
      "status": "active",
      "title": "每日检查构建状态",
      "prompt": "检查当前工作区的最新构建结果，汇总失败原因并给出下一步。",
      "scheduledAt": "2026-11-02T01:00:00.000Z",
      "timeZone": "Asia/Shanghai",
      "time": "09:00:00",
      "targetKind": "new_once",
      "targetCwd": "DSH Harmony",
      "createdAt": "2026-10-26T02:10:00.000Z",
      "updatedAt": "2026-11-01T02:10:00.000Z",
      "lastDeliveryAt": "2026-11-01T01:00:00.000Z"
    }`;
  }

  private automationHistoryJson(): string {
    return `{
      "available": true,
      "records": [
        {
          "scheduledAt": "2026-11-01T01:00:00.000Z",
          "deliveredAt": "2026-11-01T01:00:02.000Z",
          "messageId": "message-31",
          "targetSessionId": "showcase-release",
          "prompt": "检查当前工作区的最新构建结果，汇总失败原因并给出下一步。"
        },
        {
          "scheduledAt": "2026-10-31T01:00:00.000Z",
          "deliveredAt": "2026-10-31T01:00:01.000Z",
          "messageId": "message-18",
          "targetSessionId": "showcase-release",
          "prompt": "检查当前工作区的最新构建结果，汇总失败原因并给出下一步。"
        },
        {
          "scheduledAt": "2026-10-30T01:00:00.000Z",
          "deliveredAt": "2026-10-30T01:00:03.000Z",
          "messageId": "message-9",
          "targetSessionId": "showcase-release",
          "prompt": "检查当前工作区的最新构建结果，汇总失败原因并给出下一步。"
        }
      ],
      "earlierRecordsUnavailable": false,
      "earlierRecordsPruned": false
    }`;
  }

  async operation(body: string): Promise<string> {
    let value: Record<string, Object> = {};
    try {
      value = JSON.parse(body) as Record<string, Object>;
    } catch (_) {
    }
    const operation = value.operation;
    const sessionId = typeof value.sessionId === 'string' ? value.sessionId : SHOWCASE_SESSION;
    if (operation === 'answerQuestion') {
      const target = sessionId === SHOWCASE_SESSION ?
        this.interaction : this.childInteractions.get(sessionId);
      if (target) this.emit(target.cancel(), 24);
      return 'true';
    }
    if (operation === 'pluginsList') {
      if (this.fixtureState === 'plugins-error') throw new Error('插件服务暂不可用');
      return this.pluginInventoryJson();
    }
    if (operation === 'pluginSetEnabled' || operation === 'pluginSetRowEnabled') {
      return `{
        "changed": true, "application": "applied", "stage": "enable",
        "target": "DSH Harmony", "enabled": true, "pendingBuilds": []
      }`;
    }
    if (operation === 'pluginInspect') {
      return `{
        "status": "accepted", "kind": "registry", "name": "@dsh/markdown-check",
        "version": "2.1.0", "description": "检查文档链接与代码块",
        "bundle": true, "registry": "https://registry.example.invalid", "host": "registry.example.invalid"
      }`;
    }
    if (operation === 'pluginInstall') {
      if (this.fixtureState === 'plugins-install-failed') {
        return `{
          "changed": false, "application": "failed", "stage": "install",
          "target": "dsh-plugin-with-missing-build", "pendingBuilds": [],
          "errorCode": "unsupported-platform"
        }`;
      }
      return `{
        "changed": true, "application": "restart-required", "stage": "install",
        "target": "@dsh/markdown-check@2.1.0", "restartReason": "plugin", "pendingBuilds": []
      }`;
    }
    if (operation === 'pluginVersions') {
      return `{
        "status": "listed", "installed": "0.4.7", "registry": "https://registry.example.invalid",
        "omitted": 0,
        "versions": [
          { "version": "0.4.7", "tags": ["latest"], "prerelease": false, "deprecated": "", "bundle": true },
          { "version": "0.4.6", "tags": [], "prerelease": false, "deprecated": "", "bundle": true }
        ]
      }`;
    }
    if (operation === 'pluginUpdate' || operation === 'pluginRemove') {
      return `{
        "changed": true, "application": "restart-required", "stage": "install",
        "target": "DSH Harmony", "restartReason": "plugin", "pendingBuilds": []
      }`;
    }
    if (operation === 'automationList') return this.automationCatalogJson();
    if (operation === 'automationView' || operation === 'automationCreate' ||
      operation === 'automationRun' || operation === 'automationEdit') {
      return this.automationTaskJson();
    }
    if (operation === 'automationHistory') return this.automationHistoryJson();
    if (operation === 'automationDelete') return '{"deleted":true}';
    if (operation === 'settingsDescribe') {
      return `{
        "writable": true,
        "namespaces": [
          {
            "ns": "ui-chat",
            "revision": 1,
            "value": {
              "transcriptView": "detailed",
              "collapseTiming": "completion",
              "foldedReplies": "all"
            }
          },
          {
            "ns": "ui-conversation",
            "revision": 1,
            "value": { "busyEnter": "queue" }
          }
        ]
      }`;
    }
    if (operation === 'modelCatalog') {
      return `{
        "default": {
          "provider": "deepseek-official",
          "model": "deepseek-v4-pro",
          "reasoningEffort": "max"
        },
        "groups": [{
          "id": "deepseek-official",
          "name": "DeepSeek",
          "models": [{
            "id": "deepseek-v4-pro",
            "name": "DeepSeek-V4-Pro",
            "reasoning": {
              "defaultEffort": "max",
              "efforts": [
                { "id": "off", "name": "关闭", "description": "直接响应" },
                { "id": "high", "name": "高", "description": "深入推理" },
                { "id": "max", "name": "最高", "description": "复杂任务" }
              ]
            }
          }]
        }],
        "failures": []
      }`;
    }
    if (operation === 'projections') {
      return showcaseProjectionJson(this.fixtureState, sessionId, this.planRemoved);
    }
    if (operation === 'planOff') {
      if (this.fixtureState === 'plan-off-error') {
        throw new Error('Mock /plan off failed');
      }
      this.planRemoved = true;
      const plan = new NativePlanProjection();
      plan.active = false;
      plan.pending = false;
      const frame = new NativeFrame();
      frame.type = 'plan';
      frame.plan = plan;
      frame.projectionSeq = 31;
      this.emit([frame], 20);
      return '{"accepted":true}';
    }
    if (operation === 'capabilities') {
      return '{"copyMarkdown":true,"downloadLog":false}';
    }
    return '{}';
  }

  async answer(body: string): Promise<void> {
    let value: Record<string, Object> = {};
    try {
      value = JSON.parse(body) as Record<string, Object>;
    } catch (_) {
    }
    if (value.engage === true) return;
    const id = typeof value.connectionId === 'string' ? value.connectionId : SHOWCASE_SESSION;
    const target = id === SHOWCASE_SESSION ? this.interaction : this.childInteractions.get(id);
    if (target) this.emit(target.cancel(), 24);
  }

  async request(_path: string, _method: http.RequestMethod = http.RequestMethod.GET,
    _body: string = ''): Promise<string> {
    return JSON.stringify({
      available: true,
      running: 0,
      waiting: 0,
      completed: 4,
      failed: 0,
      tasks: []
    });
  }

  async listFiles(_id: string, path: string): Promise<NativeDirectoryListing> {
    const value = new NativeDirectoryListing();
    value.path = path;
    const entries: NativeDirectoryEntry[] = [];
    if (!path || path === '.') {
      ['docs', 'harmony', 'gateway'].forEach((name: string): void => {
        const entry = new NativeDirectoryEntry();
        entry.name = name;
        entry.type = 'directory';
        entries.push(entry);
      });
      ['README.md', 'package.json'].forEach((name: string): void => {
        const entry = new NativeDirectoryEntry();
        entry.name = name;
        entry.type = 'file';
        entry.size = name === 'README.md' ? SHOWCASE_README.length : 420;
        entries.push(entry);
      });
    } else if (path === 'docs') {
      ['assets', 'DEPLOYMENT.md', 'DESIGN.md'].forEach((name: string): void => {
        const entry = new NativeDirectoryEntry();
        entry.name = name;
        entry.type = name === 'assets' ? 'directory' : 'file';
        entries.push(entry);
      });
    }
    value.entries = entries;
    return value;
  }

  async findWorkspaceFile(_id: string, name: string): Promise<string> {
    return name === 'README.md' ? 'README.md' : '';
  }

  async statFile(id: string, path: string): Promise<NativeFileStat> {
    const value = new NativeFileStat();
    value.absolutePath = path;
    value.version = id + ':v1';
    value.bytes = path.endsWith('README.md') ? SHOWCASE_README.length : 420;
    return value;
  }

  async file(id: string, path: string, offset: number = 1, _limit: number = 240): Promise<NativeFilePage> {
    const value = new NativeFilePage();
    value.absolutePath = path;
    value.version = id + ':v1';
    value.text = path.endsWith('README.md') ? SHOWCASE_README : '{\n  "name": "dsh-harmony"\n}\n';
    value.lines = value.text.split('\n').length;
    value.offset = offset;
    value.eof = true;
    return value;
  }

  async readFileBytes(id: string, path: string, _baseFile: string = '',
    offset: number = 0, length: number = 262144, _expectedVersion: string = '',
    _expectedBytes: number = -1): Promise<NativeFileBytes> {
    const source = path.endsWith('README.md') ? SHOWCASE_README : '{\n  "name": "dsh-harmony"\n}\n';
    const bytes = StoreShowcaseClient.utf8(source);
    const value = new NativeFileBytes();
    value.protocol = 1;
    value.absolutePath = path;
    value.version = id + ':v1';
    value.bytes = bytes.length;
    value.offset = offset;
    value.eof = offset + length >= bytes.length;
    value.data = bytes.slice(offset, Math.min(bytes.length, offset + length));
    value.length = value.data.length;
    return value;
  }

  async create(_cwd: string = '', _agentPreset: string = '', _workspaceId: string = '',
    _reuseId: string = ''): Promise<string> {
    return SHOWCASE_SESSION;
  }

  async prompt(id: string, text: string, mode: string = 'queue',
    attachments: NativeAttachmentDraft[] = [], requestId: string = '',
    address: NativeSessionAddress | null = null): Promise<string> {
    const child = address?.kind === 'subagent';
    const target = child ? this.childInteractions.get(id) : this.interaction;
    if (!target || (!child && id !== SHOWCASE_SESSION)) {
      throw new Error('Showcase session unavailable');
    }
    if (child && attachments.length) {
      throw new Error('子智能体不支持此附件');
    }
    if (child) {
      const identity = this.childInteractions.has(id) ? showcaseChildIdentity(id) : null;
      if (!identity || identity.mode !== 'continuable') {
        throw new Error('此子智能体只读');
      }
    }
    if (this.fixtureState === 'dock-send-error') {
      throw new Error('Mock 发送失败，请重试');
    }
    const resolvedRequestId = requestId || 'showcase-request-' + (++this.promptSerial).toString();
    const mapped = attachments.map((item: NativeAttachmentDraft): NativeShowcaseAttachment => {
      const value = new NativeShowcaseAttachment();
      value.id = item.id;
      value.kind = item.kind;
      value.name = item.name;
      value.mediaType = item.mediaType;
      value.bytes = item.bytes;
      value.receiptId = item.receiptId;
      return value;
    });
    const plan = target.prompt(resolvedRequestId, text, mapped, mode);
    if (!plan.accepted) throw new Error('Mock prompt rejected an empty request');
    const acknowledgementDelay = plan.queued &&
      this.fixtureState === 'dock-queue-pending' ? 4200 : plan.queued ? 650 : 120;
    this.emit(plan.admissionFrames, acknowledgementDelay);
    if (plan.streamFrames.length) {
      this.emit(plan.streamFrames, acknowledgementDelay + 360);
      this.emit(plan.settleFrames, acknowledgementDelay + 820);
    }
    return resolvedRequestId;
  }

  async cancel(id: string, address: NativeSessionAddress | null = null): Promise<void> {
    const target = address?.kind === 'subagent' ? this.childInteractions.get(id) : this.interaction;
    if (target) this.emit(target.cancel(), 80);
  }

  private emit(frames: NativeFrame[], delay: number): void {
    if (!frames.length) return;
    const timer = setTimeout((): void => {
      this.timers = this.timers.filter((value: number): boolean => value !== timer);
      if (!this.receiverReady || this.paused) return;
      frames.forEach((frame: NativeFrame): void => { this.receiver(frame); });
    }, delay);
    this.timers.push(timer);
  }

  async exportSession(_id: string, _format: string, _receive: (part: ArrayBuffer) => void): Promise<void> {
  }

  private static utf8(value: string): Uint8Array {
    const result: number[] = [];
    for (let index: number = 0; index < value.length; index++) {
      let code: number = value.charCodeAt(index);
      if (code < 0x80) {
        result.push(code);
      } else if (code < 0x800) {
        result.push(0xC0 | (code >> 6), 0x80 | (code & 0x3F));
      } else if (code >= 0xD800 && code <= 0xDBFF && index + 1 < value.length) {
        const low: number = value.charCodeAt(++index);
        code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00);
        result.push(0xF0 | (code >> 18), 0x80 | ((code >> 12) & 0x3F),
          0x80 | ((code >> 6) & 0x3F), 0x80 | (code & 0x3F));
      } else {
        result.push(0xE0 | (code >> 12), 0x80 | ((code >> 6) & 0x3F), 0x80 | (code & 0x3F));
      }
    }
    return new Uint8Array(result);
  }
}
