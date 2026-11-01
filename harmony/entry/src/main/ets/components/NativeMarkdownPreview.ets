import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeMarkdownBlock, nativeMarkdownBlocks } from '../services/NativeDocumentModel';
import { NativeMarkdownTable, nativeMarkdownTable } from '../services/NativeMarkdownTable';
import { NativeCodeBlock } from './NativeCodeBlock';
import { NativeInlineText } from './NativeInlineText';
import { NativeTable } from './NativeTable';
import { NativeDesign } from '../services/NativeDesign';

/** Native Markdown file preview using the same inline and table primitives as chat. */
@Component
export struct NativeMarkdownPreview {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  @Prop @Watch('changed') source: string = '';
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private blocks: NativeMarkdownBlock[] = [];

  aboutToAppear(): void { this.changed(); }
  private changed(): void { this.blocks = nativeMarkdownBlocks(this.source); }
  private headingSize(level: number): number {
    if (level <= 1) return 22;
    if (level === 2) return 19;
    if (level === 3) return 17;
    return 15;
  }
  private table(block: NativeMarkdownBlock): NativeMarkdownTable | null {
    return nativeMarkdownTable(block.text);
  }

  build() {
    Column({ space: 11 }) {
      ForEach(this.blocks, (block: NativeMarkdownBlock, index: number) => {
        if (block.kind === 'heading') {
          Text(block.text).width('100%').fontSize(this.headingSize(block.level))
            .fontWeight(block.level <= 2 ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(NativeDesign.textPrimary(this.dark)).copyOption(CopyOptions.InApp)
            .padding({ top: block.level <= 2 ? 4 : 1 })
        } else if (block.kind === 'code') {
          NativeCodeBlock({ code: block.text, language: block.language })
        } else if (block.kind === 'quote') {
          Column() {
            NativeInlineText({ text: block.text, textSize: 13, lineHeight: '21fp',
              muted: true, client: this.client, sessionId: this.sessionId })
          }.width('100%').padding({ left: 11, right: 9, top: 8, bottom: 8 })
            .borderRadius(NativeDesign.radiusControl)
            .backgroundColor(NativeDesign.subtleSurface(this.dark))
            .border({ width: { left: 2 }, color: NativeDesign.accent(this.dark) })
        } else if (block.kind === 'table' && this.table(block)) {
          NativeTable({ table: this.table(block) as NativeMarkdownTable,
            client: this.client, sessionId: this.sessionId })
        } else {
          NativeInlineText({ text: block.text, textSize: 13, lineHeight: '21fp',
            client: this.client, sessionId: this.sessionId })
        }
      }, (_block: NativeMarkdownBlock, index: number) => index.toString())
      if (!this.blocks.length) {
        Text('空文件').fontSize(NativeDesign.fontSection).fontColor(NativeDesign.textTertiary(this.dark))
      }
    }.width('100%').justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
      .align(Alignment.TopStart)
  }
}
