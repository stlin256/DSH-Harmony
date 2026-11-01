import { NativeMessage } from '../services/NativeSessionModel';
import { nativeActivity, nativeToolArgumentsVisible, nativeToolDetail, nativeToolCategory,
  nativeProcessIcon, nativeToolOutputVisible } from '../services/NativeTranscript';
import { NativeTextContent } from './NativeTextContent';
import { DSHIcon } from './DSHIcon';
import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeImageStrip } from './NativeImageStrip';
import { NativeRichContent } from './NativeRichContent';
import { NativeDiffBlock } from './NativeDiffBlock';
import { NativeDiffDocument, nativeDiff } from '../services/NativeDiff';
import { NativeMotion } from '../services/NativeMotion';
import { NativePlanDocument, nativePlanDocument } from '../services/NativePlan';
import { NativePlanView } from './NativePlanView';
import { NativeDesign } from '../services/NativeDesign';
import { NativeToolStructured, nativeToolStructured } from '../services/NativeToolStructured';
import { NativeStructuredToolView } from './NativeStructuredToolView';

@Component
export struct NativeToolCallView {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  workspaceRoot: string = '';
  onOpenFile: (path: string) => void = (_path: string): void => {};
  disclosures: Map<string, boolean> = new Map<string, boolean>();
  @Prop @Watch('changed') message: NativeMessage = new NativeMessage();
  @Prop depth: number = 0;
  @Prop hideHeader: boolean = false;
  @Prop forceExpanded: boolean = false;
  @Prop maxExpandedHeight: number = 240;
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private expanded: boolean = false;
  @State private diff: NativeDiffDocument = new NativeDiffDocument();
  @State private plan: NativePlanDocument = new NativePlanDocument();
  @State private structured: NativeToolStructured = new NativeToolStructured();
  @State private detail: string = '';
  aboutToAppear(): void {
    const saved = this.disclosures.get(this.message.turnKey + '|' + this.message.id);
    this.expanded = this.forceExpanded || saved === true;
    this.changed();
  }
  private changed(): void {
    const category = nativeToolCategory(this.message.toolName, this.message.args);
    this.diff = ['edit', 'write'].includes(category) ? nativeDiff(this.message) : new NativeDiffDocument();
    this.plan = this.message.toolName === 'todo_write' ?
      nativePlanDocument(this.message) : new NativePlanDocument();
    this.structured = nativeToolStructured(this.message, this.workspaceRoot);
    this.detail = nativeToolDetail(this.message, this.workspaceRoot);
  }
  private toggle(): void {
    if (this.message.phase === 'preparing') return;
    NativeMotion.disclosure(this.getUIContext(), (): void => {
      this.expanded = !this.expanded;
      this.disclosures.set(this.message.turnKey + '|' + this.message.id, this.expanded);
    });
  }
  build() {
    Column({ space: 4 }) {
      if (!this.hideHeader) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            DSHIcon({ glyph: nativeProcessIcon(nativeToolCategory(this.message.toolName, this.message.args)),
              color: NativeDesign.textTertiary(this.dark), glyphSize: 14 })
            Text(nativeActivity(nativeToolCategory(this.message.toolName, this.message.args),
              this.message.status === 'running' || this.message.status === 'preparing'))
              .fontSize(12).fontWeight(FontWeight.Medium)
              .fontColor(NativeDesign.textSecondary(this.dark)).maxLines(1)
            if (this.detail) {
              Text('·').fontSize(12).fontColor(NativeDesign.textTertiary(this.dark))
              Text(this.detail).fontSize(12).layoutWeight(1).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(NativeDesign.textTertiary(this.dark))
                .opacity(this.expanded ? 0 : 1).translate({ x: this.expanded ? 4 : 0 })
                .animation(NativeMotion.disclosureParam())
            } else {
              Blank().layoutWeight(1)
            }
            if (this.diff.matched && (this.diff.added > 0 || this.diff.removed > 0)) {
              Text('+' + this.diff.added).fontSize(10).fontWeight(FontWeight.Medium)
                .fontColor(NativeDesign.success(this.dark))
              Text('-' + this.diff.removed).fontSize(10).fontWeight(FontWeight.Medium)
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
        }.height(30).width('100%').padding({ left: 2, right: 2 }).backgroundColor(Color.Transparent)
          .responseRegion({ x: 0, y: -7, width: '100%', height: NativeDesign.hitTarget })
          .onClick(() => { this.toggle(); })
      }
      if (this.forceExpanded || this.expanded) {
        Scroll() {
          Column({ space: 6 }) {
            if (this.diff.matched) {
              NativeDiffBlock({ document: this.diff })
            } else if (this.message.toolName === 'todo_write') {
              if (this.plan.parsed) {
                NativePlanView({ document: this.plan })
              } else {
                Text(this.message.phase === 'preparing' ? '正在更新计划' : '计划内容不可用')
                  .fontSize(12).fontColor(NativeDesign.textTertiary(this.dark))
              }
            } else if (this.structured.bodyStructured) {
              NativeStructuredToolView({
                client: this.client,
                sessionId: this.sessionId,
                document: this.structured,
                maxExpandedHeight: this.maxExpandedHeight,
                onOpenFile: this.onOpenFile
              })
            }
            if (!this.diff.matched && this.message.toolName !== 'todo_write' &&
              this.structured.showRawArguments && this.message.args &&
              nativeToolArgumentsVisible(this.message)) {
              NativeTextContent({ text: this.message.args, monospace: true, client: this.client, sessionId: this.sessionId })
            }
            if (this.message.images.length) {
              NativeImageStrip({
                client: this.client,
                sessionId: this.sessionId,
                attachments: this.message.images
              })
            }
            if (!this.diff.matched && this.message.toolName !== 'todo_write' &&
              this.structured.showRawOutput &&
              this.message.output && nativeToolOutputVisible(this.message)) {
              Divider().color(NativeDesign.divider(this.dark))
              if (this.message.blocks.length) {
                NativeRichContent({
                  blocks: this.message.blocks,
                  client: this.client,
                  sessionId: this.sessionId
                })
              } else {
                NativeTextContent({ text: this.message.output, client: this.client, sessionId: this.sessionId })
              }
            }
            if (this.message.error) { Text(this.message.error).fontSize(12)
              .fontColor(NativeDesign.danger(this.dark)) }
            if (this.message.status === 'interrupted') {
              Text('已中断').fontSize(11).fontColor(NativeDesign.textTertiary(this.dark))
            }
            ForEach(this.message.children, (child: NativeMessage) => {
              NativeNestedToolRow({ client: this.client, sessionId: this.sessionId, message: child,
                workspaceRoot: this.workspaceRoot, onOpenFile: this.onOpenFile,
                maxExpandedHeight: this.maxExpandedHeight })
            }, (child: NativeMessage) => child.id)
          }.padding({ left: 8, right: 16, top: 8, bottom: 8 }).width('100%')
            .alignItems(HorizontalAlign.Start).borderRadius(8)
            .backgroundColor(NativeDesign.field(this.dark))
        }.width('100%').constraintSize({ maxHeight: Math.max(96, this.maxExpandedHeight) })
          .scrollable(ScrollDirection.Vertical).scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.None)
          .transition(NativeMotion.disclosureTransition())
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}

/** Non-recursive summary for nested PTC actions. */
@Component
struct NativeNestedToolRow {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  workspaceRoot: string = '';
  onOpenFile: (path: string) => void = (_path: string): void => {};
  @Prop @Watch('changed') message: NativeMessage = new NativeMessage();
  @Prop maxExpandedHeight: number = 240;
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private expanded: boolean = false;
  @State private structured: NativeToolStructured = new NativeToolStructured();

