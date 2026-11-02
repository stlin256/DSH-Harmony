import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeDiffDocument, nativeDiff } from '../services/NativeDiff';
import { NativePlanDocument, NativePlanItem } from '../services/NativePlan';
import {
  NativeImageAttachment,
  NativeMessage,
  NativeQueueItem
} from '../services/NativeSessionModel';
import {
  NativeShowcaseAttachment,
  nativeShowcaseQueueItem
} from '../services/NativeShowcaseInteraction';
import { NativeDesign } from '../services/NativeDesign';
import { NativeBackgroundNoticeView } from './NativeBackgroundNoticeView';
import { NativeDiffBlock } from './NativeDiffBlock';
import { NativeMessageView } from './NativeMessageView';
import { NativeProcessView } from './NativeProcessView';
import { NativeQueueDock } from './NativeQueueDock';
import { NativeTaskDock } from './NativeTaskDock';

class DisclosureFileDiff {
  path: string = '';
  oldText: string = '';
  newText: string = '';
}

class DisclosureDiffPayload {
  diffs: DisclosureFileDiff[] = [];
}

function disclosureMessage(id: string, role: string, text: string): NativeMessage {
  const value = new NativeMessage();
  value.id = id;
  value.role = role;
  value.seq = 1;
  value.turn = 1;
  value.turnKey = 'turn:disclosure';
  value.step = 1;
  value.text = text;
  return value;
}

function disclosureOperation(id: string, label: string, detail: string, role: string,
  toolName: string = '', args: string = '', output: string = '',
  metaRaw: string = ''): NativeMessage {
  const value = disclosureMessage(id, role, role === 'tool' ? output : '');
  value.label = label;
  value.detail = detail;
  value.renderKey = id + ':stable';
  if (role === 'tool') {
    value.toolName = toolName;
    value.phase = 'result';
    value.status = 'success';
    value.args = args;
    value.output = output;
    value.metaRaw = metaRaw;
  } else {
    value.reasoning = output;
    value.text = '';
  }
  return value;
}

function disclosureProcess(operation: NativeMessage): NativeMessage {
  const group = disclosureMessage('process:disclosure', 'process', '');
  group.label = '工作过程';
  group.detail = '1 项操作';
  group.closed = true;
  group.children = [operation];
  return group;
}

function disclosurePlan(): NativePlanDocument {
  const document = new NativePlanDocument();
  document.parsed = true;
  const rows: string[][] = [
    ['核对展开态截图', 'completed'],
    ['检查长路径与文件操作', 'completed'],
    ['验证队列展开', 'in_progress'],
    ['复查最大字体', 'pending']
  ];
  rows.forEach((row: string[]): void => {
    const item = new NativePlanItem();
    item.content = row[0];
    item.status = row[1];
    document.items.push(item);
  });
  return document;
}

function disclosureDiffMessage(): NativeMessage {
  const payload = new DisclosureDiffPayload();
  const file = new DisclosureFileDiff();
  file.path = 'harmony/entry/src/main/ets/components/NativeProcessStepView.ets';
  const oldRows: string[] = [];
  const newRows: string[] = [];
  for (let index = 1; index <= 24; index++) {
    oldRows.push('const disclosureRow' + index.toString() + ' = ' + index.toString() + ';');
    newRows.push(index === 13 ?
      'const disclosureMiddleVisibleOnlyExpanded = 13;' :
      'const disclosureRow' + index.toString() + ' = ' + index.toString() + ';');
  }
  file.oldText = oldRows.join('\n');
  file.newText = newRows.join('\n');
  payload.diffs.push(file);
  return disclosureOperation('edit-disclosure-diff', '修改了文件',
    'NativeProcessStepView.ets', 'tool', 'edit', JSON.stringify(payload), '',
    '{"path":"harmony/entry/src/main/ets/components/NativeProcessStepView.ets"}');
}

