import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeExperience } from '../services/NativeExperience';
import { NativeChatPreferences, NativeSettingsDescription } from '../services/NativeHostSettings';
import {
  NativeStorageManager,
  NativeStorageUsage,
  nativeFormatStorageBytes
} from '../services/NativeStorageManager';
import { AboutSettings } from './AboutSettings';
import { DSHIcon } from './DSHIcon';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';
import { NativeIconButton } from './NativeIconButton';
import {
  NativeSettingsHit,
  nativeSearchSettings
} from '../services/NativeSettingsIndex';

class NotificationPreferences {
  version: number = 1;
  completed: string = 'quiet';
  failed: string = 'standard';
  approval: string = 'standard';
  connection: string = 'off';
}

class PushDeviceRegistration {
  id: string = '';
  token: string = '';
  notifications: NotificationPreferences = new NotificationPreferences();
}

class SettingsState {
  themeMode: string = 'system';
  reduceMotion: boolean = false;
  reduceTransparency: boolean = false;
  widgetDetails: boolean = true;
  supportsPush: boolean = false;
  pushEnabled: boolean = false;
  notificationsEnabled: boolean = true;
  notificationPermissionKnown: boolean = false;
  backgroundMonitor: boolean = false;
  notifyCompleted: string = 'quiet';
  notifyFailed: string = 'standard';
  notifyApproval: string = 'standard';
  notifyConnection: string = 'off';
}

@Component
export struct NativeSettings {
  client: NativeHarnessClient = new NativeHarnessClient('');
  serverOrigin: string = '';
  invoke: (command: string, value: string) => Promise<string> = async (): Promise<string> => '';
  onReturn: () => void = (): void => {};
  onConnection: () => void = (): void => {};
  onLogin: () => void = (): void => {};
  onLogout: () => Promise<void> = async (): Promise<void> => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeHostSettingsRevision') @Watch('hostChanged') private hostRevision: number = 0;
  @StorageLink('nativeAppActive') @Watch('activityChanged') private active: boolean = true;
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @StorageLink('nativeSafeLeft') private safeLeft: number = 0;
  @StorageLink('nativeSafeRight') private safeRight: number = 0;
  @StorageLink('nativeSettingsPage') private settingsPage: string = 'root';
  @State private host: NativeSettingsDescription = new NativeSettingsDescription();
  @State private chat: NativeChatPreferences = new NativeChatPreferences();
  @State private hostLoading: boolean = false;
  @State private pluginVersion: string = '';
  @State private hostSaving: string[] = [];
  @State private hostError: string = '';
  @State private retryHostNs: string = '';
  @State private retryHostField: string = '';
  @State private retryHostValue: string = '';
  @State private themeMode: string = 'system';
  @State private chatMode: string = 'detailed';
  @State private chatCollapseTiming: string = 'completion';
  @State private chatFoldedReplies: string = 'all';
  @State private chatBusyEnter: string = 'queue';
  @State private reduceMotion: boolean = false;
  @State private reduceTransparency: boolean = false;
  @State private widgetDetails: boolean = true;
  @State private supportsPush: boolean = false;
  @State private pushEnabled: boolean = false;
  @State private notificationsEnabled: boolean = true;
  @State private notificationPermissionKnown: boolean = false;
  @State private backgroundMonitor: boolean = false;
  @State private notifyCompleted: string = 'quiet';
  @State private notifyFailed: string = 'standard';
  @State private notifyApproval: string = 'standard';
  @State private notifyConnection: string = 'off';
  @State private storageUsage: NativeStorageUsage = new NativeStorageUsage();
  @State private storageLoading: boolean = false;
  @State private storageClearing: boolean = false;
  @State private storageError: string = '';
  @State private initializing: boolean = true;
  @State private pending: string[] = [];
  @State private status: string = '';
  @State private error: string = '';
  @State private settingsQuery: string = '';
  private mounted: boolean = false;
  private notificationWrites: Promise<void> = Promise.resolve();

  private updateState(action: () => void): void {
    NativeMotion.animate(this.getUIContext(), 'micro', action);
  }

  private baseSurface(): string {
    return NativeDesign.base(this.dark);
  }

  private cardSurface(): string {
    return NativeDesign.raised(this.dark);
  }

  private dividerColor(): string {
    return NativeDesign.divider(this.dark);
  }

  private primaryText(): string {
    return NativeDesign.textPrimary(this.dark);
  }

  private secondaryText(): string {
    return NativeDesign.textSecondary(this.dark);
  }

  private tertiaryText(): string {
    return NativeDesign.textTertiary(this.dark);
  }

  private dangerText(): string {
    return NativeDesign.danger(this.dark);
  }

  aboutToAppear(): void {
    this.mounted = true;
    if (AppStorage.get<boolean>('storeShowcase') === true &&
      AppStorage.get<string>('storeShowcaseState') === 'settings-search') {
      this.settingsQuery = '通知';
    }
    this.hostChanged();
    this.initialize().catch(() => { this.error = '读取设置失败'; this.initializing = false; });
    this.refreshHost();
  }

  aboutToDisappear(): void {
    this.mounted = false;
  }

  private activityChanged(): void {
    if (this.mounted && this.active && !this.initializing) {
      this.refreshNotificationState().catch((): void => {});
    }
  }

  private hostChanged(): void {
    this.host = this.client.hostSettings.description;
    this.chat = this.client.hostSettings.chat();
    this.chatMode = this.chat.mode;
    this.chatCollapseTiming = this.chat.collapseTiming;
    this.chatFoldedReplies = this.chat.foldedReplies;
    this.chatBusyEnter = this.chat.busyEnter;
  }

  private async refreshHost(): Promise<void> {
    this.hostLoading = true;
    this.hostError = '';
    try {
      await this.client.hostSettings.refresh();
      const state = await this.client.state();
      if (this.mounted) this.pluginVersion = state.pluginVersion;
      if (this.mounted) this.hostChanged();
    } catch (_) {
      if (this.mounted) this.hostError = 'DSH 设置暂不可用';
    } finally {
      if (this.mounted) this.hostLoading = false;
    }
  }

