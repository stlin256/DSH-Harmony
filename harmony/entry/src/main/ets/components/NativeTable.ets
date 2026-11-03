import { NativeMarkdownTable } from '../services/NativeMarkdownTable';
import { NativeInlineText } from './NativeInlineText';
import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeDesign } from '../services/NativeDesign';

@Component
export struct NativeTable {
  @Prop table: NativeMarkdownTable = new NativeMarkdownTable();
  @Prop maskSecrets: boolean = false;
  @Prop literal: boolean = false;
  @Prop cellWidth: number = 148;
  @Prop columnWidths: number[] = [];
  @Prop layoutId: string = 'native-table';
  @Prop maxLines: number = 3;
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  @StorageLink('nativeDark') private dark: boolean = false;

  private widthFor(index: number): number {
    return index >= 0 && index < this.columnWidths.length &&
      this.columnWidths[index] > 0 ? this.columnWidths[index] : this.cellWidth;
  }

  @Builder
  private cell(value: string, header: boolean, align: string, cellId: string, index: number) {
    Column() {
      if (this.literal && !header) {
        Text(value || ' ')
          .fontSize(NativeDesign.fontCaption)
          .fontColor(NativeDesign.textPrimary(this.dark))
          .textAlign(align === 'right' ? TextAlign.End : align === 'center' ? TextAlign.Center : TextAlign.Start)
          .maxLines(this.maxLines)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      } else {
        NativeInlineText({ text: value, textSize: 12, muted: !header, alignment: align,
          maskSecrets: this.maskSecrets, client: this.client, sessionId: this.sessionId })
      }
    }.id(cellId).width(this.widthFor(index))
      .padding({ left: 10, right: 10, top: 8, bottom: 8 }).alignItems(HorizontalAlign.Start)
      .backgroundColor(header ? NativeDesign.field(this.dark) : Color.Transparent)
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          ForEach(this.table.headers, (value: string, index: number) => {
            this.cell(value, true, this.table.aligns[index],
              this.layoutId + '-h-' + index.toString(), index)
          }, (_value: string, index: number) => 'h' + index)
        }
        ForEach(this.table.rows, (row: string[], rowIndex: number) => {
          Row() {
            ForEach(row, (value: string, index: number) => {
              this.cell(value, false, this.table.aligns[index],
                this.layoutId + '-r-' + rowIndex.toString() + '-' + index.toString(), index)
            }, (_value: string, index: number) => rowIndex + ':' + index)
          }.backgroundColor(rowIndex % 2 ? NativeDesign.subtleSurface(this.dark) : Color.Transparent)
        }, (_row: string[], index: number) => 'r' + index)
      }.alignItems(HorizontalAlign.Start)
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Auto).width('100%')
      .align(Alignment.TopStart).id(this.layoutId)
      .border({ width: 0.5, color: NativeDesign.border(this.dark),
        radius: NativeDesign.radiusControl })
      .backgroundColor(NativeDesign.base(this.dark))
  }
}
