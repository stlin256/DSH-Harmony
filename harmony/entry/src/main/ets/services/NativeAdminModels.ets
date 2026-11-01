export class NativePluginRow {
  rowId: string = '';
  moduleName: string = '';
  entryId: string = '';
  title: string = '';
  description: string = '';
  metadataError: string = '';
}

export class NativePluginError {
  code: string = '';
  diagnostic: string = '';
}

export class NativePluginBundle {
  name: string = '';
  official: boolean = false;
  availability: string = '';
  installed: boolean = false;
  enabled: boolean = false;
  removable: boolean = false;
  updatable: boolean = false;
  optional: boolean = false;
  listedByDefault: boolean | undefined = undefined;
  version: string = '';
  description: string = '';
  title: string = '';
  localizedDescription: string = '';
  metadataError: string = '';
  source: string = '';
  readOnlyReason: string = '';
  installSpec: string = '';
  installVersion: string = '';
  errorCode: string = '';
  errorDiagnostic: string = '';
  rows: NativePluginRow[] = [];
}

export class NativePluginEntry {
  entryId: string = '';
  moduleName: string = '';
  title: string = '';
  description: string = '';
  enabled: boolean = false;
  phase: string = '';
  diagnostic: string = '';
  readOnlyReason: string = '';
}

export class NativePluginInventory {
  available: boolean = false;
  bundles: NativePluginBundle[] = [];
  plugins: NativePluginEntry[] = [];
}

export class NativePluginChange {
  changed: boolean = false;
  application: string = '';
  stage: string = '';
  target: string = '';
  enabled: boolean | undefined = undefined;
  restartReason: string = '';
  errorCode: string = '';
  errorDiagnostic: string = '';
  failedAt: string = '';
  bundle: string = '';
  version: string = '';
  pendingBuilds: string[] = [];
}

export class NativePluginInspection {
  status: string = '';
  kind: string = '';
  name: string = '';
  version: string = '';
  description: string = '';
  bundle: boolean | null = null;
  registry: string | null = null;
  host: string = '';
  problem: string = '';
  reason: string = '';
  registries: string[] = [];
}

export class NativePluginVersion {
  version: string = '';
  tags: string[] = [];
  prerelease: boolean = false;
  deprecated: string = '';
  bundle: boolean = false;
  incompatibleCode: string = '';
}

export class NativePluginVersionList {
  status: string = '';
  installed: string = '';
  registry: string | null = null;
  omitted: number = 0;
  problem: string = '';
  reason: string = '';
  versions: NativePluginVersion[] = [];
}

export class NativeAutomationTask {
  id: string = '';
  kind: string = '';
  status: string = 'active';
  title: string = '';
  prompt: string = '';
  scheduledAt: string = '';
  timeZone: string = '';
  everySeconds: number = 0;
  afterSeconds: number = 0;
  time: string = '';
  weekdays: number[] = [];
  expression: string = '';
  rrule: string = '';
  targetKind: string = '';
  targetSessionId: string = '';
  targetCwd: string = '';
  targetAgentPreset: string = '';
  executionActive: boolean = false;
  deliveryFloorEndsAt: string = '';
  createdAt: string = '';
  updatedAt: string = '';
  lastDeliveryAt: string = '';
}

export class NativeAutomationCatalog {
  available: boolean = false;
  items: NativeAutomationTask[] = [];
}

export class NativeAutomationDelivery {
  scheduledAt: string = '';
  deliveredAt: string = '';
  messageId: string = '';
  targetSessionId: string = '';
  prompt: string = '';
}

export class NativeAutomationHistory {
  available: boolean = false;
  code: string = '';
  records: NativeAutomationDelivery[] = [];
  earlierRecordsUnavailable: boolean = false;
  earlierRecordsPruned: boolean = false;
  nextBefore: string = '';
}

export class NativeAutomationDraft {
  title: string = '';
  prompt: string = '';
  kind: string = 'every';
  interval: string = '30';
  time: string = '09:00';
  timeZone: string = 'Asia/Shanghai';
  weekdays: number[] = [1, 3, 5];
  expression: string = '0 9 * * *';
  rrule: string = '';
  atDate: string = '';
  atTime: string = '';
  targetKind: string = 'new_once';
  sessionId: string = '';
  cwd: string = '';
  agentPreset: string = '';
  updatedAt: string = '';
}

export class NativePluginActionResult {
  ok: boolean = false;
  restartRequired: boolean = false;
  message: string = '';
  pendingBuilds: string[] = [];
}

export function nativePluginTitle(bundle: NativePluginBundle): string {
  return bundle.title || bundle.name || '未命名插件';
}

export function nativePluginDescription(bundle: NativePluginBundle): string {
  return bundle.localizedDescription || bundle.description || '';
}

export function nativePluginPhase(value: string): string {
  if (value === 'active') return '运行中';
  if (value === 'loading') return '加载中';
  if (value === 'unloading') return '卸载中';
  if (value === 'failed') return '失败';
  if (value === 'pending') return '等待';
  return '未运行';
}

export function nativePluginApplication(value: string): string {
  if (value === 'applied') return '已应用';
  if (value === 'restart-required') return '重启后生效';
  if (value === 'overridden') return '被更高优先级覆盖';
  if (value === 'cancelled') return '已取消';
  if (value === 'failed') return '操作失败';
  return '处理中';
}

