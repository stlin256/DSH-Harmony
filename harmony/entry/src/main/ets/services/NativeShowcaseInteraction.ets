import {
  NativeFrame,
  NativeImageAttachment,
  NativeMessage,
  NativeQueueBlock,
  NativeQueueFile,
  NativeQueueItem
} from './NativeSessionModel';

/** Bounded attachment input used only by the offline UI transport. */
export class NativeShowcaseAttachment {
  id: string = '';
  kind: string = '';
  name: string = '';
  mediaType: string = '';
  bytes: number = 0;
  receiptId: string = '';
}

export class NativeShowcasePromptPlan {
  requestId: string = '';
  accepted: boolean = false;
  queued: boolean = false;
  admissionFrames: NativeFrame[] = [];
  streamFrames: NativeFrame[] = [];
  settleFrames: NativeFrame[] = [];
}

function showcaseMessage(id: string, role: string, seq: number, turn: number,
  step: number, text: string): NativeMessage {
  const value = new NativeMessage();
  value.id = id;
  value.role = role;
  value.seq = seq;
  value.turn = turn;
  value.turnKey = 'turn:' + turn.toString();
  value.step = step;
  value.time = 1761900000 + seq;
  value.text = text;
  return value;
}

function stateFrame(running: boolean, waiting: boolean, queue: NativeQueueItem[] | null): NativeFrame {
  const frame = new NativeFrame();
  frame.type = 'state';
  frame.running = running;
  frame.waiting = waiting;
  if (queue !== null) {
    frame.queueKnown = true;
    frame.queue = queue;
  }
  return frame;
}

function queueBlock(attachment: NativeShowcaseAttachment): NativeQueueBlock {
  const block = new NativeQueueBlock();
  block.kind = attachment.kind === 'image' ? 'image' : 'file';
  if (block.kind === 'image') {
    const image = new NativeImageAttachment();
    image.attachmentId = attachment.receiptId || attachment.id;
    image.mediaType = attachment.mediaType;
    image.bytes = attachment.bytes;
    image.name = attachment.name;
    block.image = image;
  } else {
    const file = new NativeQueueFile();
    file.attachmentId = attachment.receiptId || attachment.id;
    file.name = attachment.name || '附件';
    file.bytes = attachment.bytes;
    block.file = file;
  }
  return block;
}

/** Creates the block order used by both pending echo and authoritative Mock queue rows. */
export function nativeShowcaseQueueItem(requestId: string, text: string,
  attachments: NativeShowcaseAttachment[]): NativeQueueItem {
  const item = new NativeQueueItem();
  item.id = 'showcase-queue-' + requestId;
  item.rpcId = requestId;
  attachments.forEach((attachment: NativeShowcaseAttachment): void => {
    item.blocks.push(queueBlock(attachment));
  });
  if (text.trim()) {
    const block = new NativeQueueBlock();
    block.kind = 'text';
    block.text = text;
    item.blocks.push(block);
  }
  return item;
}

/**
 * Stateful in-memory transcript used by StoreShowcaseClient. It deliberately
 * emits the same durable frame order as a normal Host so the UI follows the
 * production send, stream, queue reconciliation and settle paths.
 */
export class NativeShowcaseInteraction {
  messages: NativeMessage[] = [];
  queue: NativeQueueItem[] = [];
  running: boolean = false;
  waiting: boolean = false;
  /** Authoritative open-turn start (epoch ms) so the running tail shows a real clock. */
  turnStartedAt: number = 0;
  cursor: number = 0;
  private streamRevision: number = 0;
  private turn: number = 1;

  constructor(messages: NativeMessage[], running: boolean = false, cursor: number = 0,
    queue: NativeQueueItem[] = []) {
    this.messages = messages.slice();
    this.running = running;
    this.cursor = cursor;
    this.queue = queue.slice();
    this.turn = 1;
    this.messages.forEach((row: NativeMessage): void => {
      if (Number.isSafeInteger(row.turn) && row.turn >= this.turn) this.turn = row.turn + 1;
    });
    if (running) this.turn = Math.max(1, this.turn - 1);
  }

