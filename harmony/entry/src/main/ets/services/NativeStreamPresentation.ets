/** Semantic streaming budgets, shared by coalescing and display pacing. */
export class NativeStreamCadence {
  static readonly frameMs: number = 32;
  static readonly scrollingFrameMs: number = 64;
  static readonly maxLagMs: number = 600;
  static readonly catchupMs: number = 240;
}

/** Pure display cursor. It never owns protocol state or discards authoritative text. */
export class NativeStreamPresentation {
  private target: string = '';
  private count: number = 0;
  private tickAt: number = 0;
  private arrivalAt: number = 0;
  private rate: number = 50;
  private credit: number = 0;

  reset(text: string = '', now: number = 0): void {
    this.target = text; this.count = text.length;
    this.tickAt = now; this.arrivalAt = now; this.rate = 50; this.credit = 0;
  }
  offer(text: string, now: number, immediate: boolean = false): void {
    if (immediate || !text.startsWith(this.target)) { this.reset(text, now); return; }
    if (text === this.target) return;
    const added = text.length - this.target.length;
    if (this.arrivalAt > 0 && now > this.arrivalAt) {
      const measured = added * 1000 / Math.max(16, now - this.arrivalAt);
      this.rate = Math.max(30, Math.min(800, this.rate * 0.7 + measured * 0.3));
    }
    if (!this.pending()) this.tickAt = now;
    this.target = text; this.arrivalAt = now;
  }
  pending(): boolean { return this.count < this.target.length; }
  value(): string { return this.target.substring(0, this.count); }
  advance(now: number, immediate: boolean = false): boolean {
    if (!this.pending()) return false;
    const before = this.count;
    if (immediate || now - this.arrivalAt >= NativeStreamCadence.maxLagMs) {
      this.count = this.target.length;
      this.credit = 0;
    } else {
      const elapsed = Math.max(0, Math.min(100, now - this.tickAt));
      const speed = Math.max(this.rate, (this.target.length - this.count) *
        1000 / NativeStreamCadence.catchupMs);
      this.credit += speed * elapsed / 1000;
      const step = Math.floor(this.credit);
      this.credit -= step;
      this.count = Math.min(this.target.length, this.count + step);
      // A dangling high surrogate must wait for its low surrogate on the next tick.
      if (this.count > 0 && this.count < this.target.length &&
        this.target.charCodeAt(this.count - 1) >= 0xD800 &&
        this.target.charCodeAt(this.count - 1) <= 0xDBFF) {
        this.count--; this.credit++;
      }
    }
    this.tickAt = now;
    return before !== this.count;
  }
}

/** Paces the live process strip: reasoning segments and preparing tool arguments. */
export class NativeStreamProcessPacer {
  private reasoning: NativeStreamPresentation = new NativeStreamPresentation();
  private parts: Map<number, NativeStreamPresentation> = new Map<number, NativeStreamPresentation>();
  private tools: Map<string, NativeStreamPresentation> = new Map<string, NativeStreamPresentation>();

  reset(now: number, reasoning: string = '', partIndexes: number[] = [],
    partTexts: string[] = [], toolKeys: string[] = [], toolTexts: string[] = []): void {
    this.reasoning.reset(reasoning, now);
    this.parts.clear();
    this.tools.clear();
    partIndexes.forEach((index: number, position: number): void => {
      const cursor = new NativeStreamPresentation();
      cursor.reset(partTexts[position] || '', now);
      this.parts.set(index, cursor);
    });
    toolKeys.forEach((key: string, position: number): void => {
      const cursor = new NativeStreamPresentation();
      cursor.reset(toolTexts[position] || '', now);
      this.tools.set(key, cursor);
    });
  }

  offer(now: number, reasoning: string, partIndexes: number[], partTexts: string[],
    toolKeys: string[], toolTexts: string[], immediate: boolean = false): void {
    this.reasoning.offer(reasoning, now, immediate);
    partIndexes.forEach((index: number, position: number): void => {
      let cursor = this.parts.get(index);
      if (!cursor) {
        cursor = new NativeStreamPresentation();
        cursor.reset('', now);
        this.parts.set(index, cursor);
      }
      cursor.offer(partTexts[position] || '', now, immediate);
    });
    toolKeys.forEach((key: string, position: number): void => {
      let cursor = this.tools.get(key);
      if (!cursor) {
        cursor = new NativeStreamPresentation();
        cursor.reset('', now);
        this.tools.set(key, cursor);
      }
      cursor.offer(toolTexts[position] || '', now, immediate);
    });
  }

  reasoningText(): string { return this.reasoning.value(); }
  partText(index: number, fallback: string): string {
    const cursor = this.parts.get(index);
    return cursor ? cursor.value() : fallback;
  }
  toolText(key: string, fallback: string): string {
    const cursor = this.tools.get(key);
    return cursor ? cursor.value() : fallback;
  }
  pacedPartTexts(): Map<number, string> {
    const values: Map<number, string> = new Map<number, string>();
    this.parts.forEach((cursor: NativeStreamPresentation, index: number): void => {
      values.set(index, cursor.value());
    });
    return values;
  }
  pacedToolTexts(): Map<string, string> {
    const values: Map<string, string> = new Map<string, string>();
    this.tools.forEach((cursor: NativeStreamPresentation, key: string): void => {
      values.set(key, cursor.value());
    });
    return values;
  }
  pending(): boolean {
    if (this.reasoning.pending()) return true;
    let waiting = false;
    this.parts.forEach((cursor: NativeStreamPresentation): void => {
      if (cursor.pending()) waiting = true;
    });
    if (waiting) return true;
    this.tools.forEach((cursor: NativeStreamPresentation): void => {
      if (cursor.pending()) waiting = true;
    });
    return waiting;
  }
  advance(now: number, immediate: boolean = false): boolean {
    let changed = this.reasoning.advance(now, immediate);
    this.parts.forEach((cursor: NativeStreamPresentation): void => {
      if (cursor.advance(now, immediate)) changed = true;
    });
    this.tools.forEach((cursor: NativeStreamPresentation): void => {
      if (cursor.advance(now, immediate)) changed = true;
    });
    return changed;
  }
}
