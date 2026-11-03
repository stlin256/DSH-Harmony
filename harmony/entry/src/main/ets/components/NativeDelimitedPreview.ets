import { NativeDelimitedTable, nativeDelimitedTable } from '../services/NativeDelimitedModel';
import { NativeMarkdownTable } from '../services/NativeMarkdownTable';
import { NativeDesign } from '../services/NativeDesign';
import { nativeAdaptiveTableWidths, nativeTableRowNumberWidth } from '../services/NativeTableLayout';
import { NativeTable } from './NativeTable';

@Component
export struct NativeDelimitedPreview {
  @Prop @Watch('refresh') source: string = '';
  @Prop @Watch('refresh') format: string = 'csv';
  @Prop @Watch('refresh') hasMore: boolean = false;
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private table: NativeMarkdownTable = new NativeMarkdownTable();
  @State private rowCount: number = 0;
  @State private error: string = '';
  @State private bounded: boolean = false;
  @State private incomplete: boolean = false;
  @State private columnWidths: number[] = [];

  aboutToAppear(): void {
    this.refresh();
  }

  private columnLabel(index: number): string {
    let value = index;
    let label = '';
    do {
      label = String.fromCharCode(65 + value % 26) + label;
      value = Math.floor(value / 26) - 1;
    } while (value >= 0);
    return label;
  }

  private refresh(): void {
    const parsed: NativeDelimitedTable = nativeDelimitedTable(
      this.source, this.format, 200, 32, 4096, this.hasMore);
    this.error = parsed.error;
    this.rowCount = parsed.rows.length;
    this.bounded = parsed.truncatedRows || parsed.truncatedColumns || parsed.truncatedCells;
    this.incomplete = parsed.incomplete;
    const columns = Math.max(1, parsed.columnCount);
    const table = new NativeMarkdownTable();
    table.headers = ['行'];
    table.aligns = ['left'];
    for (let index = 0; index < columns; index++) {
      table.headers.push(this.columnLabel(index));
      table.aligns.push('left');
    }
    table.rows = parsed.rows.map((row: string[], rowIndex: number): string[] => {
      const values: string[] = [String(rowIndex + 1)];
      for (let index = 0; index < columns; index++) {
        values.push(index < row.length ? row[index] : '');
      }
      return values;
    });
    const dataRows = table.rows.map((row: string[]): string[] => row.slice(1));
    this.columnWidths = [nativeTableRowNumberWidth(table.rows.length)]
      .concat(nativeAdaptiveTableWidths(table.headers.slice(1), dataRows));
    this.table = table;
  }

  private caption(): string {
    if (this.incomplete && this.hasMore) return '当前分页末尾仍在加载';
    if (this.bounded) return '表格预览已限行、限列或缩短单元格，源码保留完整内容';
    return '';
  }

  build() {
    Column({ space: 6 }) {
      if (this.caption()) {
        Text(this.caption())
          .fontSize(NativeDesign.fontMicro)
          .fontColor(NativeDesign.textTertiary(this.dark))
          .maxLines(2)
          .width('100%')
      }
      if (this.error) {
        Column({ space: 6 }) {
          Text(this.error)
            .fontSize(NativeDesign.fontSection)
            .fontColor(NativeDesign.danger(this.dark))
            .textAlign(TextAlign.Center)
          Text('可切换到源码查看原始内容')
            .fontSize(NativeDesign.fontCaption)
            .fontColor(NativeDesign.textTertiary(this.dark))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (!this.rowCount) {
        Text('此表格没有可显示的行')
          .fontSize(NativeDesign.fontSection)
          .fontColor(NativeDesign.textTertiary(this.dark))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      } else {
        Scroll() {
          NativeTable({
            table: this.table,
            columnWidths: this.columnWidths,
            layoutId: 'delimited-table',
            literal: true,
            maxLines: 3
          }).width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.None)
        .align(Alignment.TopStart)
      }
    }.layoutWeight(1).width('100%').alignItems(HorizontalAlign.Start)
  }
}
