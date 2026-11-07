import {
  NativePluginBlock,
  NativePluginDocument,
  NativePluginItem,
  NativePluginMetric,
  NativePluginTableRow
} from '../services/NativeToolStructured';
import { nativeDshUiChoiceReply, nativeDshUiConfirmReply } from '../services/NativeDshUi';
import { NativeDesign } from '../services/NativeDesign';
import { DSHIcon } from './DSHIcon';

/**
 * Read-only renderer for the bounded `dsh-go/view` tool-card contract.
 *
 * Persisted plugin cards never execute actions or load remote images. Unknown
 * future component types degrade to one quiet row while the raw result remains
 * available from the parent tool row.
 */
@Component
export struct NativePluginCard {
  @Prop document: NativePluginDocument = new NativePluginDocument();
  interactive: boolean = false;
  @Prop canReply: boolean = false;
  onReply: (text: string) => Promise<boolean> =
    async (_text: string): Promise<boolean> => false;
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private pickedLabels: string[] = [];
  @State private answered: boolean = false;
  @State private sending: boolean = false;

  private selected(item: NativePluginItem): boolean {
    return item.selected || this.pickedLabels.includes(item.title);
  }

  private canInteract(): boolean {
    return this.interactive && this.canReply && !this.answered && !this.sending;
  }

  private async sendReply(text: string): Promise<void> {
    if (!text || this.sending || this.answered) return;
    this.sending = true;
    let accepted = false;
    try {
      accepted = await this.onReply(text);
    } catch (_) {
      accepted = false;
    }
    this.sending = false;
    this.answered = accepted;
  }

  private pickOption(block: NativePluginBlock, item: NativePluginItem): void {
    if (!this.canInteract()) return;
    if (block.multi) {
      if (this.pickedLabels.includes(item.title)) {
        this.pickedLabels = this.pickedLabels.filter((label: string): boolean => label !== item.title);
      } else {
        this.pickedLabels = this.pickedLabels.concat([item.title]);
      }
      return;
    }
    this.pickedLabels = [item.title];
    this.sendReply(nativeDshUiChoiceReply(this.document.title, [item.title]));
  }

  private confirm(block: NativePluginBlock, accepted: boolean): void {
    if (!this.canInteract()) return;
    const label = accepted ? (block.confirmLabel || '确认') : (block.cancelLabel || '取消');
    this.pickedLabels = [label];
    this.sendReply(nativeDshUiConfirmReply(this.document.title, accepted, label));
  }

  private toneColor(tone: string): ResourceColor {
    if (tone === 'success') return NativeDesign.success(this.dark);
    if (tone === 'warning') return NativeDesign.warning(this.dark);
    if (tone === 'danger') return NativeDesign.danger(this.dark);
    if (tone === 'accent') return NativeDesign.accent(this.dark);
    return NativeDesign.textSecondary(this.dark);
  }

  private toneSurface(tone: string): ResourceColor {
    if (tone === 'success') return NativeDesign.successSurface(this.dark);
    if (tone === 'warning') return NativeDesign.warningSurface(this.dark);
    if (tone === 'danger') return NativeDesign.dangerSurface(this.dark);
    if (tone === 'accent') return NativeDesign.accentSurface(this.dark);
    return NativeDesign.subtleSurface(this.dark);
  }

