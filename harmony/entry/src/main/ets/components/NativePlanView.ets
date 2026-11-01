import { DSHIcon } from './DSHIcon';
import { NativePlanDocument, NativePlanItem, nativePlanProgress } from '../services/NativePlan';
import { NativeDesign } from '../services/NativeDesign';

@Component
export struct NativePlanView {
  @Prop document: NativePlanDocument = new NativePlanDocument();
  @Prop showHeader: boolean = true;
  @StorageLink('nativeDark') private dark: boolean = false;

  private statusLabel(status: string): string {
    if (status === 'completed') return '已完成';
    if (status === 'in_progress') return '进行中';
    return '待处理';
  }

  @Builder
  private statusMark(item: NativePlanItem) {
    Stack() {
      if (item.status === 'completed') {
        DSHIcon({ glyph: 'check-outline', glyphSize: NativeDesign.glyphMicro,
          color: NativeDesign.success(this.dark) })
      } else if (item.status === 'in_progress') {
        Text('●').fontSize(NativeDesign.fontMicro)
          .fontColor(NativeDesign.accent(this.dark))
      } else {
        Text('○').fontSize(NativeDesign.fontSection)
          .fontColor(NativeDesign.textTertiary(this.dark))
      }
    }.width(16).height(16)
  }

  build() {
    Column({ space: 5 }) {
      if (this.showHeader) {
        Row({ space: 7 }) {
          DSHIcon({ glyph: 'plan-outline', glyphSize: NativeDesign.glyphControl,
            color: NativeDesign.textTertiary(this.dark) })
          Text('任务计划').fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium)
            .fontColor(NativeDesign.textPrimary(this.dark))
          Text(nativePlanProgress(this.document)).fontSize(NativeDesign.fontCaption).layoutWeight(1).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textTertiary(this.dark))
        }.width('100%')
        Divider().color(NativeDesign.divider(this.dark))
      }
      Column({ space: 5 }) {
        ForEach(this.document.items, (item: NativePlanItem, index: number) => {
          Row({ space: 7 }) {
            this.statusMark(item)
            Text(item.content).fontSize(NativeDesign.fontCaption).lineHeight(16).layoutWeight(1)
              .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(item.status === 'completed' ?
                NativeDesign.textSecondary(this.dark) : NativeDesign.textPrimary(this.dark))
          }.width('100%').alignItems(VerticalAlign.Top)
            .accessibilityText(this.statusLabel(item.status) + '：' + item.content)
        }, (item: NativePlanItem, index: number) =>
          index.toString() + ':' + item.status + ':' + item.content)
      }.width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
