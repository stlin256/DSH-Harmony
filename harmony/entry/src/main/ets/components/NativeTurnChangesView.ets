import { DSHIcon } from './DSHIcon';
import { NativeMotion } from '../services/NativeMotion';
import {
  nativeTurnFilePresentation,
  NativeTurnChangeSummary,
  NativeTurnFileChange
} from '../services/NativeTurnChanges';
import { NativeDesign } from '../services/NativeDesign';

function formattedCount(value: number): string {
  const safe = Number.isFinite(value) ? Math.max(0, Math.floor(value)) : 0;
  return safe.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/** A compact number-only vertical roll for changing aggregate values. */
@Component
export struct NativeRollingNumber {
  @Prop @Watch('valueChanged') value: number = 0;
  @Prop color: ResourceColor = '#3964FE';
  @State private currentValue: number = 0;
  @State private previousValue: number = 0;
  @State private progress: number = 1;
  @State private settled: boolean = true;
  private settleTimer: number = -1;

  aboutToAppear(): void {
    this.currentValue = this.value;
    this.previousValue = this.value;
  }

  aboutToDisappear(): void {
    clearTimeout(this.settleTimer);
  }

  private valueChanged(): void {
    const next = Number.isFinite(this.value) ? this.value : 0;
    if (next === this.currentValue) return;
    clearTimeout(this.settleTimer);
    this.previousValue = this.currentValue;
    this.currentValue = next;
    this.settled = false;
    this.progress = 0;
    setTimeout((): void => {
      const update = (): void => { this.progress = 1; };
      if (!NativeMotion.enabled()) {
        update();
      } else {
        NativeMotion.animate(this.getUIContext(), 'micro', update);
      }
      this.settleTimer = setTimeout((): void => {
        this.previousValue = this.currentValue;
        this.settled = true;
      }, NativeMotion.enabled() ? NativeMotion.duration('micro') + 30 : 0);
    }, 0);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (!this.settled && this.previousValue !== this.currentValue) {
        Text(formattedCount(this.previousValue)).fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(this.color)
          .translate({ y: -7 * this.progress })
          .opacity(1 - this.progress)
      }
      Text(formattedCount(this.currentValue)).fontSize(12).fontWeight(FontWeight.Medium)
        .fontColor(this.color)
        .translate({ y: (1 - this.progress) * 7 })
        .opacity(this.settled ? 1 : this.progress)
    }.height(18).accessibilityText(formattedCount(this.currentValue))
  }
}

@Component
export struct NativeTurnChangePill {
  @Prop summary: NativeTurnChangeSummary = new NativeTurnChangeSummary();
  @Prop maxWidth: number = 360;
  @StorageLink('nativeDark') private dark: boolean = false;

  build() {
    Row({ space: 5 }) {
      DSHIcon({ glyph: 'edit-outline', glyphSize: 13,
        color: NativeDesign.accent(this.dark) })
      Text('正在编辑').fontSize(NativeDesign.fontCaption)
        .fontColor(NativeDesign.textSecondary(this.dark))
      NativeRollingNumber({
        value: this.summary.fileCount,
        color: NativeDesign.textPrimary(this.dark)
      })
      Text('个文件').fontSize(NativeDesign.fontCaption)
        .fontColor(NativeDesign.textSecondary(this.dark))
      Row({ space: 1 }) {
        Text('+').fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
          .fontColor(NativeDesign.success(this.dark))
        NativeRollingNumber({ value: this.summary.added, color: NativeDesign.success(this.dark) })
      }
      Row({ space: 1 }) {
        Text('-').fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
          .fontColor(NativeDesign.danger(this.dark))
        NativeRollingNumber({ value: this.summary.removed, color: NativeDesign.danger(this.dark) })
      }
    }.constraintSize({ minHeight: NativeDesign.compactChip }).padding({ left: 10, right: 11 })
      .constraintSize({
      minWidth: 112,
      maxWidth: this.maxWidth
    }).borderRadius(NativeDesign.radiusGroup)
      .backgroundColor(NativeDesign.overlay(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
      .shadow({ radius: 12, color: this.dark ? '#66000000' : '#24000000',
        offsetX: 0, offsetY: 3 })
      .accessibilityGroup(true)
      .accessibilityText('本次已修改 ' + this.summary.fileCount + ' 个文件，增加 ' +
        this.summary.added + ' 行，删除 ' + this.summary.removed + ' 行')
  }
}

@Component
export struct NativeTurnChangesCard {
  @Prop @Watch('summaryChanged') summary: NativeTurnChangeSummary =
    new NativeTurnChangeSummary();
  @Prop workspaceRoot: string = '';
  @Prop maxExpandedHeight: number = 260;
  @Prop copied: boolean = false;
  @Prop canCopy: boolean = true;
  onOpenFile: (path: string) => void = (_path: string): void => {};
  onCopy: () => void = (): void => {};
  onExpandedChange: (expanded: boolean) => void = (_expanded: boolean): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private expanded: boolean = false;
  private currentTurn: string = '';

  aboutToAppear(): void {
    this.currentTurn = this.summary.turnKey;
  }

  private summaryChanged(): void {
    if (this.currentTurn === this.summary.turnKey) return;
    this.currentTurn = this.summary.turnKey;
    this.expanded = false;
  }

  private toggle(): void {
    if (this.summary.files.length <= 3) return;
    NativeMotion.disclosure(this.getUIContext(), (): void => {
      this.expanded = !this.expanded;
      this.onExpandedChange(this.expanded);
    });
  }

  private shownFiles(): NativeTurnFileChange[] {
    return this.expanded ? this.summary.files : this.summary.files.slice(0, 3);
  }

  private metricColor(add: boolean): ResourceColor {
    return add ? NativeDesign.success(this.dark) : NativeDesign.danger(this.dark);
  }

  private outcomeLabel(): string {
    if (this.summary.outcome === 'failed' || this.summary.outcome === 'error') return '执行失败';
    if (this.summary.outcome === 'cancelled' || this.summary.outcome === 'interrupted') return '已停止';
    return '已完成';
  }

  private fileMetric(file: NativeTurnFileChange): string {
    if (file.binary) return '二进制';
    if (file.oversized) return '过大';
    return '+' + formattedCount(file.added) + '  -' + formattedCount(file.removed);
  }

  private fileDirectory(file: NativeTurnFileChange): string {
    return nativeTurnFilePresentation(file.path, this.workspaceRoot, file.display).directory;
  }

  private fileName(file: NativeTurnFileChange): string {
    return nativeTurnFilePresentation(file.path, this.workspaceRoot, file.display).name;
  }

  private fileDisplayPath(file: NativeTurnFileChange): string {
    return nativeTurnFilePresentation(file.path, this.workspaceRoot, file.display).relativePath;
  }

  @Builder
  private fileRow(file: NativeTurnFileChange) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 7 }) {
        DSHIcon({ glyph: 'file-outline', glyphSize: 14,
          color: NativeDesign.textSecondary(this.dark) })
        Column({ space: 1 }) {
          Text(this.fileName(file)).fontSize(12)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .fontColor(NativeDesign.textPrimary(this.dark))
          if (this.fileDirectory(file)) {
            Text(this.fileDirectory(file)).fontSize(9).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .fontColor(NativeDesign.textTertiary(this.dark))
          }
        }.layoutWeight(1).constraintSize({ minWidth: 0 }).alignItems(HorizontalAlign.Start)
        if (file.binary || file.oversized) {
          Text(this.fileMetric(file)).fontSize(11)
            .flexShrink(0)
            .fontColor(NativeDesign.textTertiary(this.dark))
        } else {
          Text('+' + formattedCount(file.added)).fontSize(11).fontWeight(FontWeight.Medium)
            .flexShrink(0)
            .fontColor(this.metricColor(true))
          Text('-' + formattedCount(file.removed)).fontSize(11).fontWeight(FontWeight.Medium)
            .flexShrink(0)
            .fontColor(this.metricColor(false))
        }
      }.width('100%').padding({ left: 10, right: 10 })
    }.height(NativeDesign.compactHitTarget).width('100%').padding(0)
      .borderRadius(NativeDesign.radiusCompact)
      .backgroundColor(Color.Transparent)
      .accessibilityText('打开已修改文件 ' + this.fileDisplayPath(file) + '，增加 ' + file.added +
        ' 行，删除 ' + file.removed + ' 行')
      .onClick((): void => { this.onOpenFile(file.path); })
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 9 }) {
            Stack({ alignContent: Alignment.Center }) {
              DSHIcon({ glyph: 'edit-outline', glyphSize: 18,
                color: NativeDesign.textPrimary(this.dark) })
            }.width(36).height(36).borderRadius(10)
              .backgroundColor(NativeDesign.selection(this.dark))
            Column({ space: 2 }) {
              Text('已编辑 ' + this.summary.fileCount + ' 个文件').fontSize(14)
                .fontWeight(FontWeight.Medium).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontColor(NativeDesign.textPrimary(this.dark))
              Row({ space: 8 }) {
                Text('+' + formattedCount(this.summary.added)).fontSize(11)
                  .fontWeight(FontWeight.Medium).fontColor(this.metricColor(true))
                Text('-' + formattedCount(this.summary.removed)).fontSize(11)
                  .fontWeight(FontWeight.Medium).fontColor(this.metricColor(false))
                Text(this.outcomeLabel()).fontSize(10)
                  .fontColor(NativeDesign.textTertiary(this.dark))
              }.width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            if (this.summary.files.length > 3) {
              DSHIcon({ glyph: this.expanded ? 'chevron-up-outline' : 'chevron-down-outline',
                glyphSize: 12, color: NativeDesign.textTertiary(this.dark) })
            }
          }.width('100%').padding({ left: 10, right: 5 })
        }.layoutWeight(1).height(NativeDesign.standardRow).padding(0).borderRadius(0)
          .backgroundColor(Color.Transparent)
          .accessibilityText(this.summary.files.length > 3 ?
            (this.expanded ? '收起' : '展开') + '本次修改的文件' :
            '本次修改了 ' + this.summary.fileCount + ' 个文件')
          .onClick((): void => { this.toggle(); })
        if (this.canCopy) {
          Button({ type: ButtonType.Normal }) {
            DSHIcon({ glyph: this.copied ? 'check-outline' : 'copy-outline', glyphSize: 14,
              color: NativeDesign.textTertiary(this.dark) })
          }.width(NativeDesign.compactControl).height(NativeDesign.compactControl)
            .padding(0).borderRadius(NativeDesign.radiusControl)
            .backgroundColor(Color.Transparent)
            .accessibilityText(this.copied ? '答复已复制' : '复制最终答复')
            .onClick((): void => { this.onCopy(); })
        }
      }.width('100%')
      Divider().strokeWidth(0.5).color(NativeDesign.divider(this.dark))
      if (this.expanded) {
        Scroll() {
          Column({ space: 1 }) {
            ForEach(this.shownFiles(), (file: NativeTurnFileChange) => {
              this.fileRow(file)
            }, (file: NativeTurnFileChange) => file.path)
          }.width('100%')
        }.width('100%').constraintSize({ maxHeight: this.maxExpandedHeight })
          .scrollable(ScrollDirection.Vertical).scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.None)
          .transition(NativeMotion.disclosureTransition())
      } else {
        ForEach(this.shownFiles(), (file: NativeTurnFileChange) => {
          this.fileRow(file)
        }, (file: NativeTurnFileChange) => file.path)
      }
      if (this.summary.files.length > 3) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 4 }) {
            Text(this.expanded ? '收起文件' : '再显示 ' + (this.summary.files.length - 3) + ' 个文件').fontSize(11)
            DSHIcon({ glyph: this.expanded ? 'chevron-up-outline' : 'chevron-down-outline',
              glyphSize: 10, color: NativeDesign.textTertiary(this.dark) })
          }
        }.width('100%').height(NativeDesign.compactControl).padding({ left: 11, right: 11 })
          .borderRadius(0).backgroundColor(Color.Transparent)
          .fontColor(NativeDesign.textSecondary(this.dark))
          .onClick((): void => { this.toggle(); })
      }
    }.width('100%').clip(true).borderRadius(NativeDesign.radiusGroup)
      .backgroundColor(NativeDesign.raised(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
      .animation(NativeMotion.disclosureParam())
  }
}