export function nativePluginErrorText(code: string): string {
  if (code === 'management-required') return '此插件由 DSH 管理，不能在此关闭';
  if (code === 'unaddressable') return '此插件不能在当前 Profile 中修改';
  if (code === 'not-removable') return '此插件不能移除';
  if (code === 'bundle-in-use') return '插件仍在运行，请重试';
  if (code === 'already-installed') return '插件已经安装';
  if (code === 'unsupported-platform') return '当前平台不支持此插件';
  if (code === 'incompatible-version') return '插件与当前 DSH 版本不兼容';
  if (code === 'stale-approval') return '构建脚本授权已过期';
  if (code === 'schedule_conflict') return '任务已在其他端更新';
  if (code === 'schedule_execution_pending') return '任务正在执行';
  if (code === 'schedule_not_found') return '任务不存在';
  return code || '操作未完成';
}

export function nativeAutomationStatus(value: string): string {
  if (value === 'active') return '运行中';
  if (value === 'paused') return '已暂停';
  if (value === 'ended') return '已结束';
  return '未知';
}

export function nativeAutomationKind(value: string): string {
  if (value === 'after') return '稍后一次';
  if (value === 'at') return '指定时间';
  if (value === 'every') return '固定间隔';
  if (value === 'daily') return '每天';
  if (value === 'weekly') return '每周';
  if (value === 'cron') return 'Cron';
  if (value === 'rrule') return '自定义规则';
  return '定时';
}

export function nativeAutomationInterval(seconds: number): string {
  if (seconds > 0 && seconds % 3600 === 0) return String(seconds / 3600) + ' 小时';
  if (seconds > 0 && seconds % 60 === 0) return String(seconds / 60) + ' 分钟';
  return Math.max(1, seconds) + ' 秒';
}

export function nativeAutomationWeekdays(values: number[]): string {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return values.slice().sort().map((day: number): string =>
    labels[Math.max(0, Math.min(6, day - 1))]).join('、');
}

export function nativeAutomationRule(task: NativeAutomationTask): string {
  if (task.kind === 'after') return '稍后 ' + nativeAutomationInterval(task.afterSeconds);
  if (task.kind === 'at') return '指定时间';
  if (task.kind === 'every') return '每 ' + nativeAutomationInterval(task.everySeconds);
  if (task.kind === 'daily') return '每天 ' + (task.time || task.scheduledAt);
  if (task.kind === 'weekly') return '每周 ' + nativeAutomationWeekdays(task.weekdays) +
    ' ' + (task.time || '');
  if (task.kind === 'cron') return task.expression || 'Cron';
  if (task.kind === 'rrule') return '自定义循环';
  return nativeAutomationKind(task.kind);
}

export function nativeAutomationTarget(task: NativeAutomationTask): string {
  if (task.targetKind === 'session') return task.targetSessionId || '已有会话';
  if (task.targetKind === 'new_once') return '新会话 · 创建一次后复用';
  if (task.targetKind === 'new') return '每次新建会话';
  return '新建会话';
}

export function nativeAutomationMatches(task: NativeAutomationTask, status: string,
  query: string): boolean {
  if (status !== 'all' && task.status !== status) return false;
  const search = query.trim().toLowerCase();
  if (!search) return true;
  return (task.title + ' ' + task.prompt + ' ' + task.targetSessionId + ' ' +
    nativeAutomationRule(task)).toLowerCase().includes(search);
}

export function nativeAutomationTimestamp(value: string): string {
  if (!value) return '未记录';
  const time = Date.parse(value);
  if (!Number.isFinite(time)) return value;
  const date = new Date(time);
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  const hour = date.getHours().toString().padStart(2, '0');
  const minute = date.getMinutes().toString().padStart(2, '0');
  return month + '/' + day + ' ' + hour + ':' + minute;
}

export function nativeAutomationDraftFromTask(task: NativeAutomationTask): NativeAutomationDraft {
  const draft = new NativeAutomationDraft();
  draft.title = task.title;
  draft.prompt = task.prompt;
  draft.kind = task.kind || 'every';
  draft.interval = String(Math.max(1, Math.round(
    (task.kind === 'after' ? task.afterSeconds : task.everySeconds) / 60)));
  draft.time = task.time ? task.time.slice(0, 5) : '09:00';
  draft.timeZone = task.timeZone || 'Asia/Shanghai';
  draft.weekdays = task.weekdays.length ? task.weekdays.slice() : [1, 3, 5];
  draft.expression = task.expression || '0 9 * * *';
  draft.rrule = task.rrule || '';
  draft.atDate = task.scheduledAt ? task.scheduledAt.slice(0, 10) : '';
  draft.atTime = task.scheduledAt ? task.scheduledAt.slice(11, 16) : '';
  draft.targetKind = task.targetKind || 'new_once';
  draft.sessionId = task.targetSessionId || '';
  draft.cwd = task.targetCwd || '';
  draft.agentPreset = task.targetAgentPreset || '';
  draft.updatedAt = task.updatedAt || '';
  return draft;
}

export function nativeAutomationDraftValid(draft: NativeAutomationDraft): boolean {
  if (!draft.title.trim() || draft.title.trim().length > 120 || !draft.prompt.trim()) return false;
  if ((draft.kind === 'after' || draft.kind === 'every') &&
    (!/^[1-9]\d*$/.test(draft.interval) || !Number.isSafeInteger(Number(draft.interval)))) return false;
  if (['daily', 'weekly'].includes(draft.kind) && !/^([01]\d|2[0-3]):[0-5]\d$/.test(draft.time)) return false;
  if (draft.kind === 'weekly' && !draft.weekdays.length) return false;
  if (draft.kind === 'cron' && draft.expression.trim().split(/\s+/).length !== 5) return false;
  if (draft.kind === 'rrule' && !draft.rrule.trim()) return false;
  if (draft.kind === 'at' && (!draft.atDate.trim() || !draft.atTime.trim())) return false;
  if (draft.targetKind === 'session' && !draft.sessionId.trim()) return false;
  return true;
}
