/** Running-tail duration formatting and copy, matching the DSH chat locale. */
export function nativeRunDuration(elapsedMs: number): string {
  const seconds = Math.max(1, Math.floor(Math.max(0, elapsedMs) / 1000));
  if (seconds < 60) return seconds + '秒';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return minutes + '分' + (seconds % 60) + '秒';
  const hours = Math.floor(minutes / 60);
  return hours + '小时' + (minutes % 60) + '分';
}

/**
 * Copy for the running tail. Without a known turn start the label stays
 * '深度求索中' and never guesses a duration (DSH chat.deepDiving).
 */
export function nativeRunningLabel(elapsedMs: number, paused: boolean = false): string {
  if (elapsedMs <= 0) return '深度求索中';
  const suffix = paused ? ' ···' : ' ···';
  return '深度求索中，用时 ' + nativeRunDuration(elapsedMs) + suffix;
}

/** Effective elapsed time with the upstream one-second floor. */
export function nativeRunningElapsed(startedAt: number, now: number, paused: boolean = false,
  frozenElapsed: number = 0): number {
  if (startedAt <= 0) return 0;
  if (paused && frozenElapsed > 0) return frozenElapsed;
  return Math.max(1000, now - startedAt);
}
