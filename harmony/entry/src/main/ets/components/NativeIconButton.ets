import { DSHIcon } from './DSHIcon';
import { NativeDesign } from '../services/NativeDesign';
import { NativeMotion } from '../services/NativeMotion';

/**
 * One 36vp visual icon container inside a 44vp interaction region.
 * State feedback paints the container while the hit region stays stable.
 */
@Component
export struct NativeIconButton {
  @Prop glyph: string = 'ellipsis-outline';
  @Prop label: string = '';
  @Prop active: boolean = false;
  @Prop controlEnabled: boolean = true;
  @Prop tone: string = 'secondary';
  @Prop glyphSize: number = NativeDesign.glyphControl;
  onPressed: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;

  private color(): ResourceColor {
    if (this.tone === 'primary' || this.active) return NativeDesign.textPrimary(this.dark);
    if (this.tone === 'accent') return NativeDesign.accent(this.dark);
    if (this.tone === 'danger') return NativeDesign.danger(this.dark);
    return NativeDesign.textSecondary(this.dark);
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      Stack({ alignContent: Alignment.Center }) {
        DSHIcon({ glyph: this.glyph, glyphSize: this.glyphSize, color: this.color() })
      }
      .width(NativeDesign.visualIconContainer)
      .height(NativeDesign.visualIconContainer)
      .borderRadius(NativeDesign.radiusControl)
      .backgroundColor(this.active ? NativeDesign.selection(this.dark) : Color.Transparent)
      .animation(this.controlEnabled ? NativeMotion.implicit('press') : { duration: 0 })
    }
    .width(NativeDesign.hitTarget)
    .height(NativeDesign.hitTarget)
    .padding(4)
    .borderRadius(NativeDesign.radiusRow)
    .backgroundColor(Color.Transparent)
    .enabled(this.controlEnabled)
    .opacity(this.controlEnabled ? 1 : 0.4)
    .accessibilityText(this.label)
    .onClick((): void => { this.onPressed(); })
  }
}
