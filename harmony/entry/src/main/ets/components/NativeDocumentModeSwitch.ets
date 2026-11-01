import { DSHIcon } from './DSHIcon';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';

/** Compact preview/source switch for SVG and Markdown workspace documents. */
@Component
export struct NativeDocumentModeSwitch {
  @Prop mode: string = 'preview';
  onMode: (mode: string) => void = (_mode: string): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;

  private select(mode: string): void {
    if (mode !== this.mode) this.onMode(mode);
  }

  private iconColor(selected: boolean): ResourceColor {
    if (selected) return NativeDesign.textInverse(this.dark);
    return NativeDesign.textTertiary(this.dark);
  }

  @Builder
  private modeButton(mode: string, glyph: string, label: string) {
    Button({ type: ButtonType.Normal }) {
      DSHIcon({ glyph: glyph, glyphSize: NativeDesign.glyphCompact, color: this.iconColor(this.mode === mode) })
    }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget).padding(0)
      .borderRadius(NativeDesign.radiusCompact).backgroundColor(Color.Transparent)
      .accessibilityText(label)
      .onClick((): void => { this.select(mode); })
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Column()
        .width(NativeDesign.hitTarget).height(NativeDesign.hitTarget).borderRadius(NativeDesign.radiusCompact)
        .backgroundColor(NativeDesign.accentSurface(this.dark))
        .translate({ x: this.mode === 'preview' ? 0 : NativeDesign.hitTarget })
        .animation(NativeMotion.implicit('micro'))
      Row() {
        this.modeButton('preview', 'eye-outline', '预览')
        this.modeButton('code', 'code-outline', '代码')
      }
    }.width(NativeDesign.hitTarget * 2).height(NativeDesign.hitTarget).padding(0)
      .borderRadius(NativeDesign.radiusControl)
      .backgroundColor(NativeDesign.field(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
      .clip(true)
  }
}
