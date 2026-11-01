import { NativeCodeToken, nativeHighlightCode } from '../services/NativeCodeHighlight';
import { NativeSourceLine, nativeSourceLines } from '../services/NativeDocumentModel';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';

/** Read-only source reader with a stable line-number gutter. */
@Component
export struct NativeCodeViewer {
  @Prop @Watch('changed') code: string = '';
  @Prop @Watch('changed') language: string = '';
  @Prop @Watch('changed') startNumber: number = 1;
  @Prop @Watch('identityChanged') identity: string = '';
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private lines: NativeSourceLine[] = [];
  @State private horizontalViewportWidth: number = 1;
  @State private horizontalContentWidth: number = 1;
  @State private horizontalTrackWidth: number = 1;
  @State private horizontalProgress: number = 0;
  @State private horizontalBarVisible: boolean = false;
  @State private viewerHeight: number = 1;
  private verticalScroller: Scroller = new Scroller();
  private horizontalScroller: Scroller = new Scroller();
  private resetTimer: number = -1;
  private horizontalBarHideTimer: number = -1;

  aboutToAppear(): void {
    this.changed();
    this.resetViewport();
  }
  aboutToDisappear(): void {
    clearTimeout(this.resetTimer);
    clearTimeout(this.horizontalBarHideTimer);
  }
  private changed(): void { this.lines = nativeSourceLines(this.code, this.startNumber); }
  private identityChanged(): void {
    this.changed();
    this.resetViewport();
  }
  private resetViewport(): void {
    clearTimeout(this.resetTimer);
    const reset = (): void => {
      try { this.verticalScroller.scrollEdge(Edge.Top); } catch (_) {}
      try { this.horizontalScroller.scrollEdge(Edge.Start); } catch (_) {}
      this.horizontalProgress = 0;
      this.horizontalBarVisible = false;
    };
    reset();
    this.resetTimer = setTimeout(reset, 32);
  }
  private color(kind: string): ResourceColor {
    if (kind === 'keyword') return this.dark ? '#C6A8FF' : '#7A3EB1';
    if (kind === 'string') return this.dark ? '#A8D8A1' : '#2E7D32';
    if (kind === 'comment') return this.dark ? '#858991' : '#777B82';
    if (kind === 'number' || kind === 'constant') return this.dark ? '#E5B76C' : '#9A5B00';
    if (kind === 'function') return this.dark ? '#8FC5FF' : '#185FA5';
    if (kind === 'type' || kind === 'property') return this.dark ? '#80D0D2' : '#08747A';
    if (kind === 'added') return this.dark ? '#86D59A' : '#137333';
    if (kind === 'removed') return this.dark ? '#FF9A9A' : '#B3261E';
    if (kind === 'punctuation') return this.dark ? '#B8BBC1' : '#5F646B';
    return this.dark ? '#E8E9EB' : '#202124';
  }
  private tokens(line: string): NativeCodeToken[] {
    return nativeHighlightCode(line, this.language);
  }
  private gutterWidth(): number {
    const digits = Math.max(2, String(this.startNumber + Math.max(0, this.lines.length - 1)).length);
    return digits * 8 + 18;
  }
  private contentHeight(): number {
    return Math.max(44, this.lines.length * 22 + 8);
  }
  private horizontalLaneHeight(): number {
    return this.horizontalOverflow() ? 12 : 0;
  }
  private workspaceHeight(): number {
    return Math.max(this.contentHeight() + this.horizontalLaneHeight(), this.viewerHeight, 1);
  }
  private horizontalOverflow(): boolean {
    return this.horizontalContentWidth > this.horizontalViewportWidth + 1;
  }
  private verticalOverflow(): boolean {
    return this.contentHeight() > this.viewerHeight + 1;
  }
  private horizontalThumbWidth(): number {
    const width = Math.max(1, this.horizontalTrackWidth);
    const viewport = Math.max(1, this.horizontalViewportWidth);
    const content = Math.max(viewport, this.horizontalContentWidth);
    return Math.max(28, width * viewport / content);
  }
  private horizontalThumbOffset(): number {
    return Math.max(0, this.horizontalTrackWidth - this.horizontalThumbWidth()) *
      Math.max(0, Math.min(1, this.horizontalProgress));
  }
  private updateHorizontalProgress(): void {
    try {
      const offset = Math.abs(this.horizontalScroller.currentOffset().xOffset);
      const maximum = Math.max(1, this.horizontalContentWidth - this.horizontalViewportWidth);
      this.horizontalProgress = Math.max(0, Math.min(1, offset / maximum));
    } catch (_) {
      this.horizontalProgress = 0;
    }
  }
  private showHorizontalBar(): void {
    clearTimeout(this.horizontalBarHideTimer);
    if (!this.horizontalBarVisible) {
      NativeMotion.animate(this.getUIContext(), 'micro', (): void => {
        this.horizontalBarVisible = true;
      });
    }
    this.horizontalBarHideTimer = setTimeout((): void => {
      NativeMotion.animate(this.getUIContext(), 'micro', (): void => {
        this.horizontalBarVisible = false;
      });
    }, NativeMotion.enabled() ? 900 : 0);
  }

