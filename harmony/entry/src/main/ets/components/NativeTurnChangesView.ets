import { DSHIcon } from './DSHIcon';
import { NativeMotion } from '../services/NativeMotion';
import {
  nativeTurnFilePresentation,
  NativeTurnChangeSummary,
  NativeTurnFileChange
} from '../services/NativeTurnChanges';

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
        this.getUIContext().animateTo({
          duration: 170,
          curve: Curve.FastOutSlowIn
        }, update);
      }
      this.settleTimer = setTimeout((): void => {
        this.previousValue = this.currentValue;
        this.settled = true;
      }, NativeMotion.enabled() ? 190 : 0);
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
        color: this.dark ? '#8AB4FF' : '#3964FE' })
      Text('正在编辑').fontSize(11).fontColor(this.dark ? '#CFD3D6' : '#61666B')
      NativeRollingNumber({
        value: this.summary.fileCount,
        color: this.dark ? '#F1F1F2' : '#25262A'
      })
      Text('个文件').fontSize(11).fontColor(this.dark ? '#CFD3D6' : '#61666B')
      Row({ space: 1 }) {
        Text('+').fontSize(11).fontWeight(FontWeight.Medium).fontColor('#36C477')
        NativeRollingNumber({ value: this.summary.added, color: '#36C477' })
      }
      Row({ space: 1 }) {
        Text('-').fontSize(11).fontWeight(FontWeight.Medium).fontColor('#EF6666')
        NativeRollingNumber({ value: this.summary.removed, color: '#EF6666' })
      }
    }.height(30).padding({ left: 10, right: 11 }).constraintSize({
      minWidth: 112,
      maxWidth: this.maxWidth
    }).borderRadius(15)
      .backgroundColor(this.dark ? '#E6222325' : '#F2FFFFFF')
      .border({ width: 0.5, color: this.dark ? '#55575B' : '#D8DCE2' })
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
    return add ? (this.dark ? '#7DE3A2' : '#187940') :
      (this.dark ? '#FF9C9C' : '#B3261E');
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
          color: this.dark ? '#BFC3C8' : '#5F646A' })
        Row({ space: 4 }) {
          if (this.fileDirectory(file)) {
            Text(this.fileDirectory(file)).fontSize(11).flexShrink(3).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ minWidth: 0 })
              .fontColor(this.dark ? '#969A9F' : '#777C82')
          }
          Text(this.fileName(file)).fontSize(12)
            .flexShrink(1).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ minWidth: 0 })
            .fontColor(this.dark ? '#E8E9EB' : '#2B2D30')
        }
        if (file.binary || file.oversized) {
          Text(this.fileMetric(file)).fontSize(11)
            .flexShrink(0)
            .fontColor(this.dark ? '#A8ABAF' : '#686D73')
        } else {
          Text('+' + formattedCount(file.added)).fontSize(11).fontWeight(FontWeight.Medium)
            .flexShrink(0)
            .fontColor(this.metricColor(true))
          Text('-' + formattedCount(file.removed)).fontSize(11).fontWeight(FontWeight.Medium)
            .flexShrink(0)
            .fontColor(this.metricColor(false))
        }
      }.width('100%').padding({ left: 10, right: 10 })
    }.height(38).width('100%').padding(0).borderRadius(8)
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
                color: this.dark ? '#F0F1F2' : '#26272A' })
            }.width(36).height(36).borderRadius(10)
              .backgroundColor(this.dark ? '#353638' : '#ECEEF1')
            Column({ space: 2 }) {
              Text('已编辑 ' + this.summary.fileCount + ' 个文件').fontSize(14)
                .fontWeight(FontWeight.Medium).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontColor(this.dark ? '#F5F5F6' : '#191A1D')
              Row({ space: 8 }) {
                Text('+' + formattedCount(this.summary.added)).fontSize(11)
                  .fontWeight(FontWeight.Medium).fontColor(this.metricColor(true))
                Text('-' + formattedCount(this.summary.removed)).fontSize(11)
                  .fontWeight(FontWeight.Medium).fontColor(this.metricColor(false))
                Text(this.outcomeLabel()).fontSize(10)
                  .fontColor(this.dark ? '#8F9296' : '#92969B')
              }.width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            if (this.summary.files.length > 3) {
              DSHIcon({ glyph: this.expanded ? 'chevron-up-outline' : 'chevron-down-outline',
                glyphSize: 12, color: this.dark ? '#9A9DA1' : '#777B80' })
            }
          }.width('100%').padding({ left: 10, right: 5 })
        }.layoutWeight(1).height(56).padding(0).borderRadius(0)
          .backgroundColor(Color.Transparent)
          .accessibilityText(this.summary.files.length > 3 ?
            (this.expanded ? '收起' : '展开') + '本次修改的文件' :
            '本次修改了 ' + this.summary.fileCount + ' 个文件')
          .onClick((): void => { this.toggle(); })
        if (this.canCopy) {
          Button({ type: ButtonType.Normal }) {
            DSHIcon({ glyph: this.copied ? 'check-outline' : 'copy-outline', glyphSize: 14,
              color: this.dark ? '#A8ABAF' : '#686D73' })
          }.width(38).height(38).padding(0).borderRadius(9)
            .backgroundColor(Color.Transparent)
            .accessibilityText(this.copied ? '答复已复制' : '复制最终答复')
            .onClick((): void => { this.onCopy(); })
        }
      }.width('100%')
      Divider().strokeWidth(0.5).color(this.dark ? '#3B3D40' : '#E5E7EA')
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
              glyphSize: 10, color: this.dark ? '#A8ABAF' : '#686D73' })
          }
        }.width('100%').height(36).padding({ left: 11, right: 11 })
          .borderRadius(0).backgroundColor(Color.Transparent)
          .fontColor(this.dark ? '#D5D7DA' : '#45494E')
          .onClick((): void => { this.toggle(); })
      }
    }.width('100%').clip(true).borderRadius(14)
      .backgroundColor(this.dark ? '#202124' : '#FFFFFF')
      .border({ width: 0.5, color: this.dark ? '#484A4D' : '#D9DCE1' })
      .animation(NativeMotion.disclosureParam())
  }
}
