import { NativeHarnessClient } from '../services/NativeHarnessClient';
import {
  NativeQueueBlock,
  NativeQueueFile,
  NativeQueueItem,
  nativeQueueEditable,
  nativeQueueText
} from '../services/NativeSessionModel';
import { DSHIcon } from './DSHIcon';
import { NativeImageView } from './NativeImageView';
import { NativeMotion } from '../services/NativeMotion';

class QueueActionPayload {
  operation: string = 'updateQueue';
  sessionId: string = '';
  itemId: string = '';
  kind: string = '';
  text?: string;
}

/** Persistent queued-input strip shared by local echoes and Host queue rows. */
@Component
export struct NativeQueueDock {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  @Prop items: NativeQueueItem[] = [];
  @Prop running: boolean = false;
  onChanged: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private collapsed: boolean = true;
  @State private editingId: string = '';
  @State private editText: string = '';
  @State private busyId: string = '';
  @State private error: string = '';

  private expanded(): boolean {
    return this.items.length <= 1 || !this.collapsed || !!this.editingId;
  }

  private fileSize(bytes: number): string {
    if (bytes < 1024) return bytes.toString() + ' B';
    if (bytes < 1024 * 1024) return Math.max(1, Math.round(bytes / 1024)).toString() + ' KB';
    return (Math.round(bytes / (1024 * 1024) * 10) / 10).toString() + ' MB';
  }

  private textPreview(item: NativeQueueItem): string {
    const text = nativeQueueText(item).replace(/\s+/g, ' ').trim();
    if (text) return text;
    const hasImage = item.blocks.some((block: NativeQueueBlock): boolean => block.kind === 'image');
    const hasFile = item.blocks.some((block: NativeQueueBlock): boolean => block.kind === 'file');
    return hasImage && hasFile ? '图片和文件' : hasImage ? '图片' : hasFile ? '文件' : '';
  }

  private hasAttachments(item: NativeQueueItem): boolean {
    return item.blocks.some((block: NativeQueueBlock): boolean =>
      block.kind === 'image' || block.kind === 'file');
  }

  private toggleCollapsed(): void {
    if (this.editingId || this.busyId) return;
    NativeMotion.disclosure(this.getUIContext(), (): void => { this.collapsed = !this.collapsed; });
  }

  private beginEdit(item: NativeQueueItem): void {
    if (item.pending || !nativeQueueEditable(item) || this.busyId) return;
    this.editingId = item.id;
    this.editText = nativeQueueText(item);
    this.error = '';
  }

  private async act(item: NativeQueueItem, kind: string, text: string = ''): Promise<void> {
    if (item.pending || this.busyId) return;
    this.busyId = item.id;
    this.error = '';
    try {
      const payload = new QueueActionPayload();
      payload.sessionId = this.sessionId;
      payload.itemId = item.id;
      payload.kind = kind;
      if (kind === 'edit') payload.text = text;
      await this.client.operation(JSON.stringify(payload));
      if (kind === 'edit') this.editingId = '';
      this.onChanged();
    } catch (_) {
      this.error = kind === 'edit' ? '无法修改排队消息' :
        kind === 'steer' ? '暂时无法立即发送' : '无法移除排队消息';
    } finally {
      this.busyId = '';
    }
  }

  @Builder
  private blocks(item: NativeQueueItem) {
    Scroll() {
      Row({ space: 6 }) {
        ForEach(item.blocks, (block: NativeQueueBlock, index: number) => {
          if (block.kind === 'image' && block.image) {
            NativeImageView({
              client: this.client,
              sessionId: this.sessionId,
              attachment: block.image,
              compact: true,
              compactSize: 42
            })
          } else if (block.kind === 'file' && block.file) {
            Row({ space: 5 }) {
              DSHIcon({ glyph: 'file-outline', glyphSize: 14,
                color: this.dark ? '#CFD3D6' : '#61666B' })
              Column({ space: 1 }) {
                Text(block.file.name).fontSize(10).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .fontColor(this.dark ? '#F1F1F2' : '#25262A')
                Text(this.fileSize(block.file.bytes)).fontSize(9)
                  .fontColor(this.dark ? '#93969B' : '#8A8D91')
              }.constraintSize({ maxWidth: 132 }).alignItems(HorizontalAlign.Start)
            }.height(34).padding({ left: 7, right: 8 }).borderRadius(9)
              .backgroundColor(this.dark ? '#353638' : '#EEF0F3')
          }
        }, (block: NativeQueueBlock, index: number) => item.id + ':' + index.toString())
      }.padding({ right: 6 })
    }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
  }

