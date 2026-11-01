import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeMessage } from '../services/NativeSessionModel';
import { DSHIcon } from './DSHIcon';
import { NativeMotion } from '../services/NativeMotion';
import { NativeProcessStepView } from './NativeProcessStepView';
import { NativeListSource } from '../services/NativeListSource';
import { NativeDesign } from '../services/NativeDesign';

/** Turn-level process disclosure containing direct operation rows. */
@Component
export struct NativeProcessView {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  workspaceRoot: string = '';
  onOpenFile: (path: string) => void = (_path: string): void => {};
  disclosures: Map<string, boolean> = new Map<string, boolean>();
  @Prop @Watch('changed') message: NativeMessage = new NativeMessage();
  @Prop newlyAppeared: boolean = false;
  @Prop maxExpandedHeight: number = 240;
  @Prop maxChildExpandedHeight: number = 160;
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('storeShowcaseProcessOpen') private showcaseOpen: boolean = false;
  @State private expanded: boolean = false;
  private disclosureId: string = '';
  private flatApplied: boolean = false;
  private currentTurnApplied: boolean = false;
  private source: NativeListSource<NativeMessage> = new NativeListSource<NativeMessage>();

  aboutToAppear(): void {
    this.flatApplied = this.message.flat;
    this.currentTurnApplied = this.message.currentTurn;
    this.changed();
  }

  private changed(): void {
    this.source.set(this.message.children, (child: NativeMessage): string => child.renderKey || child.id);
    const key = this.message.turnKey + '|' + this.message.id;
    if (key !== this.disclosureId) {
      this.disclosureId = key;
      this.flatApplied = this.message.flat;
      this.currentTurnApplied = this.message.currentTurn;
      this.expanded = this.resolveExpanded(key);
    } else if (this.flatApplied !== this.message.flat ||
      this.currentTurnApplied !== this.message.currentTurn) {
      this.flatApplied = this.message.flat;
      this.currentTurnApplied = this.message.currentTurn;
      this.expanded = this.resolveExpanded(key);
    }
  }

  private resolveExpanded(key: string): boolean {
    if (this.message.flat || this.showcaseOpen) return true;
    if (this.disclosures.has(key)) return this.disclosures.get(key) === true;
    return this.message.currentTurn;
  }

  private toggle(): void {
    NativeMotion.disclosure(this.getUIContext(), (): void => {
      this.expanded = !this.expanded;
      this.disclosures.set(this.disclosureId, this.expanded);
    });
  }

  @Builder
  private members() {
    List({ space: 2 }) {
      LazyForEach(this.source, (child: NativeMessage) => {
        ListItem() {
          NativeProcessStepView({ client: this.client, sessionId: this.sessionId, message: child,
            workspaceRoot: this.workspaceRoot, onOpenFile: this.onOpenFile,
            disclosures: this.disclosures, maxExpandedHeight: this.maxChildExpandedHeight })
        }
      }, (child: NativeMessage) => child.id)
    }.width('100%').padding({ right: 10 })
      .constraintSize({ maxHeight: Math.max(96, this.maxExpandedHeight) })
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)
      .cachedCount(4)
      .transition(NativeMotion.disclosureTransition())
  }

  build() {
    Column({ space: this.expanded ? 6 : 0 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 4 }) {
          DSHIcon({ glyph: 'think-outline', color: NativeDesign.textTertiary(this.dark), glyphSize: 14 })
          Text('工作过程').fontSize(12).fontWeight(FontWeight.Medium)
            .fontColor(NativeDesign.textSecondary(this.dark))
          if (this.message.detail) {
            Text('·').fontSize(12).fontColor(NativeDesign.textTertiary(this.dark))
            Text(this.message.detail).fontSize(12).layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textTertiary(this.dark))
              .opacity(this.expanded ? 0 : 1)
              .animation(NativeMotion.disclosureParam())
          } else {
            Blank().layoutWeight(1)
          }
          DSHIcon({ glyph: 'chevron-left-outline',
            color: NativeDesign.textTertiary(this.dark), glyphSize: 12 })
            .rotate({ angle: this.expanded ? -90 : 180 })
            .animation(NativeMotion.disclosureParam())
        }.width('100%')
      }.height(30).width('100%').padding({ left: 2, right: 2 })
        .responseRegion({ x: 0, y: -7, width: '100%', height: NativeDesign.hitTarget })
        .backgroundColor(Color.Transparent).onClick((): void => { this.toggle(); })
      if (this.expanded) { this.members() }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .transition(this.newlyAppeared ? NativeMotion.processEntranceTransition() : TransitionEffect.IDENTITY)
  }
}
