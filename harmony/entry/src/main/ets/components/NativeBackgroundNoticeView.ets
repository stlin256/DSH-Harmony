import { NativeMessage } from '../services/NativeSessionModel';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';
import { DSHIcon } from './DSHIcon';

/**
 * A Host-authored `tool-jobs` notice.
 *
 * The body is intentionally plain, selectable text. It cannot become a user
 * prompt, link, Markdown action, steering message or queue command.
 */
@Component
export struct NativeBackgroundNoticeView {
  @Prop @Watch('changed') message: NativeMessage = new NativeMessage();
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private expanded: boolean = false;
  private identity: string = '';

  aboutToAppear(): void {
    this.identity = this.message.id;
  }

  private changed(): void {
    if (this.identity !== this.message.id) {
      this.identity = this.message.id;
      this.expanded = false;
    }
  }

  private preview(): string {
    return (this.message.text || '').replace(/\s+/g, ' ').trim();
  }

  private title(): string {
    return this.message.sourceForm === 'notice' ? '后台任务' : '后台任务消息';
  }

  private toggle(): void {
    if (!this.message.text) return;
    NativeMotion.disclosure(this.getUIContext(), (): void => {
      this.expanded = !this.expanded;
    });
  }

  build() {
    Column({ space: 4 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 7 }) {
          DSHIcon({ glyph: 'queue-outline', glyphSize: NativeDesign.glyphCompact,
            color: NativeDesign.textTertiary(this.dark) })
          Text(this.title()).fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium)
            .fontColor(NativeDesign.textSecondary(this.dark))
          if (!this.expanded && this.preview()) {
            Text('·').fontSize(NativeDesign.fontSection).fontColor(NativeDesign.textTertiary(this.dark))
            Text(this.preview()).layoutWeight(1).fontSize(NativeDesign.fontCaption).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textTertiary(this.dark))
          } else {
            Blank()
          }
          if (this.message.text) {
            DSHIcon({ glyph: 'chevron-left-outline', glyphSize: NativeDesign.glyphInline,
              color: NativeDesign.textTertiary(this.dark) })
              .rotate({ angle: this.expanded ? -90 : 180 })
              .animation(NativeMotion.disclosureParam())
          }
        }.width('100%')
      }.height(NativeDesign.compactControl).width('100%').padding({ left: 2, right: 2 })
        .responseRegion({ x: 0, y: -7, width: '100%', height: NativeDesign.hitTarget })
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.expanded ? '收起后台任务消息' : '展开后台任务消息')
        .onClick((): void => { this.toggle(); })
      if (this.expanded && this.message.text) {
        Scroll() {
          Text(this.message.text).width('100%').fontSize(NativeDesign.fontCaption).lineHeight(17)
            .fontFamily('Noto Sans Mono, monospace')
            .fontColor(NativeDesign.textSecondary(this.dark))
            .copyOption(CopyOptions.InApp)
        }.width('100%').constraintSize({ maxHeight: 200 })
          .scrollable(ScrollDirection.Vertical).scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.None)
          .padding({ left: 9, right: 12, top: 8, bottom: 8 })
          .borderRadius(NativeDesign.radiusRow)
          .backgroundColor(NativeDesign.field(this.dark))
          .transition(NativeMotion.disclosureTransition())
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
