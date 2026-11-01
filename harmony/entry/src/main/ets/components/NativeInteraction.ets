import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeFrame, NativeQuestion, NativeOption } from '../services/NativeSessionModel';
import { nativeStructuredText } from '../services/NativeInteractionFormat';
import { NativeTextContent } from './NativeTextContent';
import { DSHIcon } from './DSHIcon';
import { NativeMotion } from '../services/NativeMotion';

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
    try {
      if (this.frame.callId) {
        const payload = new OperationAnswerPayload();
        payload.sessionId = this.frame.connectionId;
        payload.callId = this.frame.callId;
        payload.answer.answers = this.answers;
        const result = await this.client.operation(JSON.stringify(payload));
        if (result !== 'true') throw new Error('Question no longer answerable');
      } else if (this.frame.interaction === 'approval/request') {
        const payload = new ApprovalSubmissionPayload();
        payload.connectionId = this.frame.connectionId;
        payload.eventId = this.frame.eventId;
        payload.value = value;
        await this.client.answer(JSON.stringify(payload));
      } else {
        const payload = new QuestionSubmissionPayload();
        payload.connectionId = this.frame.connectionId;
        payload.eventId = this.frame.eventId;
        payload.value.answers = this.answers;
        await this.client.answer(JSON.stringify(payload));
      }
      this.onDone();
    } catch (_) {
      this.unconfirmed = true;
      this.error = '提交结果未确认，请刷新';
    } finally {
      this.busy = false;
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
        Circle().width(7).height(7).backgroundColor(this.dark ? '#F0B84A' : '#A56A00')
        Text('等待审批').fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(this.dark ? '#F0B84A' : '#8A5A00')
        Blank()
        if (this.remaining >= 0) {
          Text(Math.ceil(this.remaining / 1000).toString() + 's').fontSize(11)
            .fontColor(this.dark ? '#B5B8BD' : '#777A80')
        }
      }.width('100%').height(34).padding({ left: 12, right: 12 })
        .backgroundColor(this.dark ? '#3C3426' : '#FFF7E7')
      Scroll() {
        Column({ space: 7 }) {
          if (this.frame.request.toolName) {
            Text(this.frame.request.toolName).fontSize(11).fontWeight(FontWeight.Medium)
              .padding({ left: 7, right: 7, top: 3, bottom: 3 }).borderRadius(7)
              .backgroundColor(this.dark ? '#353638' : '#F0F2F5')
              .fontColor(this.dark ? '#CFD3D6' : '#61666B')
          }
          Text(this.approvalReason() || '该工具请求执行需要你确认').fontSize(14)
            .fontWeight(FontWeight.Medium).fontColor(this.dark ? '#F9FAFB' : '#17181B')
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').constraintSize({ maxHeight: 220 }).scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.None).padding(12)
      Row({ space: 8 }) {
        Button({ type: ButtonType.Normal }) {
          Text('拒绝').fontSize(13).fontWeight(FontWeight.Medium)
        }.layoutWeight(1).height(38).borderRadius(11)
          .backgroundColor(this.dark ? '#353638' : '#F5F6F7')
          .fontColor(this.dark ? '#F1F1F2' : '#25262A')
          .border({ width: 0.5, color: this.dark ? '#4A4B4F' : '#DDE0E5' })
          .enabled(!this.busy && !this.unconfirmed)
          .onClick((): void => { this.submit('rejected'); })
        Button({ type: ButtonType.Normal }) {
          if (this.busy) LoadingProgress().width(15).height(15).color('#FFFFFF')
          else Text('允许一次').fontSize(13).fontWeight(FontWeight.Medium)
        }.layoutWeight(1).height(38).borderRadius(11)
          .backgroundColor(this.dark ? '#679EFE' : '#3964FE').fontColor('#FFFFFF')
          .enabled(!this.busy && !this.unconfirmed)
          .onClick((): void => { this.submit('allowed-once'); })
      }.width('100%').padding({ left: 12, right: 12, bottom: 12 })
    }.width('100%').borderRadius(15).clip(true)
      .backgroundColor(this.dark ? '#292A2C' : '#FFFFFF')
      .border({ width: 0.5, color: this.dark ? '#414247' : '#E1E3E7' })
  }

  @Builder
  private optionRow(question: NativeQuestion, option: NativeOption, optionIndex: number) {
    Row({ space: 9 }) {
      if (question.multiSelect) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.selected(question.id, option.label)) {
            DSHIcon({ glyph: 'check-outline', glyphSize: 11, color: '#FFFFFF' })
          }
        }.width(20).height(20).borderRadius(6)
          .backgroundColor(this.selected(question.id, option.label) ?
            this.dark ? '#679EFE' : '#3964FE' : Color.Transparent)
          .border({ width: 1, color: this.selected(question.id, option.label) ?
            this.dark ? '#679EFE' : '#3964FE' : this.dark ? '#6B6E73' : '#B8BDC5' })
      } else {
        Text((optionIndex + 1).toString()).fontSize(11).fontWeight(FontWeight.Medium)
          .width(22).height(22).textAlign(TextAlign.Center)
          .fontColor(this.selected(question.id, option.label) ? '#FFFFFF' :
            this.dark ? '#B5B8BD' : '#61666B')
          .backgroundColor(this.selected(question.id, option.label) ?
            this.dark ? '#679EFE' : '#3964FE' : this.dark ? '#353638' : '#EEF0F3')
          .borderRadius(11)
      }
      Column({ space: 3 }) {
        Text(this.optionLabel(option)).fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor(this.dark ? '#F1F1F2' : '#25262A').width('100%')
        if (this.optionDescription(option)) {
          Text(this.optionDescription(option)).fontSize(11).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(this.dark ? '#A2A5AA' : '#777A80').width('100%')
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 9, right: 9, top: 8, bottom: 8 }).borderRadius(11)
      .backgroundColor(this.selected(question.id, option.label) ?
        this.dark ? '#303942' : '#F1F5FF' : Color.Transparent)
      .border({ width: this.selected(question.id, option.label) ? 0.8 : 0,
        color: this.dark ? '#679EFE' : '#3964FE' })
      .enabled(!this.busy && !this.unconfirmed)
      .onClick((): void => { this.toggle(question, option.label); })
      .animation(NativeMotion.implicit('press'))
  }

  @Builder
  private questionCard(question: NativeQuestion) {
    Column({ space: 0 }) {
      Row({ space: 7 }) {
        Text(question.header ? nativeStructuredText(question.header) : '需要你的回答')
          .fontSize(11).fontWeight(FontWeight.Medium).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          .fontColor(this.dark ? '#8AB4FF' : '#315ECA')
        Text((this.index + 1).toString() + ' / ' + this.frame.request.questions.length.toString())
          .fontSize(11).fontColor(this.dark ? '#93969B' : '#8A8D91')
        if (this.remaining >= 0) {
          Text(' · ' + Math.ceil(this.remaining / 1000).toString() + 's').fontSize(11)
            .fontColor(this.dark ? '#B5B8BD' : '#777A80')
        }
      }.width('100%').height(34).padding({ left: 12, right: 12 })
      Scroll() {
        Column({ space: 10 }) {
          Text(this.questionTitle(question)).fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor(this.dark ? '#F9FAFB' : '#17181B').width('100%')
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
                    DSHIcon({ glyph: 'check-outline', glyphSize: 11, color: '#FFFFFF' })
                  }
                }.width(20).height(20).borderRadius(6)
                  .backgroundColor(this.answerFor(question.id).custom.trim() ?
                    this.dark ? '#679EFE' : '#3964FE' : Color.Transparent)
                  .border({ width: 1, color: this.dark ? '#6B6E73' : '#B8BDC5' })
              } else {
                DSHIcon({ glyph: 'edit-outline', glyphSize: 14,
                  color: this.answerFor(question.id).custom.trim() ?
                    this.dark ? '#8AB4FF' : '#3964FE' : this.dark ? '#93969B' : '#8A8D91' })
              }
              TextArea({ text: this.answerFor(question.id).custom, placeholder: '自定义回答' })
                .layoutWeight(1).height(44).fontSize(13).borderRadius(10)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(this.dark ? '#353638' : '#F5F6F7')
                .fontColor(this.dark ? '#F9FAFB' : '#17181B')
                .placeholderColor(this.dark ? '#93969B' : '#8A8D91')
                .enabled(!this.busy && !this.unconfirmed)
                .onFocus((): void => { this.engage(); })
                .onChange((text: string): void => { this.custom(question, text); })
            }.width('100%').padding({ left: 9, right: 3, top: 4, bottom: 4 })
              .borderRadius(12).backgroundColor(this.dark ? '#2D2E31' : '#F8F9FA')
              .border({ width: 0.5, color: this.dark ? '#44454A' : '#E1E3E7' })
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
      }.width('100%').constraintSize({ maxHeight: 330 }).scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.None)
      Row({ space: 6 }) {
        Button({ type: ButtonType.Normal }) {
          DSHIcon({ glyph: 'chevron-left-outline', glyphSize: 13,
            color: this.dark ? '#CFD3D6' : '#61666B' }).rotate({ angle: 180 })
        }.width(32).height(32).borderRadius(9).backgroundColor(Color.Transparent)
          .enabled(this.index > 0 && !this.busy)
          .accessibilityText('上一题').onClick((): void => { this.move(this.index - 1); })
        Text((this.index + 1).toString() + ' / ' + this.frame.request.questions.length.toString())
          .fontSize(11).fontColor(this.dark ? '#93969B' : '#8A8D91')
        Button({ type: ButtonType.Normal }) {
          DSHIcon({ glyph: 'chevron-left-outline', glyphSize: 13,
            color: this.dark ? '#CFD3D6' : '#61666B' }).rotate({ angle: 0 })
        }.width(32).height(32).borderRadius(9).backgroundColor(Color.Transparent)
          .enabled(this.index < this.frame.request.questions.length - 1 && !this.busy)
          .accessibilityText('下一题').onClick((): void => { this.move(this.index + 1); })
        Blank()
        Button(question.intent?.reject || '跳过', { type: ButtonType.Normal }).height(34).fontSize(11)
          .borderRadius(9).backgroundColor(this.dark ? '#353638' : '#F5F6F7')
          .fontColor(this.dark ? '#CFD3D6' : '#61666B')
          .enabled(!this.busy && !this.unconfirmed).onClick((): void => { this.skipQuestion(); })
        Button({ type: ButtonType.Normal }) {
          if (this.busy) LoadingProgress().width(14).height(14).color('#FFFFFF')
          else Text(this.index < this.frame.request.questions.length - 1 ?
            '下一题' : (question.intent?.approve || '提交')).fontSize(11).fontWeight(FontWeight.Medium)
        }.height(34).padding({ left: 12, right: 12 }).borderRadius(9)
          .backgroundColor(this.dark ? '#679EFE' : '#3964FE').fontColor('#FFFFFF')
          .enabled(!this.busy && !this.unconfirmed && this.answered(this.answerFor(question.id)))
          .opacity(this.answered(this.answerFor(question.id)) ? 1 : 0.42)
          .onClick((): void => { this.continueQuestions(); })
      }.width('100%').height(48).padding({ left: 8, right: 8 })
    }.width('100%').borderRadius(15).clip(true)
      .backgroundColor(this.dark ? '#292A2C' : '#FFFFFF')
      .border({ width: 0.5, color: this.dark ? '#414247' : '#E1E3E7' })
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
        Text(this.error).fontSize(11).fontColor(this.dark ? '#FF9393' : '#C53030')
          .padding({ left: 12, right: 12 })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .transition(NativeMotion.previewTransition())
  }
}
