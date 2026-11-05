import { NativeDesign } from '../services/NativeDesign';
import { NativeMotion } from '../services/NativeMotion';
import { nativeRunningElapsed, nativeRunningLabel } from '../services/NativeRunningStatus';

const SWEEP_CYCLE_MS = 2000;
const SWEEP_INTERVAL_MS = 33;
const SWEEP_TRAVEL_START = -0.35;
const SWEEP_TRAVEL_END = 1.35;
const SWEEP_BAND = 0.16;

/**
 * The running label owns the 1s clock and 33ms light-sweep state, so its
 * re-renders never touch the sibling whale animation.
 */
@Component
export struct NativeRunningLabel {
  @Prop startedAt: number = 0;
  @Prop @Watch('pausedChanged') paused: boolean = false;
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

  build() {
    Text(this.label())
      .fontSize(NativeDesign.fontCaption)
      .lineHeight(22)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .fontFeature('"tnum" 1')
      .shaderStyle(this.labelStyle())
      .layoutWeight(1)
  }
}