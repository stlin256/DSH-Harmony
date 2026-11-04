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
