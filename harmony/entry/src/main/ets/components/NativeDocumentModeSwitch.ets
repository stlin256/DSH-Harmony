import { NativeDesign } from '../services/NativeDesign';
import { NativeIconButton } from './NativeIconButton';

/** One title-bar action for switching between rendered and source content. */
@Component
export struct NativeDocumentModeSwitch {
  @Prop mode: string = 'preview';
  onMode: (mode: string) => void = (_mode: string): void => {};

  build() {
    NativeIconButton({
      glyph: this.mode === 'preview' ? 'code-outline' : 'eye-outline',
      label: this.mode === 'preview' ? '切换到源码' : '切换到渲染预览',
      glyphSize: NativeDesign.glyphControl,
      onPressed: (): void => {
        this.onMode(this.mode === 'preview' ? 'code' : 'preview');
      }
    })
  }
}
