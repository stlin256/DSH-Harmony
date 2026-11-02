import { common } from '@kit.AbilityKit';
import { ColorMetrics } from '@kit.ArkUI';
import { drawing } from '@kit.ArkGraphics2D';
import {
  nativeInlineExternalLink,
  nativeInlineMarkdown,
  nativeInlineMarkdownMasked,
  NativeInlineRun
} from '../services/NativeInlineMarkdown';
import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { nativeBareFileName, nativeFileTarget, nativeLinkKind } from '../services/NativeLinkResolver';
import { NativeFileViewRequest } from '../services/NativeSessionModel';
import { NativeWorkspaceTarget } from '../services/NativeWorkspaceTarget';
import { NativeExperience } from '../services/NativeExperience';
import { NativeDesign } from '../services/NativeDesign';
import { NativeIconButton } from './NativeIconButton';

@Component
export struct NativeInlineText {
  @Prop @Watch('changed') text: string = '';
  @Prop textSize: number = 14;
  @Prop muted: boolean = false;
  @Prop alignment: string = 'left';
  @Prop lineHeight: string = '22fp';
  @Prop baseWeight: FontWeight = FontWeight.Normal;
  @Prop @Watch('changed') maskSecrets: boolean = false;
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @StorageLink('nativeSafeLeft') private safeLeft: number = 0;
  @StorageLink('nativeSafeRight') private safeRight: number = 0;
  @State private runs: NativeInlineRun[] = [];
  @State private remotePreview: boolean = false;
  @State private remoteUrl: string = '';
  @State private remoteTitle: string = '';
  @State private remoteError: string = '';
  private lastOpenHref: string = '';
  private lastOpenAt: number = 0;
  private fileRequestSequence: number = 0;
  private mounted: boolean = false;
  private pendingFileRequest: string = '';

