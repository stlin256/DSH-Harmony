import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { pdfService, pdfViewManager, PdfView } from '@kit.PDFKit';
import {
  NativeFilePage,
  NativeFileStat,
  NativeHarnessClient,
  NativeHttpError
} from '../services/NativeHarnessClient';
import { NativeFileContent, NativeFileTransfer } from '../services/NativeFileTransfer';
import { NativeDocumentDescriptor, nativeDocumentDescriptor } from '../services/NativeDocumentModel';
import { DSHIcon } from './DSHIcon';
import { NativeMotion } from '../services/NativeMotion';
import { NativeImageZoom, NativeImageZoomTarget } from '../services/NativeImageZoom';
import { NativeDocumentModeSwitch } from './NativeDocumentModeSwitch';
import { NativeCodeViewer } from './NativeCodeViewer';
import { NativeMarkdownPreview } from './NativeMarkdownPreview';
import { NativeHtmlPreview } from './NativeHtmlPreview';
import { NativeDesign } from '../services/NativeDesign';
import { NativeIconButton } from './NativeIconButton';
import {
  NativeWorkspaceCache,
  NativeWorkspaceCachedBinary,
  NativeWorkspaceTextCacheEntry
} from '../services/NativeWorkspaceCache';
import { NativeStorageManager } from '../services/NativeStorageManager';

const previewImageLimit: number = 128 * 1024 * 1024;
const previewPdfLimit: number = 64 * 1024 * 1024;
const previewHtmlLimit: number = 8 * 1024 * 1024;

/** One compact foreground reader shared by chat links and the file browser. */
@Component
export struct NativeFilePreview {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  @Prop @Watch('pathChanged') path: string = '';
  onClose: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @StorageLink('nativeSafeLeft') private safeLeft: number = 0;
  @StorageLink('nativeSafeRight') private safeRight: number = 0;
  @State private text: string = '';
  @State private title: string = '';
  @State private version: string = '';
  @State private lineLabel: string = '';
  @State private bytesLabel: string = '';
  @State private error: string = '';
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private downloading: boolean = false;
  @State private hasMore: boolean = false;
  @State private imageMap: image.PixelMap | null = null;
  @State private zoom: number = 1;
  @State private offsetX: number = 0;
  @State private offsetY: number = 0;
  @State private documentKind: string = 'unknown';
  @State private language: string = '';
  @State private mode: string = 'code';
  @State private canToggle: boolean = false;
  @State private lineStart: number = 1;
  @State private pdfUri: string = '';
  @State private pdfOpening: boolean = false;
  @State private pdfLoaded: boolean = false;
  @State private previewBusy: boolean = false;
  @State private markdownViewportHeight: number = 1;
  private source: image.ImageSource | null = null;
  private mounted: boolean = false;
  private textLoaded: boolean = false;
  private nextOffset: number = 1;
  private generation: number = 0;
  private expectedBytes: number = -1;
  private imageWidth: number = 1;
  private imageHeight: number = 1;
  private viewportWidth: number = 1;
  private viewportHeight: number = 1;
  private pinchStartZoom: number = 1;
  private pinchStartOffsetX: number = 0;
  private pinchStartOffsetY: number = 0;
  private pinchStartDistance: number = 0;
  private pinchStartMidX: number = 0;
  private pinchStartMidY: number = 0;
  private touchMode: string = 'none';
  private touchLastX: number = 0;
  private touchLastY: number = 0;
  private touchStartAt: number = 0;
  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private touchMoved: boolean = false;
  private lastTapAt: number = 0;
  private lastTapX: number = 0;
  private lastTapY: number = 0;
  private lastPinchEndedAt: number = 0;
  private readonly pdfController: pdfViewManager.PdfController = new pdfViewManager.PdfController();

