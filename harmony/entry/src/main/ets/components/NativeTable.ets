import { NativeMarkdownTable } from '../services/NativeMarkdownTable';
import { NativeInlineText } from './NativeInlineText';
import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeDesign } from '../services/NativeDesign';

@Component
export struct NativeTable {
  @Prop table: NativeMarkdownTable = new NativeMarkdownTable();
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  @StorageLink('nativeDark') private dark: boolean = false;

  @Builder
  private cell(value: string, header: boolean, align: string) {
    Column() {
      NativeInlineText({ text: value, textSize: 12, muted: !header, alignment: align,
        client: this.client, sessionId: this.sessionId })
    }.width(148).padding({ left: 10, right: 10, top: 8, bottom: 8 }).alignItems(HorizontalAlign.Start)
      .backgroundColor(header ? NativeDesign.field(this.dark) : Color.Transparent)
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          ForEach(this.table.headers, (value: string, index: number) => {
            this.cell(value, true, this.table.aligns[index])
          }, (_value: string, index: number) => 'h' + index)
        }
        ForEach(this.table.rows, (row: string[], rowIndex: number) => {
          Row() {
            ForEach(row, (value: string, index: number) => {
              this.cell(value, false, this.table.aligns[index])
            }, (_value: string, index: number) => rowIndex + ':' + index)
          }.backgroundColor(rowIndex % 2 ? NativeDesign.subtleSurface(this.dark) : Color.Transparent)
        }, (_row: string[], index: number) => 'r' + index)
      }.alignItems(HorizontalAlign.Start)
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Auto).width('100%')
      .border({ width: 0.5, color: NativeDesign.border(this.dark),
        radius: NativeDesign.radiusControl })
      .backgroundColor(NativeDesign.base(this.dark))
  }
}
