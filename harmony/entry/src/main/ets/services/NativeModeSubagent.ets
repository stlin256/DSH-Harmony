/** Pure Plan-mode and subagent presentation rules shared by UI and tests. */

export const nativeSubagentOneShot: string = 'one-shot';
export const nativeSubagentContinuable: string = 'continuable';
export const nativeSubagentExternal: string = 'external';
export const nativeSubagentUnknown: string = 'unknown';
export const nativeSubagentAddressSession: string = 'session';
export const nativeSubagentAddressSubagent: string = 'subagent';
export const nativeSubagentMaxDepth: number = 8;

export class NativePlanProjection {
  active: boolean = false;
  pending: boolean = false;
}

export function nativePlanTargetActive(plan: NativePlanProjection | null): boolean {
  if (!plan) return false;
  return plan.pending ? !plan.active : plan.active;
}

export class NativeSubagentEntry {
  id: string = '';
  createdAt: number = 0;
  mode: string = nativeSubagentUnknown;
  label: string = '';
  running: boolean = false;
}

export class NativeSubagentIdentity {
  mode: string = nativeSubagentUnknown;
  label: string = '';
  seq: number = -1;
}

export class NativeSubagentActiveTiming {
  since: number = 0;
  through: number = 0;
}

export class NativeSubagentTiming {
  settledMs: number = 0;
  active: NativeSubagentActiveTiming | null = null;
  lastTurnCompleted: boolean = false;
  hasLastTurnCompleted: boolean = false;
}

export class NativeSubagentProjectionValues {
  plan: NativePlanProjection | null = null;
  subagentCatalog: NativeSubagentEntry[] | null = null;
  subagent: NativeSubagentIdentity | null = null;
  subagentKnown: boolean = false;
  subagentTiming: NativeSubagentTiming | null = null;
}

export class NativeProjectionSnapshot {
  kind: string = 'sequenced';
  asOfSeq: number = -1;
  values: NativeSubagentProjectionValues = new NativeSubagentProjectionValues();
}

export class NativeSessionAddress {
  kind: string = nativeSubagentAddressSession;
  sessionId: string = '';
  parentSessionId: string = '';
  childSessionId: string = '';
  mode: string = nativeSubagentUnknown;
}

export function nativeSessionAddress(sessionId: string): NativeSessionAddress {
  const address = new NativeSessionAddress();
  address.kind = nativeSubagentAddressSession;
  address.sessionId = sessionId;
  return address;
}

export function nativeSubagentAddress(parentSessionId: string, childSessionId: string,
  mode: string): NativeSessionAddress | null {
  if (!nativeSessionIdValid(parentSessionId) || !nativeSessionIdValid(childSessionId) ||
    parentSessionId === childSessionId ||
    (mode !== nativeSubagentOneShot && mode !== nativeSubagentContinuable && mode !== nativeSubagentUnknown)) {
    return null;
  }
  const address = new NativeSessionAddress();
  address.kind = nativeSubagentAddressSubagent;
  address.parentSessionId = parentSessionId;
  address.childSessionId = childSessionId;
  address.sessionId = childSessionId;
  address.mode = mode;
  return address;
}

export function nativeSessionIdValid(value: string): boolean {
  return /^[A-Za-z0-9_-]{1,160}$/.test(value);
}

export function nativeSessionAddressKey(address: NativeSessionAddress): string {
  return address.kind === nativeSubagentAddressSubagent ?
    address.parentSessionId + '/' + address.childSessionId + '/' + address.mode : address.sessionId;
}

export function nativeSubagentCanOpen(entry: NativeSubagentEntry): boolean {
  return entry.mode !== nativeSubagentExternal && nativeSessionIdValid(entry.id);
}

export function nativeSubagentReadOnlyReason(address: NativeSessionAddress,
  identity: NativeSubagentIdentity | null, identityKnown: boolean = identity !== null,
  parentAvailable: boolean | undefined = undefined, running: boolean = false): string {
  if (address.kind !== nativeSubagentAddressSubagent) return '';
  const mode = identityKnown ? identity?.mode || nativeSubagentUnknown : address.mode;
  if (mode === nativeSubagentOneShot) return 'one-shot';
  if (mode === nativeSubagentContinuable) {
    return parentAvailable === false && !running ? 'parent-unavailable' : '';
  }
  return 'unknown';
}

export function nativeSubagentComposerEnabled(address: NativeSessionAddress,
  identity: NativeSubagentIdentity | null, identityKnown: boolean = identity !== null,
  parentAvailable: boolean | undefined = undefined, running: boolean = false): boolean {
  if (address.kind !== nativeSubagentAddressSubagent) return true;
  if (nativeSubagentReadOnlyReason(address, identity, identityKnown, parentAvailable, running)) return false;
  const mode = identityKnown ? identity?.mode || nativeSubagentUnknown : address.mode;
  return mode !== nativeSubagentContinuable || parentAvailable !== false;
}

/** Prevent duplicate loops and unbounded path growth without retaining transcript copies. */
export function nativeSubagentStackPush(stack: NativeSessionAddress[],
  next: NativeSessionAddress): NativeSessionAddress[] {
  if (!nativeSessionIdValid(next.childSessionId) || stack.length >= nativeSubagentMaxDepth) return stack.slice();
  const keys: Set<string> = new Set<string>();
  stack.forEach((row: NativeSessionAddress): void => { keys.add(nativeSessionAddressKey(row)); });
  const key = nativeSessionAddressKey(next);
  if (keys.has(key)) return stack.slice();
  return stack.concat([next]);
}

export function nativeSubagentModeLabel(mode: string): string {
  if (mode === nativeSubagentOneShot) return '一次性';
  if (mode === nativeSubagentContinuable) return '可继续';
  if (mode === nativeSubagentExternal) return '外部';
  return '模式未知';
}

export function nativeSubagentDuration(ms: number, now: number,
  active: NativeSubagentActiveTiming | null): string {
  const settled = Number.isSafeInteger(ms) && ms >= 0 ? ms : 0;
  const current = active && Number.isSafeInteger(active.since) && Number.isSafeInteger(active.through) ?
    Math.max(0, Math.max(active.since, Math.min(now, active.through)) - active.since) : 0;
  const totalSeconds = Math.floor((settled + current) / 1000);
  const days = Math.floor(totalSeconds / 86400);
  if (days > 0) return days.toString() + '天';
  const hours = Math.floor(totalSeconds / 3600);
  if (hours > 0) return hours.toString() + '小时';
  const minutes = Math.floor(totalSeconds / 60);
  if (minutes > 0) return minutes.toString() + '分';
  return totalSeconds.toString() + '秒';
}

export class NativeProjectionSequence {
  private values: Map<string, number> = new Map<string, number>();
  accept(key: string, seq: number): boolean {
    if (!Number.isSafeInteger(seq) || seq < 0) return true;
    const previous = this.values.get(key);
    if (previous !== undefined && seq <= previous) return false;
    this.values.set(key, seq);
    return true;
  }
  clear(): void {
    this.values.clear();
  }
}