  aboutToAppear(): void {
    this.mounted = true;
    this.reload();
  }
  aboutToDisappear(): void {
    this.mounted = false;
    this.generation++;
    this.releaseImage();
    this.releasePdf();
  }
  private enforceCacheLimit(): void {
    NativeStorageManager.enforceDefaultLimit(
      this.getUIContext().getHostContext() as common.UIAbilityContext,
      this.client.cacheKey(), this.sessionId).catch((): void => {});
  }
  private pathChanged(): void {
    if (this.mounted) this.reload();
  }
  private reload(): void {
    this.generation++;
    this.releaseImage();
    this.text = ''; this.textLoaded = false; this.nextOffset = 1; this.lineStart = 1;
    this.hasMore = false; this.error = ''; this.loading = true; this.loadingMore = false;
    this.version = ''; this.lineLabel = ''; this.bytesLabel = '';
    this.title = this.basename(this.path);
    this.expectedBytes = -1;
    this.zoom = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this.applyDescriptor(nativeDocumentDescriptor(this.path));
    this.releasePdf();
    this.pdfOpening = false;
    this.previewBusy = false;
    this.load(this.generation);
  }
  private applyDescriptor(value: NativeDocumentDescriptor): void {
    this.documentKind = value.kind;
    this.language = value.language;
    this.mode = value.defaultMode;
    this.canToggle = value.canToggle;
  }
  private basename(value: string): string {
    const parts = value.replace(/\\/g, '/').split('/');
    return parts[parts.length - 1] || value || '文件';
  }
  private releaseImage(): void {
    this.imageMap?.release();
    this.source?.release();
    this.imageMap = null;
    this.source = null;
  }
  private releasePdf(): void {
    try { this.pdfController.releaseDocument(); } catch (_) {}
    this.pdfLoaded = false;
    if (this.pdfUri) {
      try { fileIo.unlinkSync(this.pdfUri); } catch (_) {}
      this.pdfUri = '';
    }
  }
  private animate(action: () => void): void {
    NativeMotion.animate(this.getUIContext(), 'navigation', action);
  }
  private toggleImageDoubleTapZoom(tapX: number, tapY: number): void {
    if (this.touchMode === 'pinch' || Date.now() - this.lastPinchEndedAt < 450) return;
    const target: NativeImageZoomTarget = NativeImageZoom.doubleTap(
      this.zoom, tapX, tapY, this.viewportWidth, this.viewportHeight,
      this.imageWidth, this.imageHeight, this.offsetX, this.offsetY);
    NativeMotion.spring(this.getUIContext(), (): void => {
      this.zoom = target.zoom;
      this.offsetX = target.offsetX;
      this.offsetY = target.offsetY;
    });
  }
  private clampOffset(value: number, viewport: number, content: number): number {
    const limit = Math.max(0, (content - viewport) / 2);
    return Math.max(-limit, Math.min(limit, value));
  }
  private clampTranslation(x: number, y: number, zoom: number): void {
    const width = Math.max(1, this.viewportWidth);
    const height = Math.max(1, this.viewportHeight);
    const fit = Math.min(width / Math.max(1, this.imageWidth),
      height / Math.max(1, this.imageHeight));
    this.offsetX = this.clampOffset(x, width, this.imageWidth * fit * zoom);
    this.offsetY = this.clampOffset(y, height, this.imageHeight * fit * zoom);
  }
  private beginImagePinch(first: TouchObject, second: TouchObject): void {
    this.touchMode = 'pinch';
    this.pinchStartZoom = this.zoom;
    this.pinchStartOffsetX = this.offsetX;
    this.pinchStartOffsetY = this.offsetY;
    this.pinchStartDistance = Math.max(1, Math.hypot(second.x - first.x, second.y - first.y));
    this.pinchStartMidX = (first.x + second.x) / 2;
    this.pinchStartMidY = (first.y + second.y) / 2;
    this.touchMoved = true;
  }
  private updateImagePinchTouches(first: TouchObject, second: TouchObject): void {
    const distance = Math.max(1, Math.hypot(second.x - first.x, second.y - first.y));
    const midpointX = (first.x + second.x) / 2;
    const midpointY = (first.y + second.y) / 2;
    const nextZoom = Math.max(1, Math.min(5, this.pinchStartZoom * distance / this.pinchStartDistance));
    const startZoom = Math.max(0.001, this.pinchStartZoom);
    const startFocusX = this.pinchStartMidX - this.viewportWidth / 2;
    const startFocusY = this.pinchStartMidY - this.viewportHeight / 2;
    const focusX = midpointX - this.viewportWidth / 2;
    const focusY = midpointY - this.viewportHeight / 2;
    const ratio = nextZoom / startZoom;
    this.zoom = nextZoom;
    this.clampTranslation(
      focusX - (startFocusX - this.pinchStartOffsetX) * ratio,
      focusY - (startFocusY - this.pinchStartOffsetY) * ratio,
      nextZoom);
  }
  private beginImagePan(point: TouchObject): void {
    this.touchMode = 'pan';
    this.touchLastX = point.x;
    this.touchLastY = point.y;
  }
  private updateImagePan(point: TouchObject): void {
    const dx = point.x - this.touchLastX;
    const dy = point.y - this.touchLastY;
    this.touchLastX = point.x;
    this.touchLastY = point.y;
    if (this.zoom <= 1.001) return;
    this.clampTranslation(this.offsetX + dx, this.offsetY + dy, this.zoom);
  }
  private activeTouches(event: TouchEvent): TouchObject[] {
    const values: TouchObject[] = [];
    for (const point of event.touches) {
      if (point.type !== TouchType.Up && point.type !== TouchType.Cancel) values.push(point);
    }
    return values;
  }
  private finishImageTouch(event: TouchEvent, points: TouchObject[]): void {
    if (points.length >= 2) {
      this.beginImagePinch(points[0], points[1]);
      return;
    }
    if (points.length === 1) {
      this.lastPinchEndedAt = Date.now();
      this.beginImagePan(points[0]);
      return;
    }
    if (this.touchMode === 'pinch') this.lastPinchEndedAt = Date.now();
    if (!this.touchMoved && event.type === TouchType.Up) {
      const now = Date.now();
      if (now - this.touchStartAt < 300 &&
        now - this.lastTapAt < 320 &&
        Math.abs(this.touchStartX - this.lastTapX) < 32 &&
        Math.abs(this.touchStartY - this.lastTapY) < 32) {
        this.lastTapAt = 0;
        this.touchMode = 'none';
        this.toggleImageDoubleTapZoom(this.touchStartX, this.touchStartY);
        return;
      }
      this.lastTapAt = now;
      this.lastTapX = this.touchStartX;
      this.lastTapY = this.touchStartY;
    }
    this.touchMode = 'none';
  }
  private handleImageTouch(event: TouchEvent): void {
    event.stopPropagation();
    const points = this.activeTouches(event);
    if (event.type === TouchType.Down) {
      if (points.length >= 2) {
        this.lastTapAt = 0;
        this.beginImagePinch(points[0], points[1]);
      } else if (points.length === 1) {
        if (this.touchMode !== 'pan') {
          this.touchStartAt = Date.now();
          this.touchStartX = points[0].x;
          this.touchStartY = points[0].y;
          this.touchMoved = false;
          this.beginImagePan(points[0]);
        }
      }
      return;
    }
    if (event.type === TouchType.Move) {
      if (points.length >= 2) {
        if (this.touchMode !== 'pinch') this.beginImagePinch(points[0], points[1]);
        this.touchMoved = true;
        this.updateImagePinchTouches(points[0], points[1]);
      } else if (points.length === 1) {
        if (this.touchMode !== 'pan') {
          this.beginImagePan(points[0]);
          return;
        }
        if (Math.abs(points[0].x - this.touchStartX) > 7 ||
          Math.abs(points[0].y - this.touchStartY) > 7) this.touchMoved = true;
        this.updateImagePan(points[0]);
      }
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.finishImageTouch(event, points);
    }
  }
  private async load(generation: number): Promise<void> {
    if (!this.path || !this.sessionId) {
      this.error = '无法打开此文件';
      this.loading = false;
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const scope = this.client.cacheKey();
    try {
      if (this.documentKind === 'pdf') {
        await this.loadPdf(generation);
      } else if (this.documentKind === 'html') {
        await this.loadHtml(generation);
      } else if (this.documentKind === 'image' || (this.documentKind === 'svg' && this.mode === 'preview')) {
        const cachedImage = await this.loadCachedImage(generation, context, scope);
        if (!this.mounted || generation !== this.generation) return;
        if (cachedImage) {
          this.loading = false;
          let stat: NativeFileStat | null = null;
          try {
            stat = await this.loadMetadata(generation);
          } catch (error) {
            if (error instanceof NativeHttpError && error.status >= 400 && error.status < 500) {
              await NativeWorkspaceCache.removeEntry(
                context, scope, this.sessionId, this.path, false, false, true);
              this.releaseImage();
              this.error = '此文件不可用';
              return;
            } else {
              return;
            }
          }
          if (!this.mounted || generation !== this.generation) return;
          if (stat && stat.version === this.version) return;
        }
        const metadata = this.loadMetadata(generation).catch((): NativeFileStat | null => null);
        if (!await this.loadImageWithRetry(generation, false)) this.error = '无法预览此图片';
        await metadata;
      } else {
        const cachedText: NativeWorkspaceTextCacheEntry | null =
          await NativeWorkspaceCache.loadText(context, scope, this.sessionId, this.path);
        if (cachedText && this.mounted && generation === this.generation) {
          this.applyPage(cachedText.page, true);
          this.loading = false;
          let stat: NativeFileStat | null = null;
          try {
            stat = await this.loadMetadata(generation);
          } catch (error) {
            if (error instanceof NativeHttpError && error.status >= 400 && error.status < 500) {
              await NativeWorkspaceCache.removeEntry(
                context, scope, this.sessionId, this.path, false, true);
              this.text = '';
              this.textLoaded = false;
              this.version = '';
              this.lineLabel = '';
              this.error = '此文件不可用';
              return;
            } else {
              return;
            }
          }
          if (!this.mounted || generation !== this.generation) return;
          if (stat && stat.version === cachedText.page.version) return;
        } else {
          this.loadMetadata(generation).catch((): void => {});
        }
        try {
          const page = await this.loadText(true, generation);
          await NativeWorkspaceCache.saveText(
            context, scope, this.sessionId, this.path, page).catch((): void => {});
          this.enforceCacheLimit();
          if (this.documentKind === 'unknown') {
            this.documentKind = 'text';
            this.mode = 'code';
          }
        } catch (_) {
          if (generation === this.generation) this.error = '此文件仅支持下载';
        }
      }
    } catch (_) {
      if (this.mounted && generation === this.generation) this.error = '无法读取文件';
    } finally {
      if (this.mounted && generation === this.generation) this.loading = false;
    }
  }
  private async loadMetadata(generation: number): Promise<NativeFileStat> {
    const stat: NativeFileStat = await this.client.statFile(this.sessionId, this.path);
    if (!this.mounted || generation !== this.generation) return stat;
    this.expectedBytes = stat.bytes;
    if (!this.version) this.version = stat.version;
    this.bytesLabel = stat.bytes >= 0 ? this.formatBytes(stat.bytes) : '';
    return stat;
  }
  private async materializePdf(context: common.UIAbilityContext,
    content: NativeFileContent): Promise<string> {
    const path = context.cacheDir + '/dsh-pdf-' + util.generateRandomUUID() + '.pdf';
    const file = fileIo.openSync(path,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, content.bytes.buffer as ArrayBuffer);
    } finally {
      fileIo.closeSync(file);
    }
    return path;
  }
  private async openEmbeddedPdf(): Promise<void> {
    if (!this.pdfUri || this.pdfOpening || this.pdfLoaded) return;
    const target = this.pdfUri;
    this.pdfOpening = true;
    this.error = '';
    try {
      try { this.pdfController.releaseDocument(); } catch (_) {}
      const result = await this.pdfController.loadDocument(target);
      if (!this.mounted || target !== this.pdfUri) return;
      if (result !== pdfService.ParseResult.PARSE_SUCCESS) {
        this.error = result === pdfService.ParseResult.PARSE_ERROR_PASSWORD ?
          '此 PDF 需要密码' : '无法打开 PDF';
        return;
      }
      this.pdfController.setPageLayout(pdfService.PageLayout.LAYOUT_SINGLE);
      this.pdfController.setPageContinuous(true);
      this.pdfController.setPageFit(pdfService.PageFit.FIT_WIDTH);
      this.pdfController.enablePageDrag(true, true);
      this.pdfLoaded = true;
    } catch (_) {
      if (this.mounted) this.error = '无法打开 PDF';
    } finally {
      if (this.mounted) this.pdfOpening = false;
    }
  }
  private async loadPdf(generation: number): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const scope = this.client.cacheKey();
    let content: NativeFileContent | null = null;
    const cached: NativeWorkspaceCachedBinary | null =
      await NativeWorkspaceCache.loadBinary(context, scope, this.sessionId, this.path);
    if (cached && this.mounted && generation === this.generation) {
      content = new NativeFileContent();
      content.bytes = cached.bytes;
      content.version = cached.version;
      content.totalBytes = cached.totalBytes;
      this.version = cached.version;
      this.expectedBytes = cached.totalBytes;
      this.bytesLabel = cached.totalBytes >= 0 ? this.formatBytes(cached.totalBytes) : '';
    }
    let stat: NativeFileStat | null = null;
    try { stat = await this.loadMetadata(generation); } catch (_) {}
    if (!this.mounted || generation !== this.generation) return;
    if (!content || (stat && stat.version !== content.version)) {
      content = await NativeFileTransfer.readComplete(
        this.client, this.sessionId, this.path, previewPdfLimit,
        stat?.version || '', stat?.bytes === undefined ? -1 : stat.bytes);
      await NativeWorkspaceCache.saveBinary(context, scope, this.sessionId, this.path,
        content.bytes, content.version, content.totalBytes).catch((): void => {});
      this.enforceCacheLimit();
    }
    if (!this.mounted || generation !== this.generation) return;
    this.version = content.version;
    this.expectedBytes = content.totalBytes;
    this.bytesLabel = content.totalBytes >= 0 ? this.formatBytes(content.totalBytes) : '';
    this.releasePdf();
    this.pdfUri = await this.materializePdf(context, content);
    if (!this.mounted || generation !== this.generation) return;
    this.loading = false;
  }
  private async loadHtml(generation: number): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const scope = this.client.cacheKey();
    const cached: NativeWorkspaceTextCacheEntry | null =
      await NativeWorkspaceCache.loadText(context, scope, this.sessionId, this.path);
    if (cached && cached.page.eof && this.mounted && generation === this.generation) {
      this.applyPage(cached.page, true);
      this.loading = false;
    }
    let stat: NativeFileStat | null = null;
    try { stat = await this.loadMetadata(generation); } catch (_) {}
    if (!this.mounted || generation !== this.generation) return;
    if (cached?.page.eof && (!stat || stat.version === cached.page.version)) return;
    try {
      const content = await NativeFileTransfer.readComplete(
        this.client, this.sessionId, this.path, previewHtmlLimit,
        stat?.version || '', stat?.bytes === undefined ? -1 : stat.bytes);
      const page = new NativeFilePage();
      page.absolutePath = this.path;
      page.version = content.version;
      page.text = util.TextDecoder.create('utf-8').decodeToString(content.bytes);
      page.offset = 1;
      page.lines = page.text.replace(/\r\n|\r/g, '\n').split('\n').length;
      page.eof = true;
      if (!this.mounted || generation !== this.generation) return;
      this.applyPage(page, true);
      this.bytesLabel = content.totalBytes >= 0 ? this.formatBytes(content.totalBytes) : '';
      await NativeWorkspaceCache.saveText(
        context, scope, this.sessionId, this.path, page).catch((): void => {});
      this.enforceCacheLimit();
    } catch (_) {
      if (!cached && this.mounted && generation === this.generation) this.error = '无法读取网页';
    }
  }
  private async loadImage(generation: number, expectedVersion: string = this.version,
    expectedBytes: number = this.expectedBytes): Promise<boolean> {
    try {
      const content: NativeFileContent = await NativeFileTransfer.readComplete(
        this.client, this.sessionId, this.path, previewImageLimit, expectedVersion, expectedBytes);
      if (!this.mounted || generation !== this.generation || !content.bytes.byteLength) return false;
      if (!await this.decodeImageContent(content, generation)) return false;
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await NativeWorkspaceCache.saveBinary(context, this.client.cacheKey(), this.sessionId,
        this.path, content.bytes, content.version, content.totalBytes).catch((): void => {});
      this.enforceCacheLimit();
      return true;
    } catch (error) {
      console.error('NativeFilePreview image read failed: ' +
        (error instanceof Error ? error.message : String(error)));
      return false;
    }
  }
  private async decodeImageContent(content: NativeFileContent, generation: number): Promise<boolean> {
    let pending: image.ImageSource | null = null;
    let stage = 'source';
    try {
      pending = image.createImageSource(content.bytes.buffer as ArrayBuffer);
      stage = 'info';
      const info = await pending.getImageInfo();
      const width = Math.max(1, info.size.width);
      const height = Math.max(1, info.size.height);
      const scale = Math.min(1, 4096 / Math.max(width, height));
      stage = 'decode';
      const bitmap = await pending.createPixelMap({
        desiredSize: {
          width: Math.max(1, Math.round(width * scale)),
          height: Math.max(1, Math.round(height * scale))
        }
      });
      if (!this.mounted || generation !== this.generation) {
        bitmap.release();
        pending.release();
        return false;
      }
      this.releaseImage();
      this.source = pending;
      this.imageMap = bitmap;
      this.imageWidth = width;
      this.imageHeight = height;
      this.zoom = 1;
      this.offsetX = 0;
      this.offsetY = 0;
      this.version = content.version;
      this.expectedBytes = content.totalBytes;
      this.bytesLabel = content.totalBytes >= 0 ?
        this.formatBytes(content.totalBytes) : this.bytesLabel;
      this.error = '';
      return true;
    } catch (error) {
      console.error('NativeFilePreview image ' + stage + ' failed: ' +
        (error instanceof Error ? error.message : String(error)));
      pending?.release();
      return false;
    }
  }
  private async loadCachedImage(generation: number, context: common.UIAbilityContext,
    scope: string): Promise<boolean> {
    const cached: NativeWorkspaceCachedBinary | null =
      await NativeWorkspaceCache.loadBinary(context, scope, this.sessionId, this.path);
    if (!cached || !this.mounted || generation !== this.generation) return false;
    const content = new NativeFileContent();
    content.bytes = cached.bytes;
    content.version = cached.version;
    content.totalBytes = cached.totalBytes;
    return this.decodeImageContent(content, generation);
  }
  private async loadImageWithRetry(generation: number, allowCache: boolean = true): Promise<boolean> {
    if (allowCache && await this.loadCachedImage(generation,
      this.getUIContext().getHostContext() as common.UIAbilityContext, this.client.cacheKey())) return true;
    if (!this.mounted || generation !== this.generation) return false;
    if (await this.loadImage(generation)) return true;
    if (!this.mounted || generation !== this.generation) return false;
    await new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, 120);
    });
    if (!this.mounted || generation !== this.generation) return false;
    return this.loadImage(generation);
  }
  private async loadText(reset: boolean, generation: number = this.generation): Promise<NativeFilePage> {
    const page: NativeFilePage = await this.client.file(this.sessionId, this.path,
      reset ? 1 : this.nextOffset, 500);
    if (!this.mounted || generation !== this.generation) return page;
    this.applyPage(page, reset);
    return page;
  }
  private applyPage(page: NativeFilePage, reset: boolean): void {
    if (reset) {
      this.text = page.text;
      this.lineStart = page.offset;
    } else if (page.text) {
      this.text += (this.text ? '\n' : '') + page.text;
    }
    this.textLoaded = true;
    this.version = page.version;
    this.nextOffset = page.offset + Math.max(0, page.lines);
    this.hasMore = !page.eof;
    const loadedLines = reset ? page.lines :
      Math.max(0, this.nextOffset - this.lineStart);
    const end = this.lineStart + Math.max(0, loadedLines - 1);
    this.lineLabel = '第 ' + this.lineStart + '–' + end + ' 行' + (page.eof ? '' : ' · 可继续加载');
  }
  private persistedTextPage(page: NativeFilePage): NativeFilePage {
    const value = new NativeFilePage();
    value.absolutePath = page.absolutePath;
    value.version = page.version;
    value.text = this.text;
    value.offset = this.lineStart;
    value.lines = this.nextOffset - this.lineStart;
    value.eof = !this.hasMore;
    return value;
  }
  private async more(): Promise<void> {
    if (this.loadingMore || !this.hasMore) return;
    const generation = this.generation;
    this.loadingMore = true;
    try {
      const page = await this.loadText(false, generation);
      if (generation === this.generation) {
        this.version = page.version;
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        await NativeWorkspaceCache.saveText(context, this.client.cacheKey(), this.sessionId,
          this.path, this.persistedTextPage(page)).catch((): void => {});
        this.enforceCacheLimit();
      }
    } catch (_) {
      if (this.mounted && generation === this.generation) this.error = '读取更多内容失败';
    } finally {
      if (this.mounted && generation === this.generation) this.loadingMore = false;
    }
  }
  private changeMode(next: string): void {
    if (!this.canToggle || next === this.mode) return;
    const generation = this.generation;
    this.animate((): void => { this.mode = next; this.error = ''; });
    if (next === 'code' && !this.textLoaded) {
      this.loading = true;
      this.loadText(true, generation)
        .then(async (page: NativeFilePage): Promise<void> => {
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          await NativeWorkspaceCache.saveText(context, this.client.cacheKey(), this.sessionId,
            this.path, page).catch((): void => {});
          this.enforceCacheLimit();
        })
        .catch((): void => { if (generation === this.generation) this.error = '无法读取源代码'; })
        .finally((): void => { if (this.mounted && generation === this.generation) this.loading = false; });
    } else if (next === 'preview' && (this.documentKind === 'svg') && !this.imageMap) {
      this.loading = true;
      this.loadImageWithRetry(generation)
        .then((ok: boolean): void => { if (!ok && generation === this.generation) this.error = '无法预览此图片'; })
        .finally((): void => { if (this.mounted && generation === this.generation) this.loading = false; });
    }
  }
  private formatBytes(bytes: number): string {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / 1024 / 1024).toFixed(1) + ' MB';
  }
  private copy(): void {
    pasteboard.getSystemPasteboard().setData(
      pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.path)).catch((): void => {});
  }
  private async download(): Promise<void> {
    if (this.downloading) return;
    this.downloading = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const saved = await NativeFileTransfer.download(context, this.client, this.sessionId, this.path);
      if (saved && this.mounted) {
        this.getUIContext().getPromptAction().showToast({ message: '文件已保存', duration: 1300 });
      }
    } catch (_) {
      if (this.mounted) this.getUIContext().getPromptAction().showToast({ message: '保存文件失败', duration: 1500 });
    } finally {
      if (this.mounted) this.downloading = false;
    }
  }

  @Builder
  private header() {
    Column({ space: 5 }) {
      Row({ space: 4 }) {
        Column({ space: 1 }) {
          Row({ space: 6 }) {
            Text(this.title).fontSize(14).fontWeight(FontWeight.Medium).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
              .fontColor(NativeDesign.textPrimary(this.dark))
            if (this.loading || this.previewBusy || this.pdfOpening) {
              LoadingProgress().width(12).height(12)
                .color(NativeDesign.accent(this.dark))
                .accessibilityText('正在加载文件')
            }
          }.width('100%')
          if (this.lineLabel || this.bytesLabel) {
            Text([this.lineLabel, this.bytesLabel].filter((value: string) => !!value).join(' · '))
              .fontSize(10).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textTertiary(this.dark))
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        NativeIconButton({
          glyph: 'copy-outline', label: '复制文件路径', glyphSize: 15,
          onPressed: (): void => { this.copy(); }
        })
        if (this.downloading) {
          Stack({ alignContent: Alignment.Center }) {
            LoadingProgress().width(14).height(14).color(NativeDesign.accent(this.dark))
          }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget)
        } else {
          NativeIconButton({
            glyph: 'download-outline', label: '下载文件', glyphSize: 15,
            onPressed: (): void => { this.download(); }
          })
        }
        NativeIconButton({
          glyph: 'close-outline', label: '关闭预览', tone: 'primary', glyphSize: 15,
          onPressed: (): void => { this.onClose(); }
        })
      }.width('100%').height(NativeDesign.headerHeight)
      if (this.canToggle) {
        Row() {
          NativeDocumentModeSwitch({ mode: this.mode,
            onMode: (value: string): void => { this.changeMode(value); } })
          Blank()
        }.width('100%').height(32)
      }
    }.width('100%')
  }
  @Builder
  private imageBody() {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.imageMap).objectFit(ImageFit.Contain).width('100%').height('100%')
        .scale({ x: this.zoom, y: this.zoom })
        .translate({ x: this.offsetX, y: this.offsetY })
    }.layoutWeight(1).width('100%').clip(true)
      .onAreaChange((_old: Area, area: Area): void => {
        this.viewportWidth = Number(area.width);
        this.viewportHeight = Number(area.height);
        this.clampTranslation(this.offsetX, this.offsetY, this.zoom);
      })
      .onTouch((event: TouchEvent): void => { this.handleImageTouch(event); })
  }
  @Builder
  private textBody() {
    if (this.documentKind === 'html' && this.mode === 'preview') {
      NativeHtmlPreview({ client: this.client, sessionId: this.sessionId,
        source: this.text, path: this.path,
        onBusyChange: (busy: boolean): void => { this.previewBusy = busy; } })
        .layoutWeight(1).width('100%').clip(true)
    } else if (this.documentKind === 'markdown' && this.mode === 'preview') {
      Scroll() {
        Column() {
          NativeMarkdownPreview({ client: this.client, sessionId: this.sessionId,
            source: this.text })
            .width('100%')
        }.width('100%')
          .constraintSize({ minHeight: this.markdownViewportHeight })
          .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
          .align(Alignment.TopStart)
      }.layoutWeight(1).width('100%').scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.None)
        .align(Alignment.TopStart)
        .onAreaChange((_old: Area, area: Area): void => {
          this.markdownViewportHeight = Math.max(1, Number(area.height));
        })
    } else {
      NativeCodeViewer({ code: this.text || (this.loading ? '' : '空文件'),
        language: this.language, startNumber: this.lineStart, identity: this.path })
    }
  }
  @Builder
  private pdfBody() {
    Stack({ alignContent: Alignment.Center }) {
      PdfView({
        controller: this.pdfController,
        pageLayout: pdfService.PageLayout.LAYOUT_SINGLE,
        isContinuous: true,
        showScroll: true,
        pageFit: pdfService.PageFit.FIT_WIDTH
      }).width('100%').height('100%')
        .backgroundColor(NativeDesign.subtleSurface(this.dark))
        .onAppear((): void => { this.openEmbeddedPdf(); })
      if (this.pdfOpening) {
        LoadingProgress().width(24).height(24).color(NativeDesign.accent(this.dark))
      } else if (this.error) {
        Column({ space: 10 }) {
          Text(this.error).fontSize(12).fontColor(NativeDesign.danger(this.dark))
          Button({ type: ButtonType.Normal }) {
            Text('重试').fontSize(12).fontColor(NativeDesign.textPrimary(this.dark))
              .padding({ left: 12, right: 12 })
          }.height(NativeDesign.hitTarget).borderRadius(NativeDesign.radiusControl)
            .backgroundColor(NativeDesign.selection(this.dark))
            .onClick((): void => { this.openEmbeddedPdf(); })
        }.padding(NativeDesign.cardPadding).borderRadius(NativeDesign.radiusRow)
          .backgroundColor(NativeDesign.overlay(this.dark))
      }
    }.layoutWeight(1).width('100%').clip(true)
      .backgroundColor(NativeDesign.subtleSurface(this.dark))
  }
  @Builder
  private body() {
    if (this.loading) {
      Column({ space: 10 }) {
        LoadingProgress().width(24).height(24).color(NativeDesign.accent(this.dark))
        Text('正在读取…').fontSize(12).fontColor(NativeDesign.textTertiary(this.dark))
      }.layoutWeight(1).justifyContent(FlexAlign.Center)
    } else if (this.documentKind === 'pdf' && this.pdfUri) {
      this.pdfBody()
    } else if (this.error && !this.imageMap && !this.textLoaded) {
      Column({ space: 12 }) {
        Text(this.error).fontSize(13).textAlign(TextAlign.Center)
          .fontColor(NativeDesign.danger(this.dark))
        Button({ type: ButtonType.Normal }) {
          Row({ space: 5 }) {
            DSHIcon({ glyph: 'browse-outline', glyphSize: 15,
              color: NativeDesign.textPrimary(this.dark) })
            Text('重试').fontSize(12).fontColor(NativeDesign.textPrimary(this.dark))
          }.padding({ left: 8, right: 10 })
        }.height(NativeDesign.hitTarget).borderRadius(NativeDesign.radiusControl)
          .backgroundColor(NativeDesign.selection(this.dark))
          .accessibilityText('重试').onClick((): void => { this.reload(); })
      }.layoutWeight(1).justifyContent(FlexAlign.Center)
    } else if (this.imageMap) {
      this.imageBody()
    } else {
      this.textBody()
    }
  }
  build() {
    Column({ space: 8 }) {
      this.header()
      this.body()
      if (this.hasMore) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 5 }) {
            if (this.loadingMore) {
              LoadingProgress().width(14).height(14).color(NativeDesign.accent(this.dark))
            } else {
              DSHIcon({ glyph: 'chevron-left-outline', glyphSize: 12,
                color: NativeDesign.textTertiary(this.dark) }).rotate({ angle: -90 })
            }
            Text('加载更多').fontSize(11).fontColor(NativeDesign.textTertiary(this.dark))
          }
        }.height(NativeDesign.hitTarget).borderRadius(NativeDesign.radiusControl)
          .padding({ left: 9, right: 11 })
          .backgroundColor(NativeDesign.field(this.dark))
          .enabled(!this.loadingMore).accessibilityText('加载更多文件内容')
          .onClick((): void => { this.more(); })
      }
    }.padding({
      left: 12 + this.safeLeft, right: 12 + this.safeRight,
      top: 8 + this.safeTop, bottom: 12 + Math.max(16, this.safeBottom)
    }).width('100%').height('100%').backgroundColor(NativeDesign.base(this.dark))
      .transition(NativeMotion.previewTransition())
  }
}