  aboutToAppear(): void { this.changed(); }
  private changed(): void {
    this.structured = nativeToolStructured(this.message, this.workspaceRoot);
  }
  private preview(): string { return nativeToolDetail(this.message, this.workspaceRoot); }
  private toggle(): void {
    NativeMotion.disclosure(this.getUIContext(), (): void => { this.expanded = !this.expanded; });
  }

  build() {
    Column({ space: this.expanded ? 4 : 0 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 6 }) {
          DSHIcon({ glyph: nativeProcessIcon(nativeToolCategory(this.message.toolName, this.message.args)),
            color: NativeDesign.textTertiary(this.dark), glyphSize: 13 })
          Text(nativeActivity(nativeToolCategory(this.message.toolName, this.message.args),
            this.message.status === 'running' || this.message.status === 'preparing'))
            .fontSize(11).fontColor(NativeDesign.textSecondary(this.dark))
          if (this.preview()) {
            Text('·').fontSize(11).fontColor(NativeDesign.textTertiary(this.dark))
            Text(this.preview()).fontSize(11).layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textTertiary(this.dark))
              .opacity(this.expanded ? 0 : 1)
              .animation(NativeMotion.disclosureParam())
          } else {
            Blank().layoutWeight(1)
          }
          DSHIcon({ glyph: 'chevron-left-outline',
            color: NativeDesign.textTertiary(this.dark), glyphSize: 11 })
            .rotate({ angle: this.expanded ? -90 : 180 })
            .animation(NativeMotion.disclosureParam())
        }.width('100%')
      }.height(28).width('100%').padding({ left: 2, right: 2 })
        .responseRegion({ x: 0, y: -8, width: '100%', height: NativeDesign.hitTarget })
        .backgroundColor(Color.Transparent).onClick((): void => { this.toggle(); })
      if (this.expanded) {
        Scroll() {
          Column({ space: 5 }) {
            if (this.message.images.length) {
              NativeImageStrip({
                client: this.client,
                sessionId: this.sessionId,
                attachments: this.message.images
              })
            }
            if (this.structured.bodyStructured) {
              NativeStructuredToolView({
                client: this.client,
                sessionId: this.sessionId,
                document: this.structured,
                maxExpandedHeight: this.maxExpandedHeight,
                onOpenFile: this.onOpenFile
              })
            }
            if (this.structured.showRawArguments && this.message.args &&
              nativeToolArgumentsVisible(this.message)) {
              NativeTextContent({ text: this.message.args, monospace: true,
                client: this.client, sessionId: this.sessionId })
            }
            if (this.structured.showRawOutput && this.message.output &&
              nativeToolOutputVisible(this.message)) {
              if (this.message.blocks.length) {
                NativeRichContent({
                  blocks: this.message.blocks,
                  client: this.client,
                  sessionId: this.sessionId
                })
              } else {
                NativeTextContent({ text: this.message.output,
                  client: this.client, sessionId: this.sessionId })
              }
            }
          }.width('100%').padding({ right: 10 }).alignItems(HorizontalAlign.Start)
        }.width('100%').constraintSize({ maxHeight: Math.max(80, this.maxExpandedHeight * 0.7) })
          .scrollable(ScrollDirection.Vertical).edgeEffect(EdgeEffect.None)
          .transition(NativeMotion.disclosureTransition())
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
