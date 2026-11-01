import { NativeHarnessClient } from './NativeHarnessClient';
import {
  NativeAutomationCatalog,
  NativeAutomationDraft,
  NativeAutomationHistory,
  NativeAutomationTask,
  NativePluginChange,
  NativePluginInspection,
  NativePluginInventory,
  NativePluginVersionList
} from './NativeAdminModels';

class PluginsListRequest {
  operation: string = 'pluginsList';
}

class PluginSetEnabledRequest {
  operation: string = 'pluginSetEnabled';
  name: string;
  enabled: boolean;

  constructor(name: string, enabled: boolean) {
    this.name = name;
    this.enabled = enabled;
  }
}

class PluginSetRowEnabledRequest {
  operation: string = 'pluginSetRowEnabled';
  entryId: string;
  enabled: boolean;

  constructor(entryId: string, enabled: boolean) {
    this.entryId = entryId;
    this.enabled = enabled;
  }
}

class PluginInspectRequest {
  operation: string = 'pluginInspect';
  spec: string;

  constructor(spec: string) {
    this.spec = spec;
  }
}

class PluginInstallRequest {
  operation: string = 'pluginInstall';
  spec: string;
  enabled: boolean = true;
  approvedBuilds: string[];

  constructor(spec: string, approvedBuilds: string[]) {
    this.spec = spec;
    this.approvedBuilds = approvedBuilds;
  }
}

class PluginRemoveRequest {
  operation: string = 'pluginRemove';
  name: string;

  constructor(name: string) {
    this.name = name;
  }
}

class PluginVersionsRequest {
  operation: string = 'pluginVersions';
  name: string;

  constructor(name: string) {
    this.name = name;
  }
}

class PluginUpdateRequest {
  operation: string = 'pluginUpdate';
  name: string;
  version: string;

  constructor(name: string, version: string) {
    this.name = name;
    this.version = version;
  }
}

class AutomationListRequest {
  operation: string = 'automationList';
}

class AutomationViewRequest {
  operation: string = 'automationView';
  id: string;

  constructor(id: string) {
    this.id = id;
  }
}

class AutomationHistoryRequest {
  operation: string = 'automationHistory';
  id: string;
  limit: number;
  before?: string;

  constructor(id: string, limit: number, before: string) {
    this.id = id;
    this.limit = limit;
    if (before) this.before = before;
  }
}

class AutomationDailyTiming {
  time: string;
  time_zone: string;

  constructor(time: string, timeZone: string) {
    this.time = time;
    this.time_zone = timeZone;
  }
}

class AutomationWeeklyTiming {
  time: string;
  time_zone: string;
  weekdays: number[];

  constructor(time: string, timeZone: string, weekdays: number[]) {
    this.time = time;
    this.time_zone = timeZone;
    this.weekdays = weekdays;
  }
}

class AutomationCronTiming {
  expression: string;
  time_zone: string;

  constructor(expression: string, timeZone: string) {
    this.expression = expression;
    this.time_zone = timeZone;
  }
}

class AutomationAtTiming {
  date: string;
  time: string;
  time_zone: string;

  constructor(date: string, time: string, timeZone: string) {
    this.date = date;
    this.time = time;
    this.time_zone = timeZone;
  }
}

class AutomationTimingPayload {
  kind: string;
  after_seconds?: number;
  every_seconds?: number;
  daily?: AutomationDailyTiming;
  weekly?: AutomationWeeklyTiming;
  cron?: AutomationCronTiming;
  at?: AutomationAtTiming;
  rrule?: string;

  constructor(kind: string) {
    this.kind = kind;
  }
}

class AutomationSessionCreatePayload {
  cwd?: string;
  agentPreset?: string;

  constructor(cwd: string, agentPreset: string) {
    if (cwd) this.cwd = cwd;
    if (agentPreset) this.agentPreset = agentPreset;
  }
}

class AutomationTargetPayload {
  kind: string;
  sessionId?: string;
  create?: AutomationSessionCreatePayload;

  constructor(kind: string, sessionId: string, cwd: string, agentPreset: string) {
    this.kind = kind;
    if (kind === 'session') {
      this.sessionId = sessionId;
    } else if (cwd || agentPreset) {
      this.create = new AutomationSessionCreatePayload(cwd, agentPreset);
    }
  }
}

class AutomationCreatePayload {
  title: string;
  prompt: string;
  timing: AutomationTimingPayload;
  target: AutomationTargetPayload;

  constructor(title: string, prompt: string, timing: AutomationTimingPayload, target: AutomationTargetPayload) {
    this.title = title;
    this.prompt = prompt;
    this.timing = timing;
    this.target = target;
  }
}

class AutomationCreateEnvelope {
  operation: string = 'automationCreate';
  request: AutomationCreatePayload;

  constructor(request: AutomationCreatePayload) {
    this.request = request;
  }
}

class AutomationPatchPayload {
  title?: string;
  prompt?: string;
  timing?: AutomationTimingPayload;
  target?: AutomationTargetPayload;
  active?: boolean;
}

class AutomationEditPayload {
  id: string;
  action: string = 'update';
  expectedUpdatedAt: string | null;
  patch: AutomationPatchPayload;

  constructor(id: string, expectedUpdatedAt: string, patch: AutomationPatchPayload) {
    this.id = id;
    this.expectedUpdatedAt = expectedUpdatedAt || null;
    this.patch = patch;
  }
}

class AutomationEditEnvelope {
  operation: string = 'automationEdit';
  request: AutomationEditPayload;

  constructor(request: AutomationEditPayload) {
    this.request = request;
  }
}

class AutomationRunRequest {
  operation: string = 'automationRun';
  id: string;