  @Builder
  private metricCell(metric: NativePluginMetric) {
    Column({ space: 2 }) {
      Text(metric.label).fontSize(NativeDesign.fontMicro).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(NativeDesign.textTertiary(this.dark))
      Text(metric.value).fontSize(NativeDesign.fontPageTitle).fontWeight(FontWeight.Medium).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(this.toneColor(metric.tone))
      if (metric.caption) {
        Text(metric.caption).fontSize(NativeDesign.fontMicro).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(NativeDesign.textTertiary(this.dark))
      }
    }.width(118).padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .alignItems(HorizontalAlign.Start).borderRadius(NativeDesign.radiusRow)
      .backgroundColor(NativeDesign.overlay(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
  }

  @Builder
  private metricsBlock(block: NativePluginBlock) {
    Scroll() {
      Row({ space: 7 }) {
        ForEach(block.metrics, (metric: NativePluginMetric, index: number) => {
          this.metricCell(metric)
        }, (metric: NativePluginMetric, index: number) =>
          metric.label + ':' + metric.value + ':' + index.toString())
      }
    }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
  }

  @Builder
  private progressBlock(block: NativePluginBlock) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(block.label || '进度').layoutWeight(1).fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(NativeDesign.textSecondary(this.dark))
        Text(block.value).fontSize(NativeDesign.fontMicro).fontColor(this.toneColor(block.tone))
      }.width('100%')
      Progress({ value: block.progress, total: 100, type: ProgressType.Linear })
        .width('100%').height(4)
        .color(this.toneColor(block.tone))
        .backgroundColor(NativeDesign.field(this.dark))
      if (block.caption) {
        Text(block.caption).fontSize(NativeDesign.fontMicro).maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(NativeDesign.textTertiary(this.dark))
      }
    }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .borderRadius(NativeDesign.radiusRow)
      .backgroundColor(NativeDesign.overlay(this.dark))
  }

  @Builder
  private textBlock(block: NativePluginBlock) {
    Text(block.text).fontSize(NativeDesign.fontSection).lineHeight(18).width('100%')
      .fontColor(block.tone === 'default' ? NativeDesign.textSecondary(this.dark) :
        this.toneColor(block.tone)).copyOption(CopyOptions.InApp)
  }

  @Builder
  private calloutBlock(block: NativePluginBlock) {
    Row({ space: 8 }) {
      DSHIcon({ glyph: block.tone === 'danger' || block.tone === 'warning' ?
        'question-outline' : 'sparkle', glyphSize: NativeDesign.glyphCompact, color: this.toneColor(block.tone) })
      Text(block.text).layoutWeight(1).fontSize(NativeDesign.fontCaption).lineHeight(17)
        .fontColor(NativeDesign.textSecondary(this.dark)).copyOption(CopyOptions.InApp)
    }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Top).borderRadius(NativeDesign.radiusRow)
      .backgroundColor(this.toneSurface(block.tone))
  }

  @Builder
  private itemRow(block: NativePluginBlock, item: NativePluginItem) {
    Row({ space: 8 }) {
      if (block.kind === 'options') {
        Stack({ alignContent: Alignment.Center }) {
          DSHIcon({ glyph: this.selected(item) ? 'check-outline' : 'question-outline', glyphSize: NativeDesign.glyphMicro,
            color: this.selected(item) ? NativeDesign.accent(this.dark) :
              NativeDesign.textTertiary(this.dark) })
        }.width(16).height(16).borderRadius(8)
          .backgroundColor(this.selected(item) ? NativeDesign.accentSurface(this.dark) :
            NativeDesign.field(this.dark))
      }
      Column({ space: 2 }) {
        Text(item.title).fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(this.toneColor(item.tone))
        if (item.subtitle) {
          Text(item.subtitle).fontSize(NativeDesign.fontMicro).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textTertiary(this.dark))
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (item.trailing) {
        Text(item.trailing).fontSize(NativeDesign.fontMicro).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(this.toneColor(item.tone))
      }
    }.width('100%').constraintSize({ minHeight: NativeDesign.compactHitTarget })
      .padding({ left: 7, right: 7, top: 5, bottom: 5 })
      .alignItems(VerticalAlign.Top).borderRadius(NativeDesign.radiusCompact)
      .backgroundColor(block.kind === 'options' && this.selected(item) ?
        NativeDesign.selectedSurface(this.dark) : NativeDesign.overlay(this.dark))
      .onClick((): void => {
        if (block.kind === 'options') this.pickOption(block, item);
      })
  }

  @Builder
  private itemsBlock(block: NativePluginBlock) {
    Column({ space: 4 }) {
      ForEach(block.items, (item: NativePluginItem, index: number) => {
        this.itemRow(block, item)
      }, (item: NativePluginItem, index: number) =>
        item.title + ':' + index.toString())
      if (block.kind === 'options' && block.multi && this.interactive && this.canReply &&
        !this.answered && this.pickedLabels.length) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            if (this.sending) {
              LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline).color(NativeDesign.accent(this.dark))
            }
            Text(this.sending ? '发送中' : '提交选择').fontSize(NativeDesign.fontMicro).fontWeight(FontWeight.Medium)
              .fontColor(NativeDesign.accent(this.dark))
          }.justifyContent(FlexAlign.Center)
        }.height(NativeDesign.compactControl).width('100%').borderRadius(NativeDesign.radiusCompact)
          .backgroundColor(NativeDesign.accentSurface(this.dark))
          .enabled(this.canInteract())
          .onClick((): void => {
            this.sendReply(nativeDshUiChoiceReply(this.document.title, this.pickedLabels));
          })
      }
    }.width('100%')
  }

  @Builder
  private confirmBlock(block: NativePluginBlock) {
    Column({ space: 7 }) {
      if (block.text) {
        Text(block.text).width('100%').fontSize(NativeDesign.fontCaption).lineHeight(17)
          .fontColor(NativeDesign.textSecondary(this.dark))
      }
      Row({ space: 7 }) {
        Button(block.cancelLabel || '取消', { type: ButtonType.Normal })
          .layoutWeight(1).height(NativeDesign.compactHitTarget)
          .fontSize(NativeDesign.fontCaption).borderRadius(NativeDesign.radiusControl)
          .backgroundColor(NativeDesign.field(this.dark))
          .fontColor(NativeDesign.textSecondary(this.dark))
          .enabled(this.canInteract())
          .onClick((): void => { this.confirm(block, false); })
        Button(block.confirmLabel || '确认', { type: ButtonType.Normal })
          .layoutWeight(1).height(NativeDesign.compactHitTarget)
          .fontSize(NativeDesign.fontCaption).borderRadius(NativeDesign.radiusControl)
          // accent() is the accent TEXT token (light blue in dark mode); a
          // filled primary button needs the stronger fill so white type keeps
          // its contrast.
          .backgroundColor(NativeDesign.accentStrong(this.dark))
          .fontColor(Color.White)
          .enabled(this.canInteract())
          .onClick((): void => { this.confirm(block, true); })
      }.width('100%')
    }.width('100%').padding({ left: 9, right: 9, top: 8, bottom: 8 })
      .borderRadius(NativeDesign.radiusRow)
      .backgroundColor(NativeDesign.overlay(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
  }

  @Builder
  private tableCell(text: string, header: boolean = false) {
    Text(text).width(118)
      .fontSize(header ? NativeDesign.fontMicro : NativeDesign.fontCaption).lineHeight(16)
      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      .fontWeight(header ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(header ? NativeDesign.textTertiary(this.dark) :
        NativeDesign.textSecondary(this.dark))
      .copyOption(CopyOptions.InApp)
  }

  @Builder
  private tableBlock(block: NativePluginBlock) {
    Scroll() {
      Column({ space: 0 }) {
        Row({ space: 0 }) {
          ForEach(block.columns, (column: string, index: number) => {
            this.tableCell(column, true)
          }, (column: string, index: number) => 'column:' + index.toString())
        }.width('100%').padding({ top: 7, bottom: 7 })
          .backgroundColor(NativeDesign.field(this.dark))
        ForEach(block.rows, (row: NativePluginTableRow, rowIndex: number) => {
          Row({ space: 0 }) {
            ForEach(row.cells, (cell: string, cellIndex: number) => {
              this.tableCell(cell)
            }, (cell: string, cellIndex: number) =>
              rowIndex.toString() + ':' + cellIndex.toString())
          }.width('100%').padding({ top: 7, bottom: 7 })
            .border({ width: { top: 0.5 }, color: NativeDesign.divider(this.dark) })
        }, (row: NativePluginTableRow, rowIndex: number) => rowIndex.toString())
      }.width(118 * Math.max(1, block.columns.length))
    }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Auto)
      .borderRadius(NativeDesign.radiusRow)
      .backgroundColor(NativeDesign.overlay(this.dark))
  }

  @Builder
  private imageBlock(block: NativePluginBlock) {
    Row({ space: 8 }) {
      DSHIcon({ glyph: 'image-outline', glyphSize: NativeDesign.glyphControl,
        color: NativeDesign.textTertiary(this.dark) })
      Column({ space: 2 }) {
        Text(block.label || block.text || '图像').fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(NativeDesign.textSecondary(this.dark))
        if (block.caption) {
          Text(block.caption).fontSize(NativeDesign.fontMicro).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textTertiary(this.dark))
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 9, right: 9, top: 8, bottom: 8 })
      .borderRadius(NativeDesign.radiusRow)
      .backgroundColor(NativeDesign.overlay(this.dark))
  }

  @Builder
  private blockView(block: NativePluginBlock) {
    if (block.kind === 'metrics' || block.kind === 'metric') {
      this.metricsBlock(block)
    } else if (block.kind === 'progress') {
      this.progressBlock(block)
    } else if (block.kind === 'callout') {
      this.calloutBlock(block)
    } else if (block.kind === 'table') {
      this.tableBlock(block)
    } else if (block.kind === 'image') {
      this.imageBlock(block)
    } else if (block.kind === 'options') {
      this.itemsBlock(block)
    } else if (block.kind === 'confirm') {
      this.confirmBlock(block)
    } else if (['list', 'keyValue', 'chart', 'compare', 'steps'].includes(block.kind)) {
      this.itemsBlock(block)
    } else if (block.kind === 'text') {
      this.textBlock(block)
    } else {
      Row({ space: 7 }) {
        DSHIcon({ glyph: 'question-outline', glyphSize: NativeDesign.glyphCompact,
          color: NativeDesign.textTertiary(this.dark) })
        Text(block.text || '此插件组件暂不支持').fontSize(NativeDesign.fontMicro).layoutWeight(1)
          .fontColor(NativeDesign.textTertiary(this.dark))
      }.width('100%').padding({ left: 7, right: 7, top: 6, bottom: 6 })
    }
  }

  build() {
    Column({ space: 7 }) {
      if (!this.document.valid) {
        Row({ space: 8 }) {
          DSHIcon({ glyph: 'question-outline', glyphSize: NativeDesign.glyphCompact,
            color: NativeDesign.textTertiary(this.dark) })
          Text('插件界面不可用').layoutWeight(1).fontSize(NativeDesign.fontCaption)
            .fontColor(NativeDesign.textTertiary(this.dark))
        }.height(NativeDesign.compactControl).width('100%')
      } else {
        Row({ space: 7 }) {
          DSHIcon({ glyph: 'sparkle', glyphSize: NativeDesign.glyphCompact,
            color: NativeDesign.accent(this.dark) })
          Text(this.document.title || '插件卡片').layoutWeight(1).fontSize(NativeDesign.fontCaption)
            .fontWeight(FontWeight.Medium).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textSecondary(this.dark))
          if (this.document.truncated) {
            Text('内容已截断').fontSize(NativeDesign.fontMicro)
              .fontColor(NativeDesign.warning(this.dark))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(NativeDesign.radiusCompact)
              .backgroundColor(NativeDesign.field(this.dark))
          }
        }.width('100%')
        ForEach(this.document.blocks, (block: NativePluginBlock, index: number) => {
          this.blockView(block)
        }, (block: NativePluginBlock, index: number) => block.kind + ':' + index.toString())
        if (this.interactive && this.answered) {
          Row({ space: 6 }) {
            DSHIcon({ glyph: 'check-outline', glyphSize: NativeDesign.glyphInline,
              color: NativeDesign.accent(this.dark) })
            Text('已回复').fontSize(NativeDesign.fontMicro).fontColor(NativeDesign.textTertiary(this.dark))
          }.width('100%')
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
