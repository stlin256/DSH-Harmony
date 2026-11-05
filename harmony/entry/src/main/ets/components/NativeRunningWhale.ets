import { NativeDesign } from '../services/NativeDesign';

const ICON_SIZE = 18;

/**
 * The DSH running whale, re-colored frame by frame from the upstream APNG.
 * Kept in its own component so the parent's sweep state never rebuilds the
 * animated image and restarts its frame loop.
 */
@Component
export struct NativeRunningWhale {
  @Prop dark: boolean = false;

  build() {
    Image(this.dark ? $r('app.media.running_whale_loop_dark') : $r('app.media.running_whale_loop_light'))
      .width(ICON_SIZE).height(ICON_SIZE).objectFit(ImageFit.Contain)
  }
}