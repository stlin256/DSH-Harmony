import { common } from '@kit.AbilityKit';
import {
  NativeDirectoryEntry,
  NativeDirectoryListing,
  NativeHarnessClient,
  NativeHttpError
} from '../services/NativeHarnessClient';
import { DSHIcon } from './DSHIcon';
import { NativeFilePreview } from './NativeFilePreview';
import { NativeExperience } from '../services/NativeExperience';
import { NativeMotion } from '../services/NativeMotion';
import { NativeFileTransfer } from '../services/NativeFileTransfer';
import {
  NativeWorkspaceCache,
  NativeWorkspaceDirectoryCacheEntry,
  nativeDirectoryFingerprint
} from '../services/NativeWorkspaceCache';
import { NativeStorageManager } from '../services/NativeStorageManager';
import { NativeBrowserHistory, NativeBrowserHistoryEntry } from '../services/NativeBrowserHistory';
import { NativeFileViewRequest } from '../services/NativeSessionModel';
import { NativeDesign } from '../services/NativeDesign';
import { NativeIconButton } from './NativeIconButton';

class NativePathPart {
  label: string = '';
  path: string = '';
}

/** Workspace-scoped directory browser. Paths are Host workspace paths. */
@Component
export struct NativeFileBrowser {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  workspaceRoot: string = '';
  @Prop path: string = '';
  @Prop initialPreviewPath: string = '';
  @Prop previewOnly: boolean = false;
  onClose: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @StorageLink('nativeSafeLeft') private safeLeft: number = 0;
  @StorageLink('nativeSafeRight') private safeRight: number = 0;
  @StorageLink('nativeBackRevision') @Watch('systemBack') private backRevision: number = 0;
  @StorageLink('nativeBrowserPushRevision') @Watch('browserPushChanged') private browserPushRevision: number = 0;
  @State private navigationPath: string = '';
  @State private displayPath: string = '';
  @State private entries: NativeDirectoryEntry[] = [];
  @State private loading: boolean = true;
  @State private navigating: boolean = false;
  @State private error: string = '';
  @State private truncated: boolean = false;
  @State private previewPath: string = '';
  @State private downloadingFile: string = '';
  @State private pressedEntry: string = '';
  private mounted: boolean = false;
  private hasLoaded: boolean = false;
  private requestGeneration: number = 0;
  private rootExitArmedAt: number = 0;
  private history: NativeBrowserHistory = new NativeBrowserHistory();

