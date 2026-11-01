const PLUGIN_BUNDLE_LIMIT = 200;
const PLUGIN_ROW_LIMIT = 240;
const PLUGIN_ENTRY_LIMIT = 500;
const AUTOMATION_LIMIT = 500;
const HISTORY_LIMIT = 100;

const pluginAvailability = new Set(['installation', 'profile', 'missing']);
const pluginApplication = new Set([
  'applied', 'restart-required', 'overridden', 'failed', 'cancelled'
]);
const pluginStage = new Set(['install', 'enable', 'remove']);
const scheduleKinds = new Set(['after', 'at', 'every', 'daily', 'weekly', 'cron', 'rrule']);
const scheduleStatuses = new Set(['active', 'paused', 'ended']);
const targetKinds = new Set(['session', 'new_once', 'new']);

function record(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
}

function text(value, maxLength) {
  if (typeof value !== 'string') return '';
  return value.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, ' ')
    .trim().slice(0, maxLength);
}

function optionalText(value, maxLength) {
  const result = text(value, maxLength);
  return result || undefined;
}

function boolean(value, fallback = false) {
  return typeof value === 'boolean' ? value : fallback;
}

function positiveInteger(value) {
  return Number.isSafeInteger(value) && value > 0 ? value : undefined;
}

function pluginPackageName(value) {
  const result = optionalText(value, 512);
  if (!result || /[\s\\]/.test(result) || result.split('/').some(part => part === '' || part === '.' || part === '..')) {
    return undefined;
  }
  return result;
}

function localizedText(value, maxLength = 4000) {
  if (typeof value === 'string') return optionalText(value, maxLength);
  const source = record(value);
  if (!source) return undefined;
  for (const key of ['zh-cn', 'zh', 'en']) {
    const result = optionalText(source[key], maxLength);
    if (result) return result;
  }
  return Object.keys(source).sort().map(key => optionalText(source[key], maxLength))
    .find(Boolean);
}

function normalizedError(value) {
  const source = record(value);
  if (!source) return undefined;
  const code = optionalText(source.code, 120);
  if (!code) return undefined;
  return {
    code,
    ...(optionalText(source.diagnostic, 4000) ? { diagnostic: text(source.diagnostic, 4000) } : {})
  };
}

/** Normalize one bundle without forwarding arbitrary Host fields. */
export function normalizePluginBundle(value) {
  const source = record(value);
  if (!source) return null;
  const name = pluginPackageName(source.name);
  if (!name || !pluginAvailability.has(source.availability)) return null;
  const meta = record(source.meta);
  const target = record(source.installTarget);
  const rows = [];
  for (const item of Array.isArray(source.rows) ? source.rows.slice(0, PLUGIN_ROW_LIMIT) : []) {
    const row = record(item);
    const rowId = optionalText(row?.rowId, 512);
    const moduleName = optionalText(row?.moduleName, 4096);
    if (!rowId || !moduleName) continue;
    const rowMeta = record(row.meta);
    rows.push({
      rowId,
      moduleName,
      entryId: optionalText(row.entryId, 512),
      title: localizedText(rowMeta?.title, 300),
      description: localizedText(rowMeta?.description, 3000),
      metadataError: optionalText(rowMeta?.error, 3000)
    });
  }
  const error = normalizedError(source.error);
  return {
    name,
    official: boolean(source.official),
    availability: source.availability,
    installed: boolean(source.installed),
    enabled: boolean(source.enabled),
    removable: boolean(source.removable),
    updatable: boolean(source.updatable),
    optional: boolean(source.optional),
    ...(typeof source.listedByDefault === 'boolean' ? { listedByDefault: source.listedByDefault } : {}),
    version: optionalText(source.version, 160),
    description: optionalText(source.description, 4000),
    title: localizedText(meta?.title, 300),
    localizedDescription: localizedText(meta?.description, 4000),
    metadataError: optionalText(meta?.error, 3000),
    source: optionalText(source.source, 4096),
    readOnlyReason: optionalText(source.readOnlyReason, 120),
    installSpec: optionalText(target?.spec, 4096),
    installVersion: optionalText(target?.version, 160),
    errorCode: error?.code,
    errorDiagnostic: error?.diagnostic,
    rows
  };
}

