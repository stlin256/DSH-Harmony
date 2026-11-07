import { NativeMotion } from '../services/NativeMotion';

const ICON_SIZE = 18;
const FRAME_MS = 200;

/**
 * DSH running whale as a timer-driven still sequence built from the upstream
 * APNG frames. A static Image swap keeps the animation alive even when the
 * parent running-tail row re-renders for the sweep.
 */
@Component
export struct NativeRunningWhale {
  @Prop dark: boolean = false;
  @Prop glyphSize: number = ICON_SIZE;
  @Prop quiet: boolean = false;
  @State private frameIndex: number = 0;
  private timer: number = -1;
  private mounted: boolean = true;
  private darkFrames: Resource[] = [
        $r('app.media.running_whale_frame_dark_00'),
        $r('app.media.running_whale_frame_dark_01'),
        $r('app.media.running_whale_frame_dark_02'),
        $r('app.media.running_whale_frame_dark_03'),
        $r('app.media.running_whale_frame_dark_04'),
        $r('app.media.running_whale_frame_dark_05'),
        $r('app.media.running_whale_frame_dark_06'),
        $r('app.media.running_whale_frame_dark_07'),
        $r('app.media.running_whale_frame_dark_08'),
        $r('app.media.running_whale_frame_dark_09'),
        $r('app.media.running_whale_frame_dark_10'),
        $r('app.media.running_whale_frame_dark_11'),
        $r('app.media.running_whale_frame_dark_12'),
        $r('app.media.running_whale_frame_dark_13'),
        $r('app.media.running_whale_frame_dark_14')
  ];
  private lightFrames: Resource[] = [
        $r('app.media.running_whale_frame_light_00'),
        $r('app.media.running_whale_frame_light_01'),
        $r('app.media.running_whale_frame_light_02'),
        $r('app.media.running_whale_frame_light_03'),
        $r('app.media.running_whale_frame_light_04'),
        $r('app.media.running_whale_frame_light_05'),
        $r('app.media.running_whale_frame_light_06'),
        $r('app.media.running_whale_frame_light_07'),
        $r('app.media.running_whale_frame_light_08'),
        $r('app.media.running_whale_frame_light_09'),
        $r('app.media.running_whale_frame_light_10'),
        $r('app.media.running_whale_frame_light_11'),
        $r('app.media.running_whale_frame_light_12'),
        $r('app.media.running_whale_frame_light_13'),
        $r('app.media.running_whale_frame_light_14')
  ];

  aboutToAppear(): void {
    this.mounted = true;
    if (!NativeMotion.enabled()) return;
    this.timer = setInterval((): void => {
      if (!this.mounted || this.quiet || !NativeMotion.enabled()) return;
      this.frameIndex = (this.frameIndex + 1) % 15;
    }, FRAME_MS);
  }

  aboutToDisappear(): void {
    this.mounted = false;
    if (this.timer >= 0) clearInterval(this.timer);
    this.timer = -1;
  }

  build() {
    Image(this.dark ? this.darkFrames[this.frameIndex] : this.lightFrames[this.frameIndex])
      .width(this.glyphSize).height(this.glyphSize).objectFit(ImageFit.Contain)
      .accessibilityLevel('no')
  }
}