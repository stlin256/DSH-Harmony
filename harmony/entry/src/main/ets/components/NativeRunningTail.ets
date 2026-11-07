import { NativeDesign } from '../services/NativeDesign';
import { NativeMotion } from '../services/NativeMotion';
import { NativeRunningLabel } from './NativeRunningLabel';
import { NativeRunningWhale } from './NativeRunningWhale';

const ICON_SIZE = 18;
const LABEL_HEIGHT = 28;

/**
 * Running-turn row at the very end of the conversation: DSH whale and
 * '深度求索中，用时 X ···'. The clock and sweep live in NativeRunningLabel, so
 * this layout (and the whale animation beside it) is not rebuilt per frame.
 */
@Component
export struct NativeRunningTail {
  @Prop startedAt: number = 0;
  @Prop paused: boolean = false;
  @Prop progress: number = 1;
  @Prop quiet: boolean = false;
  @StorageLink('nativeDark') private dark: boolean = false;

  private iconGlow(): number {
    return NativeMotion.enabled() && !this.paused ? 0 : 0;
  }

  build() {
    Column({ space: 0 }) {
      Divider().strokeWidth(0.5).color(NativeDesign.divider(this.dark)).opacity(0.7)
      Row({ space: 7 }) {
        NativeRunningWhale({ dark: this.dark })
        NativeRunningLabel({ startedAt: this.startedAt, paused: this.paused })
        Blank()
      }.width('100%').height(LABEL_HEIGHT)
        .padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset })
        .alignItems(VerticalAlign.Center)
    }.width('100%').id('running-tail')
      .height((LABEL_HEIGHT + 1) * this.progress)
      .opacity(this.progress)
      .translate({ y: (1 - this.progress) * 4 })
      .clip(true)
      .accessibilityGroup(true)
      .accessibilityText(this.paused ? '深度求索中，连接暂时中断' : '深度求索中')
  }
}