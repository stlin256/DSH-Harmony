/** View-only data source; off-screen rows create no ArkUI components. */
export class NativeListSource<T> implements IDataSource {
  private rows: T[] = [];
  private keys: string[] = [];
  private listeners: DataChangeListener[] = [];
  totalCount(): number { return this.rows.length; }
  getData(index: number): T { return this.rows[index]; }
  registerDataChangeListener(listener: DataChangeListener): void { if (!this.listeners.includes(listener)) this.listeners.push(listener); }
  unregisterDataChangeListener(listener: DataChangeListener): void { this.listeners = this.listeners.filter((item: DataChangeListener) => item !== listener); }
  /** Explicit single-row notification for callers whose state lives outside the row objects. */
  notifyChanged(index: number): void {
    if (index < 0 || index >= this.rows.length) return;
    this.listeners.forEach((listener: DataChangeListener): void => { listener.onDataChange(index); });
  }
  set(rows: T[], keyOf?: (item: T) => string, equals?: (left: T, right: T) => boolean): void {
    const previous = this.rows;
    const previousKeys = this.keys;
    const key = (item: T): string => keyOf ? keyOf(item) : JSON.stringify(item);
    // An injected comparator keeps change detection at field level; the
    // serialization fallback remains for callers without one.
    const same = (left: T, right: T): boolean =>
      left === right || (equals ? equals(left, right) : JSON.stringify(left) === JSON.stringify(right));
    const occurrences: Map<string, number> = new Map<string, number>();
    const nextKeys = rows.map((item: T): string => {
      const base = key(item);
      const occurrence = occurrences.get(base) || 0;
      occurrences.set(base, occurrence + 1);
      return occurrence === 0 ? base : base + '#' + occurrence;
    });
    // Retain an immutable snapshot: callers frequently append to the same
    // array instance, and a live reference would hide the structural delta.
    this.rows = rows.slice();
    this.keys = nextKeys;
    this.listeners.forEach((listener: DataChangeListener) => {
      if (rows.length === previous.length + 1 &&
        previousKeys.every((value: string, index: number): boolean => value === nextKeys[index])) {
        listener.onDataAdded(rows.length - 1);
        return;
      }
      const stableKeys = rows.length === previous.length &&
        nextKeys.every((value: string, index: number): boolean => value === previousKeys[index]);
      if (stableKeys) {
        // Streaming deltas usually change rows near the tail, but a mid-list
        // content-only change must still be delivered: compare every row, and
        // notify the few changed indices directly.
        const changedRows: number[] = [];
        for (let index = 0; index < rows.length; index++) {
          if (!same(previous[index], rows[index])) changedRows.push(index);
        }
        if (changedRows.length > 0 && changedRows.length <= 4) {
          changedRows.forEach((index: number): void => { listener.onDataChange(index); });
          return;
        }
      }
      const changed: number[] = [];
      const length = Math.min(previous.length, rows.length);
      for (let index = 0; index < length; index++) {
        // A row replaced at the same position is a change even when its key
        // differs; skipping it left the previous item stale on screen.
        if (previousKeys[index] !== nextKeys[index] || !same(previous[index], rows[index])) changed.push(index);
      }
      if (rows.length === previous.length && (rows.length === 0 || key(previous[0]) === key(rows[0])) &&
        changed.length <= 4) {
        changed.forEach((index: number): void => { listener.onDataChange(index); });
        return;
      }
      listener.onDataReloaded();
    });
  }
  /**
   * Publish a text-only tail replacement without rebuilding every render key.
   * Callers must keep row count and identity stable and change only the final
   * `changedTail` rows. Any structural change falls back to `set`.
   */
  setTail(rows: T[], changedTail: number = 1): void {
    if (changedTail <= 0 || rows.length !== this.rows.length || rows.length === 0) {
      this.set(rows);
      return;
    }
    this.rows = rows.slice();
    const start = Math.max(0, rows.length - changedTail);
    this.listeners.forEach((listener: DataChangeListener) => {
      for (let index = start; index < rows.length; index++) listener.onDataChange(index);
    });
  }
}
