import {
  NativePermissionCatalog,
  NativePermissionOption,
  NativePermissionSelection,
  nativePermissionCanSelect,
  nativePermissionDescription,
  nativePermissionIcon,
  nativePermissionLabel,
  nativePermissionRequiresRisk
} from '../services/NativePermissions';
import { NativeDesign } from '../services/NativeDesign';
import { NativeMotion } from '../services/NativeMotion';
import { DSHIcon } from './DSHIcon';
import { NativeIconButton } from './NativeIconButton';

/** Compact current-session permission popover. Writes stay owned by the page. */
@Component
export struct NativePermissionPicker {
  catalog: NativePermissionCatalog | null = null;
  selection: NativePermissionSelection | null = null;
  busyValue: string = '';
  error: string = '';
  pickerWidth: number = 316;
  onSelect: (value: string) => void = (_value: string): void => {};
  onClose: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;

  private currentValue(): string {
    return this.selection?.currentValue || '';
  }

  private selected(option: NativePermissionOption): boolean {
    return option.value === this.currentValue();
  }

  private optionColor(option: NativePermissionOption): string {
    if (this.selected(option)) return NativeDesign.textPrimary(this.dark);
    if (nativePermissionRequiresRisk(option.value)) return NativeDesign.warning(this.dark);
    return NativeDesign.textPrimary(this.dark);
  }

  private optionGlyphColor(option: NativePermissionOption): string {
    if (nativePermissionRequiresRisk(option.value)) return NativeDesign.warning(this.dark);
    if (this.selected(option)) return NativeDesign.accent(this.dark);
    return NativeDesign.textSecondary(this.dark);
  }

  private busy(option: NativePermissionOption): boolean {
    return !!this.busyValue && this.busyValue === option.value;
  }

  @Builder
  private optionRow(option: NativePermissionOption) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 9 }) {
        Stack({ alignContent: Alignment.Center }) {
          DSHIcon({
            glyph: nativePermissionIcon(option.value),
            glyphSize: NativeDesign.glyphCompact,
            color: this.optionGlyphColor(option)
          })
        }.width(28).height(28).borderRadius(NativeDesign.radiusBadge)
          .backgroundColor(this.selected(option) ?
            NativeDesign.selectedSurface(this.dark) : NativeDesign.field(this.dark))
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(nativePermissionLabel(option, option.value))
              .fontSize(NativeDesign.fontCompact).fontWeight(this.selected(option) ?
                FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.optionColor(option)).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .hitTestBehavior(HitTestMode.None)
            if (option.value === 'auto') {
              Text('EXP').fontSize(NativeDesign.fontMicro).fontWeight(FontWeight.Medium)
                .fontColor(NativeDesign.warning(this.dark))
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .borderRadius(4)
                .backgroundColor(NativeDesign.warningSurface(this.dark))
            }
          }.width('100%')
          Text(nativePermissionDescription(option, option.value))
            .fontSize(NativeDesign.fontCaption).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textTertiary(this.dark)).width('100%')
            .hitTestBehavior(HitTestMode.None)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.busy(option)) {
          LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
            .color(NativeDesign.accent(this.dark))
        } else if (this.selected(option)) {
          DSHIcon({ glyph: 'check-outline', glyphSize: NativeDesign.glyphCompact,
            color: NativeDesign.accent(this.dark) })
        }
      }.width('100%')
    }.width('100%').height(50).padding({ left: 8, right: 8 })
      .borderRadius(NativeDesign.radiusControl)
      .backgroundColor(this.selected(option) ?
        NativeDesign.selectedSurface(this.dark) : Color.Transparent)
      .id('permission-option-' + option.value)
      .hitTestBehavior(HitTestMode.Block)
      .enabled(!this.busyValue && nativePermissionCanSelect(this.catalog, option.value))
      .accessibilityText(nativePermissionLabel(option, option.value) + '，' +
        nativePermissionDescription(option, option.value))
      .onClick((): void => { this.onSelect(option.value); })
      .transition(NativeMotion.rowTransition())
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text('会话权限').fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium)
            .fontColor(NativeDesign.textPrimary(this.dark))
          Text('只影响当前会话').fontSize(NativeDesign.fontCaption)
            .fontColor(NativeDesign.textTertiary(this.dark))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.busyValue) {
          LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
            .color(NativeDesign.accent(this.dark))
        }
        NativeIconButton({
          glyph: 'close-outline',
          label: '关闭权限选择',
          glyphSize: NativeDesign.glyphCompact,
          onPressed: this.onClose
        })
      }.width('100%').padding({ left: 4, right: 0 })
      Scroll() {
        Column({ space: 2 }) {
          ForEach(this.catalog?.options || [], (option: NativePermissionOption) => {
            this.optionRow(option)
          }, (option: NativePermissionOption) => option.value)
          if (this.selection?.currentValue === 'custom') {
            Row({ space: 8 }) {
              DSHIcon({ glyph: nativePermissionIcon('custom'),
                glyphSize: NativeDesign.glyphCompact, color: NativeDesign.textTertiary(this.dark) })
              Column({ space: 2 }) {
                Text('自定义权限').fontSize(NativeDesign.fontCompact)
                  .fontColor(NativeDesign.textSecondary(this.dark))
                Text('当前设置不属于可选的 Host 预设')
                  .fontSize(NativeDesign.fontCaption).fontColor(NativeDesign.textTertiary(this.dark))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%').height(48).padding({ left: 8, right: 8 })
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').constraintSize({ maxHeight: 278 })
        .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.None)
      if (this.error) {
        Divider().strokeWidth(0.5).color(NativeDesign.divider(this.dark))
        Text(this.error).fontSize(NativeDesign.fontCaption)
          .fontColor(NativeDesign.danger(this.dark))
          .padding({ left: 4, right: 4, bottom: 2 })
      }
    }.width(this.pickerWidth).padding(10).borderRadius(NativeDesign.radiusGroup)
      .id('permission-picker')
      .backgroundColor(NativeDesign.overlay(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
      .transition(NativeMotion.overlayTransition())
  }
}
