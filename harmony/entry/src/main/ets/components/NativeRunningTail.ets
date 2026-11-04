import { NativeDesign } from '../services/NativeDesign';
import { NativeMotion } from '../services/NativeMotion';
import { nativeRunningElapsed, nativeRunningLabel } from '../services/NativeRunningStatus';

/** Whale-tail path from the DSH client's RunningWhaleTail static SVG fallback. */
const RUNNING_WHALE_PATH: string =
  'M8.844 13.742C8.967 12.328 8.45 10.4 8.45 9.65C8.45 8.94 8.88 8.43 9.6 8.43C11.285 8.43 ' +
  '12.106 8.281 12.685 8.104C13.71 7.791 14.585 6.768 15.055 5.945C15.137 5.803 14.99 5.641 14.829 5.671C13.829 ' +
  '5.86 12.828 5.376 11.827 4.978C10.659 4.514 9.491 4.707 8.935 4.876C8.805 4.915 8.658 4.819 8.636 4.686C8.468 ' +
  '3.643 7.405 2.615 5.498 2.238C4.54 2.048 3.748 1.574 3.347 1.202C3.252 1.113 3.088 1.125 3.03 1.242C2.628 ' +
  '2.059 2.168 3.82 5.248 6.115C5.82 6.494 6.31 6.785 6.574 7.637C6.72 8.104 6.157 9.168 6.061 9.368C5.157 ' +
  '11.27 5.089 12.19 4.926 13.742';

/**
 * Running-turn tail: the DSH whale and '深度求索中，用时 X ···' line. The whale
 * uses the colorized DSH frames and a gentle tail sway; the label shimmer is a
 * semantic color sweep between the DSH deep-diving and shimmer tokens so the
 * animation stays inside the glyphs without a blend-layer halo.
 */
@Component
export struct NativeRunningTail {
  @Prop @Watch('turnChanged') turnKey: string = '';
  @Prop paused: boolean = false;
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private now: number = Date.now();
  @State private startedAt: number = 0;
  @State private frozenElapsed: number = 0;
  @State private shimmered: boolean = false;
  @State private whaleTilt: number = -12;
  @State private whaleScale: number = 1;
  private clockTimer: number = -1;
  private animTimer: number = -1;
  private animStart: number = 0;

  aboutToAppear(): void {
    if (this.turnKey !== '') this.startedAt = Date.now();
    this.clockTimer = setInterval((): void => {
      if (this.startedAt > 0 && !this.paused) this.now = Date.now();
    }, 1000);
    if (NativeMotion.enabled()) {
      this.animStart = Date.now();
      this.animTimer = setInterval((): void => { this.stepAnimation(); }, 100);
    }
  }

  aboutToDisappear(): void {
    if (this.clockTimer >= 0) clearInterval(this.clockTimer);
    if (this.animTimer >= 0) clearInterval(this.animTimer);
    this.clockTimer = -1;
    this.animTimer = -1;
  }

  private stepAnimation(): void {
    if (this.paused) return;
    const elapsed = Date.now() - this.animStart;
    const wave = Math.sin((elapsed / 900) * 2 * Math.PI);
    this.whaleTilt = wave * 12;
    this.whaleScale = 0.86 + (wave + 1) * 0.14;
    this.shimmered = Math.floor(elapsed / 750) % 2 === 1;
  }

  private turnChanged(): void {
    if (this.turnKey !== '' && this.startedAt === 0) this.startedAt = Date.now();
    if (!this.paused) this.now = Date.now();
  }

  private elapsed(): number {
    return nativeRunningElapsed(this.startedAt, this.now, this.paused, this.frozenElapsed);
  }

  private label(): string {
    return nativeRunningLabel(this.elapsed(), this.paused);
  }

  private deepDivingColor(): string {
    return NativeDesign.deepDiving(this.dark);
  }

  private shimmerColor(): string {
    return NativeDesign.deepDivingShimmer(this.dark);
  }

  private labelColor(): string {
    return this.shimmered ? this.shimmerColor() : this.deepDivingColor();
  }

  @Builder
  private tailIcon() {
    if (NativeMotion.enabled()) {
      Image(this.dark ? $r('app.media.running_whale_dark') : $r('app.media.running_whale_light'))
        .width(14).height(14).objectFit(ImageFit.Contain)
        .rotate({ angle: this.whaleTilt, centerX: '50%', centerY: '80%' })
        .scale({ x: 1, y: this.whaleScale, centerX: '50%', centerY: '80%' })
        .accessibilityLevel('no')
    } else {
      Shape() {
        Path()
          .commands(RUNNING_WHALE_PATH)
          .fill(Color.Transparent)
          .stroke(this.deepDivingColor())
          .strokeWidth(1)
      }.viewPort({ x: 0, y: 0, width: 16, height: 16 }).width(14).height(14)
        .accessibilityLevel('no')
    }
  }

  build() {
    Column({ space: 0 }) {
      Divider().strokeWidth(0.5).color(NativeDesign.divider(this.dark)).opacity(0.7)
      Row({ space: 6 }) {
        this.tailIcon()
        Text(this.label())
          .fontSize(NativeDesign.fontCaption)
          .lineHeight(22)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontFeature('"tnum" 1')
          .fontColor(this.labelColor())
        Blank()
      }.width('100%').height(28)
        .padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset })
        .alignItems(VerticalAlign.Center)
    }.width('100%').id('running-tail')
      .accessibilityGroup(true)
      .accessibilityText(this.paused ? '深度求索中，连接暂时中断' : this.label())
  }
}