function disclosureNestedProcess(): NativeMessage {
  const child = disclosureOperation('read-nested', '已读取文件',
    'NativeTaskDock.ets', 'tool', 'read',
    '{"path":"harmony/entry/src/main/ets/components/NativeTaskDock.ets"}',
    '1: const nestedDisclosureVisibleOnlyExpanded = true;',
    '{"path":"harmony/entry/src/main/ets/components/NativeTaskDock.ets","offset":1,' +
      '"totalLines":1,"lang":"typescript","lines":[{"number":1,' +
      '"text":"const nestedDisclosureVisibleOnlyExpanded = true;"}]}');
  child.callId = 'read-nested';
  child.parentCallId = 'command-parent';
  const parent = disclosureOperation('command-parent', '执行了命令',
    '检查嵌套调用', 'tool', 'exec_command',
    '{"command":"rg disclosure harmony/entry/src","workdir":"dsh-harmony"}',
    'command completed', '{"exitCode":0,"cwd":"dsh-harmony"}');
  parent.callId = 'command-parent';
  parent.children = [child];
  return disclosureProcess(parent);
}

function disclosureMalformedProcess(): NativeMessage {
  return disclosureProcess(disclosureOperation('read-malformed', '已读取文件',
    'NativeMalformedStructuredPayload.ets', 'tool', 'read',
    '{"path":"harmony/entry/src/main/ets/components/disclosure/deeply/nested/' +
      'NativeMalformedStructuredPayload.ets"}',
    'malformed-structured-output-only',
    '{"path":"harmony/entry/src/main/ets/components/disclosure/deeply/nested/' +
      'NativeMalformedStructuredPayload.ets","lines":[{"number":"invalid","text":42}]}'));
}

function disclosureEmptyProcess(): NativeMessage {
  return disclosureProcess(disclosureOperation('read-empty', '已读取文件',
    'EmptyStructuredResult.ets', 'tool', 'read',
    '{"path":"harmony/entry/src/main/ets/components/EmptyStructuredResult.ets"}',
    '',
    '{"path":"harmony/entry/src/main/ets/components/EmptyStructuredResult.ets",' +
      '"offset":0,"totalLines":0,"lines":[]}'));
}

function disclosureOversizedProcess(): NativeMessage {
  let children: string = '';
  for (let index = 0; index < 50; index++) {
    children += (index === 0 ? '' : ',') +
      '{"type":"text","text":"oversized-plugin-row-' + index.toString() + '"}';
  }
  const view = '{"dsh-go/view":{"type":"stack","title":"超长插件结果",' +
    '"children":[' + children + ']}}';
  return disclosureProcess(disclosureOperation('plugin-oversized', '已调用工具',
    '超长插件结果', 'tool', 'plugin_view', '{}', '', view));
}

function disclosureReadImageProcess(): NativeMessage {
  const operation = disclosureOperation('read-image', '已读取图片',
    'disclosure-preview.png', 'tool', 'read_image',
    '{"file_path":"artifacts/store/disclosure-preview.png"}',
    'read image',
    '{"path":"artifacts/store/disclosure-preview.png","width":1280,"height":720}');
  const image = new NativeImageAttachment();
  image.attachmentId = 'read-image-preview';
  image.mediaType = 'image/png';
  image.bytes = 24576;
  image.width = 1280;
  image.height = 720;
  image.name = 'disclosure-preview.png';
  operation.images = [image];
  return disclosureProcess(operation);
}

function disclosureProcessMessage(state: string): NativeMessage {
  if (state === 'disclosure-process-reasoning') {
    return disclosureProcess(disclosureOperation('reasoning', '思考过程',
      '核对展开边界', 'reasoning', '', '', '先核对标题与正文的边界。\n推理正文只在展开后显示。'));
  }
  if (state === 'disclosure-process-read') {
    return disclosureProcess(disclosureOperation('read', '已读取文件',
      'NativeTaskDock.ets', 'tool', 'read',
      '{"path":"harmony/entry/src/main/ets/components/NativeTaskDock.ets"}',
      '1: const disclosureValue = 42;',
      '{"path":"harmony/entry/src/main/ets/components/NativeTaskDock.ets","offset":1,' +
        '"totalLines":3,"lang":"typescript","lines":[{"number":1,' +
        '"text":"const disclosureValue = 42;"},{"number":2,' +
        '"text":"const headerHeight = NativeDesign.compactControl;"},{"number":3,' +
        '"text":"export struct NativeTaskDock {}"}]}'));
  }
  if (state === 'disclosure-process-search') {
    return disclosureProcess(disclosureOperation('search', '已搜索代码',
      'disclosure', 'tool', 'grep', '{"pattern":"disclosure","path":"harmony/entry/src"}', '',
      '{"total":2,"matches":[{"path":"harmony/entry/src/main/ets/components/NativeDiffBlock.ets",' +
        '"matches":[{"lineNumber":30,"line":"process-order-stable disclosure"}]}]}'));
  }
  if (state === 'disclosure-process-terminal') {
    return disclosureProcess(disclosureOperation('terminal', '执行了命令',
      '构建 Mock 变体', 'tool', 'exec_command',
      '{"command":"hvigorw assembleHap","description":"构建 Mock 变体","workdir":"harmony"}',
      'BUILD SUCCESSFUL\nGenerated entry-mock-signed.hap',
      '{"exitCode":0,"cwd":"C:/dsh-harmony/harmony"}'));
  }
  if (state === 'disclosure-process-diff') return disclosureProcess(disclosureDiffMessage());
  if (state === 'disclosure-process-nested') return disclosureNestedProcess();
  if (state === 'disclosure-process-malformed') return disclosureMalformedProcess();
  if (state === 'disclosure-process-empty') return disclosureEmptyProcess();
  if (state === 'disclosure-process-oversized') return disclosureOversizedProcess();
  if (state === 'disclosure-process-read-image') return disclosureReadImageProcess();
  if (state === 'disclosure-process-web') {
    return disclosureProcess(disclosureOperation('web', '已搜索网页',
      '展开态设计基线', 'tool', 'web_search', '{"query":"DSH disclosure design"}', '',
      '{"sources":[{"url":"https://example.com/design","title":"DSH Harmony 设计基线",' +
        '"snippet":"紧凑展开行与单一滚动容器。"}],"answer":"优先保证层级与触控。"}'));
  }
  if (state === 'disclosure-process-web-fetch') {
    return disclosureProcess(disclosureOperation('web-fetch', '已抓取网页',
      'disclosure.example', 'tool', 'web_fetch',
      '{"url":"https://example.com/disclosure"}', '',
      '{"url":"https://example.com/disclosure","statusCode":200,' +
        '"answer":"网页正文已抓取，字段与来源保持只读。","sources":[' +
        '{"url":"https://example.com/disclosure","title":"展开态正文",' +
        '"snippet":"web-fetch-body-only"}]}'));
  }
  if (state === 'disclosure-process-goal') {
    return disclosureProcess(disclosureOperation('goal', '更新了计划',
      '完成展开态验收', 'tool', 'get_goal', '{"objective":"完成展开态验收"}', '',
      '{"goal":{"objective":"完成展开态验收","phase":"验证中","roundsStarted":2,' +
        '"maxGoalRounds":6},"ref":{"revision":3}}'));
  }
  if (state === 'disclosure-process-job') {
    return disclosureProcess(disclosureOperation('job', '后台任务已结束',
      'showcase-job-42', 'tool', 'job_output',
      '{"job_id":"showcase-job-42"}', 'exit 0',
      '{"jobId":"showcase-job-42","state":"completed","command":"hvigorw assembleHap",' +
        '"exitCode":0}'));
  }
  if (state === 'disclosure-process-job-lifecycle') {
    return disclosureProcess(disclosureOperation('job-lifecycle', '后台任务状态',
      '构建任务', 'tool', 'job_lifecycle', '{}', '',
      '{"jobId":"showcase-job-42","kind":"background","label":"构建任务",' +
        '"status":"completed","detail":"job-lifecycle-detail-only","cause":"exit 0",' +
        '"toolCall":{"callId":"call-42","rootCallId":"root-42"}}'));
  }
  if (state === 'disclosure-process-subagent') {
    return disclosureProcess(disclosureOperation('agent', '已协调子代理',
      '展开态检查', 'tool', 'subagent',
      '{"description":"展开态检查","name":"reviewer","agent_id":"child-42"}', '',
      '{"subagentId":"child-42","state":"completed","runs":2}'));
  }
  if (state === 'disclosure-process-present') {
    return disclosureProcess(disclosureOperation('present', '已调用工具',
      'NativeTaskDock.ets', 'tool', 'present',
      '{"files":[{"path":"harmony/entry/src/main/ets/components/NativeTaskDock.ets",' +
        '"description":"可交互文件卡与紧凑展开头"}]}', '',
      '{}'));
  }
  if (state === 'disclosure-process-image') {
    return disclosureProcess(disclosureOperation('image', '已调用工具',
      'AI 生成图片', 'tool', 'generated_image', '{}', '',
      '{"dsh-go/media":{"kind":"image","status":"done","request":{"label":"商店展示图",' +
        '"model":"image-pro","aspect":"16:9","n":1},"items":[{"path":' +
        '"artifacts/store/disclosure-preview.png","mime":"image/png","width":640,' +
        '"height":480,"bytes":12288}]}}'));
  }
  if (state === 'disclosure-process-question') {
    return disclosureProcess(disclosureOperation('question', '向用户提出了问题',
      '折叠状态选择', 'tool', 'ask_user_question',
      '{"questions":[{"question":"哪些内容应保留？","options":[{"label":"始终保留"},' +
        '{"label":"按需折叠"}]}]}', '', '{}'));
  }
  if (state === 'disclosure-process-plugin') {
    return disclosureProcess(disclosureOperation('plugin', '已调用工具',
      '构建摘要', 'tool', 'plugin_view', '{}', '',
      '{"dsh-go/view":{"type":"stack","title":"构建摘要","children":[{"type":"text",' +
        '"text":"插件结果已渲染"},{"type":"metric","label":"用例","value":"24",' +
        '"tone":"good"}]}}'));
  }
  if (state === 'disclosure-process-plan') {
    return disclosureProcess(disclosureOperation('plan-tool', '更新了计划',
      '创建 1 · 进行中 1', 'tool', 'todo_write',
      '{"todos":[{"content":"核对展开态","status":"completed"},' +
        '{"content":"检查计划工具正文","status":"in_progress"}]}', '', '{}'));
  }
  if (state === 'disclosure-process-command') {
    return disclosureProcess(disclosureOperation('slash-command', '执行了命令',
      '/compact keep recent', 'tool', 'slash_command', '{}', '',
      '{"name":"compact","args":"keep recent","text":"slash-command-result-only",' +
        '"kind":"success"}'));
  }
  return disclosureProcess(disclosureOperation('read-default', '已读取文件',
    'NativeTaskDock.ets', 'tool', 'read',
    '{"path":"harmony/entry/src/main/ets/components/NativeTaskDock.ets"}',
    '1: const disclosureValue = 42;',
    '{"path":"harmony/entry/src/main/ets/components/NativeTaskDock.ets","lines":' +
      '[{"number":1,"text":"const disclosureValue = 42;"}]}'));
}