  aboutToAppear(): void { this.mounted = true; this.changed(); }
  aboutToDisappear(): void {
    this.mounted = false;
    if (this.pendingFileRequest &&
      AppStorage.get<string>('nativeFileViewPendingRequest') === this.pendingFileRequest) {
      AppStorage.setOrCreate<string>('nativeFileViewPendingRequest', '');
    }
  }
  private changed(): void {
    this.runs = this.maskSecrets ? nativeInlineMarkdownMasked(this.text) : nativeInlineMarkdown(this.text);
  }
  private runColor(run: NativeInlineRun): ResourceColor {
    if (run.href) return NativeDesign.accent(this.dark);
    if (this.muted) return NativeDesign.textSecondary(this.dark);
    return NativeDesign.textPrimary(this.dark);
  }
  private runBackground(run: NativeInlineRun): TextBackgroundStyle {
    return { color: run.code ? NativeDesign.selection(this.dark) : Color.Transparent,
      radius: run.code ? NativeDesign.spaceXS - 1 : 0 };
  }
  private externalIconFilter(): drawing.ColorFilter {
    const color = ColorMetrics.resourceColor(NativeDesign.accent(this.dark));
    return drawing.ColorFilter.createBlendModeColorFilter({
      alpha: color.alpha,
      red: color.red,
      green: color.green,
      blue: color.blue
    }, drawing.BlendMode.SRC_IN);
  }
  private async open(run: NativeInlineRun): Promise<void> {
    if (!run.href) return;
    const now = Date.now();
    if (run.href === this.lastOpenHref && now - this.lastOpenAt < 350) return;
    this.lastOpenHref = run.href;
    this.lastOpenAt = now;
    try {
      const kind = nativeLinkKind(run.href);
      if (kind === 'http' && run.isImage) {
        this.remoteUrl = run.href; this.remoteTitle = run.alt || '图片'; this.remoteError = '';
        this.remotePreview = true;
        return;
      }
      if (kind === 'http' || kind === 'external') {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        await context.startAbility({ action: 'ohos.want.action.viewData', uri: run.href });
      } else {
        await this.openFile(run.href);
      }
    } catch (_) {
      this.getUIContext().getPromptAction().showToast({ message: '无法打开此链接', duration: 1500 });
    }
  }
  private fileTarget(href: string): string {
    return nativeFileTarget(href, this.client.sessionCwd(this.sessionId));
  }
  private fileRequestId(): string {
    this.fileRequestSequence++;
    const requestId = Date.now().toString(36) + ':' + this.fileRequestSequence;
    this.pendingFileRequest = requestId;
    AppStorage.setOrCreate<string>('nativeFileViewPendingRequest', requestId);
    return requestId;
  }
  private openFileView(kind: string, path: string, requestId: string): void {
    const request = new NativeFileViewRequest();
    request.kind = kind;
    request.sessionId = this.sessionId;
    request.path = path;
    request.requestId = requestId;
    request.previewOnly = kind === 'file';
    this.pendingFileRequest = '';
    AppStorage.setOrCreate<string>('nativeFileViewPendingRequest', '');
    AppStorage.setOrCreate<string>('nativeFileViewPayload', JSON.stringify(request));
    AppStorage.setOrCreate<number>('nativeFileViewRevision',
      (AppStorage.get<number>('nativeFileViewRevision') || 0) + 1);
  }
  private fileRequestActive(requestId: string): boolean {
    if (!this.mounted) return false;
    if (AppStorage.get<string>('nativeFileViewPendingRequest') === requestId) return true;
    try {
      const raw = AppStorage.get<string>('nativeFileViewPayload') || '';
      if (!raw) return false;
      const current = JSON.parse(raw) as NativeFileViewRequest;
      return current.requestId === requestId;
    } catch (_) {
      return false;
    }
  }
  private unavailableFile(requestId: string): void {
    if (!this.fileRequestActive(requestId)) return;
    this.pendingFileRequest = '';
    AppStorage.setOrCreate<string>('nativeFileViewPendingRequest', '');
    this.getUIContext().getPromptAction().showToast({ message: '文件或文件夹不可用', duration: 1500 });
  }
  private async openFile(href: string): Promise<void> {
    if (!this.sessionId) {
      this.getUIContext().getPromptAction().showToast({ message: '请先在会话中打开此链接', duration: 1500 });
      return;
    }
    const path = this.fileTarget(href);
    if (!path) return;
    const requestId = this.fileRequestId();
    try {
      const target: NativeWorkspaceTarget = await this.client.resolveWorkspaceTarget(
        this.sessionId, path, nativeBareFileName(href));
      if (!this.fileRequestActive(requestId)) return;
      if (!target.kind || !target.path) {
        this.unavailableFile(requestId);
        return;
      }
      this.openFileView(target.kind, target.path, requestId);
    } catch (_) {
      this.unavailableFile(requestId);
    }
  }
  @Builder
  private remoteImagePreview() {
    Column({ space: 8 }) {
      Row({ space: 4 }) {
        Text(this.remoteTitle || '图片').fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(NativeDesign.textPrimary(this.dark))
        NativeIconButton({
          glyph: 'close-outline', label: '关闭图片预览', tone: 'primary', glyphSize: NativeDesign.glyphControl,
          onPressed: (): void => { this.remotePreview = false; }
        })
      }.height(NativeDesign.headerHeight).width('100%')
      if (this.remoteError) {
        Text(this.remoteError).fontSize(NativeDesign.fontCompact).layoutWeight(1).textAlign(TextAlign.Center)
          .fontColor(NativeDesign.danger(this.dark))
      } else {
        Scroll() {
          Image(this.remoteUrl).objectFit(ImageFit.Contain).width('100%')
            .onError(() => { this.remoteError = '图片加载失败'; })
        }.scrollable(ScrollDirection.Free).layoutWeight(1).width('100%').align(Alignment.Center)
      }
    }.padding({
      left: 12 + this.safeLeft, right: 12 + this.safeRight,
      top: 8 + this.safeTop, bottom: 10 + this.safeBottom
    }).width('100%').height('100%').backgroundColor(NativeDesign.base(this.dark))
  }
  build() {
    Text() {
      ForEach(this.runs, (run: NativeInlineRun) => {
        Span(run.text).fontSize(run.code ? this.textSize - 1 : this.textSize)
          .fontWeight(run.bold ? FontWeight.Medium : this.baseWeight)
          .fontStyle(run.italic ? FontStyle.Italic : FontStyle.Normal)
          .fontFamily(run.code || run.secret ? 'Noto Sans Mono, monospace' : 'HarmonyOS Sans')
          .fontColor(this.runColor(run)).textBackgroundStyle(this.runBackground(run))
          .decoration({ type: run.strike ? TextDecorationType.LineThrough : run.href ? TextDecorationType.Underline : TextDecorationType.None })
          .onClick((): void => {
            if (run.href) this.open(run);
          })
        if (nativeInlineExternalLink(run.href)) {
          Span(' ').fontSize(Math.max(2, this.textSize - 8))
          ImageSpan($rawfile('dsh-icons/external-link-outline.svg'))
            .width(Math.max(9, this.textSize - 3)).height(Math.max(9, this.textSize - 3))
            .verticalAlign(ImageSpanAlignment.CENTER)
            .supportSvg2(true)
            .colorFilter(this.externalIconFilter())
            .onClick((): void => { this.open(run); })
        }
      }, (_run: NativeInlineRun, index: number) => index.toString())
    }.fontSize(this.textSize).lineHeight(this.lineHeight)
      .width('100%').wordBreak(WordBreak.BREAK_WORD)
      .textAlign(this.alignment === 'right' ? TextAlign.End : this.alignment === 'center' ? TextAlign.Center : TextAlign.Start)
      .bindContentCover(this.remotePreview, this.remoteImagePreview, {
        modalTransition: NativeExperience.reducedMotion() ? ModalTransition.NONE : ModalTransition.DEFAULT,
        onDisappear: (): void => { this.remotePreview = false; }
      })
  }
}
