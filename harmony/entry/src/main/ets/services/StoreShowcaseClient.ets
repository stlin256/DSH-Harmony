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
  NativeMessage,
  NativeSession,
  NativeSessionCacheRecord,
  NativeSessionList,
  NativeSessionModel,
  NativeTextBlock,
  NativeWorkspaceItem,
  NativeWorkspaceSnapshot
} from './NativeSessionModel';
import { NativeUiFixture } from './NativeUiFixture';
import { http } from '@kit.NetworkKit';

const SHOWCASE_SESSION = 'showcase-release';
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
  if (state === 'live-change') return showcaseLiveChangeMessages();
  if (state === 'streaming') return showcaseStreamingMessages();
  if (state === 'empty') return [];
  if (state === 'long-history') return showcaseLongHistoryMessages();
  if (state === 'attachments') return showcaseLiveChangeMessages();
  return showcaseMessages();
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

function showcaseSessions(state: string = 'completed'): NativeSession[] {
  const firstTitle = state === 'live-change' ? '底部 Dock 运行态' :
    state === 'streaming' ? '流式输出与标题更新' :
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
  return definitions.map((row: string[]): NativeSession => {
    const value = new NativeSession();
    value.id = row[0];
    value.title = row[1];
    value.cwd = row[2];
    value.blank = row[3] === 'true';
    value.running = (state === 'live-change' || state === 'attachments' ||
      state === 'streaming' || state === 'empty') &&
      row[0] === SHOWCASE_SESSION;
    value.updatedAt = 1761900000000 - definitions.findIndex((item: string[]) => item[0] === row[0]) * 60000;
    return value;
  });
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

function showcaseFrame(state: string = 'completed'): NativeFrame {
  const frame = new NativeFrame();
  frame.type = 'snapshot';
  frame.messages = showcaseMessagesFor(state);
  frame.cursor = state === 'long-history' ? 80 :
    state === 'live-change' || state === 'attachments' ? 4 :
    state === 'streaming' ? 2 : state === 'empty' ? 0 : 14;
  frame.beforeSeq = 0;
  frame.hasMore = false;
  frame.running = state === 'live-change' || state === 'attachments' ||
    state === 'streaming' || state === 'empty';
  frame.waiting = false;
  frame.text = state === 'streaming' ?
    '正在输出完整的流式回答，内容会按显示帧更新而不会阻塞底部工具栏。' : '';
  frame.reasoning = state === 'streaming' ?
    '先检查传输状态，再确认工作过程与底部 Dock 的布局。' : '';
  return frame;
}

/**
 * In-memory Host used only when EntryAbility receives `storeShowcase=true`.
 * The normal product never selects this client and never loads these fixtures.
 */
export class StoreShowcaseClient extends NativeHarnessClient {
  private paused: boolean = false;
  private fixtureState: string;

  constructor(state: string = 'completed') {
    super('https://showcase.invalid');
    this.fixtureState = NativeUiFixture.state(state);
    const model = new NativeSessionModel();
    const record = new NativeSessionCacheRecord();
    record.version = 1;
    record.messages = showcaseMessagesFor(this.fixtureState);
    record.cursor = this.fixtureState === 'long-history' ? 80 :
      this.fixtureState === 'live-change' || this.fixtureState === 'attachments' ? 4 :
      this.fixtureState === 'streaming' ? 2 : this.fixtureState === 'empty' ? 0 : 14;
    record.hasMore = false;
    record.running = this.fixtureState === 'live-change' || this.fixtureState === 'attachments' ||
      this.fixtureState === 'streaming' || this.fixtureState === 'empty';
    record.waiting = false;
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
    value.pluginVersion = '0.3.6';
    return value;
  }

  async sessions(): Promise<NativeSessionList> {
    const value = new NativeSessionList();
    value.protocol = 2;
    value.items = showcaseSessions(this.fixtureState);
    return value;
  }

  sessionCwd(id: string): string {
    return id === 'showcase-passkey' ? 'Passkey Gateway' : 'DSH Harmony';
  }

  async workspaces(): Promise<NativeWorkspaceSnapshot> {
    return showcaseWorkspaces();
  }

  async page(_id: string, _before: number, _throughSeq: number = -1): Promise<NativeFrame> {
    return showcaseFrame(this.fixtureState);
  }

  async follow(id: string, receive: (frame: NativeFrame) => void, _ended: (reason: string) => void): Promise<void> {
    if (id !== SHOWCASE_SESSION || this.paused) return;
    receive(showcaseFrame(this.fixtureState));
  }

  pause(): void {
    this.paused = true;
    setTimeout((): void => {
      this.paused = false;
    }, 0);
  }

  async operation(body: string): Promise<string> {
    let value: Record<string, Object> = {};
    try {
      value = JSON.parse(body) as Record<string, Object>;
    } catch (_) {
    }
    const operation = value.operation;
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
      return `{
        "values": {
          "modelSelection": {
            "next": {
              "provider": "deepseek-official",
              "model": "deepseek-v4-pro",
              "reasoningEffort": "max"
            }
          }
        }
      }`;
    }
    if (operation === 'capabilities') {
      return '{"copyMarkdown":true,"downloadLog":false}';
    }
    return '{}';
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

  async prompt(_id: string, _text: string, _mode: string = 'queue',
    _attachments: NativeAttachmentDraft[] = []): Promise<string> {
    return 'showcase-request';
  }

  async cancel(_id: string): Promise<void> {
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
