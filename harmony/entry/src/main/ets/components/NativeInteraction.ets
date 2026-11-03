import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeFrame, NativeQuestion, NativeOption } from '../services/NativeSessionModel';
import { nativeStructuredText } from '../services/NativeInteractionFormat';
import { NativeTextContent } from './NativeTextContent';
import { DSHIcon } from './DSHIcon';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';
import { nativePermissionLabel, nativePermissionRequiresRisk } from '../services/NativePermissions';

class Answer {
  id: string = '';
  selected: string[] = [];
  custom: string = '';
  skipped: boolean = false;
}
class AnswerPayload { answers: Answer[] = []; }
class OperationAnswerPayload {
  operation: string = 'answerQuestion';
  sessionId: string = '';
  callId: string = '';
  answer: AnswerPayload = new AnswerPayload();
}
class ApprovalSubmissionPayload {
  connectionId: string = '';
  eventId: string = '';
  delegate: boolean = false;
  value: string = '';
}
class QuestionSubmissionPayload {
  connectionId: string = '';
  eventId: string = '';
  delegate: boolean = false;
  value: AnswerPayload = new AnswerPayload();
}

/** One compact, request-scoped approval or question surface. */
@Component
export struct NativeInteraction {
  client: NativeHarnessClient = new NativeHarnessClient('');
  @Prop frame: NativeFrame = new NativeFrame();
  onDone: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @State private answers: Answer[] = [];
  @State private index: number = 0;
  @State private remaining: number = -1;
  @State private busy: boolean = false;
  @State private unconfirmed: boolean = false;
  @State private error: string = '';
  private countdown: number = -1;
  private engaged: boolean = false;

  aboutToAppear(): void {
    this.remaining = this.frame.remainingMs === undefined ? -1 : this.frame.remainingMs;
    if (this.remaining >= 0) {
      this.countdown = setInterval(() => { this.remaining = Math.max(0, this.remaining - 1000); }, 1000);
    }
    this.answers = (this.frame.request.questions || []).map((question: NativeQuestion): Answer => {
      const answer = new Answer();
      answer.id = question.id;
      return answer;
    });
  }

  aboutToDisappear(): void { clearInterval(this.countdown); }

  private currentQuestion(): NativeQuestion | null {
    const questions = this.frame.request.questions || [];
    return questions.length > this.index ? questions[this.index] : null;
  }

  private answerFor(id: string): Answer {
    return this.answers.find((answer: Answer): boolean => answer.id === id) || new Answer();
  }

  private questionTitle(question: NativeQuestion): string {
    return nativeStructuredText(question.question);
  }

  private optionLabel(option: NativeOption): string {
    return nativeStructuredText(option.label);
  }

  private optionDescription(option: NativeOption): string {
    return nativeStructuredText(option.description);
  }

  private selected(id: string, label: string): boolean {
    return this.answerFor(id).selected.includes(label);
  }

  private answered(answer: Answer): boolean {
    return answer.skipped || answer.selected.length > 0 || answer.custom.trim().length > 0;
  }

  private approvalReason(): string {
    const request = this.frame.request;
    const localized = request.displayReason?.zh || request.displayReason?.en || '';
    return nativeStructuredText(localized || request.reason || '');
  }

  private approvalTarget(): string {
    const raw = (this.frame.request.targetPermission || this.frame.request.targetScope || '').trim();
    if (!raw) return '';
    if (raw === 'read-only' || raw === 'workspace-write' || raw === 'danger-full-access' || raw === 'auto') {
      return nativePermissionLabel(null, raw);
    }
    return raw.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').slice(0, 80);
  }

  private approvalRisk(): boolean {
    return nativePermissionRequiresRisk(this.frame.request.targetPermission) ||
      this.frame.request.targetScope === 'danger-full-access';
  }

  private engage(): void {
    if (this.engaged || this.remaining < 0 || this.frame.callId) return;
    this.engaged = true;
    clearInterval(this.countdown);
    this.remaining = -1;
    this.client.answer(JSON.stringify({
      connectionId: this.frame.connectionId,
      eventId: this.frame.eventId,
      engage: true
    })).catch((): void => {
      this.unconfirmed = true;
      this.error = '请求状态已变化，请刷新';
    });
  }

  private replaceAnswer(id: string, update: (value: Answer) => Answer): void {
    this.answers = this.answers.map((answer: Answer): Answer => answer.id === id ? update(answer) : answer);
  }

  private toggle(question: NativeQuestion, label: string): void {
    if (this.busy || this.unconfirmed) return;
    this.engage();
    this.replaceAnswer(question.id, (answer: Answer): Answer => {
      const next = new Answer();
      next.id = answer.id;
      next.custom = question.multiSelect ? answer.custom : '';
      next.skipped = false;
      next.selected = answer.selected.includes(label) ?
        answer.selected.filter((value: string): boolean => value !== label) :
        (question.multiSelect ? answer.selected.concat([label]) : [label]);
      return next;
    });
    if (!question.multiSelect && this.index < this.frame.request.questions.length - 1) {
      NativeMotion.animate(this.getUIContext(), 'micro', (): void => { this.index++; });
    }
  }

  private custom(question: NativeQuestion, text: string): void {
    if (this.busy || this.unconfirmed) return;
    this.engage();
    this.replaceAnswer(question.id, (answer: Answer): Answer => {
      const next = new Answer();
      next.id = answer.id;
      next.selected = question.multiSelect ? answer.selected : [];
      next.custom = text;
      next.skipped = false;
      return next;
    });
    this.error = '';
  }

  private move(next: number): void {
    const questions = this.frame.request.questions || [];
    if (next < 0 || next >= questions.length) return;
    NativeMotion.animate(this.getUIContext(), 'micro', (): void => { this.index = next; });
    this.error = '';
  }

  private async submit(value: string): Promise<void> {
    if (this.busy || this.unconfirmed) return;
    this.busy = true;
    this.error = '';
    let submitted = false;
    try {
      if (this.frame.interaction === 'approval/request') {
        const payload = new ApprovalSubmissionPayload();
        payload.connectionId = this.frame.connectionId;
        payload.eventId = this.frame.eventId;
        payload.value = value;
        await this.client.answer(JSON.stringify(payload));
        // The request is not settled until Host emits interaction-ended.
        submitted = true;
      } else if (this.frame.callId) {
        const payload = new OperationAnswerPayload();
        payload.sessionId = this.frame.connectionId;
        payload.callId = this.frame.callId;
        payload.answer.answers = this.answers;
        const result = await this.client.operation(JSON.stringify(payload));
        if (result !== 'true') throw new Error('Question no longer answerable');
      } else {
        const payload = new QuestionSubmissionPayload();
        payload.connectionId = this.frame.connectionId;
        payload.eventId = this.frame.eventId;
        payload.value.answers = this.answers;
        await this.client.answer(JSON.stringify(payload));
      }
      if (!submitted) this.onDone();
    } catch (_) {
      this.unconfirmed = true;
      this.error = '提交结果未确认，请刷新';
    } finally {
      if (!submitted) this.busy = false;
    }
  }

  private continueQuestions(): void {
    const question = this.currentQuestion();
    if (!question) return;
    const answer = this.answerFor(question.id);
    if (!this.answered(answer)) {
      this.error = '请选择一个选项或填写回答';
      return;
    }
    if (this.index < this.frame.request.questions.length - 1) {
      this.move(this.index + 1);
      return;
    }
    const missing = this.answers.findIndex((item: Answer): boolean => !this.answered(item));
    if (missing >= 0) {
      this.error = '还有问题未完成';
      this.move(missing);
      return;
    }
    this.submit('');
  }

  private skipQuestion(): void {
    const question = this.currentQuestion();
    if (!question) return;
    this.engage();
    this.replaceAnswer(question.id, (answer: Answer): Answer => {
      const next = new Answer();
      next.id = answer.id;
      next.skipped = true;
      return next;
    });
    if (this.index < this.frame.request.questions.length - 1) this.move(this.index + 1);
    else this.submit('');
  }

  @Builder
  private approvalCard() {
    Column({ space: 0 }) {
      Row({ space: 7 }) {
        if (this.busy) {
          LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
            .color(this.approvalRisk() ? NativeDesign.danger(this.dark) : NativeDesign.warning(this.dark))
        } else {
          Text('').width(8).height(8).borderRadius(4)
            .backgroundColor(this.approvalRisk() ? NativeDesign.danger(this.dark) : NativeDesign.warning(this.dark))
        }
        Text(this.busy ? '正在提交审批' : '等待审批').fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium)
          .fontColor(this.approvalRisk() ? NativeDesign.danger(this.dark) : NativeDesign.warning(this.dark))
        Blank()
        if (this.remaining >= 0) {
          Text(Math.ceil(this.remaining / 1000).toString() + 's').fontSize(NativeDesign.fontCaption)
            .fontColor(NativeDesign.textTertiary(this.dark))
        }
      }.width('100%').height(NativeDesign.compactChip).padding({ left: 12, right: 12 })
        .backgroundColor(this.approvalRisk() ?
          NativeDesign.dangerSurface(this.dark) : NativeDesign.warningSurface(this.dark))
      Scroll() {
        Column({ space: 7 }) {
          Row({ space: 6 }) {
            if (this.frame.request.toolName) {
              Text(this.frame.request.toolName).fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .borderRadius(NativeDesign.radiusBadge)
                .backgroundColor(NativeDesign.selection(this.dark))
                .fontColor(NativeDesign.textSecondary(this.dark))
            }
            if (this.approvalTarget()) {
              Text(this.approvalTarget()).fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .borderRadius(NativeDesign.radiusBadge)
                .backgroundColor(this.approvalRisk() ?
                  NativeDesign.dangerSurface(this.dark) : NativeDesign.warningSurface(this.dark))
                .fontColor(this.approvalRisk() ?
                  NativeDesign.danger(this.dark) : NativeDesign.warning(this.dark))
            }
          }.width('100%')
          Text(this.approvalReason() || '该工具请求执行需要你确认').fontSize(NativeDesign.fontBody)
            .fontWeight(FontWeight.Medium).fontColor(NativeDesign.textPrimary(this.dark))
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').constraintSize({ maxHeight: 220 }).scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.None).padding(12)
      Row({ space: 8 }) {
        Button({ type: ButtonType.Normal }) {
          Text('拒绝').fontSize(NativeDesign.fontCompact).fontWeight(FontWeight.Medium)
        }.layoutWeight(1).height(NativeDesign.compactHitTarget)
          .borderRadius(NativeDesign.radiusControl)
          .backgroundColor(NativeDesign.field(this.dark))
          .fontColor(NativeDesign.textPrimary(this.dark))
          .border({ width: 0.5, color: NativeDesign.border(this.dark) })
          .id('approval-reject')
          .enabled(!this.busy && !this.unconfirmed)
          .onClick((): void => { this.submit('rejected'); })
        Button({ type: ButtonType.Normal }) {
          if (this.busy) LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
            .color(NativeDesign.textInverse(this.dark))
          else Text('允许一次').fontSize(NativeDesign.fontCompact).fontWeight(FontWeight.Medium)
        }.layoutWeight(1).height(NativeDesign.compactHitTarget)
          .borderRadius(NativeDesign.radiusControl)
          .backgroundColor(this.approvalRisk() ?
            NativeDesign.danger(this.dark) : NativeDesign.accentStrong(this.dark))
          .fontColor(NativeDesign.textInverse(this.dark))
          .id('approval-allow-once')
          .enabled(!this.busy && !this.unconfirmed)
          .onClick((): void => { this.submit('allowed-once'); })
      }.width('100%').padding({ left: 12, right: 12, bottom: 8 })
    }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true)
      .backgroundColor(NativeDesign.overlay(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
  }

  @Builder
  private optionRow(question: NativeQuestion, option: NativeOption, optionIndex: number) {
    Row({ space: 9 }) {
      if (question.multiSelect) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.selected(question.id, option.label)) {
            DSHIcon({ glyph: 'check-outline', glyphSize: NativeDesign.glyphInline,
              color: NativeDesign.textInverse(this.dark) })
          }
        }.width(20).height(20).borderRadius(NativeDesign.radiusBadge)
          .backgroundColor(this.selected(question.id, option.label) ?
            NativeDesign.accentStrong(this.dark) : Color.Transparent)
          .border({ width: 1, color: this.selected(question.id, option.label) ?
            NativeDesign.accentStrong(this.dark) : NativeDesign.border(this.dark) })
      } else {
        Text((optionIndex + 1).toString()).fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
          .width(22).height(22).textAlign(TextAlign.Center)
          .fontColor(this.selected(question.id, option.label) ?
            NativeDesign.textInverse(this.dark) : NativeDesign.textSecondary(this.dark))
          .backgroundColor(this.selected(question.id, option.label) ?
            NativeDesign.accentStrong(this.dark) : NativeDesign.selection(this.dark))
          .borderRadius(11)
      }
      Column({ space: 3 }) {
        Text(this.optionLabel(option)).fontSize(NativeDesign.fontCompact).fontWeight(FontWeight.Medium)
          .fontColor(NativeDesign.textPrimary(this.dark)).width('100%')
        if (this.optionDescription(option)) {
          Text(this.optionDescription(option)).fontSize(NativeDesign.fontCaption).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textTertiary(this.dark)).width('100%')
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').constraintSize({ minHeight: NativeDesign.hitTarget })
      .padding({ left: 9, right: 9, top: 8, bottom: 8 })
      .borderRadius(NativeDesign.radiusRow)
      .backgroundColor(this.selected(question.id, option.label) ?
        NativeDesign.selectedSurface(this.dark) : Color.Transparent)
      .border({ width: this.selected(question.id, option.label) ? 0.8 : 0,
        color: NativeDesign.accentStrong(this.dark) })
      .enabled(!this.busy && !this.unconfirmed)
      .onClick((): void => { this.toggle(question, option.label); })
      .animation(NativeMotion.implicit('press'))
  }

  @Builder
  private questionCard(question: NativeQuestion) {
    Column({ space: 0 }) {
      Row({ space: 7 }) {
        Text(question.header ? nativeStructuredText(question.header) : '需要你的回答')
          .fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          .fontColor(NativeDesign.accent(this.dark))
        if (this.remaining >= 0) {
          Text(' · ' + Math.ceil(this.remaining / 1000).toString() + 's').fontSize(NativeDesign.fontCaption)
            .fontColor(NativeDesign.textTertiary(this.dark))
        }
      }.width('100%').height(NativeDesign.compactControl)
        .padding({ left: 12, right: 12, top: 6, bottom: 2 })
        .id('question-header-row')
      Scroll() {
        Column({ space: 10 }) {
          Text(this.questionTitle(question)).fontSize(NativeDesign.fontCompactTitle).fontWeight(FontWeight.Medium)
            .fontColor(NativeDesign.textPrimary(this.dark)).width('100%')
          if (question.detail) {
            NativeTextContent({ text: nativeStructuredText(question.detail),
              client: this.client, sessionId: this.frame.connectionId })
          }
          if ((question.options || []).length) {
            Column({ space: 2 }) {
              ForEach(question.options, (option: NativeOption, optionIndex: number) => {
                this.optionRow(question, option, optionIndex)
              }, (option: NativeOption) => question.id + ':' + option.label)
            }.width('100%')
          }
          if (question.intent?.kind !== 'approval') {
            Row({ space: 8 }) {
              if (question.multiSelect) {
                Stack({ alignContent: Alignment.Center }) {
                  if (this.answerFor(question.id).custom.trim()) {
                    DSHIcon({ glyph: 'check-outline', glyphSize: NativeDesign.glyphInline,
                      color: NativeDesign.textInverse(this.dark) })
                  }
                }.width(20).height(20).borderRadius(NativeDesign.radiusBadge)
                  .backgroundColor(this.answerFor(question.id).custom.trim() ?
                    NativeDesign.accentStrong(this.dark) : Color.Transparent)
                  .border({ width: 1, color: NativeDesign.border(this.dark) })
              } else {
                DSHIcon({ glyph: 'edit-outline', glyphSize: NativeDesign.glyphCompact,
                  color: this.answerFor(question.id).custom.trim() ?
                    NativeDesign.accent(this.dark) : NativeDesign.textTertiary(this.dark) })
              }
              TextArea({ text: this.answerFor(question.id).custom, placeholder: '自定义回答' })
                .layoutWeight(1).height(NativeDesign.compactHitTarget)
                .id('question-custom-answer')
                .fontSize(NativeDesign.fontCompact).borderRadius(NativeDesign.radiusCompact)
                .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                .align(Alignment.Center)
                .backgroundColor(NativeDesign.field(this.dark))
                .fontColor(NativeDesign.textPrimary(this.dark))
                .placeholderColor(NativeDesign.textTertiary(this.dark))
                .enabled(!this.busy && !this.unconfirmed)
                .onFocus((): void => { this.engage(); })
                .onChange((text: string): void => { this.custom(question, text); })
            }.width('100%')
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 12, right: 12, top: 4, bottom: 12 })
      }.width('100%').constraintSize({ maxHeight: 330 }).scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.None)
      Row({ space: 6 }) {
        Button({ type: ButtonType.Normal }) {
          DSHIcon({ glyph: 'chevron-left-outline', glyphSize: NativeDesign.glyphCompact,
            color: NativeDesign.textSecondary(this.dark) })
        }.width(NativeDesign.compactControl).height(NativeDesign.compactControl)
          .borderRadius(NativeDesign.radiusControl).backgroundColor(Color.Transparent)
          .enabled(this.index > 0 && !this.busy)
          .accessibilityText('上一题').onClick((): void => { this.move(this.index - 1); })
        Text((this.index + 1).toString() + ' / ' + this.frame.request.questions.length.toString())
          .fontSize(NativeDesign.fontCaption).fontColor(NativeDesign.textTertiary(this.dark))
        Button({ type: ButtonType.Normal }) {
          DSHIcon({ glyph: 'chevron-right-outline', glyphSize: NativeDesign.glyphCompact,
            color: NativeDesign.textSecondary(this.dark) })
        }.width(NativeDesign.compactControl).height(NativeDesign.compactControl)
          .borderRadius(NativeDesign.radiusControl).backgroundColor(Color.Transparent)
          .enabled(this.index < this.frame.request.questions.length - 1 && !this.busy)
          .accessibilityText('下一题').onClick((): void => { this.move(this.index + 1); })
        Blank()
        Row() {
          Text(question.intent?.reject || '跳过')
            .fontSize(NativeDesign.fontCaption).fontColor(NativeDesign.textSecondary(this.dark))
        }.height(NativeDesign.compactControl).padding({ left: 10, right: 10 })
          .justifyContent(FlexAlign.Center)
          .id('question-skip')
          .borderRadius(NativeDesign.radiusControl)
          .backgroundColor(NativeDesign.field(this.dark))
          .accessibilityText(question.intent?.reject || '跳过')
          .enabled(!this.busy && !this.unconfirmed).onClick((): void => { this.skipQuestion(); })
        Row() {
          if (this.busy) LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
            .color(NativeDesign.textInverse(this.dark))
          else Text(this.index < this.frame.request.questions.length - 1 ?
            '下一题' : (question.intent?.approve || '提交'))
            .fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
            .fontColor(NativeDesign.textInverse(this.dark))
        }.height(NativeDesign.compactControl).padding({ left: 10, right: 10 })
          .justifyContent(FlexAlign.Center)
          .id('question-submit')
          .borderRadius(NativeDesign.radiusControl)
          .backgroundColor(NativeDesign.accentStrong(this.dark))
          .accessibilityText(this.index < this.frame.request.questions.length - 1 ?
            '下一题' : (question.intent?.approve || '提交'))
          .enabled(!this.busy && !this.unconfirmed && this.answered(this.answerFor(question.id)))
          .opacity(this.answered(this.answerFor(question.id)) ? 1 : 0.42)
          .onClick((): void => { this.continueQuestions(); })
      }.width('100%').constraintSize({ minHeight: NativeDesign.compactHitTarget })
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    }.width('100%').borderRadius(NativeDesign.radiusGroup).clip(true)
      .id('question-card')
      .backgroundColor(NativeDesign.overlay(this.dark))
      .border({ width: 0.5, color: NativeDesign.border(this.dark) })
  }

  build() {
    Column({ space: 6 }) {
      if (this.frame.interaction === 'approval/request') {
        this.approvalCard()
      } else if (this.currentQuestion()) {
        ForEach([this.currentQuestion() as NativeQuestion], (question: NativeQuestion) => {
          this.questionCard(question)
        }, (question: NativeQuestion) => this.frame.eventId + ':' + question.id)
      }
      if (this.error) {
        Text(this.error).fontSize(NativeDesign.fontCaption).fontColor(NativeDesign.danger(this.dark))
          .padding({ left: 12, right: 12 })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .transition(NativeMotion.previewTransition())
  }
}