  snapshot(): NativeFrame {
    const frame = new NativeFrame();
    frame.type = 'snapshot';
    frame.messages = this.messages.slice();
    frame.cursor = this.cursor;
    frame.beforeSeq = 0;
    frame.hasMore = false;
    frame.running = this.running;
    frame.waiting = this.waiting;
    frame.turnStartedAt = this.turnStartedAt;
    frame.revision = this.streamRevision;
    frame.queueKnown = true;
    frame.queue = this.queue.slice();
    return frame;
  }

  prompt(requestId: string, text: string, attachments: NativeShowcaseAttachment[],
    mode: string = 'queue'): NativeShowcasePromptPlan {
    const value = new NativeShowcasePromptPlan();
    value.requestId = requestId;
    const clean = text.trim();
    if (!requestId || (!clean && !attachments.length)) return value;
    value.accepted = true;

    if (this.running && mode === 'queue') {
      value.queued = true;
      if (!this.queue.some((item: NativeQueueItem): boolean => item.rpcId === requestId)) {
        this.queue = this.queue.concat([
          nativeShowcaseQueueItem(requestId, clean, attachments)
        ]);
      }
      value.admissionFrames = [stateFrame(true, this.waiting, this.queue)];
      return value;
    }

    this.running = true;
    this.waiting = false;
    const userSeq = this.cursor + 1;
    const user = showcaseMessage('showcase-user-' + requestId, 'user', userSeq,
      this.turn, 1, clean);
    user.label = '你';
    user.sourceKind = 'client';

    const assistantSeq = userSeq + 1;
    const assistant = showcaseMessage('showcase-assistant-' + requestId, 'assistant',
      assistantSeq, this.turn, 2,
      '已收到这条测试消息。Dock、发送与流式状态均已正常更新。');

    const turnSeq = assistantSeq + 1;
    const end = showcaseMessage('showcase-turn-end-' + requestId, 'turn', turnSeq,
      this.turn, 2, '');
    end.eventType = 'turn/end';
    end.outcome = 'completed';
    end.label = '已完成';
    end.turnKey = 'turn:' + this.turn.toString();

    this.messages = this.messages.concat([user, assistant, end]);
    this.cursor = turnSeq;
    this.turn++;
    this.running = false;

    const userFrame = new NativeFrame();
    userFrame.type = 'event';
    userFrame.seq = userSeq;
    userFrame.message = user;

    const titleFrame = new NativeFrame();
    titleFrame.type = 'title';
    titleFrame.title = clean.length > 18 ? clean.slice(0, 18) + '…' : clean;

    const startFrame = new NativeFrame();
    startFrame.type = 'start';
    startFrame.attemptId = 'showcase-attempt-' + requestId;
    startFrame.revision = ++this.streamRevision;
    startFrame.nextIndex = 0;

    const deltaFrame = new NativeFrame();
    deltaFrame.type = 'delta';
    deltaFrame.attemptId = startFrame.attemptId;
    deltaFrame.revision = ++this.streamRevision;
    deltaFrame.index = 0;
    deltaFrame.text = assistant.text;

    const assistantFrame = new NativeFrame();
    assistantFrame.type = 'event';
    assistantFrame.seq = assistantSeq;
    assistantFrame.message = assistant;

    const turnFrame = new NativeFrame();
    turnFrame.type = 'event';
    turnFrame.seq = turnSeq;
    turnFrame.message = end;

    const streamEndFrame = new NativeFrame();
    streamEndFrame.type = 'end';
    streamEndFrame.attemptId = startFrame.attemptId;
    streamEndFrame.revision = ++this.streamRevision;
    streamEndFrame.index = 1;
    streamEndFrame.outcomeKind = 'committed';
    streamEndFrame.committedSeq = assistantSeq;
    streamEndFrame.committedEventType = 'assistant/message';

    value.admissionFrames = [stateFrame(true, false, null), userFrame, titleFrame];
    value.streamFrames = [startFrame, deltaFrame];
    value.settleFrames = [
      streamEndFrame,
      assistantFrame,
      turnFrame,
      stateFrame(false, false, null)
    ];
    return value;
  }

  cancel(): NativeFrame[] {
    if (!this.running && !this.waiting) return [];
    this.running = false;
    this.waiting = false;
    return [stateFrame(false, false, null)];
  }
}
