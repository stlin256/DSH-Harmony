import { NativeHarnessClient } from '../services/NativeHarnessClient';
import {
  NativeCatalogModel,
  NativeModelDirectoryState,
  NativeModelEffort,
  NativeModelProvider,
  NativeModelSelection
} from '../services/NativeModelDirectory';
import { DSHIcon } from './DSHIcon';
import { NativeExperience } from '../services/NativeExperience';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';
import { NativeIconButton } from './NativeIconButton';

/** Compact composer popover. It paints the per-session cache before refreshing. */
@Component
export struct NativeModelPicker {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  @Prop currentCaption: string = '模型';
  pickerWidth: number = 316;
  onClose: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeModelRevision') @Watch('modelChanged') private modelRevision: number = 0;
  @State private directory: NativeModelDirectoryState = new NativeModelDirectoryState();
  @State private loading: boolean = false;
  @State private busy: boolean = false;
  @State private error: string = '';
  private mounted: boolean = false;

  aboutToAppear(): void {
    this.mounted = true;
    this.directory = this.client.modelDirectory.state(this.sessionId);
    this.refresh();
  }
  aboutToDisappear(): void {
    this.mounted = false;
  }
  private modelChanged(): void {
    if (this.mounted) this.directory = this.client.modelDirectory.state(this.sessionId);
  }
  private currentModel(): NativeCatalogModel | undefined {
    return this.directory.catalog.groups.find((row: NativeModelProvider) => row.id === this.directory.selected.provider)?.models
      .find((row: NativeCatalogModel) => row.id === this.directory.selected.model);
  }
  private modelCount(): number {
    return this.directory.catalog.groups.reduce((sum: number, provider: NativeModelProvider) => sum + provider.models.length, 0);
  }
  private async refresh(): Promise<void> {
    this.loading = this.modelCount() === 0;
    this.error = '';
    try {
      const value = await this.client.modelDirectory.load(this.sessionId);
      if (this.mounted) this.directory = value;
    } catch (_) {
      if (this.mounted) this.error = this.modelCount() ? '刷新失败，显示缓存' : '模型目录加载失败';
    } finally {
      if (this.mounted) this.loading = false;
    }
  }
  private async choose(provider: string, model: NativeCatalogModel, effort: string, closeAfter: boolean): Promise<void> {
    if (this.busy) return;
    const selectedEffort = this.directory.selected.reasoningEffort || this.currentModel()?.reasoning?.defaultEffort || '';
    if (provider === this.directory.selected.provider && model.id === this.directory.selected.model &&
      (effort || model.reasoning?.defaultEffort || '') === selectedEffort) {
      if (closeAfter) this.onClose();
      return;
    }
    this.busy = true;
    this.error = '';
    const route = new NativeModelSelection();
    route.provider = provider;
    route.model = model.id;
    route.reasoningEffort = effort;
    try {
      await this.client.modelDirectory.select(this.sessionId, route);
      if (this.mounted) {
        this.directory = this.client.modelDirectory.state(this.sessionId);
        if (closeAfter) this.onClose();
      }
    } catch (_) {
      if (this.mounted) this.error = '切换失败';
    } finally {
      if (this.mounted) this.busy = false;
    }
  }
  @Builder
  private choice(title: string, detail: string, selected: boolean, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(title).fontSize(NativeDesign.fontCompact).fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(NativeDesign.textPrimary(this.dark))
          if (detail) {
            Text(detail).fontSize(NativeDesign.fontCaption).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textTertiary(this.dark))
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (selected) { DSHIcon({ glyph: 'check-outline', glyphSize: NativeDesign.glyphCompact, color: NativeDesign.textPrimary(this.dark) }) }
      }.width('100%')
    }.width('100%').height(detail ? NativeDesign.pickerRow : NativeDesign.hitTarget)
      .padding({ left: 9, right: 9 }).borderRadius(NativeDesign.radiusControl)
      .backgroundColor(selected ? NativeDesign.selection(this.dark) : Color.Transparent)
      .enabled(enabled && !this.busy).onClick(action)
  }
  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text('模型与推理').fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium)
            .fontColor(NativeDesign.textPrimary(this.dark))
          Text(this.currentCaption).fontSize(NativeDesign.fontCaption).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textTertiary(this.dark))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.busy || this.loading) { LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline) }
        NativeIconButton({ glyph: 'close-outline', label: '关闭模型选择', glyphSize: NativeDesign.glyphCompact,
          onPressed: this.onClose })
      }.width('100%').padding({ left: 2, right: 2 })

      Scroll() {
        Column({ space: 3 }) {
          ForEach(this.directory.catalog.groups, (provider: NativeModelProvider) => {
            Text(provider.name).fontSize(NativeDesign.fontMicro).fontWeight(FontWeight.Medium)
              .padding({ left: 9, top: 5, bottom: 2 }).fontColor(NativeDesign.textTertiary(this.dark))
            ForEach(provider.models, (model: NativeCatalogModel) => {
              this.choice(model.name, model.id === model.name ? '' : model.id,
                this.directory.selected.provider === provider.id && this.directory.selected.model === model.id, true,
                () => { this.choose(provider.id, model, model.reasoning?.defaultEffort || '', !model.reasoning); })
            }, (model: NativeCatalogModel) => provider.id + ':' + model.id)
          }, (provider: NativeModelProvider) => provider.id)
          if (this.currentModel()?.reasoning) {
            Text('推理').fontSize(NativeDesign.fontMicro).fontWeight(FontWeight.Medium).padding({ left: 9, top: 8, bottom: 2 })
              .fontColor(NativeDesign.textTertiary(this.dark))
            this.choice('默认', '', !this.directory.selected.reasoningEffort, true, () => {
              const model = this.currentModel();
              if (model) this.choose(this.directory.selected.provider, model, '', true);
            })
            ForEach(this.currentModel()?.reasoning?.efforts || [], (effort: NativeModelEffort) => {
              this.choice(effort.name, effort.description,
                (this.directory.selected.reasoningEffort || this.currentModel()?.reasoning?.defaultEffort) === effort.id,
                true, () => {
                  const model = this.currentModel();
                  if (model) this.choose(this.directory.selected.provider, model, effort.id, true);
                })
            }, (effort: NativeModelEffort) => effort.id)
          }
          if (this.loading && !this.modelCount()) {
            Row({ space: 8 }) {
              LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
              Text(this.currentCaption).fontSize(NativeDesign.fontSection).fontColor(NativeDesign.textSecondary(this.dark))
            }.height(NativeDesign.compactRow).padding({ left: 9 })
          }
          if (!this.loading && !this.modelCount()) {
            Text('此服务未提供模型目录').fontSize(NativeDesign.fontSection).padding({ left: 9, top: 10, bottom: 10 })
              .fontColor(NativeDesign.textTertiary(this.dark))
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').constraintSize({ maxHeight: 278 })
        .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.None)
      if (this.error) {
        Row() {
          Text(this.error).fontSize(NativeDesign.fontCaption).layoutWeight(1).fontColor(NativeDesign.danger(this.dark))
          Button('重试', { type: ButtonType.Normal }).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontCaption)
            .enabled(!this.busy).onClick(() => { this.refresh(); })
        }.width('100%')
      }
    }.width(this.pickerWidth).padding(10).borderRadius(NativeDesign.radiusGroup)
      .id('model-picker')
      .backgroundColor(NativeDesign.overlay(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
      .transition(NativeMotion.overlayTransition())
  }
}