/** Normalize one live plugin Loader entry. */
export function normalizePluginEntry(value) {
  const source = record(value);
  if (!source) return null;
  const entryId = optionalText(source.entryId, 512);
  const moduleName = optionalText(source.moduleName, 4096);
  if (!entryId || !moduleName) return null;
  const phases = new Set(['pending', 'loading', 'active', 'failed', 'unloading']);
  const meta = record(source.meta);
  return {
    entryId,
    moduleName,
    title: localizedText(meta?.title, 300),
    description: localizedText(meta?.description, 3000),
    enabled: boolean(source.enabled),
    phase: phases.has(source.fiberPhase) ? source.fiberPhase : null,
    diagnostic: optionalText(source.diagnostic, 4000),
    readOnlyReason: optionalText(source.readOnlyReason, 120)
  };
}

/** Join bounded bundle and entry snapshots for the native plugin page. */
export function normalizePluginInventory(bundles, plugins) {
  return {
    available: true,
    bundles: (Array.isArray(bundles) ? bundles : []).slice(0, PLUGIN_BUNDLE_LIMIT)
      .map(normalizePluginBundle).filter(Boolean),
    plugins: (Array.isArray(plugins) ? plugins : []).slice(0, PLUGIN_ENTRY_LIMIT)
      .map(normalizePluginEntry).filter(Boolean)
  };
}

/** Normalize one persisted plugin-management outcome. */
export function normalizePluginChange(value) {
  const source = record(value);
  if (!source || !pluginApplication.has(source.application) ||
      !pluginStage.has(source.stage)) return null;
  const error = normalizedError(source.error);
  const pendingBuilds = Array.isArray(source.pendingBuilds)
    ? source.pendingBuilds.slice(0, 100).map(item => optionalText(item, 512)).filter(Boolean)
    : [];
  return {
    changed: boolean(source.changed),
    application: source.application,
    stage: source.stage,
    target: text(source.target, 4096),
    ...(typeof source.enabled === 'boolean' ? { enabled: source.enabled } : {}),
    restartReason: optionalText(source.restartReason, 120),
    errorCode: error?.code,
    errorDiagnostic: error?.diagnostic,
    failedAt: optionalText(source.failedAt, 120),
    bundle: optionalText(source.bundle, 512),
    version: optionalText(source.version, 160),
    pendingBuilds
  };
}

/** Normalize install inspection into the fields the native form can safely show. */
export function normalizePluginInspection(value) {
  const source = record(value);
  if (!source) return null;
  if (source.status === 'accepted') {
    const kind = new Set(['registry', 'path', 'git', 'tarball']);
    if (!kind.has(source.kind)) return null;
    return {
      status: 'accepted',
      kind: source.kind,
      name: optionalText(source.name, 512),
      version: optionalText(source.version, 160),
      description: optionalText(source.description, 4000),
      bundle: typeof source.bundle === 'boolean' ? source.bundle : null,
      registry: typeof source.registry === 'string' ? text(source.registry, 4096) : null,
      host: optionalText(source.host, 512)
    };
  }
  if (source.status === 'refused') {
    const problem = optionalText(source.problem, 120);
    if (!problem) return null;
    return {
      status: 'refused',
      problem,
      reason: optionalText(source.reason, 4000),
      registries: Array.isArray(source.registries)
        ? source.registries.slice(0, 20).map(item => typeof item === 'string'
          ? text(item, 4096) : null)
        : []
    };
  }
  return null;
}