function disclosureDirectMessage(state: string): NativeMessage {
  if (state === 'disclosure-reasoning') {
    const reasoning = disclosureMessage('reasoning-direct', 'reasoning', '');
    reasoning.reasoning = '第一行说明摘要。\ndirect-reasoning-body-only';
    return reasoning;
  }
  const tool = disclosureOperation('legacy-tool', '执行了命令', '构建检查',
    'tool', 'exec_command', '{"command":"hvigorw assembleHap"}',
    'legacy-tool-output-only\nBUILD SUCCESSFUL');
  return tool;
}

function disclosureNotice(): NativeMessage {
  const value = disclosureMessage('background-notice', 'background-notice',
    '后台任务仍在运行。\nbackground-notice-body-only\n构建完成后会保留此记录。');
  value.sourceForm = 'notice';
  return value;
}

function disclosureQueue(): NativeQueueItem[] {
  const attachment = new NativeShowcaseAttachment();
  attachment.id = 'queue-file';
  attachment.kind = 'file';
  attachment.name = 'NativeTaskDock.ets';
  attachment.mediaType = 'text/plain';
  attachment.bytes = 4096;
  attachment.receiptId = 'queue-file-receipt';
  return [
    nativeShowcaseQueueItem('matrix-one', 'queue-expanded-row-one', []),
    nativeShowcaseQueueItem('matrix-two', 'queue-expanded-row-two', [attachment]),
    nativeShowcaseQueueItem('matrix-three', 'queue-expanded-row-three', [])
  ];
}

