import { pasteboard } from '@kit.BasicServicesKit';
import { NativeTextContent } from './NativeTextContent';
import { DSHIcon } from './DSHIcon';
import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeImageView } from './NativeImageView';
import { NativeImageStrip } from './NativeImageStrip';
import { NativeExperience } from '../services/NativeExperience';
import { nativeReasoningPreview } from '../services/NativeTranscript';
import { NativeMessage, NativeTextBlock, NativeImageAttachment } from '../services/NativeSessionModel';
import { NativeInlineText } from './NativeInlineText';
import { NativeCodeBlock } from './NativeCodeBlock';
import { NativeDshUiCard } from './NativeDshUiCard';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';
import { nativeDshUiReplyLabel } from '../services/NativeDshUi';

@Component
export struct NativeMessageView {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  disclosures: Map<string, boolean> = new Map<string, boolean>();
  @Prop preview: boolean = true;
  @Prop runningReasoning: boolean = false;
  @Prop dshUiCanReply: boolean = false;
  onCompatibility: () => void = (): void => {};
  onDshUiReply: (text: string) => Promise<boolean> =
    async (_text: string): Promise<boolean> => false;
  @Prop message: NativeMessage = new NativeMessage();
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private reasoningOpen: boolean = false;
  @State private toolOpen: boolean = false;
  aboutToAppear(): void {
    this.reasoningOpen = this.disclosures.get(this.message.turnKey + '|' + this.message.id) === true;
    this.toolOpen = true;
  }

  private copyMessage(): void {
    const text = this.message.text || this.message.blocks.map((block: NativeTextBlock) => block.text).join('\n');
    if (!text) return;
    pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text))
      .then((): void => {
        this.getUIContext().getPromptAction().showToast({ message: '已复制', duration: 900 });
      }).catch((): void => {});
  }

  private hasCopyableText(): boolean {
    return this.message.role === 'user' && (!!this.message.text || this.message.blocks.length > 0);
  }

  private dshUiReplyLabel(): string {
    return this.message.role === 'user' ? nativeDshUiReplyLabel(this.message.text) : '';
  }

  private animate(action: () => void): void {
    NativeMotion.animate(this.getUIContext(), 'micro', action);
  }

  build() {
    Column({ space: 6 }) {
      if (this.message.role !== 'user' && this.message.role !== 'assistant' && this.message.role !== 'tool' && this.message.role !== 'reasoning') {
        Text(this.message.label).fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(NativeDesign.textSecondary(this.dark))
      }
      if (this.message.reasoning) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            DSHIcon({ glyph: 'chevron-left-outline',
              color: NativeDesign.textTertiary(this.dark), glyphSize: 12 })
              .rotate({ angle: this.reasoningOpen ? -90 : 180 })
            Text('思考过程').fontSize(12)
            if (!this.reasoningOpen && this.preview) {
              Text(nativeReasoningPreview(this.message.reasoning, this.runningReasoning)).fontSize(12).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            }
          }.width('100%')
        }.width('100%').height(NativeDesign.hitTarget).padding(0)
          .fontSize(NativeDesign.fontBody).borderRadius(NativeDesign.radiusCompact)
          .backgroundColor(Color.Transparent)
          .fontColor(NativeDesign.textSecondary(this.dark))
          .onClick(() => { this.animate(() => { this.reasoningOpen = !this.reasoningOpen;
            this.disclosures.set(this.message.turnKey + '|' + this.message.id, this.reasoningOpen); }); })
        if (this.reasoningOpen) {
          NativeTextContent({ text: this.message.reasoning, client: this.client, sessionId: this.sessionId })
        }
      }
      if (this.message.role === 'tool') {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            DSHIcon({ glyph: 'chevron-left-outline',
              color: NativeDesign.textTertiary(this.dark), glyphSize: 12 })
              .rotate({ angle: this.toolOpen ? -90 : 180 })
            Text(this.message.label).fontSize(12).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.height(NativeDesign.hitTarget).fontSize(NativeDesign.fontBody)
          .borderRadius(NativeDesign.radiusCompact).backgroundColor(Color.Transparent)
          .fontColor(NativeDesign.textSecondary(this.dark))
          .onClick(() => { this.animate(() => { this.toolOpen = !this.toolOpen; }); })
      }
      if (this.dshUiReplyLabel()) {
        Row({ space: 6 }) {
          DSHIcon({ glyph: 'check-outline', glyphSize: 13,
            color: NativeDesign.accent(this.dark) })
          Text(this.dshUiReplyLabel()).fontSize(11).fontWeight(FontWeight.Medium)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.accent(this.dark))
        }.constraintSize({ minHeight: 30 }).padding({ left: 10, right: 12, top: 6, bottom: 6 })
          .borderRadius(15).backgroundColor(NativeDesign.accentSurface(this.dark))
      } else if (this.message.role !== 'tool' || this.toolOpen) {
        if (!this.message.blocks.length && this.message.text) { NativeTextContent({ text: this.message.text, client: this.client, sessionId: this.sessionId }) }
        ForEach(this.message.blocks, (block: NativeTextBlock) => {
          if (block.kind === 'code') {
            if ((block.language || '').trim().toLowerCase() === 'dsh-ui') {
              NativeDshUiCard({
                source: block.text,
                canReply: this.dshUiCanReply,
                onReply: this.onDshUiReply
              })
            } else {
              NativeCodeBlock({ code: block.text, language: block.language })
            }
          } else if (block.kind === 'heading') {
            NativeInlineText({ text: block.text, textSize: 18, lineHeight: '28fp',
              baseWeight: FontWeight.Medium, client: this.client, sessionId: this.sessionId })
          } else if (block.kind === 'quote') {
            Column() {
              NativeInlineText({ text: block.text, textSize: 13, muted: true,
                client: this.client, sessionId: this.sessionId })
            }.padding(NativeDesign.spaceM).borderRadius(NativeDesign.radiusRow)
              .backgroundColor(NativeDesign.field(this.dark))
          } else {
            NativeTextContent({ text: block.text, client: this.client, sessionId: this.sessionId })
          }
        }, (_block: NativeTextBlock, index: number) => index.toString())
      }
      if (this.message.images?.length) {
        if (this.message.role === 'user') {
          NativeImageStrip({
            client: this.client,
            sessionId: this.sessionId,
            attachments: this.message.images,
            thumbnailSize: 72,
            trailingInset: 0
          })
        } else {
          ForEach(this.message.images, (attachment: NativeImageAttachment) => {
            NativeImageView({ client: this.client, sessionId: this.sessionId, attachment })
          }, (attachment: NativeImageAttachment) => attachment.attachmentId)
        }
      }
      if (this.message.role === 'notice') {
        Button('打开完整交互', { type: ButtonType.Normal })
          .height(NativeDesign.hitTarget).fontSize(NativeDesign.fontBody)
          .borderRadius(NativeDesign.radiusControl)
          .backgroundColor(NativeDesign.field(this.dark))
          .fontColor(NativeDesign.textPrimary(this.dark))
          .onClick(this.onCompatibility)
      }
      if (!this.message.text && !this.message.reasoning && !this.message.images?.length) {
        Text('此消息暂不支持原生显示。').fontSize(13)
          .fontColor(NativeDesign.textSecondary(this.dark))
      }
    }.alignItems(HorizontalAlign.Start)
      .width(this.dshUiReplyLabel() ? 'auto' : this.message.role === 'user' ? '82%' : '100%')
      .padding(this.dshUiReplyLabel() ? 0 :
        this.message.role === 'user' || this.message.role === 'tool' ? 10 :
          this.message.role === 'reasoning' ? 0 : 2)
      .backgroundColor((this.message.role === 'user' && !this.dshUiReplyLabel()) ||
        this.message.role === 'tool' ? NativeDesign.field(this.dark) : Color.Transparent)
      .borderRadius(NativeDesign.radiusGroup)
      .accessibilityText(this.hasCopyableText() ? '消息，长按复制' : '')
      .gesture(
        LongPressGesture({ repeat: false })
          .onAction((): void => {
            if (this.hasCopyableText()) this.copyMessage();
          })
      )
  }
}
