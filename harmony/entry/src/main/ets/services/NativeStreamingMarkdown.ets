/** Incremental display buffering for an append-only assistant response. */
export class NativeStreamingMarkdownUpdate {
  changed: boolean = false;
  reset: boolean = false;
  tail: string = '';
  tailInFence: boolean = false;
  appended: string[] = [];
}

/**
 * Completed Markdown blocks stop participating in the streaming paint loop.
 * The active tail remains authoritative and is never trimmed from the model.
 */
export class NativeStreamingMarkdownBuffer {
  private value: string = '';
  private tail: string = '';
  private blocks: string[] = [];
  private blockStart: number = 0;
  private lineStart: number = 0;
  private scanAt: number = 0;
  private fenceCharacter: string = '';
  private fenceLength: number = 0;
  private tableCandidate: boolean = false;
  readonly maxBlockLength: number = 4096;
  scannedCharacters: number = 0;

  blockCount(): number { return this.blocks.length; }
  getBlocks(): string[] { return this.blocks.slice(); }

  private reset(): void {
    this.blocks = [];
    this.tail = '';
    this.blockStart = 0;
    this.lineStart = 0;
    this.scanAt = 0;
    this.fenceCharacter = '';
    this.fenceLength = 0;
    this.tableCandidate = false;
    this.scannedCharacters = 0;
  }

  private finishBlock(source: string, end: number,
    update: NativeStreamingMarkdownUpdate): void {
    if (end <= this.blockStart) return;
    const block = source.substring(this.blockStart, end);
    if (block.trim().length > 0) {
      this.blocks.push(block);
      update.appended.push(block);
    }
    this.blockStart = end;
    this.tableCandidate = false;
  }

  private processLine(source: string, lineEnd: number, line: string,
    update: NativeStreamingMarkdownUpdate): void {
    if (this.fenceCharacter) {
      const close = /^[ \t]*(?:>[ \t]?)*[ \t]*(`{3,}|~{3,})[ \t]*$/.exec(line);
      if (close && close[1].charAt(0) === this.fenceCharacter &&
        close[1].length >= this.fenceLength) {
        this.fenceCharacter = '';
        this.fenceLength = 0;
      }
      return;
    }
    const fence = /^[ \t]*(?:>[ \t]?)*[ \t]*(`{3,}|~{3,})(.*)$/.exec(line);
    if (fence) {
      this.fenceCharacter = fence[1].charAt(0);
      this.fenceLength = fence[1].length;
      return;
    }
    if (line.trim().length === 0) {
      this.finishBlock(source, lineEnd, update);
      return;
    }
    if (line.indexOf('|') >= 0) this.tableCandidate = true;
    const length = lineEnd - this.blockStart;
    if (!this.tableCandidate && length >= this.maxBlockLength) {
      this.finishBlock(source, lineEnd, update);
    }
  }

  update(next: string): NativeStreamingMarkdownUpdate {
    const update = new NativeStreamingMarkdownUpdate();
    if (next === this.value) {
      update.tail = this.tail;
      update.tailInFence = this.fenceCharacter.length > 0;
      return update;
    }
    update.changed = true;
    update.reset = !next.startsWith(this.value);
    if (update.reset) this.reset();
    const from = update.reset ? 0 : this.scanAt;
    this.value = next;
    for (let index = from; index < next.length; index++) {
      if (next.charAt(index) !== '\n') continue;
      const line = next.substring(this.lineStart, index);
      this.scannedCharacters += line.length + 1;
      this.processLine(next, index + 1, line, update);
      this.lineStart = index + 1;
    }
    this.scanAt = next.length;
    this.tail = next.substring(this.blockStart);
    update.tail = this.tail;
    update.tailInFence = this.fenceCharacter.length > 0;
    return update;
  }
}
