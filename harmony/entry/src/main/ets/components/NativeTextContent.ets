import { pasteboard } from '@kit.BasicServicesKit';
import { NativeTextSource } from '../services/NativeTextSource';
import { NativeInlineText } from './NativeInlineText';
import { NativeMarkdownTable, nativeMarkdownTable } from '../services/NativeMarkdownTable';
import { NativeTable } from './NativeTable';
import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeExperience } from '../services/NativeExperience';
import { NativeDesign } from '../services/NativeDesign';
import { NativeIconButton } from './NativeIconButton';

/** Full text is retained. Very long bodies open a virtualised native reader. */
@Component
export struct NativeTextContent {
  @Prop @Watch('changed') text: string = '';
  @Prop monospace: boolean = false;
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @StorageLink('nativeSafeLeft') private safeLeft: number = 0;
  @StorageLink('nativeSafeRight') private safeRight: number = 0;
  @State private reading: boolean = false;
  @State private copied: boolean = false;
  @State private table: NativeMarkdownTable | null = null;
  private source: NativeTextSource = new NativeTextSource();
  aboutToAppear(): void { this.changed(); }
  private changed(): void {
    this.source.set(this.text);
    this.table = this.monospace ? null : nativeMarkdownTable(this.text);
  }
  @Builder
  private body(value: string) {
    if (!this.monospace && this.table) {
      NativeTable({ table: this.table, client: this.client, sessionId: this.sessionId })
    } else if (this.monospace) {
      Text(value).width('100%').fontSize(NativeDesign.fontSection).lineHeight('22fp')
        .fontFamily('Noto Sans Mono, monospace').copyOption(CopyOptions.InApp)
        .fontColor(NativeDesign.textPrimary(this.dark))
    } else {
      NativeInlineText({ text: value, client: this.client, sessionId: this.sessionId })
    }
  }
  @Builder
  private reader() {
    Column({ space: 12 }) {
      Row({ space: 4 }) {
        Text('完整内容').fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).layoutWeight(1)
          .fontColor(NativeDesign.textPrimary(this.dark))
        NativeIconButton({
          glyph: this.copied ? 'check-outline' : 'copy-outline',
          label: this.copied ? '已复制全文' : '复制全文',
          glyphSize: NativeDesign.glyphControl,
          onPressed: (): void => {
          pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.text))
            .then(() => { this.copied = true; }).catch(() => { this.copied = false; });
          }
        })
        NativeIconButton({
          glyph: 'close-outline', label: '关闭完整内容', tone: 'primary', glyphSize: NativeDesign.glyphControl,
          onPressed: (): void => { this.reading = false; }
        })
      }.width('100%').height(NativeDesign.headerHeight)
      List() {
        LazyForEach(this.source, (part: string) => {
          ListItem() {
            this.body(part)
          }
        }, (_part: string, index: number) => index.toString())
      }.layoutWeight(1).width('100%').cachedCount(4)
    }.padding({
      left: 12 + this.safeLeft, right: 12 + this.safeRight,
      top: 8 + this.safeTop, bottom: 10 + this.safeBottom
    }).width('100%').height('100%').backgroundColor(NativeDesign.base(this.dark))
  }
  build() {
    Column({ space: 8 }) {
      this.body(this.text.length > 8192 ? this.source.getData(0) : this.text)
      if (this.text.length > 8192) {
        Button('阅读全文 · ' + this.text.length + ' 字符', { type: ButtonType.Normal })
          .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection)
          .borderRadius(NativeDesign.radiusControl)
          .backgroundColor(NativeDesign.field(this.dark))
          .fontColor(NativeDesign.textSecondary(this.dark))
          .onClick(() => { this.reading = true; this.copied = false; })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .bindContentCover(this.reading, this.reader, {
        modalTransition: NativeExperience.reducedMotion() ? ModalTransition.NONE : ModalTransition.DEFAULT,
        onDisappear: (): void => { this.reading = false; }
      })
  }
}