  @Builder
  private bottomHorizontalScrollBar() {
    Row() {
      Stack({ alignContent: Alignment.Start }) {
        Row().width(this.horizontalThumbWidth()).height(3).borderRadius(1.5)
          .backgroundColor(NativeDesign.textTertiary(this.dark))
          .translate({ x: this.horizontalThumbOffset() })
      }.layoutWeight(1).height(3)
        .onAreaChange((_old: Area, area: Area): void => {
          this.horizontalTrackWidth = Math.max(1, Number(area.width));
        })
    }.width('100%').height(8).alignItems(VerticalAlign.Bottom)
      .padding({ left: this.gutterWidth() + 10, right: 10, bottom: 2 })
      .opacity(this.horizontalBarVisible ? 1 : 0)
      .hitTestBehavior(HitTestMode.Transparent)
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Scroll(this.verticalScroller) {
        Row() {
          Column({ space: 0 }) {
            ForEach(this.lines, (line: NativeSourceLine) => {
              Text(String(line.number)).width('100%').height(22).lineHeight(22)
                .fontSize(11).fontFamily('Noto Sans Mono, monospace').textAlign(TextAlign.End)
                .fontColor(NativeDesign.textTertiary(this.dark))
            }, (line: NativeSourceLine) => String(line.number))
          }.width(this.gutterWidth()).height(this.workspaceHeight())
            .padding({ top: 4, right: 10 })
            .border({ width: { right: 0.5 }, color: NativeDesign.divider(this.dark) })
          Scroll(this.horizontalScroller) {
            Column({ space: 0 }) {
              ForEach(this.lines, (line: NativeSourceLine) => {
                Text() {
                  ForEach(this.tokens(line.text), (token: NativeCodeToken) => {
                    Span(token.text).fontColor(this.color(token.kind))
                  }, (_token: NativeCodeToken, index: number) => index.toString())
                }.height(22).lineHeight(22).fontSize(12).maxLines(1)
                  .fontFamily('Noto Sans Mono, monospace').copyOption(CopyOptions.InApp)
                  .fontColor(NativeDesign.textPrimary(this.dark))
              }, (line: NativeSourceLine) => String(line.number))
            }.padding({ left: 10, top: 4, bottom: 4 }).alignItems(HorizontalAlign.Start)
              .onAreaChange((_old: Area, area: Area): void => {
                this.horizontalContentWidth = Math.max(1, Number(area.width));
                this.updateHorizontalProgress();
              })
          }.layoutWeight(1).height(this.workspaceHeight()).scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off).edgeEffect(EdgeEffect.None).align(Alignment.TopStart)
            .onAreaChange((_old: Area, area: Area): void => {
              this.horizontalViewportWidth = Math.max(1, Number(area.width));
              this.updateHorizontalProgress();
            })
            .onScroll((_xOffset: number, _yOffset: number): void => {
              this.updateHorizontalProgress();
              this.showHorizontalBar();
            })
            .onScrollStop((): void => {
              this.updateHorizontalProgress();
              this.showHorizontalBar();
            })
        }.width('100%').height(this.workspaceHeight())
          .alignItems(VerticalAlign.Top).align(Alignment.TopStart)
      }.width('100%').height('100%').scrollable(ScrollDirection.Vertical)
      .scrollBar(this.verticalOverflow() ? BarState.Auto : BarState.Off)
      .edgeEffect(EdgeEffect.None)
        .align(Alignment.TopStart)
      if (this.horizontalOverflow()) {
        this.bottomHorizontalScrollBar()
      }
    }.width('100%').layoutWeight(1).clip(true)
      .onAreaChange((_old: Area, area: Area): void => {
        this.viewerHeight = Math.max(1, Number(area.height));
      })
      .backgroundColor(NativeDesign.subtleSurface(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
      .borderRadius(NativeDesign.radiusControl)
  }
}
