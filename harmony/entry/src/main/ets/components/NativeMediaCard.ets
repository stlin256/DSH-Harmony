import {
  NativeMediaDocument,
  NativeMediaItem,
  NativeMediaRequestInfo
} from '../services/NativeToolStructured';
import { NativeDesign } from '../services/NativeDesign';
import { DSHIcon } from './DSHIcon';

/**
 * Compact result card for `dsh-go/media`.
 *
 * The metadata is read-only and item taps use the workspace file surface.
 * Video does not claim inline playback; its poster or file opens through the
 * existing read-only viewer.
 */
@Component
export struct NativeMediaCard {
  @Prop document: NativeMediaDocument = new NativeMediaDocument();
  onOpenFile: (path: string) => void = (_path: string): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;

  private formatBytes(bytes: number): string {
    if (bytes <= 0) return '';
    if (bytes < 1024) return bytes.toString() + ' B';
    if (bytes < 1024 * 1024) return Math.max(1, Math.round(bytes / 1024)).toString() + ' KB';
    return (Math.round(bytes / (1024 * 1024) * 10) / 10).toString() + ' MB';
  }

  private formatDuration(seconds: number): string {
    if (seconds <= 0) return '';
    const whole = Math.max(0, Math.round(seconds));
    const minutes = Math.floor(whole / 60);
    const remainder = whole % 60;
    return minutes.toString() + ':' + (remainder < 10 ? '0' : '') + remainder.toString();
  }

  private statusLabel(): string {
    if (this.document.status === 'running') return '生成中';
    if (this.document.status === 'failed') return '失败';
    return '已完成';
  }

  private statusColor(): ResourceColor {
    if (this.document.status === 'failed') return NativeDesign.danger(this.dark);
    if (this.document.status === 'running') return NativeDesign.accent(this.dark);
    return NativeDesign.success(this.dark);
  }

  private requestLine(): string {
    const request: NativeMediaRequestInfo = this.document.request;
    const facts: string[] = [
      request.label || request.model,
      request.aspect,
      request.count > 0 ? request.count.toString() + ' 张' : '',
      request.quality,
      request.resolution,
      request.seconds > 0 ? request.seconds.toString() + ' 秒' : '',
      request.refs > 0 ? request.refs.toString() + ' 个参考' : ''
    ];
    if (this.document.costEstimate >= 0) {
      const amount = Math.round(this.document.costEstimate * 100) / 100;
      facts.push((this.document.costCurrency || '费用') + ' ' + amount.toString());
    }
    return facts.filter((fact: string): boolean => !!fact).join(' · ');
  }

  private itemFacts(item: NativeMediaItem): string {
    const facts: string[] = [];
    if (item.width > 0 && item.height > 0) {
      facts.push(item.width.toString() + ' × ' + item.height.toString());
    }
    if (item.duration > 0) facts.push(this.formatDuration(item.duration));
    const bytes = this.formatBytes(item.bytes);
    if (bytes) facts.push(bytes);
    if (item.codec) facts.push(item.codec);
    return facts.join(' · ');
  }

