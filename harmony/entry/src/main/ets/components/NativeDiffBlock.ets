import { pasteboard } from '@kit.BasicServicesKit';
import { NativeDiffDocument, NativeDiffRow, nativeDiffText } from '../services/NativeDiff';
import { DSHIcon } from './DSHIcon';
import { NativeExperience } from '../services/NativeExperience';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';

@Component
export struct NativeDiffBlock {
  @Prop document: NativeDiffDocument = new NativeDiffDocument();
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private expanded: boolean = false;
  @State private showLineNumbers: boolean = false;
  @State private copied: boolean = false;

  private color(kind: string): ResourceColor {
    if (kind === 'add') return NativeDesign.success(this.dark);
    if (kind === 'del') return NativeDesign.danger(this.dark);
    if (kind === 'path') return NativeDesign.accent(this.dark);
    if (kind === 'gap') return NativeDesign.textTertiary(this.dark);
    return NativeDesign.textSecondary(this.dark);
  }
  private rowBackground(kind: string): ResourceColor {
    if (kind === 'add') return NativeDesign.successSurface(this.dark);
    if (kind === 'del') return NativeDesign.dangerSurface(this.dark);
    return Color.Transparent;
  }
  private toggle(): void {
    const update = (): void => { this.expanded = !this.expanded; };
    NativeMotion.disclosure(this.getUIContext(), update);
  }
  private toggleLineNumbers(): void {
    NativeMotion.animate(this.getUIContext(), 'micro', (): void => {
      this.showLineNumbers = !this.showLineNumbers;
    });
  }
  private copy(): void {
    pasteboard.getSystemPasteboard().setData(pasteboard.createData(
      pasteboard.MIMETYPE_TEXT_PLAIN, nativeDiffText(this.document.rows)))
      .then(() => { this.copied = true; }).catch(() => { this.copied = false; });
  }
  private shownRows(): NativeDiffRow[] {
    if (this.expanded || this.document.rows.length <= 16) return this.document.rows;
    const rows: NativeDiffRow[] = this.document.rows.slice(0, 8);
    const gap = new NativeDiffRow(); gap.kind = 'gap';
    gap.text = '⋯ ' + (this.document.rows.length - 16) + ' 行';
    rows.push(gap);
    return rows.concat(this.document.rows.slice(this.document.rows.length - 8));
  }
  private lineNumberWidth(): number {
    let width = 1;
    this.document.rows.forEach((row: NativeDiffRow): void => {
      width = Math.max(width, row.oldLine > 0 ? row.oldLine.toString().length : 0,
        row.newLine > 0 ? row.newLine.toString().length : 0);
    });
    return width;
  }
  private paddedLineNumber(value: number, width: number): string {
    let valueText = value > 0 ? value.toString() : '';
    while (valueText.length < width) valueText = ' ' + valueText;
    return valueText;
  }
  private lineText(row: NativeDiffRow): string {
    const marker = row.kind === 'add' ? '+ ' : row.kind === 'del' ? '- ' :
      row.kind === 'context' ? '  ' : '';
    if (!this.showLineNumbers) return marker + row.text;
    if (row.kind !== 'add' && row.kind !== 'del' && row.kind !== 'context') return row.text;
    const width = this.lineNumberWidth();
    return this.paddedLineNumber(row.oldLine, width) + '  ' +
      this.paddedLineNumber(row.newLine, width) + '  ' + marker + row.text;
  }
  @Builder
  private line(row: NativeDiffRow) {
    Text(this.lineText(row))
      .fontSize(11).lineHeight('18fp').fontFamily('Noto Sans Mono, monospace')
      .fontColor(this.color(row.kind)).backgroundColor(this.rowBackground(row.kind))
      .wordBreak(WordBreak.BREAK_WORD)
      .padding({ left: 7, right: 7, top: 1, bottom: 1 })
  }
  build() {
    Column({ space: 0 }) {
      Row({ space: 2 }) {
        Text(this.document.path || '变更').fontSize(11).fontWeight(FontWeight.Medium).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(NativeDesign.accent(this.dark))
        Button({ type: ButtonType.Normal }) {
          Text('#').fontSize(13).fontWeight(FontWeight.Medium)
            .fontFamily('Noto Sans Mono, monospace')
            .fontColor(this.showLineNumbers ? NativeDesign.textPrimary(this.dark) :
              NativeDesign.textTertiary(this.dark))
        }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
          .padding(0).borderRadius(NativeDesign.radiusControl)
          .backgroundColor(this.showLineNumbers ?
            NativeDesign.selection(this.dark) : Color.Transparent)
          .accessibilityText(this.showLineNumbers ? '隐藏行号' : '显示行号')
          .onClick((): void => { this.toggleLineNumbers(); })
        Button({ type: ButtonType.Normal }) {
          DSHIcon({ glyph: this.copied ? 'check-outline' : 'copy-outline', glyphSize: 13,
            color: NativeDesign.textTertiary(this.dark) })
        }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
          .borderRadius(NativeDesign.radiusControl).backgroundColor(Color.Transparent)
          .accessibilityText(this.copied ? '已复制 Diff' : '复制 Diff').onClick(() => { this.copy(); })
        if (this.document.rows.length > 16) {
          Button({ type: ButtonType.Normal }) {
            DSHIcon({ glyph: 'chevron-left-outline', glyphSize: 12,
              color: NativeDesign.textTertiary(this.dark) })
              .rotate({ angle: this.expanded ? -90 : 180 })
          }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
            .borderRadius(NativeDesign.radiusControl).backgroundColor(Color.Transparent)
            .accessibilityText(this.expanded ? '收起 Diff' : '展开 Diff').onClick(() => { this.toggle(); })
        }
      }.height(NativeDesign.hitTarget).width('100%')
      Scroll() {
        Column({ space: 0 }) {
          ForEach(this.shownRows(), (row: NativeDiffRow) => {
            this.line(row)
          }, (_row: NativeDiffRow, index: number) => index.toString())
        }.alignItems(HorizontalAlign.Start).width('100%')
      }.scrollable(ScrollDirection.Horizontal).width('100%')
        .constraintSize({ maxHeight: this.expanded ? 420 : 224 })
        .animation(NativeMotion.disclosureParam())
    }.padding({ left: 7, right: 7, top: 4, bottom: 7 }).width('100%')
      .borderRadius(NativeDesign.radiusControl)
      .backgroundColor(NativeDesign.subtleSurface(this.dark))
  }
}
