import {
  GatewayState,
  NativeDirectoryEntry,
  NativeDirectoryListing,
  NativeFileBytes,
  NativeFilePage,
  NativeFileStat,
  NativeHarnessClient,
  NativeHttpError,
  NativeAttachmentDraft,
  NativeUploadResult
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
import { NativePermissionSelection } from './NativePermissions';
import {
  NativeAutomationCatalog,
  NativeAutomationDelivery,
  NativeAutomationHistory,
  NativeAutomationTask,
  NativePluginBundle,
  NativePluginChange,
  NativePluginEntry,
  NativePluginInventory,
  NativePluginRow,
  NativePluginVersion,
  NativePluginVersionList
} from './NativeAdminModels';
import { http } from '@kit.NetworkKit';
import { BuildInfo } from './BuildInfo';

const SHOWCASE_SESSION = 'showcase-release';
const SHOWCASE_CHILD_CONTINUABLE = 'showcase-child-continuable';
const SHOWCASE_CHILD_ONE_SHOT = 'showcase-child-one-shot';
const SHOWCASE_CHILD_UNKNOWN = 'showcase-child-unknown';
const SHOWCASE_CHILD_EXTERNAL = 'showcase-child-external';
const SHOWCASE_README = '# ' + BuildInfo.appName + `

DeepSeek Harness 的鸿蒙原生客户端。

## 产品定位

在手机上继续桌面端已经开始的开发工作。会话、工作区、计划与子智能体保持
同一套上下文，阅读、审批和文件检查都为触控重新整理，但不改变上游语义。

## 核心能力

- 原生会话流：流式输出、工作过程、计划与最终回答各自保持正确的出现顺序
- 工作区浏览：目录导航、源码预览、表格、图片、PDF、HTML 与配置文本
- 计划协作：悬浮任务计划、可继续子智能体与明确的父子会话层级
- 权限边界：只读、工作区写入、完全权限与单次审批保持可见且可回溯
- 桌面卡片：一眼查看运行状态、最近结果与需要处理的审批
- 通知分级：完成、失败、审批与连接变化可独立设置
- 外观系统：亮色、暗色与跟随系统，API 23 也有完整的功能与层级

## 开发

    构建默认变体
    构建社区版本
    构建商店版本
    构建移动体验变体

提交前依次运行类型检查、协议测试、界面覆盖率检查与真机 E2E。展示资源
必须由设备上的确定性界面状态生成，不使用真实账户、主机或会话内容。

## 设计原则

1. 信息优先：控件服务于阅读、比较与重复操作。
2. 原生触控：命中区、安全区、键盘与系统返回都遵循 HarmonyOS 习惯。
3. 克制动效：只表达层级、方向和状态变化，不制造装饰性循环。
4. 可回退：加载、离线、失败与权限不足都提供明确下一步。

## 隐私

客户端不内置第三方统计 SDK。远程连接信息保存在本机安全存储中，日志默认
隐藏凭据。导出诊断前会提示范围，并允许用户检查将要发送的内容。

## 许可证

源代码、第三方依赖与商店变体分别遵循仓库中的许可证和构建说明。
`;
const SHOWCASE_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
<!-- DSH_SOURCE_MARKER -->
<rect width="640" height="360" rx="24" fill="#151517"/>
<circle cx="116" cy="112" r="54" fill="#3964FE"/>
<path d="M204 88h264M204 132h196M204 176h228" stroke="#F6F7F9" stroke-width="16" stroke-linecap="round"/>
</svg>
`;
/**
 * HTML preview fixture. It deliberately contains an inline script so the device
 * capture proves scripts still run in the preview (the user requirement) while
 * the authored-URL allowlist keeps everything a script composes off the network.
 */
const SHOWCASE_HTML = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>DSH_HTML_MARKER</title>
<style>body{font-family:system-ui,sans-serif;margin:24px;line-height:1.6}
.card{border:1px solid #3964FE;border-radius:12px;padding:16px;margin-bottom:16px}
h1{font-size:22px;margin:0 0 8px}</style></head>
<body>
<div class="card"><h1>HTML 预览</h1>
<p>这段文字由本地 HTML 渲染，脚本照常执行。</p>
<p id="script-target">脚本尚未运行</p></div>
<div class="card"><p>作者声明的远程图片会加载；脚本拼出的地址一律被拦截。</p>
<img src="https://images.example.invalid/banner.png" alt="远程图片" width="240"></div>
<script>
document.getElementById('script-target').textContent = 'DSH_SCRIPT_RAN';
</script>
</body></html>
`;
const SHOWCASE_CONF = `; DSH_CONFIG_MARKER
[server]
host = 127.0.0.1
port = 4317
read_timeout = 30s
write_timeout = 30s
idle_timeout = 120s
max_connections = 24
request_body_limit = 16mb
trusted_proxy = false

[preview]
marker = DSH_CONFIG_MARKER
line_limit = 500
table_rows = 200
wrap_source = false
preserve_indentation = true
highlight_delimited_text = true
maximum_rendered_bytes = 4194304

[workspace]
root = DSH_HOME
follow_symlinks = false
read_binary_metadata = true
include_hidden_files = true
default_encoding = utf-8
fallback_encoding = gb18030
refresh_debounce_ms = 180

[transcript]
history_page_size = 40
prefetch_threshold = 12
keep_process_groups = true
collapse_completed_turns = true
stream_patch_interval_ms = 16
preserve_tool_order = true

[cache]
directory = DSH_HOME/cache
metadata_ttl_seconds = 300
transcript_ttl_seconds = 86400
workspace_ttl_seconds = 60
maximum_size_gib = 5
cleanup_batch_size = 32
retain_last_successful_preview = true

[notifications]
completed = quiet
failed = standard
approval = standard
connection = off
group_by_session = true
include_preview = false

[approval]
default_mode = workspace-write
show_scope = true
show_reason = true
single_action_label = allow-once
timeout_seconds = 30
record_decisions = true

[automation]
enabled = true
time_zone = Asia/Shanghai
history_limit = 50
merge_adjacent_results = true

[diagnostics]
level = info
redact_secrets = true
include_tool_output = false
export_manifest = true
log_directory = DSH_HOME/logs
`;
const SHOWCASE_CSV = `name,team,owner,updated_at,note,status
Alpha,Platform,Lin,2026-11-01,"first line
second line",DSH_TABLE_MARKER
Beta,Client,Chen,2026-11-01,"quoted, separator",ready
Gamma,Infra,Zhao,2026-10-31,"literal ""quote""",**literal value**
Delta,Quality,Wu,2026-10-31,,ready
Epsilon,Design,Sun,2026-10-30,compact layout,review
Zeta,Runtime,He,2026-10-30,stream patch,ready
Eta,Workspace,Xu,2026-10-29,file preview,ready
Theta,Notifications,Gu,2026-10-29,digest group,ready
Iota,Permissions,Ma,2026-10-28,single approval,review
Kappa,Automation,Zhu,2026-10-28,history retention,ready
Lambda,Cards,Hu,2026-10-27,quick summary,ready
Mu,Search,Guo,2026-10-27,first-paint cache,ready
Nu,Markdown,Lin,2026-10-26,tables and code,ready
Xi,Images,Chen,2026-10-26,thumbnail cache,ready
Omicron,Gateway,Zhao,2026-10-25,passkey session,ready
Pi,Release,Wu,2026-10-25,signature check,review
Rho,Docs,Sun,2026-10-24,deployment guide,ready
Sigma,Tests,He,2026-10-24,device evidence,ready
Tau,Plugins,Xu,2026-10-23,versioned update,ready
Upsilon,OpenSource,Gu,2026-10-23,license index,ready
short`;
const SHOWCASE_TSV = `name\tteam\towner\tupdated_at\tstatus
Alpha\tPlatform\tLin\t2026-11-01\tDSH_TSV_MARKER
Beta\tClient\tChen\t2026-11-01\tready
Gamma\tInfra\tZhao\t2026-10-31\tready
Delta\tQuality\tWu\t2026-10-31\treview
Epsilon\tDesign\tSun\t2026-10-30\tready
Zeta\tRuntime\tHe\t2026-10-30\tready
Eta\tWorkspace\tXu\t2026-10-29\tready
Theta\tNotifications\tGu\t2026-10-29\treview
Iota\tPermissions\tMa\t2026-10-28\tready
Kappa\tAutomation\tZhu\t2026-10-28\tready
Lambda\tCards\tHu\t2026-10-27\tready
Mu\tSearch\tGuo\t2026-10-27\tready
Nu\tMarkdown\tLin\t2026-10-26\tready
Xi\tImages\tChen\t2026-10-26\tready
Omicron\tGateway\tZhao\t2026-10-25\treview
`;
const SHOWCASE_MALFORMED_CSV = `name,note
"unterminated,value
`;
const SHOWCASE_BINARY = new Uint8Array([
  0x50, 0x4B, 0x03, 0x04, 0x00, 0x01, 0x02, 0x03, 0x00, 0x00, 0x00, 0x00
]);

function showcaseFileSource(path: string): string {
  if (path.endsWith('README.md')) return SHOWCASE_README;
  if (path.endsWith('preview.html')) return SHOWCASE_HTML;
  if (path.endsWith('diagram.svg')) return SHOWCASE_SVG;
  if (path.endsWith('app.conf')) return SHOWCASE_CONF;
  if (path.endsWith('users.csv')) return SHOWCASE_CSV;
  if (path.endsWith('report.tsv')) return SHOWCASE_TSV;
  if (path.endsWith('malformed.csv')) return SHOWCASE_MALFORMED_CSV;
  if (path.endsWith('.npmrc')) return 'registry=https://registry.example.invalid/\nstrict-ssl=true\n';
  if (path.endsWith('LICENSE')) {
    return 'Apache License\nVersion 2.0, January 2004\n\n' +
      'Copyright 2026 ' + BuildInfo.appName + ' contributors\n\n' +
      'Licensed under the Apache License, Version 2.0 (the "License");\n' +
      'you may not use this file except in compliance with the License.\n' +
      'You may obtain a copy of the License at\n\n' +
      'https://www.apache.org/licenses/LICENSE-2.0\n\n' +
      'Unless required by applicable law or agreed to in writing, software\n' +
      'distributed under the License is distributed on an "AS IS" BASIS,\n' +
      'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n';
  }
  if (path.endsWith('package.json')) {
    return '{\n' +
      '  "name": "dsh-harmony",\n' +
      '  "private": true,\n' +
      '  "version": "1.4.0",\n' +
      '  "scripts": {\n' +
      '    "test": "node --test",\n' +
      '    "qa": "node scripts/qa.mjs pr",\n' +
      '    "verify:ui": "node scripts/verify-ui-coverage.mjs"\n' +
      '  },\n' +
      '  "devDependencies": {\n' +
      '    "typescript": "5.7.2",\n' +
      '    "eslint": "9.16.0"\n' +
      '  }\n' +
      '}\n';
  }
  if (path.endsWith('BUILDING.md') || path.endsWith('DEPLOYMENT.md') ||
      path.endsWith('DESIGN.md')) {
    return '# ' + path.split('/').pop() + '\n\n' +
      'This project document records the release workflow, visual tokens and\n' +
      'device verification expectations used by the native application.\n\n' +
      '## Required checks\n\n' +
      '- Build the default, community, store and experience variants.\n' +
      '- Run protocol, model and layout tests before device capture.\n' +
      '- Verify every new state in the deterministic interface feature manifest.\n' +
      '- Capture clean device evidence without private account or host data.\n' +
      '- Review safe areas, keyboard movement and system Back behavior.\n\n' +
      '## Visual baseline\n\n' +
      'Compact information density, neutral surfaces, precise outlines and a\n' +
      'single DeepSeek blue accent. Motion communicates direction and state only.\n';
  }
  return '{\n  "name": "dsh-harmony",\n  "private": true\n}\n';
}

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

function showcaseHistory(prefix: string, turns: string[][]): NativeMessage[] {
  const rows: NativeMessage[] = [];
  turns.forEach((turn: string[], index: number): void => {
    const turnNumber = index + 1;
    const seq = index * 3 + 1;
    rows.push(message(prefix + '-history-user-' + turnNumber, 'user',
      seq, turnNumber, 1, turn[0]));
    rows.push(message(prefix + '-history-assistant-' + turnNumber, 'assistant',
      seq + 1, turnNumber, 2, turn[1]));
    const end = message(prefix + '-history-end-' + turnNumber, 'turn',
      seq + 2, turnNumber, 2, '');
    end.eventType = 'turn/end';
    end.outcome = 'completed';
    rows.push(end);
  });
  return rows;
}

function showcaseWithHistory(prefix: string, current: NativeMessage[],
  turns: string[][]): NativeMessage[] {
  const history = showcaseHistory(prefix, turns);
  current.forEach((row: NativeMessage): void => {
    row.turn += turns.length;
    row.turnKey = 'turn:' + row.turn;
  });
  const rows = history.concat(current);
  rows.forEach((row: NativeMessage, index: number): void => {
    row.seq = index + 1;
  });
  return rows;
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
  const completedPreferences = new ShowcaseFileDiff();
  completedPreferences.path = 'harmony/entry/src/main/ets/services/NativeUiPreferences.ets';
  completedPreferences.oldText = '';
  completedPreferences.newText = 'export class NativeUiPreferences {\n' +
    '  static screen(value: Object): string { return \'conversation\'; }\n' +
    '  static state(value: Object): string { return \'completed\'; }\n' +
    '  static theme(value: Object): string { return \'system\'; }\n}\n';
  completedDiff.diffs.push(completedPreferences);
  const completedDocs = new ShowcaseFileDiff();
  completedDocs.path = 'docs/testing/2026-11-01-device-ui-e2e.md';
  completedDocs.oldText = '';
  completedDocs.newText = '# Device UI and Bottom Dock E2E\n\n' +
    'Screenshots and ArkUI bounds are captured through HDC.\n\n' +
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

function showcaseMarketingPlanMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('marketing-plan-user', 'user', 1, 1, 1,
    '把设置页里的离线状态和同步状态整理成一套可复用的组件，并补上空数据回退。'));
  const reasoning = message('marketing-plan-reason', 'reasoning', 2, 1, 2,
    '先对齐状态入口和文案，再整理组件边界，最后检查离线时的保留信息。');
  reasoning.reasoning = reasoning.text;
  reasoning.text = '';
  rows.push(reasoning);
  rows.push(toolMessage('marketing-plan-start', 'marketing-plan-todo', 'todo_write',
    showcasePlan([
      showcaseTodo('梳理离线与同步状态入口', 'in_progress'),
      showcaseTodo('整理状态组件与文案', 'pending'),
      showcaseTodo('补齐空数据回退', 'pending')
    ]), '', 3, 1, 2));
  rows.push(toolMessage('marketing-plan-read-start', 'marketing-plan-read', 'read',
    '{"path":"harmony/entry/src/main/ets/services/NativeHostSettings.ets"}', '', 4, 1, 2));
  rows.push(toolMessage('marketing-plan-read-result', 'marketing-plan-read', 'read',
    '', '已读取 2 个文件：状态定义与设置投影', 5, 1, 2, true));
  const diff = new ShowcaseDiffPayload();
  const settingsDiff = new ShowcaseFileDiff();
  settingsDiff.path = 'harmony/entry/src/main/ets/components/NativeSettings.ets';
  settingsDiff.oldText = 'renderSyncState();';
  settingsDiff.newText = 'renderSyncState();\n// keep the last successful sync time\n// expose retry only when offline';
  diff.diffs.push(settingsDiff);
  const hostSettingsDiff = new ShowcaseFileDiff();
  hostSettingsDiff.path = 'harmony/entry/src/main/ets/services/NativeHostSettings.ets';
  hostSettingsDiff.oldText = 'syncState = loading;';
  hostSettingsDiff.newText = 'syncState = cached || loading;\n' +
    '// preserve the last successful timestamp';
  diff.diffs.push(hostSettingsDiff);
  const emptyStateDiff = new ShowcaseFileDiff();
  emptyStateDiff.path = 'harmony/entry/src/main/ets/components/NativeEmptyState.ets';
  emptyStateDiff.oldText = '';
  emptyStateDiff.newText = 'export class NativeEmptyState {\n' +
    '  static retryLabel = \'重新同步\';\n}\n';
  diff.diffs.push(emptyStateDiff);
  const offlineTestDiff = new ShowcaseFileDiff();
  offlineTestDiff.path = 'docs/testing/offline-sync-e2e.md';
  offlineTestDiff.oldText = '';
  offlineTestDiff.newText = '# Offline sync\n\n- cached timestamp remains visible\n' +
    '- empty data exposes one retry action\n';
  diff.diffs.push(offlineTestDiff);
  rows.push(toolMessage('marketing-plan-edit-start', 'marketing-plan-edit', 'edit',
    JSON.stringify(diff), '', 6, 1, 2));
  rows.push(toolMessage('marketing-plan-edit-result', 'marketing-plan-edit', 'edit',
    '', '', 7, 1, 2, true));
  const assistant = message('marketing-plan-assistant', 'assistant', 8, 1, 3, '');
  assistant.text = '状态设置已收敛。离线、同步中和已同步共用一套组件，' +
    '断网时保留最近一次成功时间，并给出可执行的重新同步入口。';
  assistant.blocks = [
    textBlock('heading', '状态设置已收敛'),
    textBlock('text', '离线、同步中和已同步共用一套状态组件；断网时保留最近一次成功同步时间。'),
    textBlock('quote', '空数据不再显示占位卡片，直接给出可执行的重新同步入口。')
  ];
  rows.push(assistant);
  const end = message('marketing-plan-end', 'turn', 9, 1, 3, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  return showcaseWithHistory('marketing-plan', rows, [
    [
      '先梳理设置页里离线、同步中和同步失败的状态入口，标出断网后仍需保留的信息。',
      '已整理出四种状态。断网后需要保留最近一次成功同步时间，失败入口要能直接重新同步。'
    ],
    [
      '失败时不要只弹一条提示，把恢复动作放进状态行，并补一个没有数据时的回退。',
      '恢复动作会固定在状态行右侧；空数据使用独立说明和重试入口，不再渲染空白占位卡。'
    ]
  ]);
}

function showcaseMarketingProcessMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('marketing-process-user', 'user', 1, 1, 1,
    '排查搜索结果切换时偶发闪白的问题，先把首帧缓存和空结果回退分开验证。'));
  const reasoning = message('marketing-process-reason', 'reasoning', 2, 1, 2,
    '从缓存命中、请求竞态和首帧布局三个方向检查，避免只看表面闪烁。');
  reasoning.reasoning = reasoning.text;
  reasoning.text = '';
  rows.push(reasoning);
  rows.push(toolMessage('marketing-process-read-start', 'marketing-process-read', 'read',
    '{"path":"harmony/entry/src/main/ets/components/SearchSurface.ets"}', '', 3, 1, 2));
  rows.push(toolMessage('marketing-process-read-result', 'marketing-process-read', 'read',
    '', '已读取 3 个文件：搜索视图、缓存与请求状态', 4, 1, 2, true));
  rows.push(toolMessage('marketing-process-command-start', 'marketing-process-command', 'exec_command',
    '{"command":"npm test -- search-cache"}', '', 5, 1, 2));
  rows.push(toolMessage('marketing-process-command-result', 'marketing-process-command', 'exec_command',
    '', 'PASS search-cache\n12 tests passed', 6, 1, 2, true));
  const diff = new ShowcaseDiffPayload();
  const searchDiff = new ShowcaseFileDiff();
  searchDiff.path = 'harmony/entry/src/main/ets/components/SearchSurface.ets';
  searchDiff.oldText = 'state = loading;';
  searchDiff.newText = 'state = cached || loading;\n// keep the previous result visible while refreshing\n// clear only after the new page settles';
  diff.diffs.push(searchDiff);
  const cacheDiff = new ShowcaseFileDiff();
  cacheDiff.path = 'harmony/entry/src/main/ets/services/SearchCache.ets';
  cacheDiff.oldText = 'if (empty) return;';
  cacheDiff.newText = 'if (empty) return fallback;\n// distinguish empty results from transient failures';
  diff.diffs.push(cacheDiff);
  const pagerDiff = new ShowcaseFileDiff();
  pagerDiff.path = 'harmony/entry/src/main/ets/services/SearchPager.ets';
  pagerDiff.oldText = 'commit(response);';
  pagerDiff.newText = 'if (response.revision < current) return;\ncommit(response);';
  diff.diffs.push(pagerDiff);
  const searchTestDiff = new ShowcaseFileDiff();
  searchTestDiff.path = 'tests/search-cache.test.ts';
  searchTestDiff.oldText = '';
  searchTestDiff.newText = 'test(\'keeps cached rows during refresh\', () => {\n' +
    '  expect(view.state).toBe(\'cached\');\n});\n';
  diff.diffs.push(searchTestDiff);
  rows.push(toolMessage('marketing-process-edit-start', 'marketing-process-edit', 'edit',
    JSON.stringify(diff), '', 7, 1, 2));
  rows.push(toolMessage('marketing-process-edit-result', 'marketing-process-edit', 'edit',
    '', '', 8, 1, 2, true));
  const assistant = message('marketing-process-assistant', 'assistant', 9, 1, 3, '');
  assistant.text = '闪白已定位。首帧缓存与请求完成之间存在状态空窗，刷新时沿用上一页结果；' +
    '空结果、失败和请求竞态分别收口，不再共用一个 loading 状态。';
  assistant.blocks = [
    textBlock('heading', '闪白已定位'),
    textBlock('text', '首帧缓存和请求完成之间存在状态空窗，刷新时沿用上一页结果即可消除闪白。'),
    textBlock('text', '• 缓存结果继续可见\n• 空结果使用独立回退\n• 请求竞态由最后一次响应收口')
  ];
  rows.push(assistant);
  const end = message('marketing-process-end', 'turn', 10, 1, 3, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  return showcaseWithHistory('marketing-process', rows, [
    [
      '先看搜索结果切换时的闪白录屏，判断是首帧布局、缓存还是请求竞态。',
      '闪白出现在旧结果已经清空、新结果还没有提交的空窗。字体和主题切换都排除了。'
    ],
    [
      '把缓存命中、真实空结果和请求失败拆开验证，别用一个 loading 状态覆盖所有情况。',
      '缓存命中继续显示上一页，真实空结果才进入空状态，失败保留原内容和重试入口。'
    ]
  ]);
}

function showcaseMarketingLineageMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('marketing-lineage-user', 'user', 1, 1, 1,
    '并行拆分搜索筛选体验的重构，分别检查状态、接口和回归用例。'));
  const reasoning = message('marketing-lineage-reason', 'reasoning', 2, 1, 2,
    '把筛选状态、接口约束和回归验证拆成三条互相独立的检查线。');
  reasoning.reasoning = reasoning.text;
  reasoning.text = '';
  rows.push(reasoning);
  rows.push(toolMessage('marketing-lineage-plan-start', 'marketing-lineage-plan', 'todo_write',
    showcasePlan([
      showcaseTodo('整理筛选状态与空结果', 'completed'),
      showcaseTodo('核对接口约束与旧数据', 'completed'),
      showcaseTodo('补齐回归与视觉检查', 'in_progress')
    ]), '', 3, 1, 2));
  rows.push(toolMessage('marketing-lineage-plan-result', 'marketing-lineage-plan', 'todo_write',
    '', '', 4, 1, 2, true));
  rows.push(toolMessage('marketing-lineage-read-start', 'marketing-lineage-read', 'read',
    '{"path":"harmony/entry/src/main/ets/components/FilterState.ets"}', '', 5, 1, 2));
  rows.push(toolMessage('marketing-lineage-read-result', 'marketing-lineage-read', 'read',
    '', '已读取 4 个文件：状态、请求、表单和回归清单', 6, 1, 2, true));
  const assistant = message('marketing-lineage-assistant', 'assistant', 7, 1, 3, '');
  assistant.text = '三条检查线已收敛。筛选状态、接口约束和回归验证分别完成，' +
    '剩余视觉检查可以直接回到对应子智能体继续确认。';
  assistant.blocks = [
    textBlock('heading', '三条检查线已收敛'),
    textBlock('text', '筛选状态与接口约束分开处理，回归检查继续保持可见，方便随时回到主会话继续确认。')
  ];
  rows.push(assistant);
  const end = message('marketing-lineage-end', 'turn', 8, 1, 3, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  return showcaseWithHistory('marketing-lineage', rows, [
    [
      '筛选重构先拆成状态、接口和回归三条线，互相不要阻塞。',
      '状态线负责筛选投影，接口线核对旧数据兼容，回归线覆盖空结果和快速切换。'
    ],
    [
      '每条线都保留可继续的上下文，视觉检查最后再汇总。',
      '三个子会话已经拆分完成，都会带同一份工作区约束和验收边界。'
    ]
  ]);
}

function showcaseMarketingDarkMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('marketing-dark-user', 'user', 1, 1, 1,
    '把通知中心的未读消息按任务分组，并保留一键回到原会话的入口。'));
  const reasoning = message('marketing-dark-reason', 'reasoning', 2, 1, 2,
    '先按任务归并通知，再用时间线保留最近一次状态变化。');
  reasoning.reasoning = reasoning.text;
  reasoning.text = '';
  rows.push(reasoning);
  rows.push(toolMessage('marketing-dark-plan-start', 'marketing-dark-plan', 'todo_write',
    showcasePlan([
      showcaseTodo('按任务聚合通知', 'completed'),
      showcaseTodo('保留时间与状态变化', 'completed'),
      showcaseTodo('验证回到原会话', 'in_progress')
    ]), '', 3, 1, 2));
  rows.push(toolMessage('marketing-dark-plan-result', 'marketing-dark-plan', 'todo_write',
    '', '', 4, 1, 2, true));
  rows.push(toolMessage('marketing-dark-read-start', 'marketing-dark-read', 'read',
    '{"path":"harmony/entry/src/main/ets/components/NativeNotificationCenter.ets"}', '', 5, 1, 2));
  rows.push(toolMessage('marketing-dark-read-result', 'marketing-dark-read', 'read',
    '', '已读取通知中心与任务状态投影', 6, 1, 2, true));
  const assistant = message('marketing-dark-assistant', 'assistant', 7, 1, 3, '');
  assistant.text = '通知分组已整理。同一任务的完成、失败和待确认提醒收拢到一组，' +
    '最近一次状态保留在顶部，点按即可回到对应会话。';
  assistant.blocks = [
    textBlock('heading', '通知分组已整理'),
    textBlock('text', '同一任务的完成、失败和待确认提醒收拢到一组，最近一次状态始终保留在顶部。'),
    textBlock('quote', '点击通知即可回到对应会话，不需要重新寻找上下文。')
  ];
  rows.push(assistant);
  const end = message('marketing-dark-end', 'turn', 8, 1, 3, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  return showcaseWithHistory('marketing-dark', rows, [
    [
      '通知列表现在按时间散着排，先按任务归并，再保留最近一次状态。',
      '会按会话聚合，完成、失败和审批提醒进入同一组，组标题展示最新结果。'
    ],
    [
      '点通知之后要直接回到原会话，还要保留当时的工作区上下文。',
      '通知携带会话和工作区标识，打开后恢复到对应轮次，并继续沿用原权限边界。'
    ]
  ]);
}

function showcaseMarketingDarkProcessMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('marketing-dark-process-user', 'user', 1, 1, 1,
    '定位图片缓存失效后重复请求的问题，确认离线回退不会影响已有图片。'));
  const reasoning = message('marketing-dark-process-reason', 'reasoning', 2, 1, 2,
    '先检查缓存键的失效条件，再核对离线回退和并发请求合并。');
  reasoning.reasoning = reasoning.text;
  reasoning.text = '';
  rows.push(reasoning);
  rows.push(toolMessage('marketing-dark-process-read-start', 'marketing-dark-process-read', 'read',
    '{"path":"harmony/entry/src/main/ets/services/ImageCache.ets"}', '', 3, 1, 2));
  rows.push(toolMessage('marketing-dark-process-read-result', 'marketing-dark-process-read', 'read',
    '', '已读取缓存键、请求合并与回退路径', 4, 1, 2, true));
  rows.push(toolMessage('marketing-dark-process-command-start', 'marketing-dark-process-command',
    'exec_command', '{"command":"npm test -- image-cache"}', '', 5, 1, 2));
  rows.push(toolMessage('marketing-dark-process-command-result', 'marketing-dark-process-command',
    'exec_command', '', 'PASS image-cache\n8 tests passed', 6, 1, 2, true));
  const diff = new ShowcaseDiffPayload();
  const cacheDiff = new ShowcaseFileDiff();
  cacheDiff.path = 'harmony/entry/src/main/ets/services/ImageCache.ets';
  cacheDiff.oldText = 'cache.delete(key);';
  cacheDiff.newText = 'cache.retainUnlessChanged(key);\n// merge concurrent requests\n// keep the last good image while offline';
  diff.diffs.push(cacheDiff);
  const requestDiff = new ShowcaseFileDiff();
  requestDiff.path = 'harmony/entry/src/main/ets/services/RequestMerge.ets';
  requestDiff.oldText = 'return fetch(key);';
  requestDiff.newText = 'return inflight.get(key) || fetchAndShare(key);';
  diff.diffs.push(requestDiff);
  const fallbackDiff = new ShowcaseFileDiff();
  fallbackDiff.path = 'harmony/entry/src/main/ets/components/NativeImageView.ets';
  fallbackDiff.oldText = 'image = null;';
  fallbackDiff.newText = 'image = cachedImage;\n// expose retry without clearing the frame';
  diff.diffs.push(fallbackDiff);
  const imageCacheTestDiff = new ShowcaseFileDiff();
  imageCacheTestDiff.path = 'tests/image-cache.test.ts';
  imageCacheTestDiff.oldText = '';
  imageCacheTestDiff.newText = 'test(\'offline keeps last image\', () => {\n' +
    '  expect(renderer.source).toBe(lastGoodImage);\n});\n';
  diff.diffs.push(imageCacheTestDiff);
  rows.push(toolMessage('marketing-dark-process-edit-start', 'marketing-dark-process-edit', 'edit',
    JSON.stringify(diff), '', 7, 1, 2));
  rows.push(toolMessage('marketing-dark-process-edit-result', 'marketing-dark-process-edit', 'edit',
    '', '', 8, 1, 2, true));
  const assistant = message('marketing-dark-process-assistant', 'assistant', 9, 1, 3, '');
  assistant.text = '重复请求已消失。缓存只在版本真正变化时失效，并发请求会合并，' +
    '离线时继续展示最近一张成功图片，并保留明确的恢复入口。';
  assistant.blocks = [
    textBlock('heading', '重复请求已消失'),
    textBlock('text', '缓存只在版本真正变化时失效，并发请求会合并，离线时继续展示最近一张成功图片。')
  ];
  rows.push(assistant);
  const end = message('marketing-dark-process-end', 'turn', 10, 1, 3, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  return showcaseWithHistory('marketing-dark-process', rows, [
    [
      '先定位图片缓存失效后的重复请求，看看是键变化还是并发没有合并。',
      '请求确实被重复发出，原因是版本刷新时先删缓存再等待并发请求，多个页面同时落入了同一空窗。'
    ],
    [
      '离线回退不要清掉已经显示的图片，弱网时也保留最后一次成功结果。',
      '缓存策略改为版本变化后原子替换，失败时沿用最近一张可用图片并标记可重试。'
    ]
  ]);
}

function showcaseMarketingSubagentMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('marketing-subagent-user', 'user', 1, 1, 1,
    '审查离线缓存的失效与回退路径，重点看弱网和版本切换。'));
  const reasoning = message('marketing-subagent-reason', 'reasoning', 2, 1, 2,
    '先检查版本键，再确认弱网下的失败回退和清理时机。');
  reasoning.reasoning = reasoning.text;
  reasoning.text = '';
  rows.push(reasoning);
  rows.push(toolMessage('marketing-subagent-read-start', 'marketing-subagent-read', 'read',
    '{"path":"harmony/entry/src/main/ets/services/OfflineCache.ets"}', '', 3, 1, 2));
  rows.push(toolMessage('marketing-subagent-read-result', 'marketing-subagent-read', 'read',
    '', '已读取版本键、失败回退和清理入口', 4, 1, 2, true));
  const assistant = message('marketing-subagent-assistant', 'assistant', 5, 1, 2,
    '检查完成。版本切换会清理旧键；弱网失败继续使用最近一次成功结果，并保留重试入口。');
  rows.push(assistant);
  const end = message('marketing-subagent-end', 'turn', 6, 1, 2, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  return showcaseWithHistory('marketing-subagent', rows, [
    [
      '先核对离线缓存的版本键和清理时机。',
      '版本键由工作区标识与内容版本共同组成，旧键会在新结果提交后清理，不会提前失效。'
    ],
    [
      '再看弱网失败时的回退，确认不会把最近一次成功结果清掉。',
      '失败路径保留最近成功结果，同时记录可重试状态；恢复网络后只合并必要请求。'
    ]
  ]);
}

function showcaseMarketingApprovalMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('marketing-approval-user', 'user', 1, 1, 1,
    '修正筛选栏在窄屏下的截断问题，只改布局样式并补一条回归检查。'));
  rows.push(message('marketing-approval-assistant', 'assistant', 2, 1, 2,
    '已完成定位，接下来需要写入一次组件样式并运行视觉回归。'));
  const end = message('marketing-approval-end', 'turn', 3, 1, 2, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  return showcaseWithHistory('marketing-approval', rows, [
    [
      '先复现窄屏筛选栏被截断的问题，只记录最小修改范围。',
      '已复现：筛选标签在 360vp 以下会挤压尾部操作，问题只涉及布局样式，不需要改筛选数据。'
    ],
    [
      '把修复限制在一次组件样式写入，并补一条视觉回归。',
      '目标文件已经缩小到筛选栏组件和一张回归快照。下一步写入需要一次工作区权限。'
    ]
  ]);
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

function showcaseSecretMessages(): NativeMessage[] {
  const rows: NativeMessage[] = [];
  rows.push(message('user-secret-masked', 'user', 1, 9, 1,
    '请检查这些访问凭据是否只在显示层遮蔽：\n' +
    'sk-live-7f2c\n' +
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJvcGVyYXRvciJ9.5xY7nL2qR8sT4mV1\n' +
    'https://ops-user:u9Qm2Lr7@api.workspace.dev/path\n' +
    '-----BEGIN CREDENTIAL-----\n' +
    'MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7\n' +
    '-----END CREDENTIAL-----'));
  rows.push(message('assistant-secret-masked', 'assistant', 2, 9, 2,
    '凭据已遮蔽。长按复制、重试和模型输入仍会使用原文。'));
  const end = message('turn-secret-masked-end', 'turn', 3, 9, 2, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
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
  if (state === 'showcase-plan') return showcaseMarketingPlanMessages();
  if (state === 'showcase-process') return showcaseMarketingProcessMessages();
  if (state === 'showcase-lineage') return showcaseMarketingLineageMessages();
  if (state === 'showcase-dark') return showcaseMarketingDarkMessages();
  if (state === 'showcase-dark-process') return showcaseMarketingDarkProcessMessages();
  if (state === 'showcase-subagent') return showcaseMarketingSubagentMessages();
  if (state === 'showcase-approval') return showcaseMarketingApprovalMessages();
  if (state === 'secret-masked') return showcaseSecretMessages();
  if (state === 'dock-send-idle' || state === 'dock-send-error' ||
      state === 'dock-material-quiet' || state === 'interaction-approval' ||
      state === 'interaction-question' || state === 'permission-current-read-only' ||
      state === 'permission-current-workspace' || state === 'permission-current-full' ||
      state === 'permission-current-custom' || state === 'permission-menu' ||
      state === 'permission-menu-error' || state === 'permission-full-confirm' ||
      state === 'permission-full-cancel' || state === 'approval-workspace-once' ||
      state === 'approval-full-once' || state === 'approval-long-reason' ||
      state === 'approval-submitting' || state === 'approval-ended' ||
      state === 'approval-disconnected') return showcaseDockMessages();
  if (state === 'dock-queue-pending') return showcaseStreamingMessages();
  if (state === 'dock-queue-authoritative' || state === 'dock-queue-many' ||
      state === 'dock-material-elevated') return showcaseLiveChangeMessages();
  if (state === 'live-change') return showcaseLiveChangeMessages();
  if (state === 'streaming' || state === 'stream-long' || state === 'stream-burst-quiet' || state === 'stream-reconnect' ||
    state === 'stream-repaired') return showcaseStreamingMessages();
  if (state === 'empty') return [];
  if (state === 'long-history') return showcaseLongHistoryMessages();
  if (state === 'attachments') return showcaseLiveChangeMessages();
  return showcaseMessages();
}

function showcaseLongStreamText(): string {
  let value = '## 长流实测\n\n';
  for (let index = 0; index < 58; index++) {
    value += '第 ' + (index + 1) +
      ' 段：**流式更新** 持续追加，`NativeTextContent.ets` 只解析未完成尾段。' +
      ' [说明](https://example.invalid/stream/' + index + ') 仍保持可读。\n\n';
    if (index % 14 === 13) {
      value += '```typescript\nconst streamFrame = ' + index + ';\n```\n\n';
    }
  }
  return value + 'STREAM-LONG-DONE';
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
  const approval = state === 'interaction-approval' || state === 'approval-workspace-once' ||
    state === 'approval-full-once' || state === 'approval-long-reason' ||
    state === 'approval-submitting' || state === 'showcase-approval';
  if (!approval && state !== 'interaction-question') return null;
  const frame = new NativeFrame();
  frame.type = 'interaction';
  frame.connectionId = SHOWCASE_SESSION;
  frame.callId = 'showcase-' + state;
  frame.eventId = 'showcase-' + state + '-request';
  if (approval) {
    frame.interaction = 'approval/request';
    frame.remainingMs = 30000;
    frame.request = new NativeInteractionRequest();
    frame.request.toolName = 'workspace/edit';
    frame.request.targetPermission = state === 'approval-full-once' ? 'danger-full-access' : 'workspace-write';
    frame.request.targetScope = frame.request.targetPermission;
    frame.request.reason = state === 'showcase-approval' ?
      '需要写入一次窄屏筛选栏样式，并运行对应的视觉回归检查。' :
      state === 'approval-long-reason' ?
      '需要写入一次已确认的界面修复。该操作涉及工作区外的发布目录、签名产物与商店截图资源；' +
        '请在确认目标权限和写入范围后决定是否仅放行当前这一次工具调用。' :
      state === 'approval-full-once' ?
        '当前工具请求一次完全权限，以检查系统构建环境并更新发布产物。' :
        '需要写入一次已确认的界面修复。';
    const localized = new NativeLocalized();
    localized.zh = frame.request.reason;
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

function showcasePermissionCurrent(state: string): string {
  if (state === 'permission-current-read-only' || state === 'permission-menu-error') return 'read-only';
  if (state === 'permission-current-full') return 'danger-full-access';
  if (state === 'permission-current-custom') return 'custom';
  return 'workspace-write';
}

function showcasePermissionCatalogJson(state: string): string {
  if (state === 'permission-menu-error') throw new Error('权限目录暂不可用');
  return `{
    "options": [
      { "value": "read-only", "name": "仅可查看", "description": "浏览和查询，不修改工作区" },
      { "value": "workspace-write", "name": "工作区内修改", "description": "只允许修改当前工作区" },
      { "value": "danger-full-access", "name": "完全权限", "description": "减少确认并允许敏感操作" },
      { "value": "auto", "name": "自动审查", "description": "由 Host 自动审查高风险调用" }
    ],
    "defaultOptions": [
      { "value": "read-only", "name": "仅可查看", "description": "浏览和查询，不修改工作区" },
      { "value": "workspace-write", "name": "工作区内修改", "description": "只允许修改当前工作区" },
      { "value": "danger-full-access", "name": "完全权限", "description": "减少确认并允许敏感操作" }
    ],
    "defaultPreset": "workspace-write"
  }`;
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
  return state === 'plan-subagent' || state === 'plan-subagent-long-count' ||
    state === 'plan-off-error' ||
    state === 'subagent-continuable' || state === 'subagent-one-shot' ||
    state === 'subagent-unknown' || state === 'subagent-parent-offline' || state === 'subagent-unavailable' ||
    state === 'showcase-lineage' || state === 'showcase-subagent';
}

function isPlanFixtureState(state: string): boolean {
  return state === 'plan-subagent' || state === 'plan-subagent-long-count' ||
    state === 'plan-dock-overlay' ||
    state === 'plan-off-error' || state === 'showcase-plan' ||
    state === 'showcase-lineage' || state === 'showcase-dark';
}

function showcaseSubagentCatalog(state: string = 'plan-subagent'): ShowcaseSubagentCatalogRow[] {
  const rows: ShowcaseSubagentCatalogRow[] = [];
  const definitions: string[][] = state === 'showcase-lineage' || state === 'showcase-subagent' ? [
    [SHOWCASE_CHILD_CONTINUABLE, 'continuable', '筛选状态检查'],
    [SHOWCASE_CHILD_ONE_SHOT, 'one-shot', '接口约束整理'],
    [SHOWCASE_CHILD_UNKNOWN, 'unknown', '回归用例整理'],
    [SHOWCASE_CHILD_EXTERNAL, 'external', '视觉回归']
  ] : [
    [SHOWCASE_CHILD_CONTINUABLE, 'continuable', '可继续检查'],
    [SHOWCASE_CHILD_ONE_SHOT, 'one-shot', '一次性检查'],
    [SHOWCASE_CHILD_UNKNOWN, 'unknown', '未知模式记录'],
    [SHOWCASE_CHILD_EXTERNAL, 'external', '外部任务']
  ];
  const count = state === 'plan-subagent-long-count' ? 128 : definitions.length;
  for (let index = 0; index < count; index++) {
    const definition = index < definitions.length ? definitions[index] :
      ['showcase-child-extra-' + index.toString(), 'external', '外部任务 ' + (index + 1).toString()];
    const row = new ShowcaseSubagentCatalogRow();
    row.id = definition[0];
    row.createdAt = 1761900000000 + index;
    row.mode = definition[1];
    row.label = definition[2];
    rows.push(row);
  }
  return rows;
}

function showcaseNativeSubagentCatalog(state: string): NativeSubagentEntry[] {
  return showcaseSubagentCatalog(state).map((row: ShowcaseSubagentCatalogRow): NativeSubagentEntry => {
    const entry = new NativeSubagentEntry();
    entry.id = row.id;
    entry.createdAt = row.createdAt;
    entry.mode = row.mode;
    entry.label = row.label;
    entry.running = row.id === SHOWCASE_CHILD_CONTINUABLE && state === 'subagent-continuable';
    return entry;
  });
}

function showcaseChildIdentity(id: string, state: string = ''): NativeSubagentIdentity {
  const identity = new NativeSubagentIdentity();
  identity.mode = id === SHOWCASE_CHILD_ONE_SHOT ? 'one-shot' :
    id === SHOWCASE_CHILD_UNKNOWN ? 'unknown' : 'continuable';
  identity.label = state === 'showcase-subagent' || state === 'showcase-lineage' ?
    id === SHOWCASE_CHILD_ONE_SHOT ? '接口约束整理' :
      id === SHOWCASE_CHILD_UNKNOWN ? '回归用例整理' : '筛选状态检查' :
    id === SHOWCASE_CHILD_ONE_SHOT ? '一次性检查' :
      id === SHOWCASE_CHILD_UNKNOWN ? '未知模式记录' : '可继续检查';
  identity.seq = 20;
  return identity;
}

function showcaseChildMessages(id: string, state: string = ''): NativeMessage[] {
  const identity = showcaseChildIdentity(id, state);
  const rows: NativeMessage[] = [];
  const marketing = state === 'showcase-subagent' || state === 'showcase-lineage';
  rows.push(message('child-user-' + id, 'user', 1, 1, 1,
    marketing ?
      '请检查离线缓存的失效与回退路径，重点看弱网和版本切换。' :
      '请检查 ' + identity.label + ' 的原生呈现。'));
  if (marketing) {
    rows.push(toolMessage('child-read-start-' + id, 'child-cache-read', 'read',
      '{"path":"harmony/entry/src/main/ets/services/OfflineCache.ets"}', '', 2, 1, 2));
    rows.push(toolMessage('child-read-result-' + id, 'child-cache-read', 'read',
      '', '已读取缓存键、失败回退、并发合并和清理入口', 3, 1, 2, true));
    rows.push(toolMessage('child-test-start-' + id, 'child-cache-test', 'exec_command',
      '{"command":"npm test -- offline-cache"}', '', 4, 1, 2));
    rows.push(toolMessage('child-test-result-' + id, 'child-cache-test', 'exec_command',
      '', 'PASS offline-cache\n14 tests passed\nretry merge verified', 5, 1, 2, true));
    const diff = new ShowcaseDiffPayload();
    const cacheDiff = new ShowcaseFileDiff();
    cacheDiff.path = 'harmony/entry/src/main/ets/services/OfflineCache.ets';
    cacheDiff.oldText = 'cache.delete(key);';
    cacheDiff.newText = 'cache.replaceAfterCommit(key);\n' +
      '// keep the last successful value while offline\n' +
      '// merge concurrent retries into one request';
    diff.diffs.push(cacheDiff);
    const requestDiff = new ShowcaseFileDiff();
    requestDiff.path = 'harmony/entry/src/main/ets/services/RequestMerge.ets';
    requestDiff.oldText = 'return fetch(key);';
    requestDiff.newText = 'return inflight.get(key) || fetchAndShare(key);';
    diff.diffs.push(requestDiff);
    const imageDiff = new ShowcaseFileDiff();
    imageDiff.path = 'harmony/entry/src/main/ets/components/NativeImageView.ets';
    imageDiff.oldText = 'image = null;';
    imageDiff.newText = 'image = cachedImage;\n// keep the last successful frame';
    diff.diffs.push(imageDiff);
    const cacheTestDiff = new ShowcaseFileDiff();
    cacheTestDiff.path = 'tests/offline-cache.test.ts';
    cacheTestDiff.oldText = '';
    cacheTestDiff.newText = 'test(\'version switch is atomic\', () => {\n' +
      '  expect(cache.current).toBe(committedValue);\n});\n';
    diff.diffs.push(cacheTestDiff);
    rows.push(toolMessage('child-edit-start-' + id, 'child-cache-edit', 'edit',
      JSON.stringify(diff), '', 6, 1, 2));
    rows.push(toolMessage('child-edit-result-' + id, 'child-cache-edit', 'edit',
      '', '', 7, 1, 2, true));
  }
  const assistant = message('child-assistant-' + id, 'assistant', marketing ? 8 : 2, 1, 3,
    marketing ?
      '检查完成。版本切换会清理旧键；弱网失败继续使用最近一次成功结果。' :
      identity.mode === 'continuable' ? '检查完成，可以继续发送消息。' :
      '此记录保持只读，不提供发送入口。');
  rows.push(assistant);
  const end = message('child-end-' + id, 'turn', marketing ? 9 : 3, 1, 3, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  if (!marketing) return rows;
  return showcaseWithHistory('child-' + id, rows, [
    [
      '先核对缓存版本键，确认版本切换时不会提前清掉仍在使用的键。',
      '版本键包含工作区标识与内容版本。旧键会在新结果提交后清理，当前实现不存在提前失效。'
    ],
    [
      '再检查弱网和请求失败，已有图片必须继续可见。',
      '弱网失败会保留最近一次成功结果，只把状态标记为可重试；恢复网络后合并重复请求。'
    ]
  ]);
}

function showcasePlanProjection(planRemoved: boolean): NativePlanProjection {
  const plan = new NativePlanProjection();
  plan.active = !planRemoved;
  plan.pending = false;
  return plan;
}

function showcaseProjectionJson(state: string, sessionId: string, planRemoved: boolean,
  currentPermission: string = ''): string {
  const values: Record<string, Object> = {};
  if (sessionId === SHOWCASE_CHILD_CONTINUABLE || sessionId === SHOWCASE_CHILD_ONE_SHOT ||
      sessionId === SHOWCASE_CHILD_UNKNOWN) {
    values.subagentKnown = true;
    values.subagent = showcaseChildIdentity(sessionId, state);
    values.subagentCatalog = [];
  } else {
    values.modelSelection = new ShowcaseModelSelectionProjection();
    const permission = new NativePermissionSelection();
    permission.currentValue = currentPermission || showcasePermissionCurrent(state);
    values.permissions = permission;
    if (isPlanFixtureState(state)) {
      values.plan = showcasePlanProjection(planRemoved);
    }
    if (isSubagentFixtureState(state)) {
      values.subagentCatalog = showcaseSubagentCatalog(state);
    }
  }
  const envelope = new ShowcaseProjectionEnvelope();
  envelope.values = values;
  return JSON.stringify(envelope);
}

function showcaseSessions(state: string = 'completed', planRemoved: boolean = false): NativeSession[] {
  const firstTitle = state === 'live-change' ? '底部 Dock 运行态' :
    state === 'showcase-plan' ? '整理离线与同步状态' :
    state === 'showcase-process' ? '排查搜索首帧闪白' :
    state === 'showcase-lineage' ? '拆分搜索筛选重构' :
    state === 'showcase-dark' ? '整理通知中心未读分组' :
    state === 'showcase-dark-process' ? '定位图片缓存重复请求' :
    state === 'showcase-subagent' ? '审查离线缓存回退' :
    state === 'showcase-approval' ? '修正窄屏筛选栏' :
    state === 'streaming' ? '流式输出与标题更新' :
    state === 'stream-long' ? '长流持续输出' :
    state === 'stream-burst-quiet' ? '分段流式输出' :
    state === 'stream-reconnect' ? '连接恢复验收' :
    state === 'stream-repaired' ? '流式 Markdown' :
    state === 'secret-masked' ? '凭据显示与复制来源' :
    state === 'dock-send-idle' || state === 'dock-material-quiet' ? 'Dock 空闲与发送' :
    state === 'dock-send-error' ? '发送失败与重试' :
    state === 'dock-queue-pending' ? '发送中与队列确认' :
    state === 'dock-queue-authoritative' ? '权威排队消息' :
    state === 'dock-queue-many' ? '多行排队消息' :
    state === 'dock-material-elevated' ? '渐变材质与实时变更' :
    state === 'interaction-approval' ? '审批卡样式检查' :
    state === 'interaction-question' ? '问题卡样式检查' :
    state === 'permission-current-read-only' ? '当前权限 · 仅可查看' :
    state === 'permission-current-workspace' ? '当前权限 · 工作区内修改' :
    state === 'permission-current-full' ? '当前权限 · 完全权限' :
    state === 'permission-current-custom' ? '当前权限 · 自定义' :
    state === 'permission-menu' ? '切换当前会话权限' :
    state === 'permission-menu-error' ? '权限目录不可用' :
    state === 'permission-full-confirm' || state === 'permission-full-cancel' ? '完全权限风险确认' :
    state === 'approval-workspace-once' ? '工作区单次审批' :
    state === 'approval-full-once' ? '完全权限单次审批' :
    state === 'approval-long-reason' ? '长原因单次审批' :
    state === 'approval-submitting' ? '审批提交中' :
    state === 'approval-ended' ? '审批已结束' :
    state === 'approval-disconnected' ? '审批连接中断' :
    state === 'plan-subagent' ? '计划与子智能体' :
    state === 'plan-subagent-long-count' ? '计划与子智能体标题很长时优先压缩标题并保留数量' :
    state === 'plan-dock-overlay' ? '悬浮任务计划' :
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
    ['showcase-mobile', '手机端交互适配', 'workspace-mobile', 'false'],
    ['showcase-streaming', '流式输出与键盘布局', 'workspace-mobile', 'false'],
    ['showcase-preview', '文件预览格式覆盖', 'workspace-mobile', 'false'],
    ['showcase-permissions', '权限模式与审批记录', 'workspace-mobile', 'false'],
    ['showcase-cards', '发布截图与桌面卡片', 'workspace-mobile', 'false']
  ];
  const sessions = definitions.map((row: string[]): NativeSession => {
    const value = new NativeSession();
    value.id = row[0];
    value.title = row[1];
    value.cwd = row[2];
    value.blank = row[3] === 'true';
    value.running = (state === 'live-change' || state === 'attachments' ||
      state === 'streaming' || state === 'stream-long' || state === 'stream-burst-quiet' || state === 'stream-reconnect' || state === 'stream-repaired' ||
      state === 'empty' || state === 'dock-queue-pending' ||
      state === 'dock-queue-authoritative' || state === 'dock-queue-many' ||
      state === 'dock-material-elevated' || state === 'interaction-approval' ||
      state === 'interaction-question' || state === 'showcase-approval' ||
      state === 'approval-workspace-once' ||
      state === 'approval-full-once' || state === 'approval-long-reason' ||
      state === 'approval-submitting') &&
      row[0] === SHOWCASE_SESSION || (state === 'stream-long' && row[0] === 'showcase-mobile');
    value.agentAvailable = row[0] === SHOWCASE_SESSION ?
      state !== 'subagent-parent-offline' : undefined;
    value.updatedAt = 1761900000000 - definitions.findIndex((item: string[]) => item[0] === row[0]) * 60000;
    if (row[0] === SHOWCASE_SESSION &&
        (isPlanFixtureState(state) || isSubagentFixtureState(state) ||
          state.startsWith('permission-') || state.startsWith('approval-'))) {
      value.projections = new NativeSubagentProjectionValues();
      const permission = new NativePermissionSelection();
      permission.currentValue = showcasePermissionCurrent(state);
      value.projections.permissions = permission;
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
        child.title = showcaseChildIdentity(id, state).label;
        child.cwd = BuildInfo.appName;
        child.origin = 'subagent';
        child.parentSessionId = SHOWCASE_SESSION;
        child.running = id === SHOWCASE_CHILD_CONTINUABLE &&
          (state === 'subagent-continuable' || state === 'showcase-subagent');
        child.agentAvailable = true;
        child.updatedAt = 1761900000000 - (index + 2) * 1000;
        const projections = new NativeSubagentProjectionValues();
        projections.subagentKnown = true;
        projections.subagent = showcaseChildIdentity(id, state);
        child.projections = projections;
        sessions.push(child);
      });
  }
  return sessions;
}

function showcaseReviewSessionMessages(sessionId: string, state: string): NativeMessage[] {
  if (sessionId === SHOWCASE_SESSION) return showcaseMessagesFor(state);
  let question = '检查这个工作区的当前状态，并整理还需要确认的事项。';
  let answer = '检查完成。当前工作区状态正常，最近一次变更已经完成验证，没有待处理的阻塞项。';
  let command = 'git status --short';
  let detail = '工作区文件、会话记录与运行状态保持同步。';
  if (sessionId === 'showcase-files') {
    question = '检查最近的发布文件，确认导出、源码和预览是否一致。';
    answer = '已核对发布目录、配置文件和预览结果。源码与导出内容一致，异常格式会显示明确的回退说明。';
    command = 'npm run verify:files';
    detail = '文件校验通过，目录、源码切换和只读预览均可正常使用。';
  } else if (sessionId === 'showcase-passkey') {
    question = '复核远程连接和一次高风险写入的审批路径。';
    answer = '审批路径已核对。高风险操作会显示目标权限、作用范围与原因，确认后只放行当前一次调用。';
    command = 'npm test -- access-control';
    detail = '连接、审批、取消和结束状态均按同一套会话投影呈现。';
  } else if (sessionId === 'showcase-notify') {
    question = '检查完成、失败、审批和连接变化四类通知。';
    answer = '四类通知可以独立设置。任务名称与敏感正文遵循卡片隐私选项，回到应用后会定位到对应会话。';
    command = 'npm test -- notifications';
    detail = '通知等级、系统权限和静默状态没有互相覆盖。';
  } else if (sessionId === 'showcase-settings') {
    question = '整理外观、动效和工作步骤展示的偏好设置。';
    answer = '设置已整理。主题、减少动态效果、减少透明度和工作步骤展示会即时更新，并在重新打开页面后保持当前值。';
    command = 'npm test -- host-settings';
    detail = '本地设置与 Host 设置使用同一套紧凑行和明确的状态反馈。';
  } else if (sessionId === 'showcase-mobile') {
    question = '检查手机端的键盘、安全区和系统返回行为。';
    answer = '键盘出现时输入区与正文同步上移；底部控件保持 20vp 安全避让；系统返回优先关闭当前层级。';
    command = 'npm test -- mobile-layout';
    detail = '窄屏、长标题和附件托盘不会挤压主要阅读区域。';
  } else if (sessionId === 'showcase-streaming') {
    return showcaseStreamingMessages();
  } else if (sessionId === 'showcase-preview') {
    question = '检查文本、配置、表格、图片、PDF 和 HTML 的预览支持。';
    answer = '预览入口按文件类型显示。源码与预览可以切换，表格根据内容自适应列宽，不支持的类型保留源码和下载。';
    command = 'npm test -- preview';
    detail = '所有预览均为只读，不显示复制标识。';
  } else if (sessionId === 'showcase-permissions') {
    question = '核对不同权限模式和单次审批的视觉层级。';
    answer = '只读、工作区写入、完全权限和自动审查均使用同一套卡片。权限控件与输入栏对齐，并通过遮罩表达层级。';
    command = 'npm test -- permissions';
    detail = '审批提交中、结束和连接中断都有稳定状态。';
  } else if (sessionId === 'showcase-cards') {
    question = '检查桌面卡片与发布状态摘要。';
    answer = '卡片会显示运行数量、完成结果和待审批任务。隐藏任务名称后仍保留匿名数量和状态。';
    command = 'npm test -- widgets';
    detail = '卡片刷新不会打断当前会话或重复投递通知。';
  }
  const rows: NativeMessage[] = [];
  rows.push(message('review-' + sessionId + '-user', 'user', 1, 1, 1, question));
  rows.push(toolMessage('review-' + sessionId + '-command-start', 'review-' + sessionId + '-command',
    'exec_command', JSON.stringify({ command }), '', 2, 1, 2));
  rows.push(toolMessage('review-' + sessionId + '-command-result', 'review-' + sessionId + '-command',
    'exec_command', '', detail, 3, 1, 2, true));
  rows.push(message('review-' + sessionId + '-assistant', 'assistant', 4, 1, 3, answer));
  const end = message('review-' + sessionId + '-end', 'turn', 5, 1, 3, '');
  end.eventType = 'turn/end';
  end.outcome = 'completed';
  rows.push(end);
  return showcaseWithHistory('review-' + sessionId, rows, [
    [
      '先确认当前版本和最近一次验证结果。',
      '版本、协议和工作区状态一致，当前没有未确认的发布阻塞。'
    ],
    [
      '再检查边界状态和失败回退。',
      '空数据、加载失败和权限不足都有明确提示，并提供可执行的下一步。'
    ]
  ]);
}

function showcaseWorkspaces(): NativeWorkspaceSnapshot {
  const value = new NativeWorkspaceSnapshot();
  value.available = true;
  const mobile = new NativeWorkspaceItem();
  mobile.workspaceId = 'workspace-mobile';
  mobile.path = BuildInfo.appName;
  mobile.title = BuildInfo.appName + ' 移动端';
  mobile.sessionIds = ['showcase-release', 'showcase-files', 'showcase-notify', 'showcase-settings',
    'showcase-mobile', 'showcase-streaming', 'showcase-preview', 'showcase-permissions',
    'showcase-cards'];
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
  private reviewMode: boolean;
  private interaction: NativeShowcaseInteraction = new NativeShowcaseInteraction([]);
  private receiver: (frame: NativeFrame) => void = (_frame: NativeFrame): void => {};
  private receiverReady: boolean = false;
  private promptSerial: number = 0;
  private timers: number[] = [];
  private childInteractions: Map<string, NativeShowcaseInteraction> =
    new Map<string, NativeShowcaseInteraction>();
  private sessionInteractions: Map<string, NativeShowcaseInteraction> =
    new Map<string, NativeShowcaseInteraction>();
  private planRemoved: boolean = false;
  private permissionCurrent: string = 'workspace-write';
  private permissionDefault: string = 'workspace-write';
  private permissionRevision: number = 6;
  private chatRevision: number = 1;
  private conversationRevision: number = 1;
  private chatTranscriptView: string = 'detailed';
  private chatCollapseTiming: string = 'completion';
  private chatFoldedReplies: string = 'all';
  private chatBusyEnter: string = 'queue';
  private pluginInventory: NativePluginInventory = new NativePluginInventory();
  private automationCatalog: NativeAutomationCatalog = new NativeAutomationCatalog();
  private automationDeliveries: Map<string, NativeAutomationDelivery[]> =
    new Map<string, NativeAutomationDelivery[]>();
  private automationSerial: number = 0;
  private uploadSerial: number = 0;
  private mutationClock: number = 0;

  constructor(state: string = 'completed', reviewMode: boolean = false) {
    super('https://showcase.invalid');
    this.fixtureState = NativeUiFixture.state(state);
    this.reviewMode = reviewMode;
    this.pluginInventory = JSON.parse(this.pluginInventoryJson()) as NativePluginInventory;
    this.automationCatalog = JSON.parse(this.automationCatalogJson()) as NativeAutomationCatalog;
    this.seedAutomationHistory();
    this.permissionCurrent = showcasePermissionCurrent(this.fixtureState);
    const seedMessages = showcaseMessagesFor(this.fixtureState);
    const seedRunning = this.fixtureState === 'live-change' ||
      this.fixtureState === 'attachments' || this.fixtureState === 'streaming' ||
      this.fixtureState === 'stream-long' || this.fixtureState === 'stream-burst-quiet' || this.fixtureState === 'stream-reconnect' ||
      this.fixtureState === 'empty' || this.fixtureState === 'dock-queue-pending' ||
      this.fixtureState === 'dock-queue-authoritative' ||
      this.fixtureState === 'dock-queue-many' ||
      this.fixtureState === 'dock-material-elevated' ||
      this.fixtureState === 'interaction-approval' ||
      this.fixtureState === 'interaction-question' ||
      this.fixtureState === 'showcase-approval' ||
      this.fixtureState === 'approval-workspace-once' ||
      this.fixtureState === 'approval-full-once' ||
      this.fixtureState === 'approval-long-reason' ||
      this.fixtureState === 'approval-submitting';
    let seedCursor = 0;
    seedMessages.forEach((row: NativeMessage): void => {
      if (Number.isSafeInteger(row.seq) && row.seq > seedCursor) seedCursor = row.seq;
    });
    const seedQueue = showcaseQueue(this.fixtureState);
    this.interaction = new NativeShowcaseInteraction(seedMessages, seedRunning, seedCursor, seedQueue);
    // The stream-tail fixture simulates a turn started elsewhere nine seconds ago.
    if (this.fixtureState === 'stream-tail') this.interaction.turnStartedAt = Date.now() - 9000;
    if (isSubagentFixtureState(this.fixtureState)) {
      [SHOWCASE_CHILD_CONTINUABLE, SHOWCASE_CHILD_ONE_SHOT, SHOWCASE_CHILD_UNKNOWN]
        .forEach((id: string): void => {
          const childRunning = id === SHOWCASE_CHILD_CONTINUABLE &&
            this.fixtureState === 'subagent-continuable';
          const childMessages = showcaseChildMessages(id, this.fixtureState);
          this.childInteractions.set(id,
            new NativeShowcaseInteraction(childMessages, childRunning, 3, []));
        });
    }
    this.interaction.waiting = this.fixtureState === 'interaction-approval' ||
      this.fixtureState === 'interaction-question' ||
      this.fixtureState === 'showcase-approval' ||
      this.fixtureState === 'approval-workspace-once' ||
      this.fixtureState === 'approval-full-once' ||
      this.fixtureState === 'approval-long-reason' ||
      this.fixtureState === 'approval-submitting';
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
      '正在输出完整的流式回答，内容会按显示帧更新而不会阻塞底部工具栏。' :
      this.fixtureState === 'stream-long' ? '正在建立长流验收…' :
      this.fixtureState === 'stream-repaired' ?
        '流式 Markdown 已完成一半，正在整理 **重点** 与 [文档](https://example.invalid/doc' +
        '\n\n| 状态 | 结果 |\n| --- | --' : '';
    record.streamReasoning = this.fixtureState === 'streaming' ?
      '先检查传输状态，再确认工作过程与底部 Dock 的布局。' : '';
    model.restore(record);
    this.models.set(SHOWCASE_SESSION, model);
    this.selectedId = SHOWCASE_SESSION;
    if (this.reviewMode) {
      ['showcase-files', 'showcase-passkey', 'showcase-notify', 'showcase-settings',
        'showcase-mobile', 'showcase-streaming', 'showcase-preview',
        'showcase-permissions', 'showcase-cards'].forEach((id: string): void => {
        this.sessionInteractions.set(id,
          new NativeShowcaseInteraction(showcaseReviewSessionMessages(id, this.fixtureState),
            false, 0, []));
      });
    }
    if (this.fixtureState === 'attachments') {
      this.attachments.set(SHOWCASE_SESSION, showcaseAttachments());
    }
  }

  static initialState(): string {
    const savedTheme = AppStorage.get<string>('nativeThemeMode');
    const themeMode = savedTheme === 'dark' || savedTheme === 'light' ? savedTheme : 'system';
    const notifyCompleted = AppStorage.get<string>('showcaseNotifyCompleted') || 'quiet';
    const notifyFailed = AppStorage.get<string>('showcaseNotifyFailed') || 'standard';
    const notifyApproval = AppStorage.get<string>('showcaseNotifyApproval') || 'standard';
    const notifyConnection = AppStorage.get<string>('showcaseNotifyConnection') || 'off';
    return JSON.stringify({
      themeMode,
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
    return 'store-showcase-v2';
  }

  async prepareCacheKey(): Promise<void> {
  }

  async state(): Promise<GatewayState> {
    const value = new GatewayState();
    value.mode = 'host';
    value.authenticated = true;
    value.pluginVersion = '0.3.9';
    return value;
  }

  async sessions(): Promise<NativeSessionList> {
    const value = new NativeSessionList();
    value.protocol = 2;
    value.items = showcaseSessions(this.fixtureState, this.planRemoved);
    return value;
  }

  sessionCwd(id: string): string {
    return id === 'showcase-passkey' ? 'Passkey Gateway' : BuildInfo.appName;
  }

  async workspaces(): Promise<NativeWorkspaceSnapshot> {
    return showcaseWorkspaces();
  }

  async page(id: string, _before: number, _throughSeq: number = -1): Promise<NativeFrame> {
    const child = this.childInteractions.get(id);
    const reviewSession = this.sessionInteractions.get(id);
    return child ? child.snapshot() :
      reviewSession ? reviewSession.snapshot() : this.interaction.snapshot();
  }

  private syntheticFollowCount: number = 0;
  private syntheticChildFailure: boolean = false;
  private syntheticRunning: boolean = false;
  private tailPumpActive: boolean = false;

  async follow(id: string, receive: (frame: NativeFrame) => void, _ended: (reason: string) => void): Promise<void> {
    const child = this.childInteractions.get(id);
    const reviewSession = this.sessionInteractions.get(id);
    if (id !== SHOWCASE_SESSION && !child && !reviewSession) return;
    this.paused = false;
    this.receiver = receive;
    this.receiverReady = true;
    if (child && this.fixtureState === 'subagent-unavailable' && !this.syntheticChildFailure) {
      this.syntheticChildFailure = true;
      const failure = new NativeFrame();
      failure.type = 'error'; failure.code = 'subagent/catalog-diagnostic'; failure.retryable = false;
      receive(failure); return;
    }
    receive(child ? child.snapshot() :
      reviewSession ? reviewSession.snapshot() : this.interaction.snapshot());
    if (id === SHOWCASE_SESSION) {
      const interaction = showcaseInteractionFrame(this.fixtureState);
      if (interaction) this.emit([interaction], 90);
      if (this.fixtureState === 'stream-burst-quiet' ||
          this.fixtureState === 'stream-reconnect') this.startSyntheticHeartbeats();
      if (this.fixtureState === 'stream-long') this.startLongStream();
    if (this.fixtureState === 'stream-tail') this.startTailStream();
      if (this.fixtureState === 'stream-tail-end') {
        this.startTailStream();
        const timer = setTimeout((): void => {
          this.timers = this.timers.filter((value: number): boolean => value !== timer);
          if (!this.receiverReady || this.paused) return;
          const stopped = new NativeFrame();
          stopped.type = 'state';
          stopped.running = false;
          stopped.waiting = false;
          this.emit([stopped], 0);
        }, 6000);
        this.timers.push(timer);
      }
      if (this.fixtureState === 'stream-burst-quiet') this.startBurstStream();
      if (this.fixtureState === 'stream-reconnect') {
        this.syntheticFollowCount++;
        if (this.syntheticFollowCount === 1) {
          const timer = setTimeout((): void => { _ended('synthetic_transport_loss'); }, 8000);
          this.timers.push(timer);
        } else {
          this.startBurstStream(true);
        }
      }
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

  private pluginBundle(name: string): NativePluginBundle | null {
    return this.pluginInventory.bundles.find((bundle: NativePluginBundle): boolean =>
      bundle.name === name) || null;
  }

  private pluginEntry(entryId: string): NativePluginEntry | null {
    return this.pluginInventory.plugins.find((entry: NativePluginEntry): boolean =>
      entry.entryId === entryId) || null;
  }

  private pluginBundleForEntry(entryId: string): NativePluginBundle | null {
    return this.pluginInventory.bundles.find((bundle: NativePluginBundle): boolean =>
      bundle.rows.some((row: NativePluginRow): boolean =>
        row.entryId === entryId || row.rowId === entryId)) || null;
  }

  private ensurePluginEntry(bundle: NativePluginBundle, row: NativePluginRow,
    enabled: boolean): NativePluginEntry {
    let entry = this.pluginEntry(row.entryId);
    if (!entry) {
      entry = new NativePluginEntry();
      entry.entryId = row.entryId;
      entry.moduleName = row.moduleName;
      entry.title = row.title;
      entry.description = row.description;
      this.pluginInventory.plugins.push(entry);
    }
    entry.enabled = enabled;
    entry.phase = enabled ? 'active' : 'stopped';
    return entry;
  }

  private pluginChange(target: string, enabled: boolean, stage: string,
    application: string = 'applied'): NativePluginChange {
    const change = new NativePluginChange();
    change.changed = true;
    change.application = application;
    change.stage = stage;
    change.target = target;
    change.enabled = enabled;
    change.pendingBuilds = [];
    return change;
  }

  private nextPatch(version: string): string {
    const parts = version.split('.');
    if (parts.length !== 3 || !parts.every((part: string): boolean => /^\d+$/.test(part))) {
      return version + '.1';
    }
    return parts[0] + '.' + parts[1] + '.' + (Number(parts[2]) + 1).toString();
  }

  private automationTask(id: string): NativeAutomationTask | null {
    return this.automationCatalog.items.find((task: NativeAutomationTask): boolean =>
      task.id === id) || null;
  }

  private automationTimestamp(): string {
    this.mutationClock++;
    return new Date(Date.now() + this.mutationClock).toISOString();
  }

  private automationValue(value: Record<string, Object> | undefined, key: string): string {
    if (!value) return '';
    const item = value[key];
    return typeof item === 'string' ? item as string : '';
  }

  private automationBoolean(value: Record<string, Object> | undefined,
    key: string): boolean | undefined {
    if (!value) return undefined;
    const item = value[key];
    return typeof item === 'boolean' ? item as boolean : undefined;
  }

  private automationNumber(value: Record<string, Object> | undefined, key: string): number {
    if (!value) return 0;
    const item = value[key];
    return typeof item === 'number' && Number.isFinite(item) ? item as number : 0;
  }

  private applyAutomationTiming(task: NativeAutomationTask,
    timing: Record<string, Object> | undefined): void {
    if (!timing) return;
    task.kind = this.automationValue(timing, 'kind') || task.kind;
    task.everySeconds = this.automationNumber(timing, 'every_seconds');
    task.afterSeconds = this.automationNumber(timing, 'after_seconds');
    task.time = '';
    task.timeZone = '';
    task.weekdays = [];
    task.expression = '';
    task.rrule = '';
    const daily = timing['daily'] as Record<string, Object> | undefined;
    const weekly = timing['weekly'] as Record<string, Object> | undefined;
    const cron = timing['cron'] as Record<string, Object> | undefined;
    const at = timing['at'] as Record<string, Object> | undefined;
    if (daily) {
      task.time = this.automationValue(daily, 'time');
      task.timeZone = this.automationValue(daily, 'time_zone');
    } else if (weekly) {
      task.time = this.automationValue(weekly, 'time');
      task.timeZone = this.automationValue(weekly, 'time_zone');
      const days = weekly['weekdays'];
      task.weekdays = Array.isArray(days) ? (days as number[]).slice() : [];
    } else if (cron) {
      task.expression = this.automationValue(cron, 'expression');
      task.timeZone = this.automationValue(cron, 'time_zone');
    } else if (at) {
      const date = this.automationValue(at, 'date');
      const time = this.automationValue(at, 'time');
      task.timeZone = this.automationValue(at, 'time_zone');
      task.scheduledAt = date && time ? date + 'T' + time + '.000Z' : task.scheduledAt;
    } else {
      task.rrule = this.automationValue(timing, 'rrule');
    }
  }

  private applyAutomationTarget(task: NativeAutomationTask,
    target: Record<string, Object> | undefined): void {
    if (!target) return;
    task.targetKind = this.automationValue(target, 'kind') || task.targetKind;
    task.targetSessionId = this.automationValue(target, 'sessionId');
    task.targetCwd = '';
    task.targetAgentPreset = '';
    const create = target['create'] as Record<string, Object> | undefined;
    if (create) {
      task.targetCwd = this.automationValue(create, 'cwd');
      task.targetAgentPreset = this.automationValue(create, 'agentPreset');
    }
  }

  private pluginInventoryJson(): string {
    if (this.pluginInventory.available) return JSON.stringify(this.pluginInventory);
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
          "title": ` + JSON.stringify(BuildInfo.appName) + `,
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
          "name": "@dsh/api-inspector",
          "official": false,
          "availability": "installation",
          "installed": true,
          "enabled": true,
          "removable": true,
          "updatable": true,
          "optional": true,
          "version": "1.4.0",
          "title": "API Inspector",
          "localizedDescription": "查看请求、响应与错误结构",
          "source": "https://registry.example.invalid/api-inspector",
          "installSpec": "@dsh/api-inspector",
          "rows": [
            {
              "rowId": "request-trace",
              "moduleName": "@dsh/api-inspector/trace",
              "entryId": "request-trace",
              "title": "请求追踪",
              "description": "定位接口与重试路径"
            }
          ]
        },
        {
          "name": "@dsh/release-notes",
          "official": false,
          "availability": "installation",
          "installed": true,
          "enabled": true,
          "removable": true,
          "updatable": false,
          "optional": true,
          "version": "0.9.3",
          "title": "Release Notes",
          "localizedDescription": "整理版本说明与变更摘要",
          "source": "https://registry.example.invalid/release-notes",
          "installSpec": "@dsh/release-notes",
          "rows": [
            {
              "rowId": "notes-summary",
              "moduleName": "@dsh/release-notes/summary",
              "entryId": "notes-summary",
              "title": "变更摘要",
              "description": "按任务聚合提交与说明"
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
        },
        {
          "name": "@dsh/code-search",
          "official": false,
          "availability": "installation",
          "installed": false,
          "enabled": false,
          "removable": false,
          "updatable": false,
          "optional": true,
          "version": "0.8.1",
          "title": "Code Search",
          "localizedDescription": "在工作区中按语义查找实现",
          "installSpec": "@dsh/code-search",
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
        },
        {
          "entryId": "request-trace",
          "moduleName": "@dsh/api-inspector/trace",
          "title": "请求追踪",
          "enabled": true,
          "phase": "active"
        },
        {
          "entryId": "notes-summary",
          "moduleName": "@dsh/release-notes/summary",
          "title": "变更摘要",
          "enabled": true,
          "phase": "active"
        }
      ]
    }`;
  }

  private automationCatalogJson(): string {
    if (this.automationCatalog.available) return JSON.stringify(this.automationCatalog);
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
          "targetCwd": ` + JSON.stringify(BuildInfo.appName) + `,
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
          "id": "automation-feedback",
          "kind": "weekly",
          "status": "active",
          "title": "整理产品反馈与高频问题",
          "prompt": "汇总本周反馈，按主题归并高频问题，并标记需要进入规格的条目。",
          "scheduledAt": "2026-11-04T03:00:00.000Z",
          "timeZone": "Asia/Shanghai",
          "time": "11:00:00",
          "weekdays": [3],
          "targetKind": "new_once",
          "targetCwd": ` + JSON.stringify(BuildInfo.appName) + `,
          "updatedAt": "2026-10-31T08:20:00.000Z"
        },
        {
          "id": "automation-release",
          "kind": "every",
          "status": "active",
          "title": "同步发布进度与阻塞项",
          "prompt": "检查当前发布任务的状态，列出阻塞项和建议的下一步。",
          "scheduledAt": "2026-11-04T06:00:00.000Z",
          "everySeconds": 21600,
          "timeZone": "Asia/Shanghai",
          "targetKind": "session",
          "targetSessionId": "showcase-release",
          "updatedAt": "2026-11-03T06:00:00.000Z"
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

  private automationTaskJson(id: string): string {
    const task = this.automationTask(id);
    if (!task) throw new NativeHttpError(404, 'schedule_not_found');
    return JSON.stringify(task);
  }

  private seedAutomationHistory(): void {
    this.automationDeliveries.clear();
    this.automationCatalog.items.forEach((task: NativeAutomationTask): void => {
      const rows: NativeAutomationDelivery[] = [];
      for (let index: number = 1; index <= 3; index++) {
        const delivery = new NativeAutomationDelivery();
        delivery.scheduledAt = '2026-11-0' + (5 - index).toString() + 'T01:00:00.000Z';
        delivery.deliveredAt = '2026-11-0' + (5 - index).toString() + 'T01:00:02.000Z';
        delivery.messageId = 'message-' + (31 - index * 4).toString();
        delivery.targetSessionId = task.targetSessionId || SHOWCASE_SESSION;
        delivery.prompt = task.prompt;
        rows.push(delivery);
      }
      this.automationDeliveries.set(task.id, rows);
    });
  }

  private automationHistoryJson(id: string): string {
    const task = this.automationTask(id);
    if (!task) throw new NativeHttpError(404, 'schedule_not_found');
    const value = new NativeAutomationHistory();
    value.available = true;
    const rows = this.automationDeliveries.get(id) || [];
    value.records = rows.slice();
    value.earlierRecordsUnavailable = false;
    value.earlierRecordsPruned = false;
    return JSON.stringify(value);
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
    if (operation === 'pluginSetEnabled') {
      const name = typeof value.name === 'string' ? value.name : '';
      const enabled = value.enabled === true;
      const bundle = this.pluginBundle(name);
      if (!bundle) throw new NativeHttpError(404, 'plugin_not_found');
      bundle.enabled = enabled;
      this.pluginInventory.plugins.forEach((entry: NativePluginEntry): void => {
        if (entry.moduleName === name || entry.moduleName.startsWith(name + '/')) {
          entry.enabled = enabled;
          entry.phase = enabled ? 'active' : 'stopped';
        }
      });
      const change = this.pluginChange(name, enabled, 'enable');
      return JSON.stringify(change);
    }
    if (operation === 'pluginSetRowEnabled') {
      const entryId = typeof value.entryId === 'string' ? value.entryId : '';
      const enabled = value.enabled === true;
      const bundle = this.pluginBundleForEntry(entryId);
      const row = bundle?.rows.find((item: NativePluginRow): boolean =>
        item.entryId === entryId || item.rowId === entryId);
      if (!bundle || !row) throw new NativeHttpError(404, 'plugin_not_found');
      this.ensurePluginEntry(bundle, row, enabled);
      const prefix = bundle.name + '/';
      bundle.enabled = this.pluginInventory.plugins.some((entry: NativePluginEntry): boolean =>
        entry.enabled && (entry.moduleName === bundle.name || entry.moduleName.startsWith(prefix)));
      const change = this.pluginChange(entryId, enabled, 'enable');
      change.bundle = bundle.name;
      return JSON.stringify(change);
    }
    if (operation === 'pluginInspect') {
      const spec = typeof value.spec === 'string' ? value.spec : '';
      const bundle = this.pluginBundle(spec) ||
        this.pluginInventory.bundles.find((item: NativePluginBundle): boolean =>
          item.installSpec === spec || spec.startsWith(item.name + '@')) || null;
      if (bundle?.installed) {
        return JSON.stringify({
          status: 'refused', kind: 'registry', name: bundle.name,
          version: bundle.version, description: bundle.localizedDescription,
          bundle: true, registry: null, host: '',
          problem: 'already-installed', reason: '插件已经安装', registries: []
        });
      }
      if (!bundle) {
        return JSON.stringify({
          status: 'refused', kind: 'registry', name: spec,
          version: '', description: '', bundle: false, registry: null, host: '',
          problem: 'plugin_not_found', reason: '未找到插件', registries: []
        });
      }
      return JSON.stringify({
        status: 'accepted', kind: 'registry', name: bundle.name,
        version: bundle.version, description: bundle.localizedDescription,
        bundle: true, registry: 'https://registry.dshoh.com',
        host: 'registry.dshoh.com', reason: '', problem: '', registries: []
      });
    }
    if (operation === 'pluginInstall') {
      const spec = typeof value.spec === 'string' ? value.spec : '';
      if (this.fixtureState === 'plugins-install-failed') {
        return `{
          "changed": false, "application": "failed", "stage": "install",
          "target": "dsh-plugin-with-missing-build", "pendingBuilds": [],
          "errorCode": "unsupported-platform"
        }`;
      }
      const bundle = this.pluginBundle(spec) ||
        this.pluginInventory.bundles.find((item: NativePluginBundle): boolean =>
          item.installSpec === spec || spec.startsWith(item.name + '@')) || null;
      if (!bundle) {
        return `{
          "changed": false, "application": "failed", "stage": "install",
          "target": ` + JSON.stringify(spec) + `, "pendingBuilds": [],
          "errorCode": "plugin_not_found", "errorDiagnostic": "未找到插件"
        }`;
      }
      bundle.installed = true;
      bundle.enabled = true;
      bundle.removable = true;
      bundle.updatable = false;
      bundle.rows.forEach((row: NativePluginRow): void => {
        this.ensurePluginEntry(bundle, row, true);
      });
      const change = this.pluginChange(bundle.name + '@' + bundle.version, true,
        'install', 'restart-required');
      change.restartReason = 'plugin';
      change.bundle = bundle.name;
      change.version = bundle.version;
      return JSON.stringify(change);
    }
    if (operation === 'pluginVersions') {
      const name = typeof value.name === 'string' ? value.name : '';
      const bundle = this.pluginBundle(name);
      if (!bundle) throw new NativeHttpError(404, 'plugin_not_found');
      const next = new NativePluginVersion();
      next.version = this.nextPatch(bundle.version);
      next.tags = ['latest'];
      next.bundle = true;
      const current = new NativePluginVersion();
      current.version = bundle.version;
      current.bundle = true;
      const versions = new NativePluginVersionList();
      versions.status = 'listed';
      versions.installed = bundle.version;
      versions.registry = 'https://registry.example.invalid';
      versions.versions = [next, current];
      return JSON.stringify(versions);
    }
    if (operation === 'pluginUpdate') {
      const name = typeof value.name === 'string' ? value.name : '';
      const version = typeof value.version === 'string' ? value.version : '';
      const bundle = this.pluginBundle(name);
      if (!bundle || !version) throw new NativeHttpError(404, 'plugin_not_found');
      bundle.version = version;
      bundle.updatable = false;
      const change = this.pluginChange(name, bundle.enabled, 'install', 'restart-required');
      change.restartReason = 'plugin';
      change.bundle = name;
      change.version = version;
      return JSON.stringify(change);
    }
    if (operation === 'pluginRemove') {
      const name = typeof value.name === 'string' ? value.name : '';
      const bundle = this.pluginBundle(name);
      if (!bundle) throw new NativeHttpError(404, 'plugin_not_found');
      bundle.installed = false;
      bundle.enabled = false;
      bundle.removable = false;
      bundle.updatable = false;
      this.pluginInventory.plugins = this.pluginInventory.plugins.filter(
        (entry: NativePluginEntry): boolean =>
          entry.moduleName !== name && !entry.moduleName.startsWith(name + '/'));
      const change = this.pluginChange(name, false, 'install', 'restart-required');
      change.restartReason = 'plugin';
      change.bundle = name;
      return JSON.stringify(change);
    }
    if (operation === 'automationList') return this.automationCatalogJson();
    if (operation === 'automationView') {
      return this.automationTaskJson(typeof value.id === 'string' ? value.id : '');
    }
    if (operation === 'automationCreate') {
      const request = value.request && typeof value.request === 'object' ?
        value.request as Record<string, Object> : undefined;
      if (!request) throw new NativeHttpError(400, 'invalid_schedule');
      const task = new NativeAutomationTask();
      const now = this.automationTimestamp();
      task.id = 'automation-created-' + (++this.automationSerial).toString();
      task.status = 'active';
      task.title = this.automationValue(request, 'title');
      task.prompt = this.automationValue(request, 'prompt');
      task.targetKind = 'new_once';
      task.scheduledAt = now;
      task.createdAt = now;
      task.updatedAt = now;
      this.applyAutomationTiming(task,
        request['timing'] as Record<string, Object> | undefined);
      this.applyAutomationTarget(task,
        request['target'] as Record<string, Object> | undefined);
      this.automationCatalog.items.push(task);
      this.automationDeliveries.set(task.id, []);
      return JSON.stringify(task);
    }
    if (operation === 'automationEdit') {
      const request = value.request && typeof value.request === 'object' ?
        value.request as Record<string, Object> : undefined;
      if (!request) throw new NativeHttpError(400, 'invalid_schedule');
      const id = this.automationValue(request, 'id');
      const task = this.automationTask(id);
      if (!task) throw new NativeHttpError(404, 'schedule_not_found');
      const expected = request['expectedUpdatedAt'];
      if (typeof expected === 'string' && expected !== task.updatedAt) {
        throw new NativeHttpError(409, 'schedule_conflict');
      }
      const patch = request['patch'] as Record<string, Object> | undefined;
      if (!patch) throw new NativeHttpError(400, 'invalid_schedule');
      const title = this.automationValue(patch, 'title');
      const prompt = this.automationValue(patch, 'prompt');
      if (title) task.title = title;
      if (prompt) task.prompt = prompt;
      this.applyAutomationTiming(task,
        patch['timing'] as Record<string, Object> | undefined);
      this.applyAutomationTarget(task,
        patch['target'] as Record<string, Object> | undefined);
      const active = this.automationBoolean(patch, 'active');
      if (active !== undefined) task.status = active ? 'active' : 'paused';
      task.updatedAt = this.automationTimestamp();
      return JSON.stringify(task);
    }
    if (operation === 'automationRun') {
      const task = this.automationTask(typeof value.id === 'string' ? value.id : '');
      if (!task) throw new NativeHttpError(404, 'schedule_not_found');
      const now = this.automationTimestamp();
      task.executionActive = false;
      task.lastDeliveryAt = now;
      task.updatedAt = now;
      const delivery = new NativeAutomationDelivery();
      delivery.scheduledAt = now;
      delivery.deliveredAt = now;
      delivery.messageId = 'message-' + (++this.automationSerial).toString();
      delivery.targetSessionId = task.targetSessionId || SHOWCASE_SESSION;
      delivery.prompt = task.prompt;
      const rows = this.automationDeliveries.get(task.id) || [];
      this.automationDeliveries.set(task.id, [delivery].concat(rows));
      return JSON.stringify(task);
    }
    if (operation === 'automationDelete') {
      const request = value.request && typeof value.request === 'object' ?
        value.request as Record<string, Object> : value;
      const id = this.automationValue(request, 'id');
      const task = this.automationTask(id);
      if (!task) throw new NativeHttpError(404, 'schedule_not_found');
      const expected = request['expectedUpdatedAt'];
      if (typeof expected === 'string' && expected !== task.updatedAt) {
        throw new NativeHttpError(409, 'schedule_conflict');
      }
      if (task.executionActive) throw new NativeHttpError(409, 'schedule_execution_pending');
      this.automationCatalog.items = this.automationCatalog.items.filter(
        (item: NativeAutomationTask): boolean => item.id !== id);
      this.automationDeliveries.delete(id);
      return '{"deleted":true}';
    }
    if (operation === 'automationHistory') {
      return this.automationHistoryJson(typeof value.id === 'string' ? value.id : '');
    }
    if (operation === 'permissionCatalog') {
      return showcasePermissionCatalogJson(this.fixtureState);
    }
    if (operation === 'setPermissionPreset') {
      const preset = typeof value.preset === 'string' ? value.preset : '';
      if (!['read-only', 'workspace-write', 'danger-full-access', 'auto'].includes(preset)) {
        throw new Error('权限模式暂不可用');
      }
      this.permissionCurrent = preset;
      const frame = new NativeFrame();
      frame.type = 'permission';
      frame.projectionSeq = 44;
      const selection = new NativePermissionSelection();
      selection.currentValue = preset;
      frame.selection = selection;
      this.emit([frame], 420);
      return '{"accepted":true}';
    }
    if (operation === 'settingsSet' &&
      value.ns === 'permission' && value.field === 'defaultPreset' &&
      typeof value.value === 'string') {
      if (!['read-only', 'workspace-write', 'danger-full-access'].includes(value.value)) {
        throw new NativeHttpError(400, 'invalid_settings_value');
      }
      if (typeof value.revision !== 'number' || !Number.isSafeInteger(value.revision)) {
        throw new NativeHttpError(400, 'invalid_settings_revision');
      }
      if (value.revision !== this.permissionRevision) {
        throw new NativeHttpError(409, 'settings_revision_conflict');
      }
      this.permissionDefault = value.value;
      this.permissionRevision++;
      return this.settingsNamespaceJson('permission');
    }
    if (operation === 'settingsSet' && typeof value.ns === 'string' &&
      typeof value.field === 'string' && typeof value.value === 'string') {
      if (typeof value.revision !== 'number' || !Number.isSafeInteger(value.revision)) {
        throw new NativeHttpError(400, 'invalid_settings_revision');
      }
      const expected = value.ns === 'ui-chat' ? this.chatRevision :
        value.ns === 'ui-conversation' ? this.conversationRevision : -1;
      if (expected < 0 || value.revision !== expected) {
        throw new NativeHttpError(409, 'settings_revision_conflict');
      }
      if (value.ns === 'ui-chat' && value.field === 'transcriptView' &&
        ['compact', 'standard', 'detailed', 'verbose'].includes(value.value)) {
        this.chatTranscriptView = value.value;
        this.chatRevision++;
        return this.settingsNamespaceJson('ui-chat');
      }
      if (value.ns === 'ui-chat' && value.field === 'collapseTiming' &&
        ['completion', 'next-input'].includes(value.value)) {
        this.chatCollapseTiming = value.value;
        this.chatRevision++;
        return this.settingsNamespaceJson('ui-chat');
      }
      if (value.ns === 'ui-chat' && value.field === 'foldedReplies' &&
        ['all', 'final'].includes(value.value)) {
        this.chatFoldedReplies = value.value;
        this.chatRevision++;
        return this.settingsNamespaceJson('ui-chat');
      }
      if (value.ns === 'ui-conversation' && value.field === 'busyEnter' &&
        ['queue', 'steer'].includes(value.value)) {
        this.chatBusyEnter = value.value;
        this.conversationRevision++;
        return this.settingsNamespaceJson('ui-conversation');
      }
      throw new NativeHttpError(400, 'invalid_settings_field');
    }
    if (operation === 'settingsDescribe') {
      return `{
        "writable": true,
        "namespaces": [
          {
            "ns": "ui-chat",
            "revision": ${this.chatRevision},
            "value": {
              "transcriptView": ${JSON.stringify(this.chatTranscriptView)},
              "collapseTiming": ${JSON.stringify(this.chatCollapseTiming)},
              "foldedReplies": ${JSON.stringify(this.chatFoldedReplies)}
            }
          },
          {
            "ns": "ui-conversation",
            "revision": ${this.conversationRevision},
            "value": { "busyEnter": ${JSON.stringify(this.chatBusyEnter)} }
          },
          {
            "ns": "permission",
            "revision": ${this.permissionRevision},
            "value": { "defaultPreset": ${JSON.stringify(this.permissionDefault)} }
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
      return showcaseProjectionJson(this.fixtureState, sessionId, this.planRemoved,
        this.permissionCurrent);
    }
    if (operation === 'planOff') {
      if (this.fixtureState === 'plan-off-error') {
        throw new Error('计划状态更新失败');
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

  private settingsNamespaceJson(ns: string): string {
    if (ns === 'ui-chat') {
      return '{"ns":"ui-chat","revision":' + this.chatRevision.toString() +
        ',"value":{"transcriptView":' + JSON.stringify(this.chatTranscriptView) +
        ',"collapseTiming":' + JSON.stringify(this.chatCollapseTiming) +
        ',"foldedReplies":' + JSON.stringify(this.chatFoldedReplies) + '}}';
    }
    if (ns === 'ui-conversation') {
      return '{"ns":"ui-conversation","revision":' + this.conversationRevision.toString() +
        ',"value":{"busyEnter":' + JSON.stringify(this.chatBusyEnter) + '}}';
    }
    return '{"ns":"permission","revision":' + this.permissionRevision.toString() +
      ',"value":{"defaultPreset":' + JSON.stringify(this.permissionDefault) + '}}';
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
    if (target) {
      const frames = target.cancel();
      if (typeof value.eventId === 'string') {
        const ended = new NativeFrame();
        ended.type = 'interaction-ended';
        ended.eventId = value.eventId;
        frames.push(ended);
      }
      // Keep the submitting fixture alive long enough for device capture and a
      // full accessibility layout dump to observe the locked actions.
      this.emit(frames, this.fixtureState === 'approval-submitting' ? 3000 : 24);
    }
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
      ['.github', 'config', 'docs', 'gateway', 'harmony', 'scripts', 'specs', 'tests']
        .forEach((name: string): void => {
        const entry = new NativeDirectoryEntry();
        entry.name = name;
        entry.type = 'directory';
        entries.push(entry);
      });
      ['README.md', 'LICENSE', '.npmrc', 'package.json', 'package-lock.json',
        'BUILDING.md', 'CHANGELOG.md', '.gitignore'].forEach((name: string): void => {
        const entry = new NativeDirectoryEntry();
        entry.name = name;
        entry.type = 'file';
        entry.size = showcaseFileSource(name).length;
        entries.push(entry);
      });
    } else if (path === 'config') {
      ['app.conf', 'production.env', 'staging.env', 'local.env', 'service.cfg',
        'models.json', 'permissions.conf', 'notifications.conf', 'preview.conf',
        'automation.conf'].forEach((name: string): void => {
        const entry = new NativeDirectoryEntry();
        entry.name = name;
        entry.type = 'file';
        entry.size = name === 'app.conf' ? SHOWCASE_CONF.length : showcaseFileSource(name).length;
        entries.push(entry);
      });
    } else if (path === 'docs') {
      ['assets', 'BUILDING.md', 'DEPLOYMENT.md', 'DESIGN.md', 'PROTOCOL.md',
        'PRIVACY.md', 'malformed.csv', 'report.tsv', 'users.csv', 'diagram.svg',
        'preview.html', 'archive.zip'].forEach((name: string): void => {
        const entry = new NativeDirectoryEntry();
        entry.name = name;
        entry.type = name === 'assets' ? 'directory' : 'file';
        entry.size = name === 'users.csv' ? SHOWCASE_CSV.length :
          name === 'report.tsv' ? SHOWCASE_TSV.length :
            name === 'malformed.csv' ? SHOWCASE_MALFORMED_CSV.length :
              name === 'diagram.svg' ? SHOWCASE_SVG.length :
              name === 'preview.html' ? SHOWCASE_HTML.length :
              name === 'archive.zip' ? SHOWCASE_BINARY.length : 420;
        entries.push(entry);
      });
    } else if (path === 'harmony') {
      ['entry', 'build-profile.json5', 'hvigorfile.ts', 'oh-package.json5']
        .forEach((name: string): void => {
          const entry = new NativeDirectoryEntry();
          entry.name = name;
          entry.type = name === 'entry' ? 'directory' : 'file';
          entry.size = showcaseFileSource(name).length;
          entries.push(entry);
        });
    } else if (path === 'scripts') {
      ['build-harmony.ps1', 'capture-store-screenshots.ps1', 'compose-store-screenshots.py',
        'device-ui-suite.ps1', 'qa.mjs', 'verify-ui-coverage.mjs']
        .forEach((name: string): void => {
          const entry = new NativeDirectoryEntry();
          entry.name = name;
          entry.type = 'file';
          entry.size = 1180 + name.length * 42;
          entries.push(entry);
        });
    } else if (path === 'tests') {
      ['protocol', 'layout', 'unit', 'device-evidence.json']
        .forEach((name: string): void => {
          const entry = new NativeDirectoryEntry();
          entry.name = name;
          entry.type = name === 'device-evidence.json' ? 'file' : 'directory';
          entry.size = name === 'device-evidence.json' ? 2840 : 0;
          entries.push(entry);
        });
    }
    value.entries = entries;
    return value;
  }

  async findWorkspaceFile(_id: string, name: string): Promise<string> {
    if (name === 'README.md') return 'README.md';
    if (name === 'diagram.svg') return 'docs/diagram.svg';
    if (name === 'app.conf') return 'config/app.conf';
    if (name === 'users.csv') return 'docs/users.csv';
    if (name === 'report.tsv') return 'docs/report.tsv';
    if (name === 'malformed.csv') return 'docs/malformed.csv';
    if (name === 'archive.zip') return 'docs/archive.zip';
    if (name === 'LICENSE') return 'LICENSE';
    if (name === '.npmrc') return '.npmrc';
    return '';
  }

  async statFile(id: string, path: string): Promise<NativeFileStat> {
    const value = new NativeFileStat();
    value.absolutePath = path;
    value.version = id + ':v1';
    value.bytes = path.endsWith('archive.zip') ? SHOWCASE_BINARY.length :
      showcaseFileSource(path).length;
    return value;
  }

  async file(id: string, path: string, offset: number = 1, _limit: number = 240): Promise<NativeFilePage> {
    const value = new NativeFilePage();
    value.absolutePath = path;
    value.version = id + ':v1';
    value.text = showcaseFileSource(path);
    value.lines = value.text.split('\n').length;
    value.offset = offset;
    value.eof = true;
    return value;
  }

  async readFileBytes(id: string, path: string, _baseFile: string = '',
    offset: number = 0, length: number = 262144, _expectedVersion: string = '',
    _expectedBytes: number = -1): Promise<NativeFileBytes> {
    const bytes = path.endsWith('archive.zip') ? SHOWCASE_BINARY :
      StoreShowcaseClient.utf8(showcaseFileSource(path));
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

  async uploadAttachment(id: string, name: string, data: Uint8Array,
    _mediaType: string = ''): Promise<NativeUploadResult> {
    if (!/^[A-Za-z0-9_-]{1,160}$/.test(id) || !name || name.length > 512) {
      throw new Error('Invalid upload');
    }
    const value = new NativeUploadResult();
    value.receiptId = 'showcase-upload-' + (++this.uploadSerial).toString() +
      '-' + data.byteLength.toString();
    return value;
  }

  async create(_cwd: string = '', _agentPreset: string = '', _workspaceId: string = '',
    _reuseId: string = ''): Promise<string> {
    return SHOWCASE_SESSION;
  }

  async prompt(id: string, text: string, mode: string = 'queue',
    attachments: NativeAttachmentDraft[] = [], requestId: string = '',
    address: NativeSessionAddress | null = null): Promise<string> {
    if (this.reviewMode) {
      await new Promise<void>((resolve: () => void): void => {
        setTimeout(resolve, 1200);
      });
      throw new NativeHttpError(402, 'insufficient_balance');
    }
    const child = address?.kind === 'subagent';
    const target = child ? this.childInteractions.get(id) : this.interaction;
    if (!target || (!child && id !== SHOWCASE_SESSION)) {
      throw new Error('Showcase session unavailable');
    }
    if (child && attachments.length) {
      throw new Error('子智能体不支持此附件');
    }
    if (child) {
      const identity = this.childInteractions.has(id) ? showcaseChildIdentity(id, this.fixtureState) : null;
      if (!identity || identity.mode !== 'continuable') {
        throw new Error('此子智能体只读');
      }
    }
    if (this.fixtureState === 'dock-send-error') {
      throw new Error('发送失败，请重试');
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
    if (!plan.accepted) throw new Error('无法提交空消息');
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
    if (this.fixtureState === 'stream-tail' && address?.kind !== 'subagent') {
      this.tailPumpActive = false;
      const stopped = new NativeFrame();
      stopped.type = 'state';
      stopped.running = false;
      stopped.waiting = false;
      this.emit([stopped], 40);
      return;
    }
    const target = address?.kind === 'subagent' ? this.childInteractions.get(id) : this.interaction;
    if (target) this.emit(target.cancel(), 80);
  }

  private emit(frames: NativeFrame[], delay: number,
    onFire: (() => void) | null = null): void {
    if (!frames.length) return;
    const timer = setTimeout((): void => {
      this.timers = this.timers.filter((value: number): boolean => value !== timer);
      if (!this.receiverReady || this.paused) return;
      if (onFire) onFire();
      frames.forEach((frame: NativeFrame): void => { this.receiver(frame); });
    }, delay);
    this.timers.push(timer);
  }

  /**
   * A live Host keeps heartbeating for the whole connection. The fixture must
   * do the same, otherwise the client watchdog correctly repairs a link that
   * only the fixture stopped feeding.
   */
  private startSyntheticHeartbeats(): void {
    const timer = setTimeout((): void => {
      this.timers = this.timers.filter((value: number): boolean => value !== timer);
      if (!this.receiverReady || this.paused) return;
      const heartbeat = new NativeFrame();
      heartbeat.type = 'heartbeat';
      heartbeat.generation = 'synthetic-generation';
      heartbeat.stateKnown = true;
      heartbeat.running = this.syntheticRunning;
      heartbeat.waiting = false;
      heartbeat.cursor = this.interaction.snapshot().cursor;
      this.receiver(heartbeat);
      this.startSyntheticHeartbeats();
    }, 2000);
    this.timers.push(timer);
  }

  private startBurstStream(recovered: boolean = false): void {
    const state = new NativeFrame(); state.type = 'state'; state.running = true; state.waiting = false;
    const start = new NativeFrame(); start.type = 'start';
    start.attemptId = 'synthetic-burst'; start.revision = 1;
    this.syntheticRunning = true;
    this.emit([state, start], 100);
    const quietMs = recovered ? 1000 : 20000;
    const first = new NativeFrame(); first.type = 'delta'; first.attemptId = start.attemptId;
    first.revision = 2; first.index = 0;
    first.text = '第一段已完整接收。中文与 emoji 😀 保持完整，显示逐步追上收到的内容。'.repeat(8) + '\n\n';
    const second = new NativeFrame(); second.type = 'delta'; second.attemptId = start.attemptId;
    second.revision = 3; second.index = 1;
    second.text = recovered ? 'STREAM-RECOVERED-DONE' : 'STREAM-BURST-DONE';
    this.emit([first], quietMs);
    this.emit([second], quietMs + 3000);
    const idle = new NativeFrame(); idle.type = 'state'; idle.running = false;
    this.emit([idle], quietMs + 5000, (): void => { this.syntheticRunning = false; });
  }

  /** Long-running turn that never settles, so the running tail can be observed. */
  private startTailStream(): void {
    let revision = 0;
    let index = 0;
    this.tailPumpActive = true;
    const start = new NativeFrame();
    start.type = 'start';
    start.attemptId = 'showcase-tail-attempt';
    start.revision = ++revision;
    start.nextIndex = 0;
    this.emit([start], 60);
    const running = new NativeFrame();
    running.type = 'state';
    running.running = true;
    running.waiting = false;
    this.emit([running], 60);
    const pump = (): void => {
      const timer = setTimeout((): void => {
        this.timers = this.timers.filter((value: number): boolean => value !== timer);
        if (!this.receiverReady || this.paused || !this.tailPumpActive) return;
        const delta = new NativeFrame();
        delta.type = 'delta';
        delta.attemptId = 'showcase-tail-attempt';
        delta.revision = ++revision;
        delta.index = index++;
        delta.text = index % 3 === 0 ? '仍在深度求索。' : '持续输出中，';
        this.emit([delta], 0);
        pump();
      }, 340);
      this.timers.push(timer);
    };
    pump();
  }

  private startLongStream(): void {
    const source = showcaseLongStreamText();
    let revision = 0;
    let index = 0;
    let offset = 0;
    const start = new NativeFrame();
    start.type = 'start';
    start.attemptId = 'showcase-long-attempt';
    start.revision = ++revision;
    start.nextIndex = 0;
    this.emit([start], 80);
    const running = new NativeFrame();
    running.type = 'state';
    running.running = true;
    running.waiting = false;
    this.emit([running], 40);
    const pump = (): void => {
      const timer = setTimeout((): void => {
        this.timers = this.timers.filter((value: number): boolean => value !== timer);
        if (!this.receiverReady || this.paused) return;
        const end = Math.min(source.length, offset + 8);
        const delta = new NativeFrame();
        delta.type = 'delta';
        delta.attemptId = start.attemptId;
        delta.revision = ++revision;
        delta.index = index++;
        delta.text = source.slice(offset, end);
        this.receiver(delta);
        offset = end;
        if (offset < source.length) {
          pump();
          return;
        }
        const state = new NativeFrame();
        state.type = 'state';
        state.running = false;
        state.waiting = false;
        this.receiver(state);
      }, 18);
      this.timers.push(timer);
    };
    const initialTimer = setTimeout((): void => {
      this.timers = this.timers.filter((value: number): boolean => value !== initialTimer);
      if (this.receiverReady && !this.paused) pump();
    }, 110);
    this.timers.push(initialTimer);
  }

  async exportSession(id: string, format: string,
    receive: (part: ArrayBuffer) => void): Promise<void> {
    if (format !== 'markdown') throw new Error('Unsupported export format');
    let frame: NativeFrame = this.interaction.snapshot();
    const child = this.childInteractions.get(id);
    const reviewSession = this.sessionInteractions.get(id);
    if (child) frame = child.snapshot();
    else if (reviewSession) frame = reviewSession.snapshot();
    let markdown = '# ' + BuildInfo.appName + ' 对话导出\n\n';
    frame.messages.forEach((message: NativeMessage): void => {
      if ((message.role !== 'user' && message.role !== 'assistant') || !message.text) return;
      markdown += '## ' + (message.role === 'user' ? '用户' : '助手') + '\n\n' +
        message.text + '\n\n';
    });
    const bytes = StoreShowcaseClient.utf8(markdown);
    receive(bytes.buffer as ArrayBuffer);
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