  @Builder
  private itemRow(item: NativeMediaItem) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        Stack({ alignContent: Alignment.Center }) {
          DSHIcon({ glyph: this.document.kind === 'video' ? 'file-outline' : 'image-outline',
            glyphSize: 15, color: NativeDesign.textTertiary(this.dark) })
          if (this.document.kind === 'video') {
            Text('▶').fontSize(7).fontColor(NativeDesign.accent(this.dark))
              .position({ x: 9, y: 11 })
          }
        }.width(28).height(28).borderRadius(8)
          .backgroundColor(NativeDesign.field(this.dark))
        Column({ space: 2 }) {
          Text(item.name || item.display).fontSize(11).fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textPrimary(this.dark))
          Text(item.display).fontSize(9).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontFamily('Noto Sans Mono, monospace')
            .fontColor(NativeDesign.textTertiary(this.dark))
          if (this.itemFacts(item)) {
            Text(this.itemFacts(item)).fontSize(9).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textTertiary(this.dark))
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        DSHIcon({ glyph: 'chevron-right-outline', glyphSize: 11,
          color: NativeDesign.textTertiary(this.dark) })
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').constraintSize({ minHeight: 48 })
      .padding({ left: 7, right: 7, top: 5, bottom: 5 })
      .borderRadius(NativeDesign.radiusRow)
      .backgroundColor(NativeDesign.overlay(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
      .onClick((): void => { this.onOpenFile(item.path); })
  }

  build() {
    Column({ space: 8 }) {
      if (!this.document.valid) {
        Row({ space: 8 }) {
          DSHIcon({ glyph: 'question-outline', glyphSize: 14,
            color: NativeDesign.textTertiary(this.dark) })
          Text('媒体信息不可用').layoutWeight(1).fontSize(11)
            .fontColor(NativeDesign.textTertiary(this.dark))
        }.height(32).width('100%')
      } else {
        Row({ space: 8 }) {
          DSHIcon({ glyph: this.document.kind === 'video' ? 'file-outline' : 'image-outline',
            glyphSize: 16, color: NativeDesign.accent(this.dark) })
          Text(this.document.kind === 'video' ? 'AI 生成视频' : 'AI 生成图片')
            .layoutWeight(1).fontSize(12).fontWeight(FontWeight.Medium)
            .fontColor(NativeDesign.textPrimary(this.dark))
          if (this.document.status === 'running') {
            LoadingProgress().width(13).height(13).color(this.statusColor())
          }
          Text(this.statusLabel()).fontSize(10).fontColor(this.statusColor())
        }.width('100%')
        if (this.requestLine()) {
          Text(this.requestLine()).fontSize(9).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textTertiary(this.dark))
        }
        if (this.document.prompt) {
          Text(this.document.prompt).fontSize(11).lineHeight(17).maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textSecondary(this.dark))
            .copyOption(CopyOptions.InApp)
        }
        if (this.document.revisedPrompt &&
          this.document.revisedPrompt !== this.document.prompt) {
          Text(this.document.revisedPrompt).fontSize(10).lineHeight(16).maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textTertiary(this.dark))
            .copyOption(CopyOptions.InApp)
        }
        if (this.document.items.length) {
          Column({ space: 4 }) {
            ForEach(this.document.items, (item: NativeMediaItem, index: number) => {
              this.itemRow(item)
            }, (item: NativeMediaItem, index: number) =>
              item.path + ':' + index.toString())
          }.width('100%')
        } else if (this.document.status === 'running') {
          Row({ space: 7 }) {
            LoadingProgress().width(13).height(13)
              .color(NativeDesign.accent(this.dark))
            Text(this.document.kind === 'video' ? '视频正在生成' : '图片正在生成')
              .fontSize(10).fontColor(NativeDesign.textTertiary(this.dark))
          }.height(30)
        }
        if (this.document.status === 'failed') {
          Row({ space: 7 }) {
            DSHIcon({ glyph: 'close-outline', glyphSize: 13,
              color: NativeDesign.danger(this.dark) })
            Text(this.document.errorText || this.document.errorCode || '生成失败')
              .layoutWeight(1).fontSize(10).lineHeight(15)
              .fontColor(NativeDesign.danger(this.dark))
              .copyOption(CopyOptions.InApp)
          }.width('100%').padding({ left: 8, right: 8, top: 7, bottom: 7 })
            .alignItems(VerticalAlign.Top).borderRadius(NativeDesign.radiusRow)
            .backgroundColor(NativeDesign.dangerSurface(this.dark))
        }
        if (this.document.implicitLabel || this.document.visibleMark || this.document.c2pa) {
          Text('AI 生成内容').fontSize(9).fontColor(NativeDesign.textTertiary(this.dark))
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
