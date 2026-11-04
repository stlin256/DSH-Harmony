/** Connection lifetime is independent of component rendering and provider cadence. */
export class NativeStreamRecovery {
  private epoch: number = 0;
  private attempts: number = 0;
  private openedAt: number = 0;
  private startedAt: number = 0;

  reset(): void { this.epoch++; this.attempts = 0; this.openedAt = 0; this.startedAt = 0; }
  retire(): number { this.epoch++; return this.epoch; }
  current(value: number): boolean { return value === this.epoch; }
  begin(now: number): number {
    this.startedAt = now;
    this.openedAt = 0;
    return this.retire();
  }
  opened(now: number): void { this.openedAt = now; }
  openingExpired(now: number, background: boolean): boolean {
    return this.openedAt === 0 && this.startedAt > 0 &&
      now - this.startedAt >= (background ? 45000 : 30000);
  }
  nextDelay(now: number): number {
    // A briefly successful snapshot must not reset an endless reconnect loop.
    if (this.openedAt > 0 && now - this.openedAt >= 30000) this.attempts = 0;
    this.openedAt = 0;
    if (this.attempts >= 6) return -1;
    const attempt = this.attempts++;
    return attempt === 0 ? 250 : Math.min(30000, 1000 * Math.pow(2, attempt));
  }
}

export function nativeStreamFailureText(code: string): string {
  if (code === 'subagent/not-found' || code === 'session/not-found') return '此会话已不可用';
  if (code === 'subagent/unauthorized' || code === 'gateway/forbidden' ||
    code === 'gateway/unauthorized') return '暂时无法访问此会话';
  if (code === 'subagent/catalog-diagnostic') return '子智能体记录暂时无法读取';
  if (code === 'gateway/invocation-unavailable' || code === 'history-unsupported' ||
    code === 'gateway/bad-request' || code === 'invalid_frame' || code === 'frame_handler_error') {
    return '会话数据暂时无法读取，请检查服务端版本';
  }
  return '连接暂时无法恢复，请重试';
}
