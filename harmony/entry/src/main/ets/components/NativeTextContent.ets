import { pasteboard } from '@kit.BasicServicesKit';
import { NativeTextSource } from '../services/NativeTextSource';
import { NativeInlineText } from './NativeInlineText';
import { NativeMarkdownTable, nativeMarkdownTable } from '../services/NativeMarkdownTable';
import { NativeTable } from './NativeTable';
import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeExperience } from '../services/NativeExperience';
import { NativeDesign } from '../services/NativeDesign';
import { NativeIconButton } from './NativeIconButton';
import { nativeRepairStreamingMarkdown } from '../services/NativeStreamMarkdown';
import {
  NativeStreamingMarkdownBuffer,
  NativeStreamingMarkdownUpdate
} from '../services/NativeStreamingMarkdown';
import { nativeSecretSpans } from '../services/NativeSecretMask';

class NativeStreamingSection {
  key: string = '';
  text: string = '';
  table: NativeMarkdownTable | null = null;
}

/** Full text is retained. Very long bodies open a virtualised native reader. */
@Component
export struct NativeTextContent {
  @Prop @Watch('changed') text: string = '';
  @Prop sourceText: string = '';
  @Prop @Watch('changed') streaming: boolean = false;
  @Prop @Watch('changed') maskSecrets: boolean = false;
  @Prop monospace: boolean = false;
  @Prop denseMonospace: boolean = false;
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
  @State private renderedText: string = '';
  @State private streamSections: NativeStreamingSection[] = [];
  @State private streamTail: string = '';
  @State private streamTailTable: NativeMarkdownTable | null = null;
  @State private streamTailPlain: boolean = false;
  @State private streamOverflow: boolean = false;
  private source: NativeTextSource = new NativeTextSource();
  private streamBuffer: NativeStreamingMarkdownBuffer = new NativeStreamingMarkdownBuffer();
  private streamStableLength: number = 0;
  private readonly streamInlineLimit: number = 8192;
  aboutToAppear(): void { this.changed(); }
  private tableFor(value: string): NativeMarkdownTable | null {
    return this.monospace ? null : nativeMarkdownTable(value);
  }
  private addStreamBlocks(blocks: string[]): void {
    if (!blocks.length) return;
    const sections = this.streamSections.slice();
    blocks.forEach((block: string): void => {
      if (this.streamStableLength >= this.streamInlineLimit) {
        this.streamOverflow = true;
        return;
      }
      const section = new NativeStreamingSection();
      section.key = sections.length.toString();
      section.text = block;
      section.table = this.tableFor(block);
      sections.push(section);
      this.streamStableLength += block.length;
    });
    this.streamSections = sections;
  }
  private updateStreaming(update: NativeStreamingMarkdownUpdate): void {
    if (update.reset) {
      this.streamSections = [];
      this.streamTail = '';
      this.streamTailTable = null;
      this.streamTailPlain = false;
      this.streamOverflow = false;
      this.streamStableLength = 0;
    }
    this.addStreamBlocks(update.appended);
    this.streamTailPlain = update.tailInFence || update.tail.length > 16384;
    this.streamTail = this.streamTailPlain ? update.tail :
      nativeRepairStreamingMarkdown(update.tail);
    this.streamTailTable = this.streamTailPlain ? null : this.tableFor(this.streamTail);
  }
  private changed(): void {
    if (!this.streaming) {
      this.streamBuffer = new NativeStreamingMarkdownBuffer();
      this.streamSections = [];
      this.streamTail = '';
      this.streamTailTable = null;
      this.streamTailPlain = false;
      this.streamOverflow = false;
      this.streamStableLength = 0;
      this.renderedText = this.text;
      this.source.set(this.renderedText,
        this.maskSecrets ? nativeSecretSpans(this.renderedText) : []);
      this.table = this.tableFor(this.renderedText);
      return;
    }
    const update = this.streamBuffer.update(this.text);
    if (update.changed) this.updateStreaming(update);
  }
  private openReader(): void {
    const authoritative = this.sourceText || this.text;
    const value = this.streaming ? nativeRepairStreamingMarkdown(authoritative) : authoritative;
    this.source.set(value, this.maskSecrets ? nativeSecretSpans(value) : []);
    this.table = this.tableFor(value);
    this.reading = true;
    this.copied = false;
  }
  @Builder
  private body(value: string, table: NativeMarkdownTable | null, plain: boolean) {
    if (!this.monospace && table) {
      NativeTable({ table: table, maskSecrets: this.maskSecrets,
        client: this.client, sessionId: this.sessionId })
    } else if (this.monospace || plain) {
      Text(value).width('100%')
        .fontSize(this.denseMonospace ? NativeDesign.fontMicro : NativeDesign.fontSection)
        .lineHeight(this.denseMonospace ? '16fp' : '22fp')
        .fontFamily('Noto Sans Mono, monospace').copyOption(CopyOptions.InApp)
        .fontColor(NativeDesign.textPrimary(this.dark))
    } else {
      NativeInlineText({ text: value, maskSecrets: this.maskSecrets,
        client: this.client, sessionId: this.sessionId })
    }
  }
  @Builder
  private streamingBody() {
    Column() {
      ForEach(this.streamSections, (section: NativeStreamingSection) => {
        this.body(section.text, section.table, false)
      }, (section: NativeStreamingSection) => section.key)
      if (this.streamTail) {
        // Render the live tail inline: a value-parameter @Builder does not
        // refresh when its argument changes, which froze paced text at the
        // first revealed character.
        if (!this.monospace && this.streamTailTable) {
          NativeTable({ table: this.streamTailTable, maskSecrets: this.maskSecrets,
            client: this.client, sessionId: this.sessionId })
        } else if (this.monospace || this.streamTailPlain) {
          Text(this.streamTail).width('100%')
            .fontSize(this.denseMonospace ? NativeDesign.fontMicro : NativeDesign.fontSection)
            .lineHeight(this.denseMonospace ? '16fp' : '22fp')
            .fontFamily('Noto Sans Mono, monospace').copyOption(CopyOptions.InApp)
            .fontColor(NativeDesign.textPrimary(this.dark))
        } else {
          NativeInlineText({ text: this.streamTail, maskSecrets: this.maskSecrets,
            client: this.client, sessionId: this.sessionId })
        }
      }
      if (this.streamOverflow) {
        Button('阅读已输出内容 · ' + this.text.length + ' 字符', { type: ButtonType.Normal })
          .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection)
          .borderRadius(NativeDesign.radiusControl)
          .backgroundColor(NativeDesign.field(this.dark))
          .fontColor(NativeDesign.textSecondary(this.dark))
          .onClick((): void => { this.openReader(); })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
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
          pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.sourceText || this.text))
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
            this.body(part, this.table, false)
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
      if (this.streaming) {
        this.streamingBody()
      } else {
        this.body(this.renderedText.length > 8192 ? this.source.getData(0) : this.renderedText,
          this.table, false)
        if (this.renderedText.length > 8192) {
          Button('阅读全文 · ' + this.text.length + ' 字符', { type: ButtonType.Normal })
            .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection)
            .borderRadius(NativeDesign.radiusControl)
            .backgroundColor(NativeDesign.field(this.dark))
            .fontColor(NativeDesign.textSecondary(this.dark))
            .onClick((): void => { this.openReader(); })
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .bindContentCover(this.reading, this.reader, {
        modalTransition: NativeExperience.reducedMotion() ? ModalTransition.NONE : ModalTransition.DEFAULT,
        onDisappear: (): void => { this.reading = false; }
      })
  }
}
