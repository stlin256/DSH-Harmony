import { NativeHarnessClient, NativeHttpError } from '../services/NativeHarnessClient';
import { NativeAdminClient } from '../services/NativeAdminClient';
import {
  NativePluginBundle,
  NativePluginChange,
  NativePluginEntry,
  NativePluginInspection,
  NativePluginInventory,
  NativePluginRow,
  NativePluginVersion,
  NativePluginVersionList,
  nativePluginApplication,
  nativePluginDescription,
  nativePluginErrorText,
  nativePluginPhase,
  nativePluginTitle
} from '../services/NativeAdminModels';
import { NativeDesign } from '../services/NativeDesign';
import { NativeMotion } from '../services/NativeMotion';
import { DSHIcon } from './DSHIcon';
import { NativeIconButton } from './NativeIconButton';

@Component
export struct NativePluginsSurface {
  client: NativeHarnessClient = new NativeHarnessClient('');
  onClose: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @StorageLink('nativeAdminBackRevision') @Watch('backRequested') private adminBackRevision: number = 0;
  @State private page: string = 'root';
  @State private navigationDirection: number = 1;
  @State private inventory: NativePluginInventory = new NativePluginInventory();
  @State private selected: NativePluginBundle = new NativePluginBundle();
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private error: string = '';
  @State private query: string = '';
  @State private busy: string[] = [];
  @State private notice: NativePluginChange = new NativePluginChange();
  @State private noticeVisible: boolean = false;
  @State private actionError: string = '';
  @State private installSpec: string = '';
  @State private inspection: NativePluginInspection | null = null;
  @State private inspecting: boolean = false;
  @State private installing: boolean = false;
  @State private versions: NativePluginVersionList | null = null;
  @State private checkingVersion: boolean = false;
  private admin: NativeAdminClient = new NativeAdminClient(this.client);
  private mounted: boolean = false;
  private showcaseOpened: boolean = false;

  private baseSurface(): string { return NativeDesign.base(this.dark); }
  private raisedSurface(): string { return NativeDesign.raised(this.dark); }
  private fieldSurface(): string { return NativeDesign.field(this.dark); }
  private selectedSurface(): string { return NativeDesign.selectedSurface(this.dark); }
  private lineColor(): string { return NativeDesign.border(this.dark); }
  private dividerColor(): string { return NativeDesign.divider(this.dark); }
  private primaryText(): string { return NativeDesign.textPrimary(this.dark); }
  private secondaryText(): string { return NativeDesign.textSecondary(this.dark); }
  private tertiaryText(): string { return NativeDesign.textTertiary(this.dark); }
  private accent(): string { return NativeDesign.accent(this.dark); }
  private danger(): string { return NativeDesign.danger(this.dark); }

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

  private filteredBundles(): NativePluginBundle[] {
    const search = this.query.trim().toLowerCase();
    return this.inventory.bundles.filter((bundle: NativePluginBundle): boolean => {
      if (!search) return true;
      const rows = bundle.rows.map((row) => row.title + ' ' + row.rowId + ' ' + row.moduleName).join(' ');
      return (nativePluginTitle(bundle) + ' ' + bundle.name + ' ' +
        nativePluginDescription(bundle) + ' ' + rows).toLowerCase().includes(search);
    });
  }

  private filteredEntries(): NativePluginEntry[] {
    return this.inventory.plugins;
  }

  private installedBundles(): NativePluginBundle[] {
    return this.filteredBundles().filter((bundle: NativePluginBundle): boolean => bundle.installed);
  }

  private availableBundles(): NativePluginBundle[] {
    return this.filteredBundles().filter((bundle: NativePluginBundle): boolean => !bundle.installed);
  }

  private statusFor(bundle: NativePluginBundle): string {
    if (bundle.errorCode) return nativePluginErrorText(bundle.errorCode);
    if (!bundle.installed) return '可安装';
    return bundle.enabled ? '已启用' : '已关闭';
  }

  private entryFor(rowId: string): NativePluginEntry | null {
    return this.inventory.plugins.find((entry: NativePluginEntry): boolean =>
      entry.entryId === rowId) || null;
  }

