import { NativeExperience } from '../services/NativeExperience';
import { NativeMotion } from '../services/NativeMotion';

/**
 * Shared bottom conversation layout. Extra dock content enables a conditionally
 * masked blur; the composer keeps its own local surface.
 */
@Component
export struct NativeBottomConversationDock {
  @BuilderParam content: () => void;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @StorageLink('nativeDark') private dark: boolean = false;
  @Prop horizontalBleed: number = 0;
  @Prop contentInset: number = 12;
  @Prop elevated: boolean = false;
  @State private measuredHeight: number = 0;
  onHeight: (height: number) => void = (_height: number): void => {};

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.elevated && NativeExperience.materialsEnabled()) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column()
            // Component material performs the actual backdrop blur. The
            // theme gradient below only controls visibility of that material.
            .width('100%').height(this.measuredHeight)
            .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
              colorMode: this.dark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT
            })
          Column()
            .width('100%').height(this.measuredHeight)
            // A translucent theme scrim provides the visible top-to-bottom
            // falloff while retaining background detail above the bottom edge.
            .linearGradient({
              angle: 180,
              colors: this.dark
                ? [['#001D1E20', 0], ['#241D1E20', 0.18], ['#661F2022', 0.62], ['#B3232528', 1]]
                : [['#00FFFFFF', 0], ['#24FFFFFF', 0.18], ['#70FFFFFF', 0.62], ['#B8FFFFFF', 1]]
            })
        }.width('100%').height(this.measuredHeight)
          .clip(true)
          .transition(TransitionEffect.OPACITY.animation(
            NativeMotion.disclosureParam()))
          .animation(NativeMotion.disclosureParam())
      }
      Column() {
        this.content()
      }.width('100%').margin({ left: -this.horizontalBleed, right: -this.horizontalBleed })
        .padding({ left: this.horizontalBleed + this.contentInset, right: this.horizontalBleed + this.contentInset,
          top: 8, bottom: Math.ceil(this.safeBottom * 1.2) + 8 })
        .animation(NativeMotion.disclosureParam())
    }.width('100%').clip(true).onAreaChange((_old: Area, area: Area): void => {
      const height = Number(area.height);
      if (height <= 0 || height === this.measuredHeight) return;
      this.measuredHeight = height;
      this.onHeight(height);
    })
  }
}
