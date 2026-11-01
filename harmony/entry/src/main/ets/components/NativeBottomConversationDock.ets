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
            // The component material is much lighter than window material.
            // Gradient foreground blur keeps its upper edge visually open.
            .width('100%').height(this.measuredHeight)
            .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN, {
              colorMode: this.dark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT
            })
            .linearGradientBlur(24, {
              fractionStops: [[0, 0], [0.18, 0], [0.58, 0.56], [1, 1]],
              direction: GradientDirection.Bottom
            })
            .opacity(0.88)
          Column()
            .width('100%').height(this.measuredHeight)
            // A translucent theme scrim provides the visible top-to-bottom
            // falloff without replacing the live backdrop with an opaque fill.
            .linearGradient({
              angle: 180,
              colors: this.dark
                ? [['#001D1E20', 0], ['#261D1E20', 0.18], ['#70242628', 0.62], ['#A627292C', 1]]
                : [['#00FFFFFF', 0], ['#29FFFFFF', 0.18], ['#8FFFFFFF', 0.62], ['#D9FFFFFF', 1]]
            })
        }.width('100%').height(this.measuredHeight)
          .transition(NativeMotion.rowTransition())
          .animation(NativeMotion.disclosureParam())
      }
      Column() {
        this.content()
      }.width('100%').margin({ left: -this.horizontalBleed, right: -this.horizontalBleed })
        .padding({ left: this.horizontalBleed + this.contentInset, right: this.horizontalBleed + this.contentInset,
          top: 8, bottom: Math.ceil(this.safeBottom * 1.2) + 8 })
    }.width('100%').onAreaChange((_old: Area, area: Area): void => {
      const height = Number(area.height);
      if (height <= 0 || height === this.measuredHeight) return;
      this.measuredHeight = height;
      this.onHeight(height);
    })
  }
}