  private async saveHost(ns: string, field: string, value: string | number): Promise<void> {
    const key = ns + ':' + field;
    if (this.hostSaving.includes(key)) return;
    this.hostSaving = this.hostSaving.concat([key]);
    this.hostError = '';
    this.retryHostNs = '';
    this.retryHostField = '';
    this.retryHostValue = '';
    try {
      await this.client.hostSettings.set(ns, field, value);
      if (this.mounted) {
        this.updateState((): void => { this.hostChanged(); });
        AppStorage.setOrCreate<number>('nativeHostSettingsRevision',
          (AppStorage.get<number>('nativeHostSettingsRevision') || 0) + 1);
      }
    } catch (_) {
      if (this.mounted) {
        this.hostError = '这一项保存失败';
        this.retryHostNs = ns;
        this.retryHostField = field;
        this.retryHostValue = String(value);
      }
    } finally {
      if (this.mounted) this.hostSaving = this.hostSaving.filter((name: string) => name !== key);
    }
  }

  private retryHostWrite(): void {
    if (this.retryHostField) this.saveHost(this.retryHostNs, this.retryHostField, this.retryHostValue);
    else this.refreshHost();
  }

  private hasHost(ns: string): boolean {
    return this.host.namespaces.some((row) => row.ns === ns);
  }

  private pendingFor(key: string): boolean {
    return this.pending.includes(key);
  }

  private pushBusy(): boolean {
    return this.pendingFor('enablePush') || this.pendingFor('disablePush');
  }

  private begin(key: string): boolean {
    if (this.initializing || this.pendingFor(key)) return false;
    this.pending = this.pending.concat([key]);
    this.error = '';
    this.status = '';
    return true;
  }

  private end(key: string): void {
    if (this.mounted) this.pending = this.pending.filter((value: string) => value !== key);
  }

  private openPage(page: string): void {
    this.status = '';
    this.error = '';
    this.hostError = '';
    this.retryHostNs = '';
    this.retryHostField = '';
    this.retryHostValue = '';
    const update = (): void => { this.settingsPage = page; };
    NativeMotion.animate(this.getUIContext(), 'navigation', update);
    if (page === 'storage') this.refreshStorageUsage().catch((): void => {});
  }

