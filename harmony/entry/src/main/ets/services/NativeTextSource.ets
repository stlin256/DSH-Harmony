import { NativeSecretSpan } from './NativeSecretMask';

/** Fixed-size rendering windows, with no content cap and no copy per off-screen row. */
export class NativeTextSource implements IDataSource {
  private value: string = '';
  private listeners: DataChangeListener[] = [];
  private readonly window: number = 4096;
  private offsets: number[] = [0];
  totalCount(): number { return Math.max(0, this.offsets.length - 1); }
  private safeBoundary(offset: number): number {
    const code = this.value.charCodeAt(offset);
    return code >= 0xDC00 && code <= 0xDFFF && offset > 0 ? offset - 1 : offset;
  }
  private boundary(index: number): number {
    if (index <= 0) return 0;
    if (index >= this.offsets.length) return this.value.length;
    return this.offsets[index];
  }
  getData(index: number): string { return this.value.slice(this.boundary(index), this.boundary(index + 1)); }
  registerDataChangeListener(listener: DataChangeListener): void { if (!this.listeners.includes(listener)) this.listeners.push(listener); }
  unregisterDataChangeListener(listener: DataChangeListener): void { this.listeners = this.listeners.filter((item: DataChangeListener) => item !== listener); }
  set(value: string, protectedRanges: NativeSecretSpan[] = []): void {
    this.value = value;
    const offsets: number[] = [0];
    let nominal = this.window;
    while (nominal < value.length) {
      let boundary = Math.min(value.length, nominal);
      for (let index = 0; index < protectedRanges.length; index++) {
        const range = protectedRanges[index];
        if (boundary > range.start && boundary < range.end) {
          boundary = range.end;
          break;
        }
      }
      boundary = this.safeBoundary(boundary);
      if (boundary <= offsets[offsets.length - 1]) {
        boundary = Math.min(value.length, offsets[offsets.length - 1] + this.window);
      }
      if (boundary < value.length) offsets.push(boundary);
      nominal = boundary + this.window;
    }
    if (offsets[offsets.length - 1] !== value.length) offsets.push(value.length);
    this.offsets = offsets;
    this.listeners.forEach((listener: DataChangeListener) => { listener.onDataReloaded(); });
  }
}
