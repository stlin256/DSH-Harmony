import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { nativeToolsParent } from '../services/NativeSessionModel';
import { NativeCatalogModel, NativeModelProvider, NativeModelEffort, NativeModelSelection, NativeModelDirectoryState } from '../services/NativeModelDirectory';
import { NativeExperience } from '../services/NativeExperience';
import { NativeMotion } from '../services/NativeMotion';
import { DSHIcon } from './DSHIcon';
import { NativeDesign } from '../services/NativeDesign';
import { NativeIconButton } from './NativeIconButton';

class Part { type: string = ''; text: string = ''; }
class QueueItem { id: string = ''; content: Part[] = []; }
class SessionState { queue: QueueItem[] | null = null; running: boolean = false; }

/** Dedicated composer subflows; session actions use the sidebar's anchored menu. */
@Component
export struct NativeSessionTools {
  client: NativeHarnessClient = new NativeHarnessClient('');
  @Prop sessionId: string = '';
  @Prop sessionTitle: string = '';
  onClose: () => void = (): void => {};
  onRename: (title: string) => void = (): void => {};
  @StorageLink('nativeSessionToolsPage') private page: string = 'modelsRoot';
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private title: string = '';
  @State private directory: NativeModelDirectoryState = new NativeModelDirectoryState();
  @State private queue: QueueItem[] = [];
  @State private running: boolean = false;
  @State private query: string = '';
  @State private editingId: string = '';
  @State private editingText: string = '';
  @State private busy: boolean = false;
  @State private error: string = '';
  private mounted: boolean = false;

  aboutToAppear(): void { this.mounted = true; this.title = this.sessionTitle; this.refresh(); }
  aboutToDisappear(): void { this.mounted = false; }
  private back(): void {
    if (this.busy) return;
    const parent = nativeToolsParent(this.page);
    if (parent) this.page = parent; else this.onClose();
    this.error = '';
  }
  private currentModel(): NativeCatalogModel | undefined {
    return this.directory.catalog.groups.find((row: NativeModelProvider) => row.id === this.directory.selected.provider)?.models
      .find((row: NativeCatalogModel) => row.id === this.directory.selected.model);
  }
  private async refresh(): Promise<void> {
    this.busy = true; this.error = '';
    try {
      if (this.page === 'rename') return;
      if (this.page === 'queue') {
        const data = JSON.parse(await this.client.operation(JSON.stringify({ operation: 'state', sessionId: this.sessionId }))) as SessionState;
        if (this.mounted) { this.queue = data.queue || []; this.running = data.running; }
      } else {
        const data = await this.client.modelDirectory.load(this.sessionId);
        if (this.mounted) { this.directory = data; if (!this.currentModel()) this.page = 'models'; }
      }
    } catch (_) { if (this.mounted) this.error = '加载失败'; }
    finally { if (this.mounted) this.busy = false; }
  }
  private async choose(provider: string, model: NativeCatalogModel, effort: string = ''): Promise<void> {
    if (this.busy) return;
    if (provider === this.directory.selected.provider && model.id === this.directory.selected.model &&
      (effort || model.reasoning?.defaultEffort || '') === (this.directory.selected.reasoningEffort || model.reasoning?.defaultEffort || '')) { this.onClose(); return; }
    this.busy = true; this.error = '';
    const route = new NativeModelSelection(); route.provider = provider; route.model = model.id; route.reasoningEffort = effort;
    try { await this.client.modelDirectory.select(this.sessionId, route); if (this.mounted) this.onClose(); }
    catch (_) { if (this.mounted) this.error = '切换失败'; }
    finally { if (this.mounted) this.busy = false; }
  }
  private async saveName(): Promise<void> {
    if (this.busy || !this.title.trim()) return;
    this.busy = true; this.error = '';
    try { await this.client.operation(JSON.stringify({ operation: 'rename', sessionId: this.sessionId, title: this.title.trim() }));
      if (this.mounted) this.onRename(this.title.trim());
    } catch (_) { if (this.mounted) this.error = '重命名失败'; }
    finally { if (this.mounted) this.busy = false; }
  }
  private async mutateQueue(id: string, kind: string): Promise<void> {
    if (this.busy) return;
    this.busy = true; this.error = '';
    try {
      await this.client.operation(JSON.stringify({ operation: 'updateQueue', sessionId: this.sessionId, itemId: id, kind, text: this.editingText }));
      if (this.mounted) { this.page = 'queue'; await this.refresh(); }
    } catch (_) { if (this.mounted) this.error = '操作未确认，请刷新'; }
    finally { if (this.mounted) this.busy = false; }
  }
  private heading(): string {
    if (this.page === 'rename') return '重命名';
    if (this.page === 'models') return '模型';
    if (this.page === 'efforts') return '推理';
    if (this.page === 'queue' || this.page === 'queueEdit') return '排队消息';
    return '模型与推理';
  }
  private pane(page: string): void {
    const change = (): void => { this.page = page; this.error = ''; };
    NativeMotion.animate(this.getUIContext(), 'navigation', change);
  }
  @Builder
  private row(label: string, detail: string, selected: boolean, child: boolean, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        Text(label).fontSize(NativeDesign.fontCompact).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        if (detail) { Text(detail).fontSize(NativeDesign.fontSection).maxLines(1).constraintSize({ maxWidth: '45%' }).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(NativeDesign.textTertiary(this.dark)) }
        if (selected) { DSHIcon({ glyph: 'check-outline', glyphSize: NativeDesign.glyphCompact, color: NativeDesign.textPrimary(this.dark) }) }
        else if (child) { DSHIcon({ glyph: 'chevron-left-outline', glyphSize: NativeDesign.glyphInline, color: NativeDesign.textTertiary(this.dark) }).rotate({ angle: 180 }) }
      }.width('100%')
    }.width('100%').height(NativeDesign.standardRow).padding({ left: 8, right: 8 })
      .borderRadius(NativeDesign.radiusRow).backgroundColor(Color.Transparent)
      .fontColor(NativeDesign.textPrimary(this.dark)).enabled(!this.busy).onClick(action)
  }
  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        NativeIconButton({ glyph: 'chevron-left-outline', label: '返回', tone: 'primary',
          controlEnabled: !this.busy, onPressed: (): void => { this.back(); } })
        Text(this.heading()).fontSize(NativeDesign.fontCompactTitle).fontWeight(FontWeight.Medium).layoutWeight(1)
        if (this.busy) { LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline) }
      }.width('100%')
      Scroll() {
        Column({ space: 4 }) {
          if (this.page === 'rename') {
            TextInput({ text: this.title, placeholder: '会话名称' }).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontBody).enabled(!this.busy).onChange((value: string) => { this.title = value; })
            Button('保存', { type: ButtonType.Normal }).width('100%').height(NativeDesign.hitTarget)
              .borderRadius(NativeDesign.radiusRow)
              .backgroundColor(NativeDesign.textPrimary(this.dark)).fontColor(NativeDesign.textInverse(this.dark))
              .enabled(!this.busy && this.title.trim().length > 0).onClick(() => { this.saveName(); })
          } else if (this.page === 'modelsRoot') {
            this.row('模型', this.currentModel()?.name || this.directory.selected.model, false, true, () => { this.pane('models'); })
            if (this.currentModel()?.reasoning) { this.row('推理', this.directory.selected.reasoningEffort || this.currentModel()?.reasoning?.defaultEffort || '提供方默认', false, true, () => { this.pane('efforts'); }) }
          } else if (this.page === 'models') {
            if (this.directory.catalog.groups.reduce((sum: number, provider: NativeModelProvider) => sum + provider.models.length, 0) > 4) {
              TextInput({ text: this.query, placeholder: '搜索模型' }).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontCompact).onChange((value: string) => { this.query = value; })
            }
            ForEach(this.directory.catalog.groups, (provider: NativeModelProvider) => {
              Text(provider.name).fontSize(NativeDesign.fontCaption).fontColor(NativeDesign.textTertiary(this.dark)).padding({ left: 8, top: 12, bottom: 4 })
              ForEach(provider.models.filter((model: NativeCatalogModel) => !this.query || (model.name + ' ' + model.id).toLowerCase().includes(this.query.toLowerCase())), (model: NativeCatalogModel) => {
                this.row(model.name, '', this.directory.selected.provider === provider.id && this.directory.selected.model === model.id, false,
                  () => { this.choose(provider.id, model, model.reasoning?.defaultEffort || ''); })
              }, (model: NativeCatalogModel) => model.id)
            }, (provider: NativeModelProvider) => provider.id)
          } else if (this.page === 'efforts') {
            if (!this.currentModel()?.reasoning?.defaultEffort) { this.row('提供方默认', '', !this.directory.selected.reasoningEffort, false, () => { const model = this.currentModel(); if (model) this.choose(this.directory.selected.provider, model); }) }
            ForEach(this.currentModel()?.reasoning?.efforts || [], (effort: NativeModelEffort) => {
              this.row(effort.name, '', (this.directory.selected.reasoningEffort || this.currentModel()?.reasoning?.defaultEffort) === effort.id, false,
                () => { const model = this.currentModel(); if (model) this.choose(this.directory.selected.provider, model, effort.id); })
            }, (effort: NativeModelEffort) => effort.id)
          } else if (this.page === 'queueEdit') {
            TextArea({ text: this.editingText }).height(140).fontSize(NativeDesign.fontBody).onChange((value: string) => { this.editingText = value; })
            Button('保存').height(NativeDesign.hitTarget).enabled(!this.busy && !!this.editingText.trim()).onClick(() => { this.mutateQueue(this.editingId, 'edit'); })
          } else if (this.page === 'queue') {
            if (!this.queue.length) { Text('没有排队消息').fontSize(NativeDesign.fontCompact).padding(12) }
            ForEach(this.queue, (item: QueueItem) => {
              Column({ space: 8 }) {
                Text(item.content.filter((part: Part) => part.type === 'text').map((part: Part) => part.text).join('\n') || '包含附件').fontSize(NativeDesign.fontCompact).maxLines(5).textOverflow({ overflow: TextOverflow.Ellipsis })
                Row({ space: 8 }) {
                  if (item.content.every((part: Part) => part.type === 'text')) { Button('编辑').height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection).enabled(!this.busy).onClick(() => { this.editingId = item.id; this.editingText = item.content.map((part: Part) => part.text).join('\n'); this.pane('queueEdit'); }) }
                  if (this.running) { Button('立即干预').height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection).enabled(!this.busy).onClick(() => { this.mutateQueue(item.id, 'steer'); }) }
                  Button('移除').height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection).enabled(!this.busy).onClick(() => { this.mutateQueue(item.id, 'remove'); })
                }
              }.padding(10).width('100%').alignItems(HorizontalAlign.Start)
                .borderRadius(NativeDesign.radiusRow).backgroundColor(NativeDesign.field(this.dark))
            }, (item: QueueItem) => item.id)
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.Top)
      if (this.error) { Row() { Text(this.error).fontSize(NativeDesign.fontSection).layoutWeight(1); Button('重试').height(NativeDesign.hitTarget).onClick(() => { this.refresh(); }) }.width('100%') }
    }.padding(12).width('100%').height('100%').backgroundColor(NativeDesign.base(this.dark))
      .foregroundColor(NativeDesign.textPrimary(this.dark))
  }
}