/** Normalize a published-version list while retaining update decisions only. */
export function normalizePluginVersions(value) {
  const source = record(value);
  if (!source) return null;
  if (source.status === 'refused') {
    return {
      status: 'refused',
      problem: optionalText(source.problem, 120),
      reason: optionalText(source.reason, 4000),
      versions: []
    };
  }
  if (source.status !== 'listed') return null;
  return {
    status: 'listed',
    installed: optionalText(source.installed, 160),
    registry: typeof source.registry === 'string' ? text(source.registry, 4096) : null,
    omitted: Number.isSafeInteger(source.omitted) && source.omitted >= 0 ? source.omitted : 0,
    versions: (Array.isArray(source.versions) ? source.versions : []).slice(0, 50).map(item => {
      const row = record(item);
      const version = optionalText(row?.version, 160);
      if (!version) return null;
      return {
        version,
        tags: Array.isArray(row.tags) ? row.tags.slice(0, 20).map(tag => optionalText(tag, 120))
          .filter(Boolean) : [],
        prerelease: boolean(row.prerelease),
        deprecated: optionalText(row.deprecated, 2000),
        bundle: boolean(row.bundle),
        incompatibleCode: optionalText(record(row.incompatible)?.code, 120)
      };
    }).filter(Boolean)
  };
}

/** Normalize one durable Schedule entry. */
export function normalizeAutomationTask(value) {
  const source = record(value);
  if (!source || !scheduleKinds.has(source.kind) || !scheduleStatuses.has(source.status)) return null;
  const id = optionalText(source.id, 200);
  const title = optionalText(source.title, 120);
  const prompt = optionalText(source.prompt, 16000);
  const scheduledAt = optionalText(source.scheduledAt, 80);
  if (!id || !title || !prompt || !scheduledAt) return null;
  const target = record(source.target);
  if (!target || !targetKinds.has(target.kind)) return null;
  const lastDelivery = record(source.lastDelivery);
  const weekdays = Array.isArray(source.weekdays)
    ? source.weekdays.filter(day => Number.isInteger(day) && day >= 1 && day <= 7).slice(0, 7)
    : [];
  return {
    id,
    kind: source.kind,
    status: source.status,
    title,
    prompt,
    scheduledAt,
    timeZone: optionalText(source.timeZone, 120),
    everySeconds: positiveInteger(source.everySeconds),
    afterSeconds: positiveInteger(source.afterSeconds),
    time: optionalText(source.time, 32),
    weekdays,
    expression: optionalText(source.expression, 300),
    rrule: optionalText(source.rrule, 4000),
    targetKind: target.kind,
    targetSessionId: optionalText(target.sessionId, 200),
    targetCwd: optionalText(record(target.create)?.cwd, 4096),
    targetAgentPreset: optionalText(record(target.create)?.agentPreset, 300),
    executionActive: source.executionActive === true,
    deliveryFloorEndsAt: optionalText(source.deliveryFloorEndsAt, 80),
    createdAt: optionalText(source.createdAt, 80),
    updatedAt: optionalText(source.updatedAt, 80),
    lastDeliveryAt: optionalText(lastDelivery?.deliveredAt, 80)
  };
}

/** Normalize and deterministically sort the Host-wide automation catalog. */
export function normalizeAutomationCatalog(value) {
  const rows = (Array.isArray(value) ? value : []).slice(0, AUTOMATION_LIMIT)
    .map(normalizeAutomationTask).filter(Boolean);
  rows.sort((left, right) => {
    if (left.status === 'active' && right.status !== 'active') return -1;
    if (right.status === 'active' && left.status !== 'active') return 1;
    const leftTime = Date.parse(left.status === 'active' ? left.scheduledAt :
      (left.updatedAt || left.scheduledAt));
    const rightTime = Date.parse(right.status === 'active' ? right.scheduledAt :
      (right.updatedAt || right.scheduledAt));
    return (Number.isFinite(leftTime) ? leftTime : Number.MAX_SAFE_INTEGER) -
      (Number.isFinite(rightTime) ? rightTime : Number.MAX_SAFE_INTEGER) ||
      left.id.localeCompare(right.id);
  });
  return { available: true, items: rows };
}

