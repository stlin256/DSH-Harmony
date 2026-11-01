import { DSHIcon } from './DSHIcon';
import { NativeMotion } from '../services/NativeMotion';
import { NativePlanDocument, nativePlanProgress } from '../services/NativePlan';
import { NativePlanView } from './NativePlanView';
import { NativeDesign } from '../services/NativeDesign';

/** Floating current-plan control anchored below the conversation title. */
@Component
export struct NativeTaskDock {
  @Prop @Watch('sessionChanged') document: NativePlanDocument = new NativePlanDocument();
  @Prop @Watch('sessionChanged') sessionId: string = '';
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private expanded: boolean = false;
  private currentSession: string = '';

  aboutToAppear(): void {
    this.currentSession = this.sessionId;
  }

  private sessionChanged(): void {
    if (this.currentSession === this.sessionId) return;
    this.currentSession = this.sessionId;
    this.expanded = false;
  }

  private toggle(): void {
    NativeMotion.disclosure(this.getUIContext(), (): void => {
      this.expanded = !this.expanded;
    });
  }

  build() {
    Column({ space: 0 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 5 }) {
          DSHIcon({ glyph: 'plan-outline', glyphSize: 14,
            color: NativeDesign.textSecondary(this.dark) })
          Text('任务计划').fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
            .fontColor(NativeDesign.textPrimary(this.dark))
          Text(nativePlanProgress(this.document)).fontSize(10).layoutWeight(1).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textTertiary(this.dark))
          DSHIcon({ glyph: this.expanded ? 'chevron-up-outline' : 'chevron-down-outline',
            glyphSize: 11, color: NativeDesign.textTertiary(this.dark) })
        }.width('100%').padding({ left: 10, right: 8 })
      }.height(NativeDesign.hitTarget).width('100%').padding(0).borderRadius(0)
        .backgroundColor(Color.Transparent)
        .accessibilityText((this.expanded ? '收起' : '展开') + '任务计划')
        .onClick((): void => { this.toggle(); })
      if (this.expanded) {
        Divider().color(NativeDesign.divider(this.dark))
        Scroll() {
          NativePlanView({ document: this.document, showHeader: false })
            .padding({ left: 10, right: 7, top: 7, bottom: 8 })
        }.width('100%').constraintSize({ maxHeight: 180 })
          .scrollable(ScrollDirection.Vertical).scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.None)
          .transition(NativeMotion.disclosureTransition())
      }
    }.width('100%').constraintSize({ maxWidth: 620 }).clip(true)
      .borderRadius(NativeDesign.radiusGroup)
      .backgroundColor(NativeDesign.raised(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
      .shadow({ radius: 18, color: this.dark ? '#88000000' : '#26000000',
        offsetX: 0, offsetY: 5 })
      .animation(NativeMotion.disclosureParam())
  }
}