  @Builder
  private actions(item: NativeQueueItem) {
    if (!item.pending) {
      Button({ type: ButtonType.Normal }) {
        DSHIcon({ glyph: 'edit-outline', glyphSize: 13,
          color: nativeQueueEditable(item) ? this.dark ? '#CFD3D6' : '#61666B' :
            this.dark ? '#55575B' : '#C4C7CC' })
      }.width(30).height(30).borderRadius(8).backgroundColor(Color.Transparent)
        .enabled(nativeQueueEditable(item) && !this.busyId)
        .accessibilityText('修改排队消息').onClick((): void => { this.beginEdit(item); })
      Button({ type: ButtonType.Normal }) {
        DSHIcon({ glyph: 'close-outline', glyphSize: 13,
          color: this.dark ? '#93969B' : '#777A80' })
      }.width(30).height(30).borderRadius(8).backgroundColor(Color.Transparent)
        .enabled(!this.busyId).accessibilityText('移除排队消息')
        .onClick((): void => { this.act(item, 'remove'); })
      Button({ type: ButtonType.Normal }) {
        DSHIcon({ glyph: 'send-arrow', glyphSize: 13,
          color: this.running ? this.dark ? '#8AB4FF' : '#3964FE' :
            this.dark ? '#55575B' : '#C4C7CC' })
      }.width(30).height(30).borderRadius(8).backgroundColor(Color.Transparent)
        .enabled(this.running && !this.busyId).accessibilityText('立即发送排队消息')
        .onClick((): void => { this.act(item, 'steer'); })
    }
  }

  @Builder
  private row(item: NativeQueueItem) {
    Row({ space: 6 }) {
      if (this.items.length === 1) {
        DSHIcon({ glyph: 'queue-outline', glyphSize: 14,
          color: this.dark ? '#93969B' : '#8A8D91' })
      }
      if (this.editingId === item.id) {
        TextInput({ text: this.editText }).layoutWeight(1).height(34).fontSize(12)
          .borderRadius(9).padding({ left: 9, right: 9 })
          .backgroundColor(this.dark ? '#353638' : '#F5F6F7')
          .fontColor(this.dark ? '#F9FAFB' : '#17181B')
          .onChange((value: string): void => { this.editText = value; })
        Button({ type: ButtonType.Normal }) {
          if (this.busyId === item.id) LoadingProgress().width(13).height(13)
          else DSHIcon({ glyph: 'check-outline', glyphSize: 13,
            color: this.dark ? '#8AB4FF' : '#3964FE' })
        }.width(30).height(30).borderRadius(8).backgroundColor(Color.Transparent)
          .enabled(!!this.editText.trim() && !this.busyId)
          .accessibilityText('保存排队消息').onClick((): void => { this.act(item, 'edit', this.editText); })
        Button({ type: ButtonType.Normal }) {
          DSHIcon({ glyph: 'close-outline', glyphSize: 13,
            color: this.dark ? '#93969B' : '#777A80' })
        }.width(30).height(30).borderRadius(8).backgroundColor(Color.Transparent)
          .enabled(!this.busyId).accessibilityText('取消修改')
          .onClick((): void => { this.editingId = ''; })
      } else {
        Column({ space: 5 }) {
          if (this.hasAttachments(item)) this.blocks(item)
          Row({ space: 6 }) {
            Text(this.textPreview(item)).fontSize(12).layoutWeight(1).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(this.dark ? '#F1F1F2' : '#25262A')
            if (item.pending) {
              Text('发送中…').fontSize(10)
                .fontColor(this.dark ? '#8AB4FF' : '#315ECA')
            }
          }.width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        this.actions(item)
      }
    }.width('100%').padding({ left: 8, right: 5, top: 6, bottom: 6 })
      .borderRadius(11).backgroundColor(this.dark ? '#292A2C' : '#F7F8FA')
      .border({ width: 0.5, color: this.dark ? '#414247' : '#E3E5E9' })
  }

  build() {
    if (this.items.length) {
      Column({ space: 4 }) {
        if (this.items.length > 1) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 6 }) {
              DSHIcon({ glyph: 'queue-outline', glyphSize: 14,
                color: this.dark ? '#93969B' : '#8A8D91' })
              Text(this.items.length.toString() + ' 条排队消息').fontSize(11).fontWeight(FontWeight.Medium)
                .fontColor(this.dark ? '#CFD3D6' : '#61666B')
              if (this.items.some((item: NativeQueueItem): boolean => item.pending)) {
                Text('发送中…').fontSize(10).fontColor(this.dark ? '#8AB4FF' : '#315ECA')
              }
              Blank()
              DSHIcon({ glyph: 'chevron-left-outline', glyphSize: 12,
                color: this.dark ? '#93969B' : '#8A8D91' })
                .rotate({ angle: this.expanded() ? -90 : 90 })
                .animation(NativeMotion.disclosureParam())
            }.width('100%')
          }.width('100%').height(30).padding({ left: 8, right: 8 })
            .backgroundColor(Color.Transparent).onClick((): void => { this.toggleCollapsed(); })
        }
        if (this.expanded()) {
          Column({ space: 4 }) {
            ForEach(this.items, (item: NativeQueueItem) => {
              this.row(item)
            }, (item: NativeQueueItem) => item.id)
          }.width('100%').transition(NativeMotion.disclosureTransition())
        }
        if (this.error) {
          Text(this.error).fontSize(10).fontColor(this.dark ? '#FF9393' : '#C53030')
            .padding({ left: 8, right: 8, bottom: 3 })
        }
      }.width('100%').transition(NativeMotion.rowTransition())
    }
  }
}