/** Normalize one bounded delivery-history response. */
export function normalizeAutomationHistory(value) {
  const source = record(value);
  if (!source) return null;
  if (source.code === 'schedule_not_found' || source.code === 'delivery_cursor_not_found') {
    return {
      available: false,
      code: source.code,
      records: [],
      earlierRecordsUnavailable: false,
      earlierRecordsPruned: false,
      nextBefore: undefined
    };
  }
  if (!Array.isArray(source.records)) return null;
  const records = source.records.slice(0, HISTORY_LIMIT).map(item => {
    const row = record(item);
    const scheduledAt = optionalText(row?.scheduledAt, 80);
    const deliveredAt = optionalText(row?.deliveredAt, 80);
    if (!scheduledAt || !deliveredAt) return null;
    return {
      scheduledAt,
      deliveredAt,
      messageId: optionalText(row.messageId, 200),
      targetSessionId: optionalText(row.targetSessionId, 200),
      prompt: optionalText(row.prompt, 16000)
    };
  }).filter(Boolean);
  return {
    available: true,
    records,
    earlierRecordsUnavailable: boolean(source.earlierRecordsUnavailable),
    earlierRecordsPruned: boolean(source.earlierRecordsPruned),
    nextBefore: optionalText(source.nextBefore, 200)
  };
}

function validIdentifier(value, maxLength = 200) {
  return typeof value === 'string' && value.length > 0 && value.length <= maxLength &&
    !/[\u0000-\u0020\u007f/\\]/.test(value);
}

function requiredText(value, maxLength) {
  if (typeof value !== 'string' || value.includes('\u0000')) return null;
  const result = value.trim();
  return result && result.length <= maxLength ? result : null;
}

/** Validate a plugin package name or install spec. */
export function pluginSpec(value) {
  return requiredText(value, 4096);
}

/** Validate one supported schedule timing selector. */
export function automationTiming(value) {
  const source = record(value);
  if (!source || !scheduleKinds.has(source.kind)) return null;
  if (source.kind === 'after') {
    const seconds = positiveInteger(source.after_seconds);
    return seconds ? { kind: 'after', after_seconds: seconds } : null;
  }
  if (source.kind === 'every') {
    const seconds = positiveInteger(source.every_seconds);
    return seconds ? { kind: 'every', every_seconds: seconds } : null;
  }
  if (source.kind === 'daily') {
    const daily = record(source.daily);
    const time = requiredText(daily?.time, 32);
    const timeZone = requiredText(daily?.time_zone, 120);
    return time && timeZone ? { kind: 'daily', daily: { time, time_zone: timeZone } } : null;
  }
  if (source.kind === 'weekly') {
    const weekly = record(source.weekly);
    const time = requiredText(weekly?.time, 32);
    const timeZone = requiredText(weekly?.time_zone, 120);
    const weekdays = Array.isArray(weekly?.weekdays) ? weekly.weekdays.slice().sort() : null;
    if (!time || !timeZone || !weekdays || weekdays.length === 0 || weekdays.length > 7 ||
        weekdays.some(day => !Number.isInteger(day) || day < 1 || day > 7) ||
        new Set(weekdays).size !== weekdays.length) return null;
    return { kind: 'weekly', weekly: { time, weekdays, time_zone: timeZone } };
  }
  if (source.kind === 'cron') {
    const cron = record(source.cron);
    const expression = requiredText(cron?.expression, 300);
    const timeZone = requiredText(cron?.time_zone, 120);
    return expression && timeZone ? { kind: 'cron', cron: { expression, time_zone: timeZone } } : null;
  }
  if (source.kind === 'at') {
    if (typeof source.at === 'string') {
      const at = requiredText(source.at, 80);
      return at ? { kind: 'at', at } : null;
    }
    const at = record(source.at);
    const date = requiredText(at?.date, 16);
    const time = requiredText(at?.time, 32);
    const timeZone = requiredText(at?.time_zone, 120);
    return date && time && timeZone ? { kind: 'at', at: { date, time, time_zone: timeZone } } : null;
  }
  const rrule = requiredText(source.rrule, 4000);
  return rrule ? { kind: 'rrule', rrule } : null;
}