  private async refreshStorageUsage(clearError: boolean = true): Promise<void> {
    if (this.storageLoading) return;
    this.storageLoading = true;
    if (clearError) this.storageError = '';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const usage = await NativeStorageManager.usageScope(context, this.client.cacheKey());
      if (this.mounted) {
        this.updateState((): void => { this.storageUsage = usage; });
      }
    } catch (_) {
      if (this.mounted && clearError) this.storageError = '无法读取缓存占用';
    } finally {
      if (this.mounted) this.storageLoading = false;
    }
  }

  private confirmClearStorage(): void {
    if (this.storageClearing || this.storageLoading) return;
    this.getUIContext().showAlertDialog({
      title: '清空缓存',
      message: '仅清除当前账户的本机缓存，不会退出登录或删除远端内容。',
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: '清空',
        fontColor: NativeDesign.danger(this.dark),
        action: (): void => {
          this.clearStorage().catch((): void => {});
        }
      }
    });
  }

  private async clearStorage(): Promise<void> {
    if (this.storageClearing || this.storageLoading) return;
    this.storageClearing = true;
    this.storageError = '';
    let failed = false;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await NativeStorageManager.clearScope(context, this.client.cacheKey());
    } catch (_) {
      failed = true;
    }
    await this.refreshStorageUsage(true);
    if (this.mounted) this.storageClearing = false;
    if (failed && this.mounted) this.storageError = '缓存清理失败，请重试';
  }

  private storageBreakdownValue(kind: string): number {
    if (kind === 'conversation') return this.storageUsage.conversation;
    if (kind === 'fileBrowser') return this.storageUsage.fileBrowser;
    if (kind === 'fileContent') return this.storageUsage.fileContent;
    if (kind === 'imageAttachments') return this.storageUsage.imageAttachments;
    if (kind === 'navigation') return this.storageUsage.navigation;
    return 0;
  }

  private level(value: string, fallback: string): string {
    return ['off', 'quiet', 'standard', 'prominent'].includes(value) ? value : fallback;
  }

  private async initialize(): Promise<void> {
    const state = JSON.parse(await this.invoke('nativeState', '')) as SettingsState;
    this.themeMode = state.themeMode || 'system';
    this.reduceMotion = state.reduceMotion === true;
    this.reduceTransparency = state.reduceTransparency === true;
    this.widgetDetails = state.widgetDetails !== false;
    this.supportsPush = state.supportsPush === true;
    this.pushEnabled = state.pushEnabled === true;
    this.notificationsEnabled = state.notificationsEnabled !== false;
    this.notificationPermissionKnown = state.notificationPermissionKnown === true;
    this.backgroundMonitor = state.backgroundMonitor === true;
    this.notifyCompleted = this.level(state.notifyCompleted, 'quiet');
    this.notifyFailed = this.level(state.notifyFailed, 'standard');
    this.notifyApproval = this.level(state.notifyApproval, 'standard');
    this.notifyConnection = this.level(state.notifyConnection, 'off');
    this.initializing = false;
  }

  private async theme(value: string): Promise<void> {
    if (!this.begin('theme')) return;
    const previous = this.themeMode;
    this.updateState((): void => { this.themeMode = value; });
    try {
      await this.invoke('themeMode', value);
    } catch (_) {
      this.updateState((): void => { this.themeMode = previous; });
      this.error = '外观保存失败';
    } finally {
      this.end('theme');
    }
  }

  private async setting(command: string, value: boolean): Promise<void> {
    if (!this.begin(command)) return;
    const previous = this.localValue(command);
    this.updateState((): void => { this.setLocalValue(command, value); });
    try {
      const response = await this.invoke(command, value ? 'true' : 'false');
      if (this.mounted && (command === 'reduceMotion' || command === 'reduceTransparency')) {
        const state = JSON.parse(response) as Record<string, Object>;
        const persisted = state[command];
        if (typeof persisted === 'boolean') {
          this.updateState((): void => { this.setLocalValue(command, persisted); });
        }
      }
    } catch (_) {
      if (this.mounted) {
        this.updateState((): void => { this.setLocalValue(command, previous); });
        this.error = command === 'backgroundMonitor' ? '后台投递启动失败' : '保存失败';
      }
    } finally {
      this.end(command);
    }
  }

  private localValue(command: string): boolean {
    if (command === 'reduceMotion') return this.reduceMotion;
    if (command === 'reduceTransparency') return this.reduceTransparency;
    if (command === 'widgetDetails') return this.widgetDetails;
    if (command === 'backgroundMonitor') return this.backgroundMonitor;
    return false;
  }

  private setLocalValue(command: string, value: boolean): void {
    if (command === 'reduceMotion') this.reduceMotion = value;
    else if (command === 'reduceTransparency') this.reduceTransparency = value;
    else if (command === 'widgetDetails') this.widgetDetails = value;
    else if (command === 'backgroundMonitor') this.backgroundMonitor = value;
  }

  private notificationValue(category: string): string {
    if (category === 'approval') return this.notifyApproval;
    if (category === 'failed') return this.notifyFailed;
    if (category === 'completed') return this.notifyCompleted;
    return this.notifyConnection;
  }

  private setNotificationValue(category: string, value: string): void {
    if (category === 'approval') this.notifyApproval = value;
    else if (category === 'failed') this.notifyFailed = value;
    else if (category === 'completed') this.notifyCompleted = value;
    else this.notifyConnection = value;
  }

  private notificationPreferences(): NotificationPreferences {
    const value = new NotificationPreferences();
    value.completed = this.notifyCompleted;
    value.failed = this.notifyFailed;
    value.approval = this.notifyApproval;
    value.connection = this.notifyConnection;
    return value;
  }

  private async saveNotificationLevel(category: string, levelValue: string): Promise<void> {
    const key = 'notification:' + category;
    if (!this.begin(key)) return;
    const previous = this.notificationValue(category);
    let localSaved = false;
    this.updateState((): void => { this.setNotificationValue(category, levelValue); });
    try {
      const write = this.notificationWrites.catch((): void => {}).then(async (): Promise<void> => {
        const notifications = this.notificationPreferences();
        await this.invoke('notificationLevels', JSON.stringify(notifications));
        localSaved = true;
        if (this.supportsPush && this.pushEnabled) await this.syncDevice(notifications);
      });
      this.notificationWrites = write;
      await write;
    } catch (_) {
      if (!localSaved) {
        this.updateState((): void => { this.setNotificationValue(category, previous); });
        this.error = '通知偏好保存失败';
      } else {
        this.error = '本机已保存，但服务端同步失败';
      }
    } finally {
      this.end(key);
    }
  }

  private async refreshNotificationState(): Promise<void> {
    const state = JSON.parse(await this.invoke('nativeState', '')) as SettingsState;
    this.notificationsEnabled = state.notificationsEnabled !== false;
    this.notificationPermissionKnown = state.notificationPermissionKnown === true;
  }

  private async syncDevice(notifications: NotificationPreferences): Promise<void> {
    const state = await this.client.state();
    if (!state.authenticated || !state.pushConfigured) return;
    const token = await this.invoke('enablePush', '');
    const id = await this.invoke('deviceId', '');
    const device = new PushDeviceRegistration();
    device.id = id;
    device.token = token;
    device.notifications = notifications;
    await this.client.request('/pocket/api/device', http.RequestMethod.POST, JSON.stringify(device));
  }

  private async action(command: string): Promise<void> {
    if (command === 'logout') {
      this.confirmLogout();
      return;
    }
    if (command === 'connection') { this.openPage('connection'); return; }
    if (command === 'about') { this.openPage('about'); return; }
    if (command === 'notificationSettings') {
      if (!this.begin(command)) return;
      try {
        await this.invoke('openNotificationSettings', '');
      } catch (_) {
        this.error = '无法打开系统通知设置';
      } finally {
        this.end(command);
      }
      return;
    }
    if (!this.begin(command)) return;
    try {
      const state = await this.client.state();
      if (!state.authenticated) { this.onLogin(); return; }
      if (command === 'enablePush') {
        if (!this.supportsPush) throw new Error('Unsupported');
        if (!state.pushConfigured) throw new Error('Server is not configured');
        if (state.mode === 'none') await this.client.request('/pocket/api/auth/none', http.RequestMethod.POST, '{}');
        await this.syncDevice(this.notificationPreferences());
        await this.invoke('pushEnabled', 'true');
        this.pushEnabled = true;
      } else if (command === 'disablePush') {
        await this.client.request('/pocket/api/device', http.RequestMethod.DELETE, JSON.stringify({ allForSession: true }));
        await this.invoke('disablePush', '');
        await this.invoke('pushEnabled', 'false');
        this.pushEnabled = false;
      } else if (command === 'sync') {
        const value = await this.client.request('/pocket/api/overview');
        await this.invoke('widgetSnapshot', value);
      } else if (command === 'testNotification') {
        await this.invoke('testNotification', '');
        await this.refreshNotificationState();
        this.notificationsEnabled = true;
        this.notificationPermissionKnown = true;
        this.status = '测试通知已发送';
      }
    } catch (_) {
      if (command === 'enablePush') this.error = 'Push 注册失败；请检查证书、服务端凭据和系统通知权限';
      else if (command === 'testNotification') this.error = '测试通知发送失败';
      else this.error = '操作失败，请重试';
    } finally {
      this.end(command);
    }
  }
  private confirmLogout(): void {
    this.getUIContext().showAlertDialog({
      title: '退出登录',
      message: '退出后将清除本机登录状态和会话缓存，并保留当前服务地址。',
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: '退出',
        fontColor: NativeDesign.danger(this.dark),
        action: (): void => {
          this.performLogout().catch((): void => {});
        }
      }
    });
  }
  private async performLogout(): Promise<void> {
    if (!this.begin('logout')) return;
    try {
      await this.onLogout();
    } catch (_) {
      this.error = '退出失败，请重试';
    } finally {
      this.end('logout');
    }
  }

  @Builder
  private rootHeader() {
    Row() {
      Text('设置').fontSize(NativeDesign.fontPageTitle).fontWeight(FontWeight.Bold)
        .fontColor(this.primaryText())
        .layoutWeight(1)
    }.width('100%').height(NativeDesign.headerHeight)
      .padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset })
  }

  @Builder
  private pageHeader(title: string) {
    Row({ space: 8 }) {
      NativeIconButton({ glyph: 'chevron-left-outline', label: '返回设置', tone: 'primary',
        onPressed: (): void => { this.openPage('root'); } })
      Text(title).fontSize(NativeDesign.fontHeaderTitle).fontWeight(FontWeight.Medium).layoutWeight(1)
        .fontColor(this.primaryText())
    }.width('100%').height(NativeDesign.headerHeight)
      .padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset })
  }

  @Builder
  private sectionLabel(title: string) {
    Text(title).fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium)
      .fontColor(this.tertiaryText()).padding({ top: 8, bottom: 5 })
  }

  private choiceOptions(values: string[], labels: string[], current: string): SelectOption[] {
    const options: SelectOption[] = labels.map((value: string): SelectOption => ({ value }));
    if (!values.includes(current)) options.unshift({ value: '未设置' });
    return options;
  }

  private choiceIndex(values: string[], current: string): number {
    const index = values.indexOf(current);
    return index >= 0 ? index : 0;
  }

  private choiceLabel(values: string[], labels: string[], current: string): string {
    const index = values.indexOf(current);
    return index >= 0 ? labels[index] : '未设置';
  }

  @Builder
  private navigationRow(icon: string, title: string, detail: string, page: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        DSHIcon({ glyph: icon, glyphSize: NativeDesign.glyphControlEmphasis, color: this.secondaryText() })
        Text(title).fontSize(NativeDesign.fontBody).layoutWeight(1).fontColor(this.primaryText())
        if (detail) {
          Text(detail).fontSize(NativeDesign.fontSection).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(this.tertiaryText())
        }
        DSHIcon({ glyph: 'chevron-left-outline', glyphSize: NativeDesign.glyphCompact, color: this.tertiaryText() })
          .rotate({ angle: 180 })
      }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
        .padding({ left: NativeDesign.cardPadding, right: NativeDesign.rowInset })
    }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
      .borderRadius(0).backgroundColor(Color.Transparent)
      .accessibilityText(title + (detail ? '，' + detail : ''))
      .onClick(() => { this.openPage(page); })
  }

  @Builder
  private settingsSearch() {
    Row({ space: 8 }) {
      DSHIcon({ glyph: 'search-outline', glyphSize: NativeDesign.glyphCompact,
        color: this.tertiaryText() })
      TextInput({ text: this.settingsQuery, placeholder: '搜索设置' })
        .layoutWeight(1).height(NativeDesign.hitTarget).padding(0)
        .fontSize(NativeDesign.fontCompact).backgroundColor(Color.Transparent)
        .placeholderColor(this.tertiaryText()).fontColor(this.primaryText())
        .accessibilityText('搜索设置')
        .onChange((value: string): void => { this.settingsQuery = value; })
      if (this.settingsQuery) {
        NativeIconButton({
          glyph: 'close-outline',
          label: '清除设置搜索',
          glyphSize: NativeDesign.glyphCompact,
          onPressed: (): void => { this.settingsQuery = ''; }
        })
      }
    }.width('100%').height(NativeDesign.hitTarget)
      .padding({ left: NativeDesign.cardPadding })
      .borderRadius(NativeDesign.radiusControl).backgroundColor(NativeDesign.field(this.dark))
  }

  @Builder
  private settingsResult(hit: NativeSettingsHit) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text(hit.entry.title).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(this.primaryText())
          if (hit.matchedSynonym) {
            Text(hit.matchedSynonym).fontSize(NativeDesign.fontCaption).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(this.tertiaryText())
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(hit.entry.path).fontSize(NativeDesign.fontCaption).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 148 }).textAlign(TextAlign.End)
          .fontColor(this.tertiaryText())
        DSHIcon({ glyph: 'chevron-left-outline', glyphSize: NativeDesign.glyphCompact,
          color: this.tertiaryText() }).rotate({ angle: 180 })
      }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
        .padding({ left: NativeDesign.cardPadding, right: NativeDesign.rowInset })
    }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
      .borderRadius(0).backgroundColor(Color.Transparent)
      .accessibilityText(hit.entry.title + '，' + hit.entry.path)
      .onClick((): void => {
        this.settingsQuery = '';
        this.openPage(hit.entry.page);
      })
  }

  @Builder
  private settingsResults() {
    if (nativeSearchSettings(this.settingsQuery).length) {
      Column() {
        ForEach(nativeSearchSettings(this.settingsQuery), (hit: NativeSettingsHit, index: number) => {
          this.settingsResult(hit)
          if (index < nativeSearchSettings(this.settingsQuery).length - 1) {
            Divider().strokeWidth(0.5).margin({ left: 44 }).color(this.dividerColor())
          }
        }, (hit: NativeSettingsHit) => hit.entry.id)
      }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true)
        .backgroundColor(this.cardSurface())
    } else {
      Row({ space: 10 }) {
        Text('没有匹配的设置').fontSize(NativeDesign.fontSection).layoutWeight(1)
          .fontColor(this.secondaryText())
        Button('清除', { type: ButtonType.Normal }).height(NativeDesign.hitTarget)
          .fontSize(NativeDesign.fontSection).borderRadius(NativeDesign.radiusControl)
          .backgroundColor(NativeDesign.field(this.dark)).fontColor(this.primaryText())
          .onClick((): void => { this.settingsQuery = ''; })
      }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
        .padding({ left: NativeDesign.cardPadding, right: NativeDesign.rowInset })
        .borderRadius(NativeDesign.radiusGroup).backgroundColor(this.cardSurface())
    }
  }

  @Builder
  private settingsRoot() {
    Column() {
      this.rootHeader()
      Scroll() {
        Column({ space: 0 }) {
          this.settingsSearch()
          if (this.settingsQuery.trim()) {
            this.sectionLabel('搜索结果')
            this.settingsResults()
          } else {
            this.sectionLabel('DSH HARMONY')
            Column() {
              this.navigationRow('deepseek-logo', 'DSH 设置', '对话与过程展示', 'dsh')
              Divider().strokeWidth(0.5).margin({ left: 44 }).color(this.dividerColor())
              this.navigationRow('dark-outline', '外观与动效',
                this.themeMode === 'system' ? '跟随系统' : this.themeMode === 'dark' ? '深色' : '浅色', 'appearance')
            }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true).backgroundColor(this.cardSurface())
            this.sectionLabel('应用')
            Column() {
              this.navigationRow('plan-outline', '通知', this.pushEnabled ? '系统推送' : '按级别投递', 'notifications')
              Divider().strokeWidth(0.5).margin({ left: 44 }).color(this.dividerColor())
              this.navigationRow('browse-outline', '桌面卡片', this.widgetDetails ? '显示任务名称' : '隐私模式', 'cards')
              Divider().strokeWidth(0.5).margin({ left: 44 }).color(this.dividerColor())
              this.navigationRow('archive-outline', '存储管理', '缓存占用与清理', 'storage')
              Divider().strokeWidth(0.5).margin({ left: 44 }).color(this.dividerColor())
              this.navigationRow('globe-outline', '服务与账户', '连接和登录', 'connection')
              Divider().strokeWidth(0.5).margin({ left: 44 }).color(this.dividerColor())
              this.navigationRow('sparkle', '关于', '版本与项目信息', 'about')
            }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true).backgroundColor(this.cardSurface())
          }
          if (this.initializing) {
            Row({ space: 8 }) {
              LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline).color(this.tertiaryText())
              Text('正在读取本机设置').fontSize(NativeDesign.fontSection).fontColor(this.tertiaryText())
            }.padding({ top: 14, left: 5 })
          }
          if (this.error) {
            Text(this.error).fontSize(NativeDesign.fontSection).padding({ top: 12, left: 5 })
              .fontColor(this.dangerText())
          }
        }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset, top: 2,
          bottom: this.safeBottom + 28 }).width('100%')
          .constraintSize({ maxWidth: 680 }).alignItems(HorizontalAlign.Start)
      }.width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
    }.padding({ top: this.safeTop, left: this.safeLeft, right: this.safeRight }).width('100%').height('100%')
      .backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition(-1))
  }

  @Builder
  private hostChoice(title: string, field: string, values: string[], labels: string[], current: string,
    ns: string = 'ui-chat') {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(title).fontSize(NativeDesign.fontBody).fontColor(this.primaryText())
        if (!this.host.writable) {
          Text('服务端设置当前为只读').fontSize(NativeDesign.fontCaption)
            .fontColor(NativeDesign.warning(this.dark))
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (this.hostSaving.includes(ns + ':' + field)) LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
      else {
        Select(this.choiceOptions(values, labels, current))
          .selected(this.choiceIndex(values, current))
          .value(this.choiceLabel(values, labels, current))
          .font({ size: NativeDesign.fontCompact }).height(NativeDesign.hitTarget)
          .borderRadius(NativeDesign.radiusControl)
          .backgroundColor(NativeDesign.field(this.dark))
          .fontColor(this.primaryText())
          .optionFontColor(this.primaryText())
          .selectedOptionFontColor(NativeDesign.accent(this.dark))
          .optionBgColor(NativeDesign.overlay(this.dark))
          .selectedOptionBgColor(NativeDesign.selectedSurface(this.dark))
          .menuBackgroundColor(NativeDesign.overlay(this.dark))
          .enabled(!this.hostSaving.includes(ns + ':' + field) && this.host.writable)
          .opacity(this.host.writable ? 1 : 0.55)
          .onSelect((index: number) => {
            const valueIndex = values.includes(current) ? index : index - 1;
            if (valueIndex < 0 || valueIndex >= values.length) return;
            this.saveHost(ns, field, values[valueIndex]);
          })
      }
    }.width('100%').constraintSize({ minHeight: NativeDesign.doubleLineRow })
      .padding({ left: NativeDesign.cardPadding, right: NativeDesign.rowInset,
        top: NativeDesign.spaceS, bottom: NativeDesign.spaceS })
  }

  @Builder
  private dshSettingsPage() {
    Column() {
      this.pageHeader('DSH 设置')
      Scroll() {
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Text('插件版本').fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium)
              .fontColor(this.primaryText())
            Blank()
            Text(this.pluginVersion ? 'v' + this.pluginVersion : '未报告').fontSize(NativeDesign.fontSection)
              .fontColor(this.tertiaryText())
          }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
            .padding({ left: NativeDesign.cardPadding, right: NativeDesign.cardPadding })
            .borderRadius(NativeDesign.radiusGroup).backgroundColor(this.cardSurface())
          if (this.hasHost('ui-chat')) {
            Column() {
              this.hostChoice('工作步骤展示', 'transcriptView',
                ['compact', 'standard', 'detailed', 'verbose'], ['简洁', '标准', '详细', '完全展开'], this.chatMode)
              Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
              this.hostChoice('过程收起时机', 'collapseTiming',
                ['completion', 'next-input'], ['完成时', '下次发送时'], this.chatCollapseTiming)
              if (this.chatMode !== 'verbose') {
                Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
                this.hostChoice('收起后显示回复', 'foldedReplies',
                  ['all', 'final'], ['全部回复', '仅最终回答'], this.chatFoldedReplies)
              }
            }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true).backgroundColor(this.cardSurface())
          }
          if (this.hasHost('ui-conversation')) {
            Column() {
              this.hostChoice('运行时发送', 'busyEnter',
                ['queue', 'steer'], ['排队', '立即干预'], this.chatBusyEnter, 'ui-conversation')
            }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true).backgroundColor(this.cardSurface())
          }
          if (this.hostLoading) {
            Row({ space: 8 }) {
              LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
              Text('正在读取 DSH 设置').fontSize(NativeDesign.fontSection).fontColor(this.tertiaryText())
            }.padding(14)
          }
          if (!this.hostLoading && !this.host.namespaces.length && !this.hostError) {
            Text('当前 DSH 服务未提供可写设置').fontSize(NativeDesign.fontCompact).padding(14)
              .fontColor(this.tertiaryText())
          }
          if (!this.hostLoading && this.host.namespaces.length && !this.host.writable) {
            Text('当前 DSH 服务未开放设置写入').fontSize(NativeDesign.fontCompact).padding(14)
              .fontColor(this.tertiaryText())
          }
          if (this.hostError) {
            Row({ space: 8 }) {
              Text(this.hostError).fontSize(NativeDesign.fontSection).layoutWeight(1)
                .fontColor(this.dangerText())
              Button('重试', { type: ButtonType.Normal }).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection)
                .onClick(() => { this.retryHostWrite(); })
            }.padding(NativeDesign.cardPadding).borderRadius(NativeDesign.radiusRow)
              .backgroundColor(NativeDesign.dangerSurface(this.dark))
          }
        }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset, top: 0,
          bottom: this.safeBottom + 28 }).width('100%')
          .constraintSize({ maxWidth: 680 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    }.padding({ top: this.safeTop, left: this.safeLeft, right: this.safeRight }).width('100%').height('100%')
      .backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition())
  }

  @Builder
  private toggleRow(key: string, title: string, detail: string,
    unavailable: string = '', showToggle: boolean = true) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(title).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium)
          .fontColor(this.primaryText())
        if (detail) Text(detail).fontSize(NativeDesign.fontCaption).maxLines(2)
          .fontColor(this.secondaryText())
        if (unavailable) Text(unavailable).fontSize(NativeDesign.fontCaption)
          .fontColor(NativeDesign.warning(this.dark))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (this.pendingFor(key)) LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
      if (showToggle) {
        Toggle({ type: ToggleType.Switch, isOn: this.localValue(key) })
          .enabled(!this.initializing && unavailable.length === 0 && !this.pendingFor(key))
          .selectedColor(NativeDesign.accentStrong(this.dark))
          .hitTestBehavior(HitTestMode.None)
          .animation(NativeMotion.implicit('micro'))
      }
    }.width('100%').constraintSize({ minHeight: NativeDesign.doubleLineRow })
      .padding({ left: NativeDesign.cardPadding, right: NativeDesign.rowInset, top: 7, bottom: 7 })
      .enabled(!this.initializing && unavailable.length === 0 && !this.pendingFor(key))
      .onClick(() => {
        if (showToggle) this.setting(key, !this.localValue(key));
      })
  }

  @Builder
  private themeChoice(mode: string, icon: string, label: string) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 7 }) {
        DSHIcon({ glyph: icon, glyphSize: NativeDesign.glyphControlEmphasis,
          color: this.themeMode === mode ? this.primaryText() : this.tertiaryText() })
        Text(label).fontSize(NativeDesign.fontSection)
          .fontColor(this.themeMode === mode ? this.primaryText() : this.tertiaryText())
      }
    }.layoutWeight(1).height(72).borderRadius(NativeDesign.radiusRow)
      .backgroundColor(this.themeMode === mode ? NativeDesign.selectedSurface(this.dark) :
        NativeDesign.field(this.dark))
      .border({ width: this.themeMode === mode ? 1 : 0,
        color: this.themeMode === mode ? NativeDesign.border(this.dark) : Color.Transparent })
      .enabled(!this.initializing && !this.pendingFor('theme'))
      .onClick(() => { this.theme(mode); })
  }

  @Builder
  private appearancePage() {
    Column() {
      this.pageHeader('外观与动效')
      Scroll() {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            this.themeChoice('light', 'light-outline', '浅色')
            this.themeChoice('dark', 'dark-outline', '深色')
            this.themeChoice('system', 'followsystem-outline', '跟随系统')
          }.width('100%').padding(6).borderRadius(NativeDesign.radiusGroup)
            .backgroundColor(this.cardSurface())
          Column() {
            this.toggleRow('reduceMotion', '减少动态效果', '关闭页面与抽屉动画')
            Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
            this.toggleRow('reduceTransparency', '减少透明效果', '使用不透明表面')
          }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true).backgroundColor(this.cardSurface())
          if (this.error) Text(this.error).fontSize(NativeDesign.fontSection)
            .fontColor(this.dangerText()).padding(12)
          if (this.status) Text(this.status).fontSize(NativeDesign.fontSection)
            .fontColor(this.tertiaryText()).padding(8)
        }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset, top: 0,
          bottom: this.safeBottom + 28 }).width('100%')
          .constraintSize({ maxWidth: 680 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    }.padding({ top: this.safeTop, left: this.safeLeft, right: this.safeRight }).width('100%').height('100%')
      .backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition())
  }

  @Builder
  private notificationLevelButton(category: string, levelValue: string, label: string) {
    Button(label, { type: ButtonType.Normal }).layoutWeight(1).height(NativeDesign.hitTarget)
      .fontSize(NativeDesign.fontMicro).borderRadius(NativeDesign.radiusControl)
      .backgroundColor(this.notificationValue(category) === levelValue ? NativeDesign.accentStrong(this.dark) :
        NativeDesign.field(this.dark))
      .fontColor(this.notificationValue(category) === levelValue ? NativeDesign.textInverse(this.dark) :
        this.secondaryText())
      .enabled(!this.initializing && !this.pushBusy() && !this.pendingFor('notification:' + category))
      .onClick(() => { this.saveNotificationLevel(category, levelValue); })
  }

  @Builder
  private notificationRow(title: string, detail: string, category: string) {
    Column({ space: 7 }) {
      Row() {
        Column({ space: 2 }) {
          Text(title).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium)
            .fontColor(this.primaryText())
          Text(detail).fontSize(NativeDesign.fontCaption).fontColor(this.secondaryText())
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.pendingFor('notification:' + category)) LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
      }.width('100%')
      Row({ space: 4 }) {
        this.notificationLevelButton(category, 'off', '关闭')
        this.notificationLevelButton(category, 'quiet', '静默')
        this.notificationLevelButton(category, 'standard', '标准')
        this.notificationLevelButton(category, 'prominent', '醒目')
      }.width('100%')
    }.width('100%').padding({ left: NativeDesign.cardPadding, right: NativeDesign.rowInset, top: 10, bottom: 10 })
  }

  @Builder
  private actionRow(title: string, detail: string, command: string, destructive: boolean = false) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(title).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium)
          .fontColor(destructive ? this.dangerText() : this.primaryText())
        if (detail) Text(detail).fontSize(NativeDesign.fontCaption).fontColor(this.secondaryText())
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (this.pendingFor(command)) LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
      else DSHIcon({ glyph: 'chevron-left-outline', glyphSize: NativeDesign.glyphCompact,
        color: this.tertiaryText() }).rotate({ angle: 180 })
    }.width('100%').constraintSize({ minHeight: NativeDesign.standardRow + 8 })
      .padding({ left: NativeDesign.cardPadding, right: 13, top: 7, bottom: 7 })
      .enabled(!this.initializing && !this.pendingFor(command))
      .onClick(() => { this.action(command); })
  }

  @Builder
  private notificationsPage() {
    Column() {
      this.pageHeader('通知')
      Scroll() {
        Column({ space: 10 }) {
          this.sectionLabel('通知级别')
          Column() {
            this.notificationRow('需要确认', '等待你批准或选择', 'approval')
            Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
            this.notificationRow('任务失败', '任务异常结束', 'failed')
            Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
            this.notificationRow('任务完成', '任务正常结束', 'completed')
            Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
            this.notificationRow('连接异常', '服务连接中断', 'connection')
          }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true).backgroundColor(this.cardSurface())
          this.sectionLabel('投递')
          Column() {
            if (this.supportsPush) {
              this.actionRow(this.pushEnabled ? '关闭系统推送' : '开启系统推送',
                this.pushEnabled ? 'Push Kit 已注册' : '在当前设备上接收后台通知',
                this.pushEnabled ? 'disablePush' : 'enablePush')
              Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
              this.actionRow('发送测试通知', '验证通知权限和跳转', 'testNotification')
            } else {
              this.toggleRow('backgroundMonitor', '后台任务监控',
                '商店版本无 Push Kit；任务运行时保持后台连接')
              Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
              this.actionRow('发送测试通知', '验证本地通知权限', 'testNotification')
            }
            Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
            this.actionRow('系统通知设置',
              !this.notificationPermissionKnown ? '通知权限状态未知' :
                this.notificationsEnabled ? '通知权限已开启' : '通知权限已关闭', 'notificationSettings')
          }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true).backgroundColor(this.cardSurface())
          if (!this.supportsPush) {
            Text('无 Push Kit · 后台运行受系统限制')
              .fontSize(NativeDesign.fontCaption).lineHeight(17).padding({ left: 5, right: 5 })
              .fontColor(this.tertiaryText())
          }
          if (this.error) Text(this.error).fontSize(NativeDesign.fontSection).padding(12)
            .fontColor(this.dangerText())
          if (this.status) Text(this.status).fontSize(NativeDesign.fontSection).padding(8)
            .fontColor(this.tertiaryText())
        }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset, top: 0,
          bottom: this.safeBottom + 28 }).width('100%')
          .constraintSize({ maxWidth: 680 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    }.padding({ top: this.safeTop, left: this.safeLeft, right: this.safeRight }).width('100%').height('100%')
      .backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition())
  }

  @Builder
  private cardsPage() {
    Column() {
      this.pageHeader('桌面卡片')
      Scroll() {
        Column({ space: 10 }) {
          Column() {
            this.toggleRow('widgetDetails', '显示任务名称', '关闭后仍显示匿名数量和状态')
            Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
            this.actionRow('立即同步', '刷新运行、待确认、完成与失败数量', 'sync')
          }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true).backgroundColor(this.cardSurface())
          if (this.error) Text(this.error).fontSize(NativeDesign.fontSection).padding(12)
            .fontColor(this.dangerText())
          if (this.status) Text(this.status).fontSize(NativeDesign.fontSection).padding(8)
            .fontColor(this.tertiaryText())
        }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset, top: 0,
          bottom: this.safeBottom + 28 }).width('100%')
          .constraintSize({ maxWidth: 680 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    }.padding({ top: this.safeTop, left: this.safeLeft, right: this.safeRight }).width('100%').height('100%')
      .backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition())
  }

  @Builder
  private storageBreakdownRow(title: string, kind: string) {
    Row({ space: 12 }) {
      Text(title).fontSize(NativeDesign.fontBody).layoutWeight(1).fontColor(this.primaryText())
      Text(nativeFormatStorageBytes(this.storageBreakdownValue(kind)))
        .fontSize(NativeDesign.fontCompact).fontWeight(FontWeight.Medium)
        .fontColor(this.secondaryText())
    }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
      .padding({ left: NativeDesign.cardPadding, right: NativeDesign.cardPadding })
  }

  @Builder
  private storagePage() {
    Column() {
      this.pageHeader('存储管理')
      Scroll() {
        Column({ space: 10 }) {
          Row({ space: 12 }) {
            Column({ space: 5 }) {
              Text('缓存池').fontSize(NativeDesign.fontSection).fontColor(this.tertiaryText())
              if (this.storageLoading && this.storageUsage.poolTotal === 0) {
                LoadingProgress().width(NativeDesign.spinnerPage).height(NativeDesign.spinnerPage).color(NativeDesign.accent(this.dark))
              } else {
                Text(nativeFormatStorageBytes(this.storageUsage.poolTotal)).fontSize(NativeDesign.fontMetric)
                  .fontWeight(FontWeight.Medium).fontColor(this.primaryText())
              }
              Text('上限 ' + nativeFormatStorageBytes(this.storageUsage.limit) +
                ' · 当前账户 ' + nativeFormatStorageBytes(this.storageUsage.total))
                .fontSize(NativeDesign.fontCaption).fontColor(this.tertiaryText())
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            if (this.storageLoading && this.storageUsage.poolTotal > 0) {
              LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline).color(this.tertiaryText())
            }
            DSHIcon({ glyph: 'archive-outline', glyphSize: NativeDesign.glyphHeader,
              color: NativeDesign.accent(this.dark) })
          }.width('100%').padding(NativeDesign.pageInset).borderRadius(NativeDesign.radiusGroup)
            .backgroundColor(this.cardSurface())
          Column() {
            this.storageBreakdownRow('对话内容', 'conversation')
            Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
            this.storageBreakdownRow('文件浏览', 'fileBrowser')
            Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
            this.storageBreakdownRow('文件内容', 'fileContent')
            Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
            this.storageBreakdownRow('图片附件', 'imageAttachments')
            Divider().strokeWidth(0.5).margin({ left: 14 }).color(this.dividerColor())
            this.storageBreakdownRow('界面索引', 'navigation')
          }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true)
            .backgroundColor(this.cardSurface())
          Button({ type: ButtonType.Normal }) {
            Row({ space: 10 }) {
              DSHIcon({ glyph: 'archive-outline', glyphSize: NativeDesign.glyphControl,
                color: this.dangerText() })
              Text('清空缓存').fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium)
                .fontColor(this.dangerText())
              Blank()
              if (this.storageClearing) LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
            }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
              .padding({ left: NativeDesign.cardPadding, right: NativeDesign.cardPadding })
          }.width('100%').constraintSize({ minHeight: NativeDesign.compactRow })
            .borderRadius(NativeDesign.radiusGroup).backgroundColor(Color.Transparent)
            .enabled(!this.storageClearing && !this.storageLoading)
            .accessibilityText('清空缓存')
            .onClick((): void => { this.confirmClearStorage(); })
          if (this.storageError) {
            Row({ space: 10 }) {
              Text(this.storageError).fontSize(NativeDesign.fontSection).layoutWeight(1)
                .fontColor(this.dangerText())
              if (!this.storageLoading) {
                Button('重试', { type: ButtonType.Normal }).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection)
                  .backgroundColor(NativeDesign.dangerSurface(this.dark))
                  .fontColor(this.dangerText())
                  .onClick((): void => { this.refreshStorageUsage().catch((): void => {}); })
              }
            }.padding(12).borderRadius(NativeDesign.radiusRow)
              .backgroundColor(NativeDesign.dangerSurface(this.dark))
          }
        }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset, top: 0,
          bottom: this.safeBottom + 28 }).width('100%')
          .constraintSize({ maxWidth: 680 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    }.padding({ top: this.safeTop, left: this.safeLeft, right: this.safeRight }).width('100%').height('100%')
      .backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition())
  }

  @Builder
  private connectionPage() {
    Column() {
      this.pageHeader('服务与账户')
      Scroll() {
        Column({ space: 10 }) {
          Column({ space: 7 }) {
            Text('当前服务').fontSize(NativeDesign.fontSection).fontColor(this.tertiaryText())
            Text(this.serverOrigin).fontSize(NativeDesign.fontBody).width('100%').wordBreak(WordBreak.BREAK_ALL)
              .fontColor(this.primaryText()).copyOption(CopyOptions.InApp)
          }.padding(NativeDesign.cardPadding).width('100%').alignItems(HorizontalAlign.Start)
            .borderRadius(NativeDesign.radiusGroup)
            .backgroundColor(this.cardSurface())
          Column() {
            this.actionRow('退出登录', '清除当前连接与本地会话缓存，返回登录页', 'logout', true)
          }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true).backgroundColor(this.cardSurface())
          if (this.error) Text(this.error).fontSize(NativeDesign.fontSection).padding(12)
            .fontColor(this.dangerText())
        }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset, top: 0,
          bottom: this.safeBottom + 28 }).width('100%')
          .constraintSize({ maxWidth: 680 }).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    }.padding({ top: this.safeTop, left: this.safeLeft, right: this.safeRight }).width('100%').height('100%')
      .backgroundColor(this.baseSurface())
      .transition(NativeMotion.navigationTransition())
  }

  build() {
    if (this.settingsPage === 'dsh') this.dshSettingsPage()
    else if (this.settingsPage === 'appearance') this.appearancePage()
    else if (this.settingsPage === 'notifications') this.notificationsPage()
    else if (this.settingsPage === 'cards') this.cardsPage()
    else if (this.settingsPage === 'storage') this.storagePage()
    else if (this.settingsPage === 'connection') this.connectionPage()
    else if (this.settingsPage === 'about') {
      Column() {
        this.pageHeader('关于')
        AboutSettings({ embedded: true, onBack: (): void => { this.openPage('root'); } }).layoutWeight(1)
      }.padding({ top: this.safeTop, left: this.safeLeft, right: this.safeRight }).width('100%').height('100%')
        .backgroundColor(this.baseSurface())
        .transition(NativeMotion.navigationTransition())
    }
    else this.settingsRoot()
  }
}
