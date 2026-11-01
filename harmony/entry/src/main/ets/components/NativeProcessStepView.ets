import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeMessage } from '../services/NativeSessionModel';
import { NativeMessageView } from './NativeMessageView';
import { NativeToolCallView } from './NativeToolCallView';
import { DSHIcon } from './DSHIcon';
import { nativeOperationLead, nativeProcessIcon, nativeToolCategory } from '../services/NativeTranscript';
import { NativeMotion } from '../services/NativeMotion';
import { NativeTextContent } from './NativeTextContent';
import { nativeDiff } from '../services/NativeDiff';
import { NativeDesign } from '../services/NativeDesign';

/** One direct operation inside the turn-level process container. */
@Component
export struct NativeProcessStepView {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  workspaceRoot: string = '';
  onOpenFile: (path: string) => void = (_path: string): void => {};
  disclosures: Map<string, boolean> = new Map<string, boolean>();
  @Prop @Watch('changed') message: NativeMessage = new NativeMessage();
  @Prop maxExpandedHeight: number = 240;
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private expanded: boolean = false;
  @State private diffAdded: number = 0;
  @State private diffRemoved: number = 0;
  private disclosureId: string = '';
  private diffSignature: string = '';

  aboutToAppear(): void {
    this.expanded = this.disclosures.get(this.disclosureKey()) === true;
    this.changed();
  }

  private disclosureKey(): string {
    return this.message.turnKey + '|' + (this.message.renderKey || this.message.id);
  }

  private changed(): void {
    if (this.message.role === 'tool' &&
      ['edit', 'write'].includes(nativeToolCategory(this.message.toolName, this.message.args))) {
      const signature = this.message.id + '|' + this.message.phase + '|' + this.message.status + '|' +
        this.message.args.length + '|' + this.message.metaRaw.length + '|' + this.message.output.length;
      if (signature !== this.diffSignature) {
        this.diffSignature = signature;
        const diff = nativeDiff(this.message);
        this.diffAdded = diff.matched ? diff.added : 0;
        this.diffRemoved = diff.matched ? diff.removed : 0;
      }
    }
    const key = this.disclosureKey();
    if (key !== this.disclosureId) {
      this.disclosureId = key;
      this.expanded = this.disclosures.get(key) === true;
    }
  }

  private toggle(): void {
    if (this.message.phase === 'preparing') return;
    NativeMotion.disclosure(this.getUIContext(), (): void => {
      this.expanded = !this.expanded;
      this.disclosures.set(this.disclosureId, this.expanded);
    });
  }

  @Builder
  private reasoningDetail() {
    Column() {
      NativeTextContent({ text: this.message.reasoning || this.message.text,
        client: this.client, sessionId: this.sessionId })
    }.padding(8).width('100%').borderRadius(NativeDesign.radiusControl)
      .backgroundColor(NativeDesign.field(this.dark))
  }

  @Builder
  private detail() {
    if (this.message.role === 'tool') {
      NativeToolCallView({ client: this.client, sessionId: this.sessionId, message: this.message,
        workspaceRoot: this.workspaceRoot, onOpenFile: this.onOpenFile,
        disclosures: this.disclosures, hideHeader: true, forceExpanded: true,
        maxExpandedHeight: this.maxExpandedHeight })
    } else {
      Scroll() {
        Column({ space: 6 }) {
          if (this.message.role === 'reasoning') {
          this.reasoningDetail()
          } else {
            NativeMessageView({ client: this.client, sessionId: this.sessionId, message: this.message,
              preview: true, disclosures: this.disclosures })
          }
        }.width('100%').padding({ right: 10 }).alignItems(HorizontalAlign.Start)
      }.width('100%').constraintSize({ maxHeight: Math.max(96, this.maxExpandedHeight) })
        .scrollable(ScrollDirection.Vertical).scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.None)
        .transition(NativeMotion.disclosureTransition())
    }
  }

  build() {
    Column({ space: this.expanded ? 4 : 0 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 4 }) {
          DSHIcon({ glyph: nativeProcessIcon(this.message.role === 'tool' ?
            nativeToolCategory(this.message.toolName, this.message.args) : 'thinking'),
            color: NativeDesign.textTertiary(this.dark), glyphSize: 14 })
          Text(this.message.label || nativeOperationLead(this.message)).fontSize(12)
            .fontWeight(FontWeight.Medium).maxLines(1)
            .fontColor(NativeDesign.textSecondary(this.dark))
          if (this.message.detail) {
            Text('·').fontSize(12).fontColor(NativeDesign.textTertiary(this.dark))
            Text(this.message.detail).fontSize(12).layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textTertiary(this.dark))
              .opacity(this.expanded ? 0 : 1)
              .animation(NativeMotion.disclosureParam())
          } else {
            Blank().layoutWeight(1)
          }
          if (this.diffAdded > 0 || this.diffRemoved > 0) {
            Text('+' + this.diffAdded).fontSize(10).fontWeight(FontWeight.Medium).maxLines(1)
              .fontColor(NativeDesign.success(this.dark))
            Text('-' + this.diffRemoved).fontSize(10).fontWeight(FontWeight.Medium).maxLines(1)
              .fontColor(NativeDesign.danger(this.dark))
          }
          if (this.message.status === 'error' || this.message.status === 'interrupted') {
            Text(this.message.status === 'error' ? '失败' : '已中断').fontSize(10)
              .fontColor(this.message.status === 'error' ?
                NativeDesign.danger(this.dark) : NativeDesign.warning(this.dark))
          }
          if (this.message.phase !== 'preparing') {
            DSHIcon({ glyph: 'chevron-left-outline',
              color: NativeDesign.textTertiary(this.dark), glyphSize: 12 })
              .rotate({ angle: this.expanded ? -90 : 180 })
              .animation(NativeMotion.disclosureParam())
          }
        }.width('100%')
      }.height(30).width('100%').padding({ left: 2, right: 2 })
        .responseRegion({ x: 0, y: -7, width: '100%', height: NativeDesign.hitTarget })
        .backgroundColor(Color.Transparent).enabled(this.message.phase !== 'preparing')
        .onClick((): void => { this.toggle(); })
      if (this.expanded) { this.detail() }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
