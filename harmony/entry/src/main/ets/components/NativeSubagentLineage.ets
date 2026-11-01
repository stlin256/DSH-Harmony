import { NativeDesign } from '../services/NativeDesign';
import { NativeMotion } from '../services/NativeMotion';
import { NativeSubagentEntry, nativeSubagentCanOpen, nativeSubagentModeLabel,
  nativeSubagentOneShot, nativeSubagentContinuable, nativeSubagentExternal } from '../services/NativeModeSubagent';
import { DSHIcon } from './DSHIcon';

@Component
export struct NativeSubagentLineage {
  dark: boolean = false;
  title: string = '子智能体';
  entries: NativeSubagentEntry[] = [];
  currentId: string = '';
  loading: boolean = false;
  error: string = '';
  maxHeight: number = 420;
  bottomInset: number = 0;
  onClose: () => void = (): void => {};
  onOpen: (entry: NativeSubagentEntry) => void = (): void => {};
  onRetry: () => void = (): void => {};

  private primary(): string {
    return NativeDesign.textPrimary(this.dark);
  }

  private secondary(): string {
    return NativeDesign.textSecondary(this.dark);
  }

  private tertiary(): string {
    return NativeDesign.textTertiary(this.dark);
  }

  private modeIcon(mode: string): string {
    if (mode === nativeSubagentExternal) return 'globe-outline';
    if (mode === nativeSubagentOneShot) return 'file-outline';
    if (mode === nativeSubagentContinuable) return 'branch-outline';
    return 'question-outline';
  }

  @Builder
  private row(entry: NativeSubagentEntry) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 9 }) {
        Stack({ alignContent: Alignment.Center }) {
          DSHIcon({ glyph: this.modeIcon(entry.mode), glyphSize: NativeDesign.glyphControl,
            color: entry.running ? NativeDesign.accent(this.dark) : this.secondary() })
          if (entry.running) {
            Stack()
              .width(6)
              .height(6)
              .borderRadius(3)
              .backgroundColor(NativeDesign.accent(this.dark))
              .position({ x: 25, y: 2 })
          }
        }.width(30).height(30)
          .borderRadius(NativeDesign.radiusControl)
          .backgroundColor(this.currentId === entry.id ?
            NativeDesign.selection(this.dark) : NativeDesign.field(this.dark))
        Column({ space: 2 }) {
          Text(entry.label || entry.id)
            .fontSize(NativeDesign.fontCompact)
            .fontWeight(this.currentId === entry.id ? FontWeight.Medium : FontWeight.Regular)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .fontColor(this.primary())
          Row({ space: 5 }) {
            Text(nativeSubagentModeLabel(entry.mode))
              .fontSize(NativeDesign.fontMicro)
              .fontColor(this.tertiary())
            if (entry.running) {
              Text('运行中').fontSize(NativeDesign.fontMicro).fontColor(NativeDesign.accent(this.dark))
            }
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (!nativeSubagentCanOpen(entry)) {
          Text('不可打开').fontSize(NativeDesign.fontMicro).fontColor(this.tertiary())
        } else {
          DSHIcon({ glyph: 'chevron-right-outline', glyphSize: NativeDesign.glyphCompact, color: this.tertiary() })
        }
      }
      .width('100%')
      .height(NativeDesign.hitTarget)
      .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .height(NativeDesign.hitTarget)
    .borderRadius(NativeDesign.radiusRow)
    .backgroundColor(this.currentId === entry.id ?
      NativeDesign.selection(this.dark) : Color.Transparent)
    .enabled(nativeSubagentCanOpen(entry))
    .opacity(nativeSubagentCanOpen(entry) ? 1 : 0.58)
    .accessibilityText((entry.label || entry.id) + '，' +
      nativeSubagentModeLabel(entry.mode) + (entry.running ? '，正在运行' : '') +
      (nativeSubagentCanOpen(entry) ? '' : '，不可打开'))
    .onClick((): void => {
      if (nativeSubagentCanOpen(entry)) this.onOpen(entry);
    })
    .animation(NativeMotion.implicit('micro'))
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        DSHIcon({ glyph: 'branch-outline', glyphSize: NativeDesign.glyphControl, color: this.secondary() })
        Text(this.title).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(this.primary())
        Button({ type: ButtonType.Circle }) {
          DSHIcon({ glyph: 'close-outline', glyphSize: NativeDesign.glyphCompact, color: this.secondary() })
        }
        .width(NativeDesign.hitTarget)
        .height(NativeDesign.hitTarget)
        .backgroundColor(Color.Transparent)
        .accessibilityText('关闭子智能体列表')
        .onClick((): void => { this.onClose(); })
      }
      .width('100%')
      .height(NativeDesign.headerHeight)
      .padding({ left: 12, right: 4 })
      Divider().strokeWidth(0.5).color(NativeDesign.divider(this.dark))
      if (this.loading && !this.entries.length) {
        Row({ space: 8 }) {
          LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline).color(NativeDesign.accent(this.dark))
          Text('加载中').fontSize(NativeDesign.fontSection).fontColor(this.secondary())
          Blank()
        }.height(NativeDesign.standardRow).padding({ left: NativeDesign.rowInset, right: NativeDesign.rowInset })
      } else if (this.error && !this.entries.length) {
        Row({ space: 8 }) {
          Text(this.error).fontSize(NativeDesign.fontSection).fontColor(NativeDesign.danger(this.dark)).layoutWeight(1)
          Button('重试', { type: ButtonType.Normal })
            .height(NativeDesign.hitTarget)
            .fontSize(NativeDesign.fontSection)
            .backgroundColor(Color.Transparent)
            .fontColor(NativeDesign.accent(this.dark))
            .onClick((): void => { this.onRetry(); })
        }.constraintSize({ minHeight: NativeDesign.standardRow })
          .padding({ left: NativeDesign.rowInset, right: 8 })
      } else if (!this.entries.length) {
        Text('暂无子智能体').fontSize(NativeDesign.fontSection).fontColor(this.tertiary())
          .height(NativeDesign.standardRow).padding({ left: NativeDesign.rowInset })
      } else {
        List({ space: 1 }) {
          ForEach(this.entries, (entry: NativeSubagentEntry) => {
            ListItem() { this.row(entry) }
          }, (entry: NativeSubagentEntry): string => entry.id)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
      if (this.error && this.entries.length) {
        Row({ space: 6 }) {
          Text(this.error).fontSize(NativeDesign.fontSection).fontColor(NativeDesign.danger(this.dark)).layoutWeight(1)
          Button('重试', { type: ButtonType.Normal }).height(NativeDesign.hitTarget)
            .fontSize(NativeDesign.fontSection).backgroundColor(Color.Transparent)
            .fontColor(NativeDesign.accent(this.dark))
            .onClick((): void => { this.onRetry(); })
        }.padding({ left: 12, right: 8 })
      }
    }
    .width('100%')
    .constraintSize({ maxHeight: this.maxHeight })
    .padding({ bottom: this.bottomInset })
    .backgroundColor(NativeDesign.overlay(this.dark))
    .border({ width: 0.5, color: NativeDesign.border(this.dark) })
    .borderRadius({ topLeft: 20, topRight: 20 })
    .shadow({ radius: 24, color: NativeDesign.mask(this.dark), offsetY: -6 })
    .clip(true)
    .transition(NativeMotion.previewTransition())
  }
}