/** Validate one schedule destination request. */
export function automationTarget(value) {
  const source = record(value);
  if (!source || !targetKinds.has(source.kind)) return null;
  if (source.kind === 'session') {
    return validIdentifier(source.sessionId) ? { kind: 'session', sessionId: source.sessionId } : null;
  }
  const create = record(source.create);
  const cwd = create?.cwd === undefined ? undefined : requiredText(create.cwd, 4096);
  const agentPreset = create?.agentPreset === undefined ? undefined : requiredText(create.agentPreset, 300);
  if ((create?.cwd !== undefined && !cwd) || (create?.agentPreset !== undefined && !agentPreset)) return null;
  return {
    kind: source.kind,
    ...(cwd ? { create: { cwd, ...(agentPreset ? { agentPreset } : {}) } } :
      agentPreset ? { create: { agentPreset } } : {})
  };
}

/** Validate a schedule create request. */
export function automationCreateRequest(value) {
  const source = record(value);
  if (!source) return null;
  const title = requiredText(source.title, 120);
  const prompt = requiredText(source.prompt, 16000);
  const timing = automationTiming(source.timing);
  const target = source.target === undefined ? undefined : automationTarget(source.target);
  if (!title || !prompt || !timing || (source.target !== undefined && !target)) return null;
  return { title, prompt, timing, ...(target ? { target } : {}) };
}

/** Validate one schedule edit or delete request. */
export function automationEditRequest(value) {
  const source = record(value);
  if (!source || !validIdentifier(source.id) || !['update', 'delete'].includes(source.action)) return null;
  const expectedUpdatedAt = source.expectedUpdatedAt;
  if (expectedUpdatedAt !== undefined && expectedUpdatedAt !== null &&
      (typeof expectedUpdatedAt !== 'string' || expectedUpdatedAt.length > 80)) return null;
  const base = {
    id: source.id,
    action: source.action,
    ...(expectedUpdatedAt === undefined ? {} : { expectedUpdatedAt })
  };
  if (source.action === 'delete') return base;
  const patch = record(source.patch);
  if (!patch) return null;
  const result = {};
  if (patch.title !== undefined) {
    const title = requiredText(patch.title, 120);
    if (!title) return null;
    result.title = title;
  }
  if (patch.prompt !== undefined) {
    const prompt = requiredText(patch.prompt, 16000);
    if (!prompt) return null;
    result.prompt = prompt;
  }
  if (patch.timing !== undefined) {
    const timing = automationTiming(patch.timing);
    if (!timing) return null;
    result.timing = timing;
  }
  if (patch.target !== undefined) {
    const target = automationTarget(patch.target);
    if (!target) return null;
    result.target = target;
  }
  if (patch.active !== undefined) {
    if (typeof patch.active !== 'boolean') return null;
    result.active = patch.active;
  }
  if (Object.keys(result).length === 0) return null;
  return { ...base, patch: result };
}

export function automationTaskId(value) {
  return validIdentifier(value) ? value : null;
}

export function automationHistoryRequest(value) {
  const source = record(value);
  const id = automationTaskId(source?.id);
  const limit = source?.limit === undefined ? 30 : source.limit;
  if (!id || !Number.isSafeInteger(limit) || limit < 1 || limit > 100 ||
      (source.before !== undefined && !validIdentifier(source.before))) return null;
  return { id, limit, ...(source.before === undefined ? {} : { before: source.before }) };
}

