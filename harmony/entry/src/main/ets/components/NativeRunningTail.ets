import { NativeDesign } from '../services/NativeDesign';
import { NativeRunningWhale } from './NativeRunningWhale';
import { NativeMotion } from '../services/NativeMotion';
import { nativeRunningElapsed, nativeRunningLabel } from '../services/NativeRunningStatus';

/** One catch-light pass from the whale through the copy and the trailing dots. */
const SWEEP_CYCLE_MS = 2000;
const SWEEP_INTERVAL_MS = 33;
const SWEEP_TRAVEL_START = -0.35;
const SWEEP_TRAVEL_END = 1.35;
const SWEEP_BAND = 0.16;
const LABEL_HEIGHT = 28;
const ICON_SIZE = 18;

/**
 * Running-turn tail at the end of the transcript: DSH whale and
 * '深度求索中，用时 X ···'. The elapsed time comes from the authoritative turn/start
 * timestamp (never a local guess). A single light band travels from the whale
 * through every glyph and the trailing dots; it fades out completely past the
 * row before the next pass starts, so the shimmer never snaps back.
 */
@Component
export struct NativeRunningTail {
  /** Authoritative turn/start epoch ms from the Host event log; 0 when unknown. */
  @Prop startedAt: number = 0;
  @Prop @Watch('pausedChanged') paused: boolean = false;
  /** Parent keeps the row mounted until the exit animation settles. */
  /** 0..1 appearance progress driven once by the workspace; stays 1 across list reloads. */
  @Prop progress: number = 1;
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private now: number = Date.now();
  @State private frozenElapsed: number = 0;
  @State private sweep: number = 0;
  private clockTimer: number = -1;
  private sweepTimer: number = -1;
  private sweepStart: number = 0;
  private mounted: boolean = true;

  aboutToAppear(): void {
    this.mounted = true;
    this.clockTimer = setInterval((): void => {
      if (!this.mounted || this.paused || !this.appActive()) return;
      this.now = Date.now();
    }, 1000);
    if (NativeMotion.enabled()) this.startSweep();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    if (this.clockTimer >= 0) clearInterval(this.clockTimer);
    if (this.sweepTimer >= 0) clearInterval(this.sweepTimer);
    this.clockTimer = -1;
    this.sweepTimer = -1;
  }

  /** Never tick timers while the ability is backgrounded. */
  private appActive(): boolean {
    return AppStorage.get<boolean>('nativeAppActive') !== false;
  }

  private startSweep(): void {
    if (this.sweepTimer >= 0) return;
    this.sweepStart = Date.now();
    this.sweepTimer = setInterval((): void => {
      if (!this.mounted || this.paused || !this.appActive()) return;
      this.sweep = ((Date.now() - this.sweepStart) % SWEEP_CYCLE_MS) / SWEEP_CYCLE_MS;
    }, SWEEP_INTERVAL_MS);
  }

  private pausedChanged(): void {
    if (this.paused) {
      this.frozenElapsed = Math.max(1000, Date.now() - this.startedAt);
      return;
    }
    this.frozenElapsed = 0;
    this.now = Date.now();
    if (NativeMotion.enabled()) {
      this.sweepStart = Date.now();
      this.startSweep();
    }
  }


  private elapsed(): number {
    return nativeRunningElapsed(this.startedAt, this.now, this.paused, this.frozenElapsed);
  }

  private label(): string {
    return nativeRunningLabel(this.elapsed(), this.paused);
  }

  private travel(): number {
    return SWEEP_TRAVEL_START + this.sweep * (SWEEP_TRAVEL_END - SWEEP_TRAVEL_START);
  }

  /** Fade the band out before/after the row so every pass is complete. */
  private bandGate(): number {
    const travel = this.travel();
    const entering = Math.min(1, Math.max(0, (travel + 0.2) / 0.22));
    const leaving = Math.min(1, Math.max(0, (1.2 - travel) / 0.22));
    return entering * leaving;
  }

  private withAlpha(hex: string, alpha: number): string {
    const value = Math.max(0, Math.min(255, Math.round(alpha * 255)));
    const digits = '0123456789abcdef';
    const a = digits.charAt(Math.floor(value / 16)) + digits.charAt(value % 16);
    return '#' + a + hex.replace('#', '');
  }

  private labelStyle(): ShaderStyle {
    const base = NativeDesign.deepDiving(this.dark);
    const gate = NativeMotion.enabled() ? this.bandGate() : 0;
    if (gate <= 0.01) {
      const flat: Array<[ResourceColor, number]> = [[base, 0], [base, 1]];
      return new LinearGradientStyle({ angle: 90, colors: flat });
    }
    const highlight = this.withAlpha(NativeDesign.deepDivingShimmer(this.dark), gate);
    const center = Math.max(0.001, Math.min(0.999, this.travel()));
    const start = Math.max(0, center - SWEEP_BAND);
    const end = Math.min(1, center + SWEEP_BAND);
    const stops: Array<[ResourceColor, number]> = [[base, 0], [base, start],
      [highlight, center], [base, end], [base, 1]];
    return new LinearGradientStyle({ angle: 90, colors: stops });
  }

  private iconGlow(): number {
    if (!NativeMotion.enabled()) return 0;
    const distance = Math.abs(this.travel() - 0.02);
    return Math.max(0, Math.min(1, 1 - distance / 0.3));
  }

  @Builder
  private tailIcon() {
    Stack() {
      NativeRunningWhale({ dark: this.dark })
      Image(this.dark ? $r('app.media.running_whale_glow_dark') : $r('app.media.running_whale_glow_light'))
        .width(ICON_SIZE).height(ICON_SIZE).objectFit(ImageFit.Contain)
        .opacity(this.iconGlow())
    }.width(ICON_SIZE).height(ICON_SIZE).accessibilityLevel('no')
  }
  build() {
    Column({ space: 0 }) {
      Divider().strokeWidth(0.5).color(NativeDesign.divider(this.dark)).opacity(0.7)
      Row({ space: 7 }) {
        this.tailIcon()
        Text(this.label())
          .fontSize(NativeDesign.fontCaption)
          .lineHeight(22)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontFeature('"tnum" 1')
          .shaderStyle(this.labelStyle())
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
      .accessibilityText(this.paused ? '深度求索中，连接暂时中断' : this.label())
  }
}