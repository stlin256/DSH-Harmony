import { NativeMotion } from '../services/NativeMotion';

const ICON_SIZE = 18;

/**
 * The DSH running whale as a native frame animation (ImageAnimator), built
 * from the upstream APNG frames re-colored for both themes. Kept in its own
 * component so parent sweep state never rebuilds the animation.
 */
@Component
export struct NativeRunningWhale {
  @Prop dark: boolean = false;
  private darkFrames: ImageFrameInfo[] = [
    { src: $r('app.media.running_whale_frame_dark_00') },
    { src: $r('app.media.running_whale_frame_dark_01') },
    { src: $r('app.media.running_whale_frame_dark_02') },
    { src: $r('app.media.running_whale_frame_dark_03') },
    { src: $r('app.media.running_whale_frame_dark_04') },
    { src: $r('app.media.running_whale_frame_dark_05') },
    { src: $r('app.media.running_whale_frame_dark_06') },
    { src: $r('app.media.running_whale_frame_dark_07') },
    { src: $r('app.media.running_whale_frame_dark_08') },
    { src: $r('app.media.running_whale_frame_dark_09') },
    { src: $r('app.media.running_whale_frame_dark_10') },
    { src: $r('app.media.running_whale_frame_dark_11') },
    { src: $r('app.media.running_whale_frame_dark_12') },
    { src: $r('app.media.running_whale_frame_dark_13') },
    { src: $r('app.media.running_whale_frame_dark_14') }
  ];
  private lightFrames: ImageFrameInfo[] = [
    { src: $r('app.media.running_whale_frame_light_00') },
    { src: $r('app.media.running_whale_frame_light_01') },
    { src: $r('app.media.running_whale_frame_light_02') },
    { src: $r('app.media.running_whale_frame_light_03') },
    { src: $r('app.media.running_whale_frame_light_04') },
    { src: $r('app.media.running_whale_frame_light_05') },
    { src: $r('app.media.running_whale_frame_light_06') },
    { src: $r('app.media.running_whale_frame_light_07') },
    { src: $r('app.media.running_whale_frame_light_08') },
    { src: $r('app.media.running_whale_frame_light_09') },
    { src: $r('app.media.running_whale_frame_light_10') },
    { src: $r('app.media.running_whale_frame_light_11') },
    { src: $r('app.media.running_whale_frame_light_12') },
    { src: $r('app.media.running_whale_frame_light_13') },
    { src: $r('app.media.running_whale_frame_light_14') }
  ];

  @Builder
  private still() {
    Image(this.dark ? $r('app.media.running_whale_frame_dark_00') :
      $r('app.media.running_whale_frame_light_00'))
      .width(ICON_SIZE).height(ICON_SIZE).objectFit(ImageFit.Contain)
  }

  build() {
    if (NativeMotion.enabled()) {
      ImageAnimator()
        .images(this.dark ? this.darkFrames : this.lightFrames)
        .duration(3000)
        .iterations(-1)
        .width(ICON_SIZE).height(ICON_SIZE)
        .accessibilityLevel('no')
    } else {
      this.still()
    }
  }
}