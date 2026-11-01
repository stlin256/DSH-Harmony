import { NativeHarnessClient, NativeHttpError } from '../services/NativeHarnessClient';
import { NativeAdminClient } from '../services/NativeAdminClient';
import {
  NativeAutomationCatalog,
  NativeAutomationDelivery,
  NativeAutomationDraft,
  NativeAutomationHistory,
  NativeAutomationTask,
  nativeAutomationDraftFromTask,
  nativeAutomationDraftValid,
  nativeAutomationKind,
  nativeAutomationMatches,
  nativeAutomationRule,
  nativeAutomationStatus,
  nativeAutomationTarget,
  nativeAutomationTimestamp
} from '../services/NativeAdminModels';
import { NativeDesign } from '../services/NativeDesign';
import { NativeMotion } from '../services/NativeMotion';
import { DSHIcon } from './DSHIcon';
import { NativeIconButton } from './NativeIconButton';

@Component
export struct NativeAutomationSurface {
  client: NativeHarnessClient = new NativeHarnessClient('');
  onClose: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @StorageLink('nativeAdminBackRevision') @Watch('backRequested') private adminBackRevision: number = 0;
  @State private page: string = 'root';
  @State private navigationDirection: number = 1;
  @State private catalog: NativeAutomationCatalog = new NativeAutomationCatalog();
  @State private selected: NativeAutomationTask = new NativeAutomationTask();
  @State private history: NativeAutomationHistory = new NativeAutomationHistory();
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private historyLoading: boolean = false;
  @State private saving: boolean = false;
  @State private actionBusy: string = '';
  @State private error: string = '';
  @State private actionError: string = '';
  @State private conflict: boolean = false;
  @State private filter: string = 'active';
  @State private query: string = '';
  @State private editing: boolean = false;
  @State private formTitle: string = '';
  @State private formPrompt: string = '';
  @State private formKind: string = 'every';
  @State private formInterval: string = '30';
  @State private formTime: string = '09:00';
  @State private formTimeZone: string = 'Asia/Shanghai';
  @State private formWeekdays: number[] = [1, 3, 5];
  @State private formExpression: string = '0 9 * * *';
  @State private formRRule: string = '';
  @State private formAtDate: string = '';
  @State private formAtTime: string = '';
  @State private formTargetKind: string = 'new_once';
  @State private formSessionId: string = '';
  @State private formCwd: string = '';
  @State private formPreset: string = '';
  @State private formUpdatedAt: string = '';
  private admin: NativeAdminClient = new NativeAdminClient(this.client);
  private mounted: boolean = false;
  private showcaseOpened: boolean = false;

  private baseSurface(): string { return NativeDesign.base(this.dark); }
  private fieldSurface(): string { return NativeDesign.field(this.dark); }
  private raisedSurface(): string { return NativeDesign.raised(this.dark); }
  private lineColor(): string { return NativeDesign.border(this.dark); }
  private dividerColor(): string { return NativeDesign.divider(this.dark); }
  private primaryText(): string { return NativeDesign.textPrimary(this.dark); }
  private secondaryText(): string { return NativeDesign.textSecondary(this.dark); }
  private tertiaryText(): string { return NativeDesign.textTertiary(this.dark); }
  private accent(): string { return NativeDesign.accent(this.dark); }
  private danger(): string { return NativeDesign.danger(this.dark); }
  private warning(): string { return NativeDesign.warning(this.dark); }

  aboutToAppear(): void {
    this.mounted = true;
    // ArkUI injects component parameters after field initialization. Rebind the
    // adapter so this surface never falls back to the empty-URL default client.
    this.admin = new NativeAdminClient(this.client);
    this.refresh();
  }

  aboutToDisappear(): void {
    this.mounted = false;
  }

  private backRequested(): void {
    this.back();
  }

  private filteredItems(): NativeAutomationTask[] {
    return this.catalog.items.filter((task: NativeAutomationTask): boolean =>
      nativeAutomationMatches(task, this.filter, this.query))
      .sort((left: NativeAutomationTask, right: NativeAutomationTask): number => {
        if (left.status === 'active' && right.status !== 'active') return -1;
        if (right.status === 'active' && left.status !== 'active') return 1;
        const leftTime = Date.parse(left.status === 'active' ? left.scheduledAt :
          (left.updatedAt || left.scheduledAt));
        const rightTime = Date.parse(right.status === 'active' ? right.scheduledAt :
          (right.updatedAt || right.scheduledAt));
        return (Number.isFinite(leftTime) ? leftTime : Number.MAX_SAFE_INTEGER) -
          (Number.isFinite(rightTime) ? rightTime : Number.MAX_SAFE_INTEGER) ||
          left.id.localeCompare(right.id);
      });
  }

  private taskFor(id: string): NativeAutomationTask | null {
    return this.catalog.items.find((task: NativeAutomationTask): boolean =>
      task.id === id) || null;
  }

  private statusColor(status: string): string {
    if (status === 'active') return NativeDesign.success(this.dark);
    if (status === 'paused') return this.warning();
    return this.tertiaryText();
  }

  private statusSurface(status: string): string {
    if (status === 'active') return NativeDesign.successSurface(this.dark);
    if (status === 'paused') return NativeDesign.warningSurface(this.dark);
    return this.fieldSurface();
  }

  private openShowcaseState(): void {
    if (this.showcaseOpened || AppStorage.get<boolean>('storeShowcase') !== true) return;
    this.showcaseOpened = true;
    const state = AppStorage.get<string>('storeShowcaseState') || '';
    if (!['automation-detail', 'automation-editor', 'automation-history',
      'automation-conflict'].includes(state)) return;
    setTimeout((): void => {
      if (!this.mounted || !this.catalog.items.length) return;
      this.selected = this.catalog.items[0];
      if (state === 'automation-detail') {
        this.openDetail(this.selected);
      } else if (state === 'automation-history') {
        this.openHistory();
      } else {
        this.openEditor();
        if (state === 'automation-conflict') {
          this.actionError = '任务已在其他设备更新';
          this.conflict = true;
        }
      }
    }, 320);
  }

  private errorText(error: Error): string {
    if (error instanceof NativeHttpError) {
      if (error.code === 'schedule_conflict') return '任务已在其他设备更新';
      if (error.code === 'schedule_execution_pending') return '任务正在执行';
      if (error.code === 'schedule_not_found') return '任务不存在';
      if (error.status === 401) return '登录已失效，请重新登录';
    }
    return error.message || '任务服务暂不可用';
  }

  private setPage(next: string, direction: number): void {
    this.navigationDirection = direction;
    NativeMotion.animate(this.getUIContext(), 'navigation', (): void => {
      this.page = next;
    });
  }

  private back(): void {
    if (this.page === 'root') {
      this.onClose();
      return;
    }
    if (this.page === 'editor') {
      this.setPage(this.editing && this.selected.id ? 'detail' : 'root', -1);
      return;
    }
    if (this.page === 'history') {
      this.setPage('detail', -1);
      return;
    }
    this.setPage('root', -1);
  }

  private openDetail(task: NativeAutomationTask): void {
    this.selected = task;
    this.actionError = '';
    this.conflict = false;
    this.history = new NativeAutomationHistory();
    this.setPage('detail', 1);
  }

  private async refresh(silent: boolean = false): Promise<void> {
    if (!silent) this.loading = true;
    this.refreshing = true;
    this.error = '';
    try {
      const value = await this.admin.automations();
      if (!this.mounted) return;
      this.catalog = value;
      if (this.selected.id) {
        const current = this.taskFor(this.selected.id);
        if (current) this.selected = current;
      }
      this.openShowcaseState();
    } catch (error) {
      if (this.mounted) this.error = this.errorText(error as Error);
    } finally {
      if (this.mounted) {
        this.loading = false;
        this.refreshing = false;
      }
    }
  }

  private resetForm(): void {
    const draft = new NativeAutomationDraft();
    draft.timeZone = 'Asia/Shanghai';
    this.loadDraft(draft);
    this.editing = false;
    this.selected = new NativeAutomationTask();
  }

  private loadDraft(draft: NativeAutomationDraft): void {
    this.formTitle = draft.title;
    this.formPrompt = draft.prompt;
    this.formKind = draft.kind;
    this.formInterval = draft.interval;
    this.formTime = draft.time;
    this.formTimeZone = draft.timeZone;
    this.formWeekdays = draft.weekdays.slice();
    this.formExpression = draft.expression;
    this.formRRule = draft.rrule;
    this.formAtDate = draft.atDate;
    this.formAtTime = draft.atTime;
    this.formTargetKind = draft.targetKind;
    this.formSessionId = draft.sessionId;
    this.formCwd = draft.cwd;
    this.formPreset = draft.agentPreset;
    this.formUpdatedAt = draft.updatedAt;
  }

  private currentDraft(): NativeAutomationDraft {
    const draft = new NativeAutomationDraft();
    draft.title = this.formTitle;
    draft.prompt = this.formPrompt;
    draft.kind = this.formKind;
    draft.interval = this.formInterval;
    draft.time = this.formTime;
    draft.timeZone = this.formTimeZone;
    draft.weekdays = this.formWeekdays.slice();
    draft.expression = this.formExpression;
    draft.rrule = this.formRRule;
    draft.atDate = this.formAtDate;
    draft.atTime = this.formAtTime;
    draft.targetKind = this.formTargetKind;
    draft.sessionId = this.formSessionId;
    draft.cwd = this.formCwd;
    draft.agentPreset = this.formPreset;
    draft.updatedAt = this.formUpdatedAt;
    return draft;
  }

  private formValid(): boolean {
    return nativeAutomationDraftValid(this.currentDraft());
  }

  private openCreate(): void {
    this.resetForm();
    this.actionError = '';
    this.conflict = false;
    this.setPage('editor', 1);
  }

  private openEditor(): void {
    this.loadDraft(nativeAutomationDraftFromTask(this.selected));
    this.editing = true;
    this.actionError = '';
    this.conflict = false;
    this.setPage('editor', 1);
  }

  private async save(): Promise<void> {
    if (this.saving || !this.formValid()) return;
    this.saving = true;
    this.actionError = '';
    this.conflict = false;
    try {
      const value = this.selected.id ?
        await this.admin.updateAutomation(this.selected, this.currentDraft()) :
        await this.admin.createAutomation(this.currentDraft());
      if (!this.mounted) return;
      this.selected = value;
      this.editing = true;
      await this.refresh(true);
      const current = this.taskFor(value.id);
      if (current) this.selected = current;
      this.setPage('detail', -1);
    } catch (error) {
      if (!this.mounted) return;
      this.actionError = this.errorText(error as Error);
      this.conflict = error instanceof NativeHttpError && error.code === 'schedule_conflict';
    } finally {
      if (this.mounted) this.saving = false;
    }
  }

  private async reloadConflict(): Promise<void> {
    this.actionError = '';
    this.conflict = false;
    await this.refresh(true);
    const current = this.selected.id ? this.taskFor(this.selected.id) : null;
    if (current) this.loadDraft(nativeAutomationDraftFromTask(current));
  }

  private async toggleActive(): Promise<void> {
    if (!this.selected.id || this.actionBusy) return;
    this.actionBusy = 'active';
    this.actionError = '';
    this.conflict = false;
    try {
      const value = await this.admin.setAutomationActive(this.selected, this.selected.status !== 'active');
      if (!this.mounted) return;
      this.selected = value;
      await this.refresh(true);
    } catch (error) {
      if (!this.mounted) return;
      this.actionError = this.errorText(error as Error);
      this.conflict = error instanceof NativeHttpError && error.code === 'schedule_conflict';
    } finally {
      if (this.mounted) this.actionBusy = '';
    }
  }

  private async runNow(): Promise<void> {
    if (!this.selected.id || this.actionBusy) return;
    this.actionBusy = 'run';
    this.actionError = '';
    try {
      const value = await this.admin.runAutomation(this.selected);
      if (!this.mounted) return;
      this.selected = value;
      await this.refresh(true);
    } catch (error) {
      if (this.mounted) this.actionError = this.errorText(error as Error);
    } finally {
      if (this.mounted) this.actionBusy = '';
    }
  }

  private confirmDelete(): void {
    if (!this.selected.id || this.actionBusy) return;
    this.getUIContext().showAlertDialog({
      title: '删除自动化任务',
      message: '将删除“' + this.selected.title + '”。已投递的消息不会删除。',
      autoCancel: true,
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '删除',
        fontColor: this.danger(),
        action: (): void => { this.deleteSelected(); }
      }
    });
  }

  private async deleteSelected(): Promise<void> {
    if (!this.selected.id || this.actionBusy) return;
    this.actionBusy = 'delete';
    this.actionError = '';
    try {
      await this.admin.deleteAutomation(this.selected);
      if (!this.mounted) return;
      this.selected = new NativeAutomationTask();
      await this.refresh(true);
      this.setPage('root', -1);
    } catch (error) {
      if (this.mounted) this.actionError = this.errorText(error as Error);
    } finally {
      if (this.mounted) this.actionBusy = '';
    }
  }

  private async loadHistory(more: boolean = false): Promise<void> {
    if (!this.selected.id || this.historyLoading) return;
    this.historyLoading = true;
    this.actionError = '';
    try {
      const before = more ? this.history.nextBefore : '';
      const value = await this.admin.history(this.selected.id, before, 30);
      if (!this.mounted) return;
      if (more) {
        const result = new NativeAutomationHistory();
        result.available = value.available;
        result.code = value.code;
        result.earlierRecordsUnavailable = value.earlierRecordsUnavailable;
        result.earlierRecordsPruned = value.earlierRecordsPruned;
        result.nextBefore = value.nextBefore;
        result.records = this.history.records.concat(value.records);
        this.history = result;
      } else {
        this.history = value;
      }
    } catch (error) {
      if (this.mounted) this.actionError = this.errorText(error as Error);
    } finally {
      if (this.mounted) this.historyLoading = false;
    }
  }

  private openHistory(): void {
    this.history = new NativeAutomationHistory();
    this.setPage('history', 1);
    this.loadHistory(false);
  }

  private toggleWeekday(day: number): void {
    this.formWeekdays = this.formWeekdays.includes(day) ?
      this.formWeekdays.filter((value: number): boolean => value !== day) :
      this.formWeekdays.concat([day]).sort();
  }

  @Builder
  private pageHeader(title: string, actionLabel: string = '', action: () => void = (): void => {}) {
    Row({ space: 4 }) {
      NativeIconButton({
        glyph: 'chevron-left-outline', label: '返回', tone: 'primary',
        glyphSize: NativeDesign.glyphControl, onPressed: (): void => { this.back(); }
      })
      Text(title).fontSize(NativeDesign.fontHeaderTitle).fontWeight(FontWeight.Medium).layoutWeight(1)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.primaryText())
      if (this.refreshing) LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline).color(this.accent())
      if (actionLabel) {
        Button(actionLabel, { type: ButtonType.Normal }).height(NativeDesign.compactHitTarget)
          .padding({ left: 12, right: 12 }).fontSize(NativeDesign.fontSection).borderRadius(NativeDesign.radiusControl)
          .backgroundColor(this.fieldSurface()).fontColor(this.primaryText()).onClick(action)
      }
    }.width('100%').height(NativeDesign.headerHeight)
  }

  @Builder
  private searchField() {
    Row({ space: 8 }) {
      DSHIcon({ glyph: 'search-outline', glyphSize: NativeDesign.glyphControl, color: this.tertiaryText() })
      TextInput({ text: this.query, placeholder: '搜索任务' })
        .layoutWeight(1).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontCompact)
        .backgroundColor(Color.Transparent).fontColor(this.primaryText())
        .placeholderColor(this.tertiaryText())
        .onChange((value: string): void => { this.query = value; })
      if (this.query) {
        Button({ type: ButtonType.Circle }) {
          DSHIcon({ glyph: 'close-outline', glyphSize: NativeDesign.glyphInline, color: this.tertiaryText() })
        }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
          .backgroundColor(Color.Transparent).accessibilityText('清除搜索')
          .onClick((): void => { this.query = ''; })
      }
    }.width('100%').height(NativeDesign.standardRow).padding({ left: 10, right: 2 })
      .borderRadius(NativeDesign.radiusRow).backgroundColor(this.fieldSurface())
      .transition(NativeMotion.rowTransition())
  }

  @Builder
  private filterButton(label: string, value: string) {
    Button(label, { type: ButtonType.Normal }).layoutWeight(1).height(NativeDesign.compactHitTarget)
      .fontSize(NativeDesign.fontCaption).borderRadius(NativeDesign.radiusControl)
      .backgroundColor(this.filter === value ? this.raisedSurface() : Color.Transparent)
      .fontColor(this.filter === value ? this.primaryText() : this.secondaryText())
      .onClick((): void => {
        NativeMotion.animate(this.getUIContext(), 'micro', (): void => { this.filter = value; });
      })
  }

  @Builder
  private filters() {
    Row({ space: 2 }) {
      this.filterButton('运行中', 'active')
      this.filterButton('已暂停', 'paused')
      this.filterButton('已结束', 'ended')
      this.filterButton('全部', 'all')
    }.width('100%').height(NativeDesign.compactRow).padding(3).borderRadius(NativeDesign.radiusRow)
      .backgroundColor(this.fieldSurface())
  }

  @Builder
  private errorNotice() {
    if (this.actionError || this.error) {
      Row({ space: 8 }) {
        DSHIcon({ glyph: 'warning-outline', glyphSize: NativeDesign.glyphControl, color: this.danger() })
        Text(this.actionError || this.error).fontSize(NativeDesign.fontCaption).layoutWeight(1).maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.danger())
        Button(this.conflict ? '刷新' : '重试', { type: ButtonType.Normal }).height(NativeDesign.compactControl)
          .fontSize(NativeDesign.fontCaption).backgroundColor(Color.Transparent).fontColor(this.accent())
          .onClick((): void => {
            if (this.conflict) this.reloadConflict();
            else if (this.page === 'root') this.refresh();
            else if (this.page === 'history') this.loadHistory(false);
            else this.refresh(true);
          })
      }.width('100%').constraintSize({ minHeight: NativeDesign.compactHitTarget })
        .padding({ left: 10, right: 4, top: 3, bottom: 3 })
        .borderRadius(NativeDesign.radiusRow).backgroundColor(NativeDesign.dangerSurface(this.dark))
        .transition(NativeMotion.rowTransition())
    }
  }

  @Builder
  private taskRow(task: NativeAutomationTask) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 10 }) {
        Stack() {
          DSHIcon({
            glyph: task.status === 'active' ? 'plan-outline' :
              task.status === 'paused' ? 'archive-outline' : 'clock-outline',
            glyphSize: NativeDesign.glyphControl,
            color: this.statusColor(task.status)
          })
        }.width(NativeDesign.compactHitTarget).height(NativeDesign.compactHitTarget)
          .borderRadius(NativeDesign.radiusControl).backgroundColor(this.statusSurface(task.status))
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text(task.title).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).layoutWeight(1)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.primaryText())
            if (task.status !== 'active') {
              Text(nativeAutomationStatus(task.status)).fontSize(NativeDesign.fontMicro)
                .fontColor(this.statusColor(task.status)).padding({ left: 5, right: 5, top: 2, bottom: 2 })
                .borderRadius(NativeDesign.radiusBadge).backgroundColor(this.statusSurface(task.status))
            }
          }.width('100%')
          Text(nativeAutomationRule(task)).fontSize(NativeDesign.fontCaption).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.secondaryText())
          Text(task.status === 'active' ?
            '下次 ' + nativeAutomationTimestamp(task.scheduledAt) +
              (task.executionActive ? ' · 执行中' : '') :
            nativeAutomationTarget(task)).fontSize(NativeDesign.fontMicro).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            .fontColor(this.tertiaryText())
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        DSHIcon({ glyph: 'chevron-left-outline', glyphSize: NativeDesign.glyphCompact, color: this.tertiaryText() })
          .rotate({ angle: 180 })
      }.width('100%').constraintSize({ minHeight: NativeDesign.doubleLineRow })
        .padding({ left: NativeDesign.rowInset, right: NativeDesign.rowInset, top: 7, bottom: 7 })
    }.width('100%').borderRadius(NativeDesign.radiusRow).backgroundColor(Color.Transparent)
      .onClick((): void => { this.openDetail(task); })
      .transition(NativeMotion.rowTransition())
  }

  @Builder
  private emptyState() {
    Column({ space: 12 }) {
      DSHIcon({ glyph: 'plan-outline', glyphSize: NativeDesign.glyphEmpty, color: this.tertiaryText() })
      Text(this.query ? '没有匹配的任务' : '还没有自动化任务')
        .fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).fontColor(this.primaryText())
      if (!this.query) {
        Button('创建任务', { type: ButtonType.Normal }).height(NativeDesign.hitTarget)
          .padding({ left: 16, right: 16 }).borderRadius(NativeDesign.radiusControl)
          .backgroundColor(this.accent()).fontColor(NativeDesign.textInverse(this.dark))
          .onClick((): void => { this.openCreate(); })
      }
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }

  @Builder
  private rootPage() {
    Column({ space: 8 }) {
      Row({ space: 4 }) {
        NativeIconButton({
          glyph: 'chevron-left-outline', label: '返回', tone: 'primary',
          glyphSize: NativeDesign.glyphControl, onPressed: (): void => { this.onClose(); }
        })
        Text('自动化任务').fontSize(NativeDesign.fontHeaderTitle).fontWeight(FontWeight.Medium)
          .layoutWeight(1).fontColor(this.primaryText())
        if (this.refreshing) LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline).color(this.accent())
        NativeIconButton({
          glyph: 'plus-outline', label: '创建任务', tone: 'primary', glyphSize: NativeDesign.glyphControl,
          onPressed: (): void => { this.openCreate(); }
        })
      }.width('100%').height(NativeDesign.headerHeight)
      this.searchField()
      this.filters()
      this.errorNotice()
      if (this.loading && !this.catalog.items.length) {
        Column({ space: 10 }) {
          LoadingProgress().width(NativeDesign.spinnerPage).height(NativeDesign.spinnerPage).color(this.accent())
          Text('正在读取任务').fontSize(NativeDesign.fontSection).fontColor(this.secondaryText())
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.filteredItems().length === 0) {
        this.emptyState()
      } else {
        List({ space: 2 }) {
          ForEach(this.filteredItems(), (task: NativeAutomationTask) => {
            ListItem() { this.taskRow(task) }
          }, (task: NativeAutomationTask) => task.id + ':' + task.status + ':' + task.updatedAt)
        }.layoutWeight(1).width('100%').scrollBar(BarState.Auto).cachedCount(12)
      }
    }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset,
      top: this.safeTop + 4, bottom: this.safeBottom + 8 })
      .width('100%').height('100%').backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition(this.navigationDirection))
  }

  @Builder
  private detailRow(title: string, value: string, icon: string = '') {
    Row({ space: 10 }) {
      if (icon) DSHIcon({ glyph: icon, glyphSize: NativeDesign.glyphCompact, color: this.tertiaryText() })
      Text(title).fontSize(NativeDesign.fontCaption).fontColor(this.secondaryText()).width(72)
      Text(value || '—').fontSize(NativeDesign.fontSection).layoutWeight(1).maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.End)
        .fontColor(this.primaryText())
    }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
      .padding({ left: NativeDesign.rowInset, right: NativeDesign.rowInset, top: 5, bottom: 5 })
  }

  @Builder
  private detailPage() {
    Column({ space: 8 }) {
      this.pageHeader(this.selected.title, this.selected.status !== 'ended' ? '编辑' : '',
        (): void => { this.openEditor(); })
      this.errorNotice()
      Scroll() {
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Stack() {
              DSHIcon({
                glyph: this.selected.status === 'active' ? 'plan-outline' : 'archive-outline',
                glyphSize: NativeDesign.glyphHero, color: this.statusColor(this.selected.status)
              })
            }.width(NativeDesign.standardRow).height(NativeDesign.standardRow)
              .borderRadius(NativeDesign.radiusGroup).backgroundColor(this.statusSurface(this.selected.status))
            Column({ space: 3 }) {
              Text(this.selected.title).fontSize(NativeDesign.fontHeaderTitle).fontWeight(FontWeight.Medium).maxLines(2)
                .fontColor(this.primaryText())
              Text(nativeAutomationStatus(this.selected.status) + ' · ' +
                nativeAutomationKind(this.selected.kind)).fontSize(NativeDesign.fontCaption).fontColor(this.secondaryText())
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%').padding({ top: 4, bottom: 4 })
          Row({ space: 8 }) {
            Button(this.actionBusy === 'active' ? '处理中…' :
              this.selected.status === 'active' ? '暂停' : '启用', { type: ButtonType.Normal })
              .layoutWeight(1).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection)
              .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
              .fontColor(this.primaryText()).enabled(!this.actionBusy && this.selected.status !== 'ended')
              .onClick((): void => { this.toggleActive(); })
            Button(this.actionBusy === 'run' ? '正在运行…' : '立即运行', { type: ButtonType.Normal })
              .layoutWeight(1).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection)
              .borderRadius(NativeDesign.radiusControl).backgroundColor(this.accent())
              .fontColor(NativeDesign.textInverse(this.dark))
              .enabled(!this.actionBusy && !this.selected.executionActive &&
                this.selected.status !== 'ended')
              .onClick((): void => { this.runNow(); })
          }.width('100%')
          Column() {
            this.detailRow('规则', nativeAutomationRule(this.selected))
            Divider().strokeWidth(0.5).color(this.dividerColor())
            this.detailRow('下次', nativeAutomationTimestamp(this.selected.scheduledAt))
            Divider().strokeWidth(0.5).color(this.dividerColor())
            this.detailRow('目标', nativeAutomationTarget(this.selected))
            if (this.selected.timeZone) {
              Divider().strokeWidth(0.5).color(this.dividerColor())
              this.detailRow('时区', this.selected.timeZone)
            }
            if (this.selected.lastDeliveryAt) {
              Divider().strokeWidth(0.5).color(this.dividerColor())
              this.detailRow('上次投递', nativeAutomationTimestamp(this.selected.lastDeliveryAt))
            }
          }.width('100%').borderRadius(NativeDesign.radiusGroup)
            .border({ width: 0.5, color: this.lineColor() })
          Text('任务指令').fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium).fontColor(this.secondaryText())
            .width('100%').padding({ left: 4 })
          Text(this.selected.prompt).fontSize(NativeDesign.fontCompact).lineHeight(20).width('100%')
            .fontColor(this.primaryText()).padding(12).borderRadius(NativeDesign.radiusRow)
            .backgroundColor(this.fieldSurface())
          Button({ type: ButtonType.Normal }) {
            Row({ space: 10 }) {
              DSHIcon({ glyph: 'archive-outline', glyphSize: NativeDesign.glyphControl, color: this.secondaryText() })
              Column({ space: 2 }) {
                Text('投递记录').fontSize(NativeDesign.fontCompact).fontWeight(FontWeight.Medium).fontColor(this.primaryText())
                Text(this.selected.lastDeliveryAt ?
                  '上次 ' + nativeAutomationTimestamp(this.selected.lastDeliveryAt) : '暂无投递记录')
                  .fontSize(NativeDesign.fontMicro).fontColor(this.tertiaryText())
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              DSHIcon({ glyph: 'chevron-left-outline', glyphSize: NativeDesign.glyphCompact, color: this.tertiaryText() })
                .rotate({ angle: 180 })
            }.width('100%').padding({ left: 12, right: 12 })
          }.width('100%').height(NativeDesign.doubleLineRow).borderRadius(NativeDesign.radiusRow)
            .backgroundColor(this.fieldSurface()).onClick((): void => { this.openHistory(); })
          Button('删除任务', { type: ButtonType.Normal }).width('100%')
            .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection).borderRadius(NativeDesign.radiusControl)
            .backgroundColor(NativeDesign.dangerSurface(this.dark)).fontColor(this.danger())
            .enabled(!this.actionBusy).onClick((): void => { this.confirmDelete(); })
        }.width('100%').padding({ bottom: 16 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.Top).scrollBar(BarState.Auto)
    }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset,
      top: this.safeTop + 4, bottom: this.safeBottom + 8 })
      .width('100%').height('100%').backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition(this.navigationDirection))
  }

  @Builder
  private fieldLabel(value: string) {
    Text(value).fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium).width('100%')
      .fontColor(this.secondaryText()).padding({ left: 4 })
  }

  @Builder
  private choiceChip(label: string, value: string, current: string, action: (value: string) => void) {
    Button(label, { type: ButtonType.Normal }).height(NativeDesign.compactChip).padding({ left: 9, right: 9 })
      .fontSize(NativeDesign.fontCaption).borderRadius(NativeDesign.radiusControl)
      .backgroundColor(current === value ? NativeDesign.accentSurface(this.dark) : this.fieldSurface())
      .fontColor(current === value ? this.accent() : this.secondaryText())
      .margin({ right: 6, bottom: 6 })
      .clip(true)
      .onClick((): void => { action(value); })
  }

  @Builder
  private timingFields() {
    if (this.formKind === 'after' || this.formKind === 'every') {
      TextInput({ text: this.formInterval, placeholder: '间隔分钟' })
        .width('100%').height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact).type(InputType.Number)
        .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
        .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
        .onChange((value: string): void => { this.formInterval = value; })
    } else if (this.formKind === 'daily' || this.formKind === 'weekly') {
      TextInput({ text: this.formTime, placeholder: '09:00' })
        .width('100%').height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact)
        .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
        .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
        .onChange((value: string): void => { this.formTime = value; })
      if (this.formKind === 'weekly') {
        Row({ space: 4 }) {
          ForEach([1, 2, 3, 4, 5, 6, 7], (day: number) => {
            Button(['一', '二', '三', '四', '五', '六', '日'][day - 1], { type: ButtonType.Normal })
              .layoutWeight(1).height(NativeDesign.compactHitTarget)
              .fontSize(NativeDesign.fontCaption).borderRadius(NativeDesign.radiusCompact)
              .backgroundColor(this.formWeekdays.includes(day) ?
                NativeDesign.accentSurface(this.dark) : this.fieldSurface())
              .fontColor(this.formWeekdays.includes(day) ? this.accent() : this.secondaryText())
              .onClick((): void => { this.toggleWeekday(day); })
          }, (day: number) => day.toString())
        }.width('100%')
      }
    } else if (this.formKind === 'cron') {
      TextInput({ text: this.formExpression, placeholder: '0 9 * * *' })
        .width('100%').height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact)
        .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
        .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
        .onChange((value: string): void => { this.formExpression = value; })
    } else if (this.formKind === 'at') {
      Row({ space: 8 }) {
        TextInput({ text: this.formAtDate, placeholder: 'YYYY-MM-DD' })
          .layoutWeight(1).height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact)
          .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
          .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
          .onChange((value: string): void => { this.formAtDate = value; })
        TextInput({ text: this.formAtTime, placeholder: '09:00' })
          .width(92).height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact)
          .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
          .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
          .onChange((value: string): void => { this.formAtTime = value; })
      }.width('100%')
    } else if (this.formKind === 'rrule') {
      TextArea({ text: this.formRRule, placeholder: 'RRULE' }).width('100%').height(88).fontSize(NativeDesign.fontSection)
        .padding(10).borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
        .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
        .onChange((value: string): void => { this.formRRule = value; })
    }
    if (this.formKind !== 'rrule') {
      TextInput({ text: this.formTimeZone, placeholder: 'Asia/Shanghai' })
        .width('100%').height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact)
        .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
        .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
        .onChange((value: string): void => { this.formTimeZone = value; })
    }
  }

  @Builder
  private editorPage() {
    Column({ space: 10 }) {
      this.pageHeader(this.editing ? '编辑任务' : '新建任务',
        this.saving ? '保存中…' : '保存', (): void => { this.save(); })
      this.errorNotice()
      Scroll() {
        Column({ space: 8 }) {
          this.fieldLabel('名称')
          TextInput({ text: this.formTitle, placeholder: '任务名称' })
            .width('100%').height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact)
            .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
            .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
            .onChange((value: string): void => { this.formTitle = value; })
          this.fieldLabel('指令')
          TextArea({ text: this.formPrompt, placeholder: '发送给智能体的任务指令' })
            .width('100%').height(120).fontSize(NativeDesign.fontCompact).padding(10)
            .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
            .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
            .onChange((value: string): void => { this.formPrompt = value; })
          this.fieldLabel('时间')
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            this.choiceChip('稍后一次', 'after', this.formKind,
              (value: string): void => { this.formKind = value; })
            this.choiceChip('固定间隔', 'every', this.formKind,
              (value: string): void => { this.formKind = value; })
            this.choiceChip('每天', 'daily', this.formKind,
              (value: string): void => { this.formKind = value; })
            this.choiceChip('每周', 'weekly', this.formKind,
              (value: string): void => { this.formKind = value; })
            this.choiceChip('Cron', 'cron', this.formKind,
              (value: string): void => { this.formKind = value; })
            this.choiceChip('指定时间', 'at', this.formKind,
              (value: string): void => { this.formKind = value; })
            this.choiceChip('RRULE', 'rrule', this.formKind,
              (value: string): void => { this.formKind = value; })
          }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
          this.timingFields()
          this.fieldLabel('目标')
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            this.choiceChip('新会话', 'new', this.formTargetKind,
              (value: string): void => { this.formTargetKind = value; })
            this.choiceChip('创建后复用', 'new_once', this.formTargetKind,
              (value: string): void => { this.formTargetKind = value; })
            this.choiceChip('已有会话', 'session', this.formTargetKind,
              (value: string): void => { this.formTargetKind = value; })
          }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
          if (this.formTargetKind === 'session') {
            TextInput({ text: this.formSessionId, placeholder: '会话 ID' })
              .width('100%').height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact)
              .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
              .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
              .onChange((value: string): void => { this.formSessionId = value; })
          } else {
            TextInput({ text: this.formCwd, placeholder: '工作目录 · 默认' })
              .width('100%').height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact)
              .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
              .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
              .onChange((value: string): void => { this.formCwd = value; })
            TextInput({ text: this.formPreset, placeholder: '智能体预设 · 默认' })
              .width('100%').height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact)
              .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
              .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
              .onChange((value: string): void => { this.formPreset = value; })
          }
          Button(this.saving ? '保存中…' : '保存任务', { type: ButtonType.Normal }).width('100%')
            .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontCompact).borderRadius(NativeDesign.radiusControl)
            .backgroundColor(this.accent()).fontColor(NativeDesign.textInverse(this.dark))
            .enabled(!this.saving && this.formValid() && !this.conflict)
            .onClick((): void => { this.save(); })
        }.width('100%').padding({ bottom: 20 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.Top).scrollBar(BarState.Auto)
    }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset,
      top: this.safeTop + 4, bottom: this.safeBottom + 8 })
      .width('100%').height('100%').backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition(this.navigationDirection))
  }

  @Builder
  private historyRecord(recordIndex: number) {
    Column({ space: 4 }) {
      Row() {
        Text('投递 ' + (recordIndex + 1).toString()).fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
        Blank()
        Text(nativeAutomationTimestamp(this.history.records[recordIndex].deliveredAt))
          .fontSize(NativeDesign.fontMicro).fontColor(this.tertiaryText())
      }.width('100%')
      Text(this.history.records[recordIndex].prompt || '已投递任务指令').fontSize(NativeDesign.fontCaption).maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').fontColor(this.secondaryText())
      if (this.history.records[recordIndex].targetSessionId) {
        Text(this.history.records[recordIndex].targetSessionId).fontSize(NativeDesign.fontMicro).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').fontColor(this.tertiaryText())
      }
    }.width('100%').padding(10).borderRadius(NativeDesign.radiusRow)
      .backgroundColor(this.fieldSurface())
  }

  @Builder
  private historyPage() {
    Column({ space: 8 }) {
      this.pageHeader('投递记录')
      this.errorNotice()
      if (this.historyLoading && !this.history.records.length) {
        Column({ space: 10 }) {
          LoadingProgress().width(NativeDesign.spinnerPage).height(NativeDesign.spinnerPage).color(this.accent())
          Text('正在读取记录').fontSize(NativeDesign.fontSection).fontColor(this.secondaryText())
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (!this.history.records.length) {
        Column({ space: 10 }) {
          DSHIcon({ glyph: 'archive-outline', glyphSize: NativeDesign.glyphHero, color: this.tertiaryText() })
          Text(this.history.code ? '此任务的记录不可用' : '暂无投递记录')
            .fontSize(NativeDesign.fontCompact).fontColor(this.secondaryText())
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 4 }) {
          ForEach(this.history.records, (record: NativeAutomationDelivery, index: number) => {
            ListItem() { this.historyRecord(index) }
          }, (record: NativeAutomationDelivery, index: number) =>
            record.messageId + ':' + record.deliveredAt + ':' + index.toString())
          if (this.history.nextBefore) {
            ListItem() {
              Button(this.historyLoading ? '读取中…' : '加载更早记录', { type: ButtonType.Normal })
                .width('100%').height(NativeDesign.hitTarget).fontSize(NativeDesign.fontCaption)
                .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
                .fontColor(this.primaryText()).enabled(!this.historyLoading)
                .onClick((): void => { this.loadHistory(true); })
            }
          }
        }.layoutWeight(1).width('100%').scrollBar(BarState.Auto)
      }
    }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset,
      top: this.safeTop + 4, bottom: this.safeBottom + 8 })
      .width('100%').height('100%').backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition(this.navigationDirection))
  }

  build() {
    Stack() {
      if (this.page === 'detail') this.detailPage()
      else if (this.page === 'editor') this.editorPage()
      else if (this.page === 'history') this.historyPage()
      else this.rootPage()
    }.width('100%').height('100%').backgroundColor(this.baseSurface())
  }
}