  constructor(id: string) {
    this.id = id;
  }
}

class AutomationDeleteRequest {
  operation: string = 'automationDelete';
  id: string;
  expectedUpdatedAt: string | null;

  constructor(id: string, expectedUpdatedAt: string) {
    this.id = id;
    this.expectedUpdatedAt = expectedUpdatedAt || null;
  }
}

export class NativeAdminClient {
  private readonly harness: NativeHarnessClient;

  constructor(harness: NativeHarnessClient) {
    this.harness = harness;
  }

  private async call(body: Object): Promise<string> {
    return this.harness.operation(JSON.stringify(body));
  }

  async plugins(): Promise<NativePluginInventory> {
    return JSON.parse(await this.call(new PluginsListRequest())) as NativePluginInventory;
  }

  async setBundleEnabled(name: string, enabled: boolean): Promise<NativePluginChange> {
    return JSON.parse(await this.call(new PluginSetEnabledRequest(name, enabled))) as NativePluginChange;
  }

  async setRowEnabled(entryId: string, enabled: boolean): Promise<NativePluginChange> {
    return JSON.parse(await this.call(new PluginSetRowEnabledRequest(entryId, enabled))) as NativePluginChange;
  }

  async inspect(spec: string): Promise<NativePluginInspection> {
    return JSON.parse(await this.call(new PluginInspectRequest(spec))) as NativePluginInspection;
  }

  async install(spec: string, approvedBuilds: string[] = []): Promise<NativePluginChange> {
    return JSON.parse(await this.call(new PluginInstallRequest(spec, approvedBuilds))) as NativePluginChange;
  }

  async remove(name: string): Promise<NativePluginChange> {
    return JSON.parse(await this.call(new PluginRemoveRequest(name))) as NativePluginChange;
  }

  async versions(name: string): Promise<NativePluginVersionList> {
    return JSON.parse(await this.call(new PluginVersionsRequest(name))) as NativePluginVersionList;
  }

  async update(name: string, version: string): Promise<NativePluginChange> {
    return JSON.parse(await this.call(new PluginUpdateRequest(name, version))) as NativePluginChange;
  }

  async automations(): Promise<NativeAutomationCatalog> {
    return JSON.parse(await this.call(new AutomationListRequest())) as NativeAutomationCatalog;
  }

  async automation(id: string): Promise<NativeAutomationTask> {
    return JSON.parse(await this.call(new AutomationViewRequest(id))) as NativeAutomationTask;
  }

  async history(id: string, before: string = '', limit: number = 30): Promise<NativeAutomationHistory> {
    return JSON.parse(await this.call(new AutomationHistoryRequest(id, limit, before))) as NativeAutomationHistory;
  }

  async createAutomation(draft: NativeAutomationDraft): Promise<NativeAutomationTask> {
    return JSON.parse(await this.call(new AutomationCreateEnvelope(
      new AutomationCreatePayload(draft.title.trim(), draft.prompt.trim(),
        this.timing(draft), this.target(draft))))) as NativeAutomationTask;
  }

  async updateAutomation(task: NativeAutomationTask, draft: NativeAutomationDraft): Promise<NativeAutomationTask> {
    const patch = new AutomationPatchPayload();
    patch.title = draft.title.trim();
    patch.prompt = draft.prompt.trim();
    patch.timing = this.timing(draft);
    patch.target = this.target(draft);
    return JSON.parse(await this.call(new AutomationEditEnvelope(
      new AutomationEditPayload(task.id, task.updatedAt, patch)))) as NativeAutomationTask;
  }

  async setAutomationActive(task: NativeAutomationTask, active: boolean): Promise<NativeAutomationTask> {
    const patch = new AutomationPatchPayload();
    patch.active = active;
    return JSON.parse(await this.call(new AutomationEditEnvelope(
      new AutomationEditPayload(task.id, task.updatedAt, patch)))) as NativeAutomationTask;
  }

  async runAutomation(task: NativeAutomationTask): Promise<NativeAutomationTask> {
    return JSON.parse(await this.call(new AutomationRunRequest(task.id))) as NativeAutomationTask;
  }

  async deleteAutomation(task: NativeAutomationTask): Promise<void> {
    await this.call(new AutomationDeleteRequest(task.id, task.updatedAt));
  }

  private timing(draft: NativeAutomationDraft): AutomationTimingPayload {
    const interval = Math.max(1, Number(draft.interval) || 1) * 60;
    const timing = new AutomationTimingPayload(draft.kind);
    if (draft.kind === 'after') {
      timing.after_seconds = interval;
    } else if (draft.kind === 'every') {
      timing.every_seconds = interval;
    } else if (draft.kind === 'daily') {
      timing.daily = new AutomationDailyTiming(draft.time + ':00', draft.timeZone.trim());
    } else if (draft.kind === 'weekly') {
      timing.weekly = new AutomationWeeklyTiming(draft.time + ':00', draft.timeZone.trim(),
        draft.weekdays.slice());
    } else if (draft.kind === 'cron') {
      timing.cron = new AutomationCronTiming(draft.expression.trim(), draft.timeZone.trim());
    } else if (draft.kind === 'at') {
      timing.at = new AutomationAtTiming(draft.atDate.trim(), draft.atTime.trim() + ':00',
        draft.timeZone.trim());
    } else {
      timing.rrule = draft.rrule.trim();
    }
    return timing;
  }

  private target(draft: NativeAutomationDraft): AutomationTargetPayload {
    return new AutomationTargetPayload(draft.targetKind, draft.sessionId.trim(),
      draft.cwd.trim(), draft.agentPreset.trim());
  }
}