  aboutToAppear(): void {
    this.mounted = true;
    this.navigationPath = this.workspacePath(this.path);
    if (this.initialPreviewPath) {
      if (!this.previewOnly) this.history.push('directory', this.navigationPath);
      this.previewPath = this.workspacePath(this.initialPreviewPath);
    }
    this.load();
  }
  aboutToDisappear(): void { this.mounted = false; }
  private animate(action: () => void): void {
    NativeMotion.animate(this.getUIContext(), 'navigation', action);
  }
  private workspacePath(value: string): string {
    return this.client.workspaceRelativePath(this.sessionId, value, this.workspaceRoot);
  }
  private async load(next: string = this.navigationPath): Promise<boolean> {
    const requested = this.workspacePath(next);
    const previousPath = this.navigationPath;
    const previousDisplayPath = this.displayPath;
    const previousEntries = this.entries;
    const previousTruncated = this.truncated;
    const generation = ++this.requestGeneration;
    const preserveContent = this.hasLoaded;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const scope = this.client.cacheKey();
    if (preserveContent) {
      this.navigating = true;
      this.navigationPath = requested;
    } else {
      this.loading = true;
    }
    this.error = '';
    let cached: NativeWorkspaceDirectoryCacheEntry | null = null;
    try {
      cached = await NativeWorkspaceCache.loadDirectory(
        context, scope, this.sessionId, requested);
      if (!this.mounted || generation !== this.requestGeneration) return false;
      if (cached) {
        this.navigationPath = requested;
        this.displayPath = cached.listing.path || requested;
        this.entries = cached.listing.entries;
        this.truncated = cached.listing.truncated;
        this.hasLoaded = true;
        this.loading = false;
        this.navigating = true;
        this.client.rememberBrowsePath(this.sessionId, requested);
      }
      const value: NativeDirectoryListing = await this.client.listFiles(this.sessionId, requested);
      if (!this.mounted || generation !== this.requestGeneration) return false;
      const fingerprint = nativeDirectoryFingerprint(value.entries, value.truncated);
      this.navigationPath = requested;
      this.displayPath = value.path;
      if (!cached || cached.fingerprint !== fingerprint) {
        this.entries = value.entries;
        this.truncated = value.truncated;
      }
      this.hasLoaded = true;
      this.rootExitArmedAt = 0;
      this.client.rememberBrowsePath(this.sessionId, requested);
      if (!cached || cached.fingerprint !== fingerprint) {
        NativeWorkspaceCache.saveDirectory(
          context, scope, this.sessionId, requested, value)
          .then((): void => {
            NativeStorageManager.enforceDefaultLimit(
              context, scope, this.sessionId).catch((): void => {});
          }).catch((): void => {});
      }
      return true;
    } catch (error) {
      if (!this.mounted || generation !== this.requestGeneration) return false;
      const stableUnavailable = error instanceof NativeHttpError &&
        error.status >= 400 && error.status < 500;
      if (cached && !stableUnavailable) {
        // A validated warm frame remains useful while a transient refresh fails.
        return true;
      }
      if (cached) {
        await NativeWorkspaceCache.removeEntry(
          context, scope, this.sessionId, requested, true, false);
      }
      if (preserveContent) {
        this.navigationPath = previousPath;
        this.displayPath = previousDisplayPath;
        this.entries = previousEntries;
        this.truncated = previousTruncated;
        this.hasLoaded = true;
        this.getUIContext().getPromptAction().showToast({
          message: '无法打开此文件夹',
          duration: 1400
        });
      } else {
        this.entries = [];
        this.truncated = false;
        this.hasLoaded = false;
        this.error = '无法打开此文件夹';
      }
      return false;
    } finally {
      if (this.mounted && generation === this.requestGeneration) {
        this.loading = false;
        this.navigating = false;
      }
    }
  }
  private currentEntry(): NativeBrowserHistoryEntry {
    return new NativeBrowserHistoryEntry(this.previewPath ? 'file' : 'directory',
      this.previewPath || this.navigationPath);
  }
  private async navigate(next: string): Promise<void> {
    const requested = this.workspacePath(next);
    if (!this.previewPath && requested === this.navigationPath) return;
    this.history.push(this.currentEntry().kind, this.currentEntry().path);
    this.previewPath = '';
    if (!await this.load(requested)) this.history.pop();
  }
  private back(confirmAtRoot: boolean = false): void {
    const previous = this.history.pop();
    if (previous) {
      this.rootExitArmedAt = 0;
      if (previous.kind === 'file') {
        this.animate((): void => { this.previewPath = previous.path; });
      } else {
        this.previewPath = '';
        this.load(previous.path);
      }
      return;
    }
    if (this.previewOnly) {
      this.rootExitArmedAt = 0;
      this.onClose();
      return;
    }
    if (!confirmAtRoot) {
      this.rootExitArmedAt = 0;
      this.onClose();
      return;
    }
    const now = Date.now();
    if (this.rootExitArmedAt && now - this.rootExitArmedAt <= 2000) {
      this.onClose();
      return;
    }
    this.rootExitArmedAt = now;
    this.getUIContext().getPromptAction().showToast({
      message: '再次返回退出文件浏览',
      duration: 1600
    });
  }
  private browserPushChanged(): void {
    if (!this.mounted) return;
    const raw = AppStorage.get<string>('nativeBrowserPushPayload') || '';
    if (!raw) return;
    try {
      const request = JSON.parse(raw) as NativeFileViewRequest;
      if (request.sessionId !== this.sessionId ||
        (request.kind !== 'file' && request.kind !== 'browser') ||
        (request.kind === 'file' && !request.path)) return;
      this.rootExitArmedAt = 0;
      if (request.kind === 'file') {
        const next = this.workspacePath(request.path);
        if (next === this.previewPath) return;
        this.history.push(this.currentEntry().kind, this.currentEntry().path);
        this.animate((): void => { this.previewPath = next; });
      } else {
        this.navigate(request.path);
      }
    } catch (_) {}
  }
  private child(entry: NativeDirectoryEntry): string {
    if (!this.navigationPath) return entry.name;
    return this.navigationPath.replace(/\/+$/, '') + '/' + entry.name;
  }
  private filePath(entry: NativeDirectoryEntry): string {
    const parent = this.displayPath.replace(/\/+$/, '');
    if (!parent) return this.child(entry);
    return parent + '/' + entry.name;
  }
  private open(entry: NativeDirectoryEntry): void {
    if (entry.type === 'directory') {
      this.navigate(this.child(entry));
    } else if (entry.type === 'file') {
      this.client.rememberBrowsePath(this.sessionId, this.navigationPath);
      this.rootExitArmedAt = 0;
      this.history.push(this.currentEntry().kind, this.currentEntry().path);
      this.animate(() => { this.previewPath = this.filePath(entry); });
    }
  }
  private systemBack(): void {
    this.back(true);
  }
  private async download(entry: NativeDirectoryEntry): Promise<void> {
    if (this.downloadingFile || entry.type !== 'file') return;
    const path = this.filePath(entry);
    this.downloadingFile = path;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const saved = await NativeFileTransfer.download(context, this.client, this.sessionId, path);
      if (saved && this.mounted) {
        this.getUIContext().getPromptAction().showToast({ message: '文件已保存', duration: 1300 });
      }
    } catch (_) {
      if (this.mounted) {
        this.getUIContext().getPromptAction().showToast({ message: '保存文件失败', duration: 1500 });
      }
    } finally {
      if (this.mounted) this.downloadingFile = '';
    }
  }
  private crumbs(): NativePathPart[] {
    const clean = this.navigationPath;
    if (!clean) return [];
    const segments = clean.split('/').filter((value: string): boolean => !!value);
    return segments.map((value: string, index: number): NativePathPart => {
      const row = new NativePathPart(); row.label = value;
      row.path = segments.slice(0, index + 1).join('/');
      return row;
    });
  }
  private formatBytes(bytes: number): string {
    if (bytes < 0) return '';
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / 1024 / 1024).toFixed(1) + ' MB';
  }
  private entryKey(entry: NativeDirectoryEntry): string {
    return entry.name + ':' + entry.type;
  }
  private byName(left: NativeDirectoryEntry, right: NativeDirectoryEntry): number {
    const a = left.name.toLowerCase();
    const b = right.name.toLowerCase();
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
  }
  private directoryEntries(): NativeDirectoryEntry[] {
    return this.entries.filter((entry: NativeDirectoryEntry): boolean =>
      entry.type === 'directory').sort((left: NativeDirectoryEntry, right: NativeDirectoryEntry): number =>
      this.byName(left, right));
  }
  private fileEntries(): NativeDirectoryEntry[] {
    return this.entries.filter((entry: NativeDirectoryEntry): boolean =>
      entry.type !== 'directory').sort((left: NativeDirectoryEntry, right: NativeDirectoryEntry): number =>
      this.byName(left, right));
  }

  @Builder
  private header() {
    Row({ space: 4 }) {
      NativeIconButton({
        glyph: 'chevron-left-outline',
        label: '返回',
        tone: 'primary',
        glyphSize: NativeDesign.glyphControl,
        onPressed: (): void => { this.back(false); }
      })
      Column({ space: 1 }) {
        Row({ space: 5 }) {
          Text(this.navigationPath || '工作区').fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textPrimary(this.dark))
          if (this.navigating) {
            LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline).color(NativeDesign.accent(this.dark))
          }
        }.width('100%')
        Text(this.navigationPath ? '文件夹' : '工作区根目录').fontSize(NativeDesign.fontMicro)
          .fontColor(NativeDesign.textTertiary(this.dark))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      NativeIconButton({
        glyph: 'browse-outline',
        label: '在工作区根目录中查找文件',
        glyphSize: NativeDesign.glyphControl,
        controlEnabled: !!this.navigationPath,
        onPressed: (): void => { if (this.navigationPath) this.navigate(''); }
      })
      NativeIconButton({
        glyph: 'close-outline',
        label: '关闭文件浏览器',
        tone: 'primary',
        glyphSize: NativeDesign.glyphControl,
        onPressed: (): void => { this.onClose(); }
      })
    }.width('100%').height(NativeDesign.headerHeight)
  }
  @Builder
  private breadcrumb() {
    Scroll() {
      Row({ space: 2 }) {
        Button(this.navigationPath ? '工作区' : '根目录', { type: ButtonType.Normal })
          .height(NativeDesign.compactChip).fontSize(NativeDesign.fontMicro)
          .borderRadius(NativeDesign.radiusChip).padding({ left: 6, right: 6 })
          .backgroundColor(Color.Transparent)
          .fontColor(NativeDesign.textTertiary(this.dark))
          .responseRegion({ x: 0, y: -9, width: '100%', height: NativeDesign.hitTarget })
          .enabled(!!this.navigationPath).onClick(() => { this.navigate(''); })
        ForEach(this.crumbs(), (part: NativePathPart, index: number) => {
          Text('/').fontSize(NativeDesign.fontMicro).fontColor(NativeDesign.textTertiary(this.dark))
          Button(part.label, { type: ButtonType.Normal })
            .height(NativeDesign.compactChip).fontSize(NativeDesign.fontMicro)
            .borderRadius(NativeDesign.radiusChip).padding({ left: 5, right: 5 })
            .backgroundColor(Color.Transparent)
            .fontColor(index === this.crumbs().length - 1 ?
              NativeDesign.textPrimary(this.dark) : NativeDesign.textTertiary(this.dark))
            .responseRegion({ x: 0, y: -9, width: '100%', height: NativeDesign.hitTarget })
            .onClick(() => { this.navigate(part.path); })
        }, (part: NativePathPart) => part.path)
      }.constraintSize({ minWidth: '100%' }).justifyContent(FlexAlign.Start)
    }.scrollable(ScrollDirection.Horizontal).width('100%').height(NativeDesign.compactChip)
  }
  @Builder
  private fileIcon(entry: NativeDirectoryEntry) {
    DSHIcon({
      glyph: entry.type === 'directory' ? 'folder-outline' : entry.type === 'file' ? 'code-outline' : 'question-outline',
      glyphSize: NativeDesign.glyphControl, color: entry.type === 'directory' ?
        NativeDesign.accent(this.dark) : NativeDesign.textSecondary(this.dark)
    })
  }
  @Builder
  private entryRow(entry: NativeDirectoryEntry) {
    Row({ space: 9 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 9 }) {
          this.fileIcon(entry)
          Column({ space: 1 }) {
            Text(entry.name).fontSize(NativeDesign.fontCompact).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textPrimary(this.dark))
            if (entry.type === 'file' && entry.size >= 0 || entry.type === 'other') {
              Text(entry.type === 'other' ? '不支持预览' : this.formatBytes(entry.size)).fontSize(NativeDesign.fontMicro)
                .fontColor(NativeDesign.textTertiary(this.dark))
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')
      }.layoutWeight(1).height(NativeDesign.standardRow).padding(0).borderRadius(0)
        .backgroundColor(Color.Transparent)
        .stateEffect(false)
        .enabled(entry.type !== 'other')
        .accessibilityText(entry.name + '，' + entry.type)
        .onClick(() => { this.open(entry); })
      if (entry.type === 'directory') {
        DSHIcon({ glyph: 'chevron-left-outline', glyphSize: NativeDesign.glyphInline,
          color: NativeDesign.textTertiary(this.dark) }).rotate({ angle: 180 })
      } else if (entry.type === 'file') {
        Button({ type: ButtonType.Normal }) {
          if (this.downloadingFile === this.filePath(entry)) {
            LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline).color(NativeDesign.accent(this.dark))
          } else {
            DSHIcon({ glyph: 'download-outline', glyphSize: NativeDesign.glyphControl,
              color: NativeDesign.textTertiary(this.dark) })
          }
        }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget).padding(0)
          .borderRadius(NativeDesign.radiusControl).backgroundColor(Color.Transparent)
          .accessibilityText('下载 ' + entry.name)
          .enabled(!this.downloadingFile)
          .onClick((): void => { this.download(entry); })
      }
    }.width('100%').height(NativeDesign.standardRow)
      .padding({ left: 8, right: 4 })
      .borderRadius(NativeDesign.radiusRow).clip(true)
      .backgroundColor(this.pressedEntry === this.entryKey(entry) ?
        NativeDesign.selection(this.dark) : Color.Transparent)
      .animation(NativeMotion.implicit('press'))
      .onTouch((event: TouchEvent): void => {
        this.pressedEntry = event.type === TouchType.Down ? this.entryKey(entry) : '';
      })
  }
  @Builder
  private content() {
    if (this.loading && !this.hasLoaded) {
      Column({ space: 10 }) {
        LoadingProgress().width(NativeDesign.spinnerPage).height(NativeDesign.spinnerPage).color(NativeDesign.accent(this.dark))
        Text('正在读取…').fontSize(NativeDesign.fontSection).fontColor(NativeDesign.textTertiary(this.dark))
      }.layoutWeight(1).justifyContent(FlexAlign.Center)
    } else if (this.error && !this.hasLoaded) {
      Column({ space: 10 }) {
        Text(this.error).fontSize(NativeDesign.fontCompact).fontColor(NativeDesign.danger(this.dark))
        Button({ type: ButtonType.Normal }) {
          DSHIcon({ glyph: 'browse-outline', glyphSize: NativeDesign.glyphControl,
            color: NativeDesign.textPrimary(this.dark) })
        }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
          .borderRadius(NativeDesign.hitTarget / 2)
          .backgroundColor(NativeDesign.selection(this.dark))
          .accessibilityText('重试').onClick(() => { this.load(this.navigationPath); })
      }.layoutWeight(1).justifyContent(FlexAlign.Center)
    } else if (!this.entries.length) {
      Text('此文件夹为空').fontSize(NativeDesign.fontSection).fontColor(NativeDesign.textTertiary(this.dark))
        .layoutWeight(1).textAlign(TextAlign.Center)
    } else {
      List({ space: 2 }) {
        if (this.directoryEntries().length) {
          ListItem() {
            Text('文件夹').fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
              .fontColor(NativeDesign.textTertiary(this.dark))
              .width('100%').height(NativeDesign.compactChip).padding({ left: NativeDesign.rowInset })
          }
          ForEach(this.directoryEntries(), (entry: NativeDirectoryEntry) => {
            ListItem() { this.entryRow(entry) }
          }, (entry: NativeDirectoryEntry) => this.entryKey(entry))
        }
        if (this.fileEntries().length) {
          ListItem() {
            Text('文件').fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
              .fontColor(NativeDesign.textTertiary(this.dark))
              .width('100%').height(NativeDesign.compactChip)
              .padding({ left: NativeDesign.rowInset, top: this.directoryEntries().length ? 4 : 0 })
          }
          ForEach(this.fileEntries(), (entry: NativeDirectoryEntry) => {
            ListItem() { this.entryRow(entry) }
          }, (entry: NativeDirectoryEntry) => this.entryKey(entry))
        }
        if (this.truncated) {
          ListItem() {
            Text('文件过多，仅显示前一部分').fontSize(NativeDesign.fontCaption).padding(10)
              .fontColor(NativeDesign.textTertiary(this.dark))
          }
        }
      }.layoutWeight(1).width('100%').cachedCount(8)
        .opacity(this.navigating ? 0.72 : 1)
        .animation(NativeMotion.disclosureParam())
        .edgeEffect(NativeMotion.enabled() ? EdgeEffect.Spring : EdgeEffect.None)
    }
  }
  build() {
    Stack() {
      Column({ space: 6 }) {
        this.header()
        this.breadcrumb()
        this.content()
      }.padding({
        left: NativeDesign.pageInset + this.safeLeft, right: NativeDesign.pageInset + this.safeRight,
        top: 8 + this.safeTop, bottom: 10 + this.safeBottom
      }).width('100%').height('100%').backgroundColor(NativeDesign.base(this.dark))
      if (this.previewPath) {
        NativeFilePreview({ client: this.client, sessionId: this.sessionId, path: this.previewPath,
          onClose: (): void => { this.back(); } })
          .transition(NativeMotion.overlayTransition())
      }
    }.width('100%').height('100%')
      .transition(NativeMotion.navigationTransition())
  }
}