  private isBusy(key: string): boolean { return this.busy.includes(key); }

  private openShowcaseState(): void {
    if (this.showcaseOpened || AppStorage.get<boolean>('storeShowcase') !== true) return;
    this.showcaseOpened = true;
    const state = AppStorage.get<string>('storeShowcaseState') || '';
    if (state !== 'plugins-detail' && state !== 'plugins-restart' &&
      state !== 'plugins-install-failed') return;
    setTimeout((): void => {
      if (!this.mounted) return;
      if (state === 'plugins-install-failed') {
        this.openInstall();
        this.installSpec = 'dsh-plugin-with-missing-build';
        this.actionError = '无法读取插件包';
        return;
      }
      const installed = this.inventory.bundles.find((bundle: NativePluginBundle): boolean =>
        bundle.installed) || this.inventory.bundles[0];
      if (installed) this.openDetail(installed);
      if (state === 'plugins-restart') {
        this.notice = new NativePluginChange();
        this.notice.application = 'restart-required';
        this.notice.restartReason = 'plugin';
        this.noticeVisible = true;
      }
    }, 320);
  }

  private async refresh(silent: boolean = false): Promise<void> {
    if (!silent) this.loading = true;
    this.refreshing = true;
    this.error = '';
    try {
      const value = await this.admin.plugins();
      if (!this.mounted) return;
      this.inventory = value;
      if (this.selected.name) {
        const selected = value.bundles.find((bundle: NativePluginBundle): boolean =>
          bundle.name === this.selected.name);
        if (selected) this.selected = selected;
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

  private errorText(error: Error): string {
    if (error instanceof NativeHttpError) {
      return nativePluginErrorText(error.code) + (error.status === 401 ? ' · 请重新登录' : '');
    }
    return error.message || '插件服务暂不可用';
  }

  private setPage(next: string, direction: number): void {
    this.navigationDirection = direction;
    NativeMotion.animate(this.getUIContext(), 'navigation', (): void => {
      this.page = next;
    });
  }

  private openDetail(bundle: NativePluginBundle): void {
    this.selected = bundle;
    this.actionError = '';
    this.noticeVisible = false;
    this.versions = null;
    this.setPage('detail', 1);
  }

  private openInstall(spec: string = ''): void {
    this.installSpec = spec;
    this.inspection = null;
    this.actionError = '';
    this.setPage('install', 1);
  }

  private back(): void {
    if (this.page === 'root') {
      this.onClose();
      return;
    }
    this.setPage('root', -1);
  }

  private applyChange(value: NativePluginChange, key: string): void {
    this.notice = value;
    this.noticeVisible = true;
    if (value.application === 'failed' || value.application === 'cancelled') {
      this.actionError = nativePluginErrorText(value.errorCode || value.application) +
        (value.errorDiagnostic ? ' · ' + value.errorDiagnostic : '');
    } else {
      this.actionError = '';
    }
    if (!this.mounted) return;
    this.busy = this.busy.filter((item: string): boolean => item !== key);
  }

  private async toggleBundle(bundle: NativePluginBundle): Promise<void> {
    const key = 'bundle:' + bundle.name;
    if (this.isBusy(key) || !!bundle.readOnlyReason) return;
    this.busy = this.busy.concat([key]);
    this.actionError = '';
    try {
      const value = await this.admin.setBundleEnabled(bundle.name, !bundle.enabled);
      if (!this.mounted) return;
      this.applyChange(value, key);
      await this.refresh(true);
    } catch (error) {
      if (this.mounted) {
        this.busy = this.busy.filter((item: string): boolean => item !== key);
        this.actionError = this.errorText(error as Error);
      }
    }
  }

  private async toggleRow(bundle: NativePluginBundle, entryId: string, enabled: boolean): Promise<void> {
    const key = 'row:' + entryId;
    if (this.isBusy(key) || !entryId) return;
    this.busy = this.busy.concat([key]);
    this.actionError = '';
    try {
      const value = await this.admin.setRowEnabled(entryId, enabled);
      if (!this.mounted) return;
      this.applyChange(value, key);
      await this.refresh(true);
    } catch (error) {
      if (this.mounted) {
        this.busy = this.busy.filter((item: string): boolean => item !== key);
        this.actionError = this.errorText(error as Error);
      }
    }
  }

  private async inspectInstall(): Promise<void> {
    if (!this.installSpec.trim() || this.inspecting || this.installing) return;
    this.inspecting = true;
    this.actionError = '';
    this.inspection = null;
    try {
      const value = await this.admin.inspect(this.installSpec.trim());
      if (!this.mounted) return;
      this.inspection = value;
      if (value.status === 'refused') {
        this.actionError = nativePluginErrorText(value.problem) +
          (value.reason ? ' · ' + value.reason : '');
      }
    } catch (error) {
      if (this.mounted) this.actionError = this.errorText(error as Error);
    } finally {
      if (this.mounted) this.inspecting = false;
    }
  }

  private async install(approvedBuilds: string[] = []): Promise<void> {
    if (this.installing || !this.installSpec.trim()) return;
    this.installing = true;
    this.actionError = '';
    try {
      const value = await this.admin.install(this.installSpec.trim(), approvedBuilds);
      if (!this.mounted) return;
      this.notice = value;
      this.noticeVisible = true;
      if (value.application === 'failed' || value.application === 'cancelled') {
        this.actionError = nativePluginErrorText(value.errorCode || value.application);
      } else {
        this.setPage('root', -1);
        await this.refresh(true);
      }
    } catch (error) {
      if (this.mounted) this.actionError = this.errorText(error as Error);
    } finally {
      if (this.mounted) this.installing = false;
    }
  }

  private confirmRemove(): void {
    if (!this.selected.name || this.isBusy('remove:' + this.selected.name)) return;
    this.getUIContext().showAlertDialog({
      title: '移除插件',
      message: '将移除 ' + nativePluginTitle(this.selected) + '。已保存的会话不会被删除。',
      autoCancel: true,
      primaryButton: { value: '取消', action: (): void => {} },
      secondaryButton: {
        value: '移除',
        fontColor: this.danger(),
        action: (): void => { this.removeSelected(); }
      }
    });
  }

  private async removeSelected(): Promise<void> {
    const key = 'remove:' + this.selected.name;
    if (this.isBusy(key)) return;
    this.busy = this.busy.concat([key]);
    try {
      const value = await this.admin.remove(this.selected.name);
      if (!this.mounted) return;
      this.applyChange(value, key);
      if (value.application !== 'failed' && value.application !== 'cancelled') {
        this.setPage('root', -1);
        await this.refresh(true);
      }
    } catch (error) {
      if (this.mounted) {
        this.busy = this.busy.filter((item: string): boolean => item !== key);
        this.actionError = this.errorText(error as Error);
      }
    }
  }

  private async checkVersions(): Promise<void> {
    if (this.checkingVersion || !this.selected.updatable) return;
    this.checkingVersion = true;
    this.actionError = '';
    try {
      const value = await this.admin.versions(this.selected.name);
      if (this.mounted) this.versions = value;
    } catch (error) {
      if (this.mounted) this.actionError = this.errorText(error as Error);
    } finally {
      if (this.mounted) this.checkingVersion = false;
    }
  }

  private updateCandidate(): string {
    if (!this.versions || this.versions.status !== 'listed') return '';
    const row = this.versions.versions.find((version: NativePluginVersion) => version.bundle && !version.prerelease &&
      !version.deprecated && !version.incompatibleCode);
    return row ? row.version : '';
  }

  private async updateSelected(version: string): Promise<void> {
    const key = 'update:' + this.selected.name;
    if (!version || this.isBusy(key)) return;
    this.busy = this.busy.concat([key]);
    try {
      const value = await this.admin.update(this.selected.name, version);
      if (!this.mounted) return;
      this.applyChange(value, key);
      await this.refresh(true);
    } catch (error) {
      if (this.mounted) {
        this.busy = this.busy.filter((item: string): boolean => item !== key);
        this.actionError = this.errorText(error as Error);
      }
    }
  }

  @Builder
  private pageHeader(title: string, actionLabel: string = '', action: () => void = (): void => {}) {
    Row({ space: 4 }) {
      NativeIconButton({ glyph: 'chevron-left-outline', label: '返回', tone: 'primary',
        glyphSize: NativeDesign.glyphControl, onPressed: (): void => { this.back(); } })
      Text(title).fontSize(NativeDesign.fontHeaderTitle).fontWeight(FontWeight.Medium).layoutWeight(1).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.primaryText())
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
      TextInput({ text: this.query, placeholder: '搜索插件或组件' })
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
  private sectionLabel(title: string, count: number) {
    Row() {
      Text(title).fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium).fontColor(this.secondaryText())
      Blank()
      Text(count.toString()).fontSize(NativeDesign.fontCaption).fontColor(this.tertiaryText())
    }.width('100%').height(NativeDesign.compactControl).padding({ left: 4, right: 4 })
  }

  @Builder
  private bundleRow(bundle: NativePluginBundle) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 10 }) {
        Stack() {
          DSHIcon({ glyph: bundle.official ? 'deepseek-logo' : 'code-outline',
            glyphSize: NativeDesign.glyphControlEmphasis, color: bundle.enabled ? this.accent() : this.secondaryText() })
        }.width(NativeDesign.compactHitTarget).height(NativeDesign.compactHitTarget)
          .borderRadius(NativeDesign.radiusControl)
          .backgroundColor(bundle.enabled ? NativeDesign.accentSurface(this.dark) : this.fieldSurface())
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(nativePluginTitle(bundle)).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1).fontColor(this.primaryText())
            if (bundle.optional) this.chip('可选')
            if (bundle.official) this.chip('官方')
          }.width('100%')
          Text(nativePluginDescription(bundle) || bundle.name).fontSize(NativeDesign.fontCaption)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').fontColor(this.secondaryText())
          Text(this.statusFor(bundle) + (bundle.version ? ' · v' + bundle.version : ''))
            .fontSize(NativeDesign.fontMicro).maxLines(1).fontColor(bundle.errorCode ? this.danger() : this.tertiaryText())
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (bundle.installed && !bundle.readOnlyReason) {
          Toggle({ type: ToggleType.Switch, isOn: bundle.enabled })
            .enabled(!this.isBusy('bundle:' + bundle.name))
            .selectedColor(this.accent())
            .onChange((isOn: boolean): void => { this.toggleBundle(bundle); })
        } else if (!bundle.installed && bundle.installSpec) {
          Button('添加', { type: ButtonType.Normal }).height(NativeDesign.compactControl)
            .fontSize(NativeDesign.fontCaption).padding({ left: 10, right: 10 })
            .borderRadius(NativeDesign.radiusCompact)
            .backgroundColor(this.selectedSurface()).fontColor(this.accent())
            .onClick((): void => {
              this.openInstall(bundle.installSpec);
            })
        } else {
          DSHIcon({ glyph: 'chevron-left-outline', glyphSize: NativeDesign.glyphCompact, color: this.tertiaryText() })
            .rotate({ angle: 180 })
        }
      }.width('100%').constraintSize({ minHeight: NativeDesign.doubleLineRow })
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    }.width('100%').borderRadius(NativeDesign.radiusRow).backgroundColor(Color.Transparent)
      .onClick((): void => { this.openDetail(bundle); })
      .transition(NativeMotion.rowTransition())
  }

  @Builder
  private chip(value: string) {
    Text(value).fontSize(NativeDesign.fontMicro).fontColor(this.accent()).padding({ left: 5, right: 5, top: 2, bottom: 2 })
      .borderRadius(NativeDesign.radiusBadge).backgroundColor(NativeDesign.accentSurface(this.dark))
  }

  @Builder
  private resultNotice() {
    if (this.noticeVisible && this.notice.application) {
      Row({ space: 8 }) {
        DSHIcon({
          glyph: this.notice.application === 'failed' ? 'warning-outline' :
            this.notice.application === 'restart-required' ? 'refresh-outline' : 'check-outline',
          glyphSize: NativeDesign.glyphControl,
          color: this.notice.application === 'failed' ? this.danger() :
            this.notice.application === 'restart-required' ? NativeDesign.warning(this.dark) : this.accent()
        })
        Column({ space: 2 }) {
          Text(nativePluginApplication(this.notice.application)).fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText())
          if (this.notice.restartReason) {
            Text('DSH 重启后生效').fontSize(NativeDesign.fontMicro).fontColor(this.secondaryText())
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        NativeIconButton({ glyph: 'close-outline', label: '关闭状态', glyphSize: NativeDesign.glyphInline,
          onPressed: (): void => { this.noticeVisible = false; } })
      }.width('100%').padding({ left: 10, right: 4, top: 8, bottom: 8 })
        .borderRadius(NativeDesign.radiusRow).backgroundColor(this.fieldSurface())
        .border({ width: 0.5, color: this.lineColor() })
        .transition(NativeMotion.rowTransition())
    }
  }

  @Builder
  private errorNotice() {
    if (this.actionError || this.error) {
      Row({ space: 8 }) {
        DSHIcon({ glyph: 'warning-outline', glyphSize: NativeDesign.glyphControl, color: this.danger() })
        Text(this.actionError || this.error).fontSize(NativeDesign.fontCaption).layoutWeight(1).maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.danger())
        Button('重试', { type: ButtonType.Normal }).height(NativeDesign.compactControl)
          .fontSize(NativeDesign.fontCaption).backgroundColor(Color.Transparent).fontColor(this.accent())
          .onClick((): void => {
            if (this.page === 'root') this.refresh();
            else if (this.page === 'install') this.inspectInstall();
            else this.refresh(true);
          })
      }.width('100%').constraintSize({ minHeight: NativeDesign.compactHitTarget })
        .padding({ left: 10, right: 4, top: 3, bottom: 3 })
        .borderRadius(NativeDesign.radiusRow).backgroundColor(NativeDesign.dangerSurface(this.dark))
        .transition(NativeMotion.rowTransition())
    }
  }

  @Builder
  private rootPage() {
    Column({ space: 8 }) {
      this.pageHeader('插件', '添加', (): void => { this.openInstall(); })
      this.searchField()
      this.resultNotice()
      this.errorNotice()
      if (this.loading && !this.inventory.bundles.length) {
        Column({ space: 10 }) {
          LoadingProgress().width(NativeDesign.spinnerPage).height(NativeDesign.spinnerPage).color(this.accent())
          Text('正在读取插件').fontSize(NativeDesign.fontSection).fontColor(this.secondaryText())
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (!this.loading && !this.inventory.bundles.length) {
        Column({ space: 12 }) {
          DSHIcon({ glyph: 'code-outline', glyphSize: NativeDesign.glyphHero, color: this.tertiaryText() })
          Text('还没有可显示的插件').fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).fontColor(this.primaryText())
          Button('安装插件', { type: ButtonType.Normal }).height(NativeDesign.hitTarget)
            .padding({ left: 16, right: 16 }).borderRadius(NativeDesign.radiusControl)
            .backgroundColor(this.accent()).fontColor(NativeDesign.textInverse(this.dark))
            .onClick((): void => { this.openInstall(); })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 2 }) {
          if (this.installedBundles().length) {
            ListItem() { this.sectionLabel('已安装', this.installedBundles().length) }
            ForEach(this.installedBundles(), (bundle: NativePluginBundle) => {
              ListItem() { this.bundleRow(bundle) }
            }, (bundle: NativePluginBundle) => 'installed:' + bundle.name)
          }
          if (this.availableBundles().length) {
            ListItem() { this.sectionLabel('可添加', this.availableBundles().length) }
            ForEach(this.availableBundles(), (bundle: NativePluginBundle) => {
              ListItem() { this.bundleRow(bundle) }
            }, (bundle: NativePluginBundle) => 'available:' + bundle.name)
          }
          if (this.filteredEntries().length) {
            ListItem() { this.sectionLabel('运行组件', this.filteredEntries().length) }
            ForEach(this.filteredEntries(), (entry: NativePluginEntry) => {
              ListItem() {
                Row({ space: 9 }) {
                  Stack() {
                    DSHIcon({ glyph: entry.phase === 'failed' ? 'warning-outline' : 'api-outline',
                      glyphSize: NativeDesign.glyphControl, color: entry.phase === 'failed' ? this.danger() :
                        entry.phase === 'active' ? this.accent() : this.tertiaryText() })
                  }.width(NativeDesign.compactControl).height(NativeDesign.compactControl)
                    .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
                  Column({ space: 2 }) {
                    Text(entry.title || entry.moduleName).fontSize(NativeDesign.fontCompact).maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                      .fontColor(this.primaryText())
                    Text(nativePluginPhase(entry.phase) + ' · ' + entry.entryId).fontSize(NativeDesign.fontMicro)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%').fontColor(this.tertiaryText())
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                }.width('100%').height(NativeDesign.compactRow).padding({ left: 10, right: 10 })
              }
            }, (entry: NativePluginEntry) => entry.entryId)
          }
        }.layoutWeight(1).width('100%').scrollBar(BarState.Auto).cachedCount(10)
      }
    }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset,
      top: this.safeTop + 4, bottom: this.safeBottom + 8 })
      .width('100%').height('100%').backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition(this.navigationDirection))
  }

  @Builder
  private detailRow(title: string, value: string, danger: boolean = false) {
    Row({ space: 12 }) {
      Text(title).fontSize(NativeDesign.fontSection).fontColor(this.secondaryText()).width(82)
      Text(value || '—').fontSize(NativeDesign.fontSection).layoutWeight(1).maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(danger ? this.danger() : this.primaryText())
    }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
  }

  @Builder
  private pluginRow(bundle: NativePluginBundle, row: NativePluginRow) {
    Row({ space: 9 }) {
      Stack() {
        DSHIcon({ glyph: 'api-outline', glyphSize: NativeDesign.glyphControl,
          color: row.entryId ? this.accent() : this.tertiaryText() })
      }.width(NativeDesign.compactControl).height(NativeDesign.compactControl)
        .borderRadius(NativeDesign.radiusCompact).backgroundColor(this.fieldSurface())
      Column({ space: 2 }) {
        Text(row.title || row.rowId).fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          .fontColor(this.primaryText())
        Text(row.description || row.moduleName).fontSize(NativeDesign.fontMicro).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          .fontColor(this.tertiaryText())
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (row.entryId) {
        Toggle({ type: ToggleType.Switch,
          isOn: this.entryFor(row.entryId)?.enabled === true })
          .enabled(!this.isBusy('row:' + row.entryId))
          .selectedColor(this.accent())
          .onChange((isOn: boolean): void => { this.toggleRow(bundle, row.entryId, isOn); })
      } else {
        Text('不可切换').fontSize(NativeDesign.fontMicro).fontColor(this.tertiaryText())
      }
    }.width('100%').height(NativeDesign.compactRow).padding({ left: 8, right: 8 })
      .borderRadius(NativeDesign.radiusControl)
  }

  @Builder
  private detailPage() {
    Column({ space: 8 }) {
      this.pageHeader(nativePluginTitle(this.selected),
        this.selected.updatable ? (this.checkingVersion ? '检查中…' : '检查更新') : '',
        (): void => { this.checkVersions(); })
      this.resultNotice()
      this.errorNotice()
      Scroll() {
        Column({ space: 10 }) {
          Row({ space: 12 }) {
            Stack() {
              DSHIcon({ glyph: this.selected.official ? 'deepseek-logo' : 'code-outline',
                glyphSize: NativeDesign.glyphHero, color: this.accent() })
            }.width(NativeDesign.standardRow).height(NativeDesign.standardRow)
              .borderRadius(NativeDesign.radiusGroup).backgroundColor(NativeDesign.accentSurface(this.dark))
            Column({ space: 4 }) {
              Text(nativePluginTitle(this.selected)).fontSize(NativeDesign.fontHeaderTitle).fontWeight(FontWeight.Medium)
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.primaryText())
              Text((this.selected.version ? 'v' + this.selected.version + ' · ' : '') +
                this.statusFor(this.selected)).fontSize(NativeDesign.fontCaption).fontColor(this.secondaryText())
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            if (this.selected.installed && !this.selected.readOnlyReason) {
              Toggle({ type: ToggleType.Switch, isOn: this.selected.enabled })
                .selectedColor(this.accent())
                .enabled(!this.isBusy('bundle:' + this.selected.name))
                .onChange((): void => { this.toggleBundle(this.selected); })
            }
          }.width('100%').padding({ top: 4, bottom: 4 })
          if (nativePluginDescription(this.selected)) {
            Text(nativePluginDescription(this.selected)).fontSize(NativeDesign.fontCompact).lineHeight(20)
              .width('100%').fontColor(this.secondaryText())
          }
          Column() {
            this.detailRow('包名', this.selected.name)
            Divider().strokeWidth(0.5).color(this.dividerColor())
            this.detailRow('版本', this.selected.version)
            Divider().strokeWidth(0.5).color(this.dividerColor())
            this.detailRow('来源', this.selected.source || this.selected.availability)
            if (this.selected.readOnlyReason) {
              Divider().strokeWidth(0.5).color(this.dividerColor())
              this.detailRow('限制', nativePluginErrorText(this.selected.readOnlyReason), true)
            }
            if (this.selected.errorCode) {
              Divider().strokeWidth(0.5).color(this.dividerColor())
              this.detailRow('状态', this.statusFor(this.selected), true)
            }
          }.width('100%').borderRadius(NativeDesign.radiusGroup)
            .border({ width: 0.5, color: this.lineColor() })
          if (this.versions) {
            Column({ space: 8 }) {
              Row() {
                Text('版本更新').fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium).fontColor(this.primaryText())
                Blank()
                Text(this.versions.status === 'listed' ?
                  (this.versions.versions.length + ' 个可用') : '暂不可用')
                  .fontSize(NativeDesign.fontMicro).fontColor(this.tertiaryText())
              }.width('100%')
              if (this.updateCandidate()) {
                Button('更新到 ' + this.updateCandidate(), { type: ButtonType.Normal })
                  .width('100%').height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection)
                  .borderRadius(NativeDesign.radiusControl).backgroundColor(this.accent())
                  .fontColor(NativeDesign.textInverse(this.dark))
                  .enabled(!this.isBusy('update:' + this.selected.name))
                  .onClick((): void => { this.updateSelected(this.updateCandidate()); })
              } else {
                Text(this.versions.status === 'refused' ?
                  nativePluginErrorText(this.versions.problem) : '已是最新版本')
                  .fontSize(NativeDesign.fontCaption).fontColor(this.secondaryText())
              }
            }.width('100%').padding(10).borderRadius(NativeDesign.radiusRow)
              .backgroundColor(this.fieldSurface())
          }
          Row() {
            Text('组件').fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium).fontColor(this.secondaryText())
            Blank()
            Text(this.selected.rows.length.toString()).fontSize(NativeDesign.fontMicro).fontColor(this.tertiaryText())
          }.width('100%').height(NativeDesign.compactControl)
          if (this.selected.rows.length) {
            Column({ space: 2 }) {
              ForEach(this.selected.rows, (row: NativePluginRow) => {
                this.pluginRow(this.selected, row)
              }, (row: NativePluginRow) => row.rowId)
            }.width('100%')
          } else {
            Text('此插件没有可管理的运行组件').fontSize(NativeDesign.fontCaption).fontColor(this.tertiaryText())
              .width('100%').padding(12)
          }
          if (this.selected.removable) {
            Button('移除插件', { type: ButtonType.Normal }).width('100%')
              .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection).borderRadius(NativeDesign.radiusControl)
              .backgroundColor(NativeDesign.dangerSurface(this.dark)).fontColor(this.danger())
              .enabled(!this.isBusy('remove:' + this.selected.name))
              .onClick((): void => { this.confirmRemove(); })
          }
        }.width('100%').padding({ bottom: 16 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.Top).scrollBar(BarState.Auto)
    }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset,
      top: this.safeTop + 4, bottom: this.safeBottom + 8 })
      .width('100%').height('100%').backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition(this.navigationDirection))
  }

  @Builder
  private installPage() {
    Column({ space: 10 }) {
      this.pageHeader('添加插件', this.inspection?.status === 'accepted' ? '安装' : '检查',
        (): void => {
          if (this.inspection?.status === 'accepted') this.install();
          else this.inspectInstall();
        })
      this.errorNotice()
      Text('包名').fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium).width('100%').fontColor(this.secondaryText())
      TextInput({ text: this.installSpec, placeholder: '包名、Git 地址或本地路径' })
        .width('100%').height(NativeDesign.standardRow).fontSize(NativeDesign.fontCompact)
        .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
        .fontColor(this.primaryText()).placeholderColor(this.tertiaryText())
        .onChange((value: string): void => {
          this.installSpec = value;
          this.inspection = null;
        })
      Row({ space: 8 }) {
        Button(this.inspecting ? '检查中…' : '检查安装源', { type: ButtonType.Normal })
          .layoutWeight(1).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection)
          .borderRadius(NativeDesign.radiusControl).backgroundColor(this.fieldSurface())
          .fontColor(this.primaryText()).enabled(!this.inspecting && !!this.installSpec.trim())
          .onClick((): void => { this.inspectInstall(); })
        if (this.inspection?.status === 'accepted') {
          Button(this.installing ? '安装中…' : '安装', { type: ButtonType.Normal })
            .layoutWeight(1).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection)
            .borderRadius(NativeDesign.radiusControl).backgroundColor(this.accent())
            .fontColor(NativeDesign.textInverse(this.dark))
            .enabled(!this.installing).onClick((): void => { this.install(); })
        }
      }.width('100%')
      if (this.inspection?.status === 'accepted') {
        Column({ space: 5 }) {
          Text(this.inspection.name || '待确认插件').fontSize(NativeDesign.fontCompactTitle).fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText())
          Text((this.inspection.version ? 'v' + this.inspection.version + ' · ' : '') +
            (this.inspection.kind || 'package')).fontSize(NativeDesign.fontCaption).fontColor(this.secondaryText())
          if (this.inspection.description) {
            Text(this.inspection.description).fontSize(NativeDesign.fontSection).lineHeight(18)
              .fontColor(this.secondaryText())
          }
        }.width('100%').padding(12).alignItems(HorizontalAlign.Start)
          .borderRadius(NativeDesign.radiusGroup).backgroundColor(this.fieldSurface())
      }
      if (this.notice.pendingBuilds.length) {
        Column({ space: 8 }) {
          Text('需要允许构建脚本').fontSize(NativeDesign.fontCompact).fontWeight(FontWeight.Medium).fontColor(this.primaryText())
          Text(this.notice.pendingBuilds.join('、')).fontSize(NativeDesign.fontCaption).fontColor(this.secondaryText())
          Button('批准并重试', { type: ButtonType.Normal }).width('100%')
            .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection).borderRadius(NativeDesign.radiusControl)
            .backgroundColor(NativeDesign.warningSurface(this.dark))
            .fontColor(NativeDesign.warning(this.dark))
            .onClick((): void => { this.install(this.notice.pendingBuilds); })
        }.width('100%').padding(12).alignItems(HorizontalAlign.Start)
          .borderRadius(NativeDesign.radiusGroup)
          .border({ width: 0.5, color: NativeDesign.warning(this.dark) })
      }
      Blank()
    }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset,
      top: this.safeTop + 4, bottom: this.safeBottom + 8 })
      .width('100%').height('100%').backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition(this.navigationDirection))
  }

  build() {
    Stack() {
      if (this.page === 'detail') this.detailPage()
      else if (this.page === 'install') this.installPage()
      else this.rootPage()
    }.width('100%').height('100%').backgroundColor(this.baseSurface())
  }
}