/** Mock-only workbench that mounts production disclosures without product routing. */
@Component
export struct NativeDisclosureFixture {
  @Prop state: string = 'disclosure-task-plan';
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  private plan: NativePlanDocument = disclosurePlan();
  private process: NativeMessage = disclosureProcessMessage('disclosure-process-read');
  private direct: NativeMessage = disclosureDirectMessage('disclosure-reasoning');
  private diff: NativeDiffDocument = nativeDiff(disclosureDiffMessage());
  private notice: NativeMessage = disclosureNotice();
  private queue: NativeQueueItem[] = disclosureQueue();

  aboutToAppear(): void {
    if (this.state.startsWith('disclosure-process-')) {
      this.process = disclosureProcessMessage(this.state);
    }
    if (this.state === 'disclosure-reasoning' || this.state === 'disclosure-legacy-tool') {
      this.direct = disclosureDirectMessage(this.state);
    }
  }

  private stateLabel(): string {
    if (this.state === 'disclosure-task-plan') return '任务计划';
    if (this.state === 'disclosure-queue') return '排队消息';
    if (this.state === 'disclosure-background-notice') return '后台任务消息';
    if (this.state === 'disclosure-reasoning') return '直接推理';
    if (this.state === 'disclosure-legacy-tool') return '旧版工具行';
    if (this.state === 'disclosure-diff') return '长 Diff';
    return this.state.replace('disclosure-process-', '过程 · ');
  }

  @Builder
  private content() {
    if (this.state === 'disclosure-task-plan') {
      NativeTaskDock({ document: this.plan, sessionId: 'disclosure-session' })
    } else if (this.state.startsWith('disclosure-process-')) {
      NativeProcessView({
        client: new NativeHarnessClient(''),
        sessionId: 'disclosure-session',
        workspaceRoot: 'dsh-harmony',
        message: this.process,
        maxExpandedHeight: 360,
        maxChildExpandedHeight: 300
      })
    } else if (this.state === 'disclosure-reasoning' || this.state === 'disclosure-legacy-tool') {
      NativeMessageView({
        client: new NativeHarnessClient(''),
        sessionId: 'disclosure-session',
        message: this.direct,
        preview: true
      })
    } else if (this.state === 'disclosure-diff') {
      NativeDiffBlock({ document: this.diff })
    } else if (this.state === 'disclosure-background-notice') {
      NativeBackgroundNoticeView({ message: this.notice })
    } else if (this.state === 'disclosure-queue') {
      NativeQueueDock({
        client: new NativeHarnessClient(''),
        sessionId: 'disclosure-session',
        items: this.queue,
        running: true
      })
    }
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('展开态验收').fontSize(NativeDesign.fontHeaderTitle).fontWeight(FontWeight.Medium)
          .fontColor(NativeDesign.textPrimary(this.dark))
        Text(this.stateLabel()).fontSize(NativeDesign.fontCaption).layoutWeight(1).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(NativeDesign.textTertiary(this.dark))
        Text(this.state).fontSize(NativeDesign.fontMicro).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(NativeDesign.accent(this.dark))
      }.width('100%').height(NativeDesign.headerHeight)
      Divider().color(NativeDesign.divider(this.dark))
      Column({ space: 12 }) {
        Text(this.stateLabel()).fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium)
          .fontColor(NativeDesign.textSecondary(this.dark))
        Column() {
          this.content()
        }.width('100%').padding(NativeDesign.cardPadding)
          .borderRadius(NativeDesign.radiusGroup)
          .backgroundColor(NativeDesign.subtleSurface(this.dark))
          .border({ width: 0.5, color: NativeDesign.border(this.dark) })
      }.layoutWeight(1).width('100%').alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
    }.width('100%').height('100%')
      .padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset,
        top: this.safeTop + NativeDesign.spaceS,
        bottom: this.safeBottom + NativeDesign.spaceS })
      .backgroundColor(NativeDesign.base(this.dark))
  }
}
