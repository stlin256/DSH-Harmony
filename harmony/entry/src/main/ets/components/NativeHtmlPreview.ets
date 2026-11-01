import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { webview } from '@kit.ArkWeb';
import { NativeFileTransfer } from '../services/NativeFileTransfer';
import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeFileViewRequest } from '../services/NativeSessionModel';
import {
  NativeHtmlAssetReference,
  nativeHtmlInline,
  nativeHtmlMimeType,
  nativeHtmlReferences,
  nativeHtmlInlineCss
} from '../services/NativeHtmlDocument';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';

const htmlAssetLimit: number = 32 * 1024 * 1024;
const htmlTextAssetLimit: number = 8 * 1024 * 1024;

@Component
export struct NativeHtmlPreview {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  @Prop @Watch('sourceChanged') source: string = '';
  @Prop path: string = '';
  onBusyChange: (busy: boolean) => void = (_busy: boolean): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private prepared: string = '';
  @State private previewRevision: number = 0;
  @State private error: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private mounted: boolean = false;
  private controllerReady: boolean = false;
  private loadRevision: number = 0;
  private awaitingPage: boolean = false;
  private busy: boolean = false;
  private readonly previewOrigin: string = 'https://dsh-harmony.invalid';

  aboutToAppear(): void {
    this.mounted = true;
    this.setBusy(true);
    this.prepare();
  }
  aboutToDisappear(): void {
    this.mounted = false;
    this.loadRevision++;
    this.setBusy(false);
  }
  private sourceChanged(): void {
    if (this.mounted) this.prepare();
  }
  private base64(bytes: Uint8Array): string {
    return new util.Base64Helper().encodeToStringSync(bytes);
  }
  private text(bytes: Uint8Array): string {
    return util.TextDecoder.create('utf-8').decodeToString(bytes);
  }
  private dataUrl(path: string, bytes: Uint8Array): string {
    return 'data:' + nativeHtmlMimeType(path) + ';base64,' + this.base64(bytes);
  }
  private previewUrl(): string {
    return this.previewOrigin + '/html-preview?revision=' + this.previewRevision;
  }
  private isPreviewUrl(url: string): boolean {
    return url.startsWith(this.previewOrigin + '/html-preview');
  }
  private previewResponse(): WebResourceResponse {
    const response = new WebResourceResponse();
    response.setResponseData(this.prepared);
    response.setResponseEncoding('UTF-8');
    response.setResponseMimeType('text/html');
    response.setResponseCode(200);
    response.setReasonMessage('OK');
    return response;
  }
  private presentation(source: string): string {
    const background = NativeDesign.base(this.dark);
    const foreground = NativeDesign.textPrimary(this.dark);
    const base = '<style id="dsh-html-preview-base">html{' +
      'min-height:100%;background:' + background + ';color:' + foreground + ';' +
      'color-scheme:' + (this.dark ? 'dark' : 'light') + ';}' +
      'body{color:inherit;}</style>';
    const layout = '<style id="dsh-html-preview-layout">' +
      'html,body{width:100%!important;max-width:100vw!important;min-width:0!important;' +
      'margin-left:auto!important;margin-right:auto!important;overflow-x:hidden!important;}' +
      'body{padding-bottom:max(20px,env(safe-area-inset-bottom,0px))!important;}' +
      'body *{box-sizing:border-box;max-width:100%!important;}' +
      'img,video,canvas,svg,iframe,object,embed{height:auto!important;}' +
      'pre,table{max-width:100%!important;overflow-x:auto;}' +
      'html,body{scrollbar-width:none;overscroll-behavior:none;}' +
      'html::-webkit-scrollbar,body::-webkit-scrollbar{display:none;width:0;height:0;}' +
      '</style>';
    if (/<head\b[^>]*>/i.test(source)) {
      const withBase = source.replace(/<head\b[^>]*>/i,
        (head: string): string => head + base);
      return withHeadLayout(withBase, layout);
    }
    return base + layout + source;
  }
  private setBusy(value: boolean): void {
    if (this.busy === value) return;
    this.busy = value;
    this.onBusyChange(value);
  }
  private async prepare(): Promise<void> {
    const revision = ++this.loadRevision;
    this.setBusy(true);
    this.error = '';
    this.prepared = '';
    const assets: Map<string, string> = new Map<string, string>();
    const css: Map<string, string> = new Map<string, string>();
    const queue: NativeHtmlAssetReference[] = nativeHtmlReferences(this.source, this.path);
    const imageTagCount = (this.source.match(/<img\b/gi) || []).length;
    const visited: Set<string> = new Set<string>();
    let bytes: number = 0;
    try {
      while (queue.length && bytes < htmlAssetLimit) {
        const item = queue.shift() as NativeHtmlAssetReference;
        const key = item.kind + '\n' + item.path;
        if (!item.path || visited.has(key)) continue;
        visited.add(key);
        try {
          const limit = Math.max(1, Math.min(item.kind === 'binary' ? htmlTextAssetLimit : htmlTextAssetLimit,
            htmlAssetLimit - bytes));
          const content = await NativeFileTransfer.readComplete(
            this.client, this.sessionId, item.path, limit);
          if (!this.mounted || revision !== this.loadRevision) return;
          bytes += content.bytes.byteLength;
          if (item.kind === 'style' || item.kind === 'binary' &&
            nativeHtmlMimeType(item.path) === 'text/css') {
            const value = this.text(content.bytes);
            css.set(item.path, value);
            queue.push(...nativeHtmlReferences('<style>' + value + '</style>', item.path));
          } else if (item.kind === 'script') {
            assets.set(item.path, this.dataUrl(item.path, content.bytes));
          } else {
            assets.set(item.path, this.dataUrl(item.path, content.bytes));
          }
        } catch (error) {
          console.warn('NativeHtmlPreview asset read failed kind=' + item.kind +
            ' mime=' + nativeHtmlMimeType(item.path) +
            ' reason=' + (error instanceof Error ? error.name : 'unknown'));
          assets.set(item.path, '');
        }
      }
      css.forEach((value: string, path: string): void => {
        assets.set(path, nativeHtmlInlineCss(value, path, assets));
      });
      const html = nativeHtmlInline(this.source, this.path, assets);
      if (!this.mounted || revision !== this.loadRevision) return;
      console.info('NativeHtmlPreview assets images=' + imageTagCount +
        ' references=' + visited.size + ' loaded=' + assets.size + ' bytes=' + bytes);
      this.prepared = this.presentation(html);
      this.previewRevision = revision;
      this.setBusy(true);
      if (this.controllerReady) {
        this.awaitingPage = true;
        try {
          this.controller.loadUrl(this.previewUrl());
        } catch (_) {
          this.awaitingPage = false;
          this.setBusy(false);
          this.error = '无法预览此网页';
        }
      }
    } catch (_) {
      if (this.mounted && revision === this.loadRevision) {
        this.error = '无法预览此网页';
        this.setBusy(false);
      }
    }
  }
  private async openLocal(path: string): Promise<void> {
    try {
      const target = await this.client.resolveWorkspaceTarget(this.sessionId, path);
      if (target.kind !== 'file' && target.kind !== 'directory') {
        if (this.mounted) this.getUIContext().getPromptAction().showToast({
          message: '文件或文件夹不可用', duration: 1500
        });
        return;
      }
      const request = new NativeFileViewRequest();
      request.kind = target.kind === 'directory' ? 'browser' : 'file';
      request.sessionId = this.sessionId;
      request.path = target.path;
      request.requestId = util.generateRandomUUID();
      AppStorage.setOrCreate<string>('nativeFileViewPayload', JSON.stringify(request));
      AppStorage.setOrCreate<number>('nativeFileViewRevision',
        (AppStorage.get<number>('nativeFileViewRevision') || 0) + 1);
    } catch (_) {
      if (this.mounted) this.getUIContext().getPromptAction().showToast({
        message: '文件或文件夹不可用', duration: 1500
      });
    }
  }
  private openExternal(url: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.startAbility({ action: 'ohos.want.action.viewData', uri: url }).catch((): void => {});
  }
  private intercept(url: string): boolean {
    if (this.isPreviewUrl(url)) return false;
    if (url === 'about:blank' || url.startsWith('data:text/html')) return false;
    if (url.startsWith('dshharmony://file?path=')) {
      const encoded = url.slice('dshharmony://file?path='.length);
      try { this.openLocal(decodeURIComponent(encoded)); } catch (_) {}
      return true;
    }
    if (/^https?:\/\//i.test(url)) {
      this.openExternal(url);
      return true;
    }
    return true;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.prepared) {
        Web({ src: this.previewUrl(), controller: this.controller })
          .width('100%').height('100%')
          .metaViewport(true)
          .overScrollMode(OverScrollMode.NEVER)
          .javaScriptAccess(true).fileAccess(false).domStorageAccess(false)
          .darkMode(WebDarkMode.Auto).forceDarkAccess(false)
          .backgroundColor(NativeDesign.base(this.dark))
          .onControllerAttached((): void => {
            this.controllerReady = true;
            this.awaitingPage = true;
          })
          .onInterceptRequest((event): WebResourceResponse | null => {
            return this.isPreviewUrl(event.request.getRequestUrl()) ? this.previewResponse() : null;
          })
          .onLoadIntercept((event): boolean => this.intercept(event.data.getRequestUrl()))
          .onPageEnd((): void => {
            this.awaitingPage = false;
            if (this.mounted) this.setBusy(false);
          })
          .onErrorReceive((event): void => {
            if (!event.request.isMainFrame() || !this.awaitingPage) return;
            this.awaitingPage = false;
            if (this.mounted) {
              this.setBusy(false);
              this.error = '网页加载失败';
            }
          })
      }
      if (this.error) {
        Text(this.error).fontSize(NativeDesign.fontCompact).fontColor(NativeDesign.danger(this.dark))
          .padding(NativeDesign.cardPadding)
          .borderRadius(NativeDesign.radiusGroup)
          .backgroundColor(NativeDesign.raised(this.dark))
      }
    }.width('100%').height('100%')
  }
}

function withHeadLayout(source: string, layout: string): string {
  return source.replace(/<\/head>/i, layout + '</head>');
}
