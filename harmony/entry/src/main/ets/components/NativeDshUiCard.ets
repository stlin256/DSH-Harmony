import {
  NativePluginDocument,
  nativeDshUiDocument
} from '../services/NativeToolStructured';
import { NativeDesign } from '../services/NativeDesign';
import { DSHIcon } from './DSHIcon';
import { NativeCodeBlock } from './NativeCodeBlock';
import { NativePluginCard } from './NativePluginCard';

/**
 * Model-authored Markdown view. The source is bounded and rendered through the
 * same read-only component catalog as plugin tool cards.
 */
@Component
export struct NativeDshUiCard {
  @Prop @Watch('changed') source: string = '';
  @Prop canReply: boolean = false;
  onReply: (text: string) => Promise<boolean> =
    async (_text: string): Promise<boolean> => false;
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private document: NativePluginDocument = new NativePluginDocument();

  aboutToAppear(): void {
    this.changed();
  }

  private changed(): void {
    this.document = nativeDshUiDocument(this.source);
  }

  build() {
    Column({ space: 7 }) {
      if (this.document.valid) {
        NativePluginCard({
          document: this.document,
          interactive: true,
          canReply: this.canReply,
          onReply: this.onReply
        })
      } else {
        Row({ space: 7 }) {
          DSHIcon({
            glyph: 'question-outline',
            glyphSize: 13,
            color: NativeDesign.textTertiary(this.dark)
          })
          Text('视图格式不可用').layoutWeight(1).fontSize(10)
            .fontColor(NativeDesign.textTertiary(this.dark))
        }.width('100%').height(30)
        NativeCodeBlock({
          code: this.source,
          language: 'json'
        })
      }
    }.width('100%').padding({ left: 10, right: 10, top: 9, bottom: 9 })
      .borderRadius(NativeDesign.radiusRow)
      .backgroundColor(NativeDesign.raised(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
  }
}
