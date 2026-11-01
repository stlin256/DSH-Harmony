import { NativeHarnessClient } from '../services/NativeHarnessClient';
import { NativeSession, NativeWorkspaceItem, NativeWorkspaceSnapshot } from '../services/NativeSessionModel';
import { DSHIcon } from './DSHIcon';
import { NativeExperience } from '../services/NativeExperience';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';
import { NativeIconButton } from './NativeIconButton';

class WorkspaceCreated { workspace: NativeWorkspaceItem = new NativeWorkspaceItem(); }

@Component
export struct NativeWorkspacePicker {
  client: NativeHarnessClient = new NativeHarnessClient('');
  @Prop snapshot: NativeWorkspaceSnapshot = new NativeWorkspaceSnapshot();
  @Prop sessions: NativeSession[] = [];
  @Prop selectedId: string = '';
  @Prop page: string = 'root';
  @Prop navigationDirection: number = 1;
  onClose: () => void = (): void => {};
  onPageChange: (page: string) => void = (): void => {};
  onSelect: (id: string) => void = (): void => {};
  onChanged: (value: NativeWorkspaceSnapshot) => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @StorageLink('nativeSafeLeft') private safeLeft: number = 0;
  @StorageLink('nativeSafeRight') private safeRight: number = 0;
  @State private path: string = '';
  @State private editingId: string = '';
  @State private title: string = '';
  @State private busy: boolean = false;
  @State private error: string = '';
  private creating(): boolean { return this.page === 'create'; }
  private archived(): boolean { return this.page === 'archive'; }
  private async command(body: string): Promise<void> {
    if (this.busy) return;
    this.busy = true; this.error = '';
    try {
      const value = await this.client.operation(body);
      this.onChanged(await this.client.workspaces());
      if (this.creating()) { this.onPageChange('root'); this.onSelect((JSON.parse(value) as WorkspaceCreated).workspace.workspaceId); }
      this.editingId = '';
    } catch (_) { this.error = '操作未确认，请刷新'; }
    finally { this.busy = false; }
  }
  @Builder
  private row(title: string, detail: string, selected: boolean, click: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        DSHIcon({ glyph: 'browse-outline', color: NativeDesign.textTertiary(this.dark), glyphSize: NativeDesign.glyphControl })
        Column({ space: 3 }) {
          Text(title).fontSize(NativeDesign.fontBody).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textPrimary(this.dark))
          if (detail) { Text(detail).fontSize(NativeDesign.fontCaption).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(NativeDesign.textTertiary(this.dark)) }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (selected) { DSHIcon({ glyph: 'check-outline', color: NativeDesign.accent(this.dark) }) }
      }.width('100%')
    }.width('100%').constraintSize({ minHeight: NativeDesign.standardRow }).padding(8)
      .borderRadius(NativeDesign.radiusRow)
      .backgroundColor(selected ? NativeDesign.selection(this.dark) : Color.Transparent).onClick(click)
  }
  build() {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        NativeIconButton({ glyph: 'chevron-left-outline', label: '返回', tone: 'primary',
          onPressed: (): void => {
            if (this.page !== 'root') this.onPageChange('root'); else this.onClose();
          } })
        Text(this.creating() ? '添加工作区' : this.archived() ? '已归档会话' : '工作区')
          .fontSize(NativeDesign.fontHeaderTitle).fontWeight(FontWeight.Medium).layoutWeight(1)
          .fontColor(NativeDesign.textPrimary(this.dark))
      }.width('100%')
      Scroll() {
        Column({ space: 5 }) {
          if (this.creating()) {
            TextInput({ text: this.path, placeholder: '服务器上的目录路径' }).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontBody)
              .onChange((value: string) => { this.path = value; })
            Button('添加', { type: ButtonType.Normal }).height(NativeDesign.hitTarget).width('100%')
              .borderRadius(NativeDesign.radiusControl)
              .backgroundColor(NativeDesign.accentStrong(this.dark)).fontColor(NativeDesign.textInverse(this.dark))
              .enabled(!this.busy && this.path.trim().length > 0)
              .onClick(() => { this.command(JSON.stringify({ operation: 'workspaceCreate', path: this.path.trim() })); })
          } else if (this.archived()) {
            ForEach(this.snapshot.archivedSessionIds, (id: string) => {
              Row({ space: 8 }) {
                Text(this.sessions.find((row: NativeSession) => row.id === id)?.title || '未命名会话')
                  .fontSize(NativeDesign.fontCompact).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Button('恢复', { type: ButtonType.Normal }).height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection).enabled(!this.busy)
                  .onClick(() => { this.command(JSON.stringify({ operation: 'unarchive', sessionId: id })); })
              }.width('100%').padding(6)
            }, (id: string) => id)
            if (!this.snapshot.archivedSessionIds.length) { Text('没有已归档会话').fontSize(NativeDesign.fontCompact) }
          } else {
            this.row('全部会话', '', !this.selectedId, () => { this.onSelect(''); })
            ForEach(this.snapshot.items, (workspace: NativeWorkspaceItem) => {
              Row({ space: 4 }) {
                Column() { this.row(workspace.title, workspace.path, this.selectedId === workspace.workspaceId, () => { this.onSelect(workspace.workspaceId); }) }.layoutWeight(1)
                Button({ type: ButtonType.Normal }) {
                  DSHIcon({ glyph: 'ellipsis-outline', color: NativeDesign.textTertiary(this.dark) })
                }.width(NativeDesign.hitTarget).height(NativeDesign.hitTarget).backgroundColor(Color.Transparent)
                  .onClick(() => { this.editingId = workspace.workspaceId; this.title = workspace.title; })
              }.width('100%')
              if (this.editingId === workspace.workspaceId) {
                Row({ space: 6 }) {
                  TextInput({ text: this.title }).fontSize(NativeDesign.fontCompact).height(NativeDesign.hitTarget).layoutWeight(1).onChange((value: string) => { this.title = value; })
                  Button('保存').height(NativeDesign.hitTarget).fontSize(NativeDesign.fontSection).enabled(!this.busy && this.title.trim().length > 0)
                    .onClick(() => { this.command(JSON.stringify({ operation: 'workspaceRename', workspaceId: this.editingId, title: this.title.trim() })); })
                }.padding(6)
              }
            }, (workspace: NativeWorkspaceItem) => workspace.workspaceId)
            if (this.snapshot.available) {
              Divider().color(NativeDesign.divider(this.dark)).margin({ top: 8, bottom: 8 })
              this.row('添加工作区', '', false, () => { this.onPageChange('create'); })
              this.row('已归档会话', '', false, () => { this.onPageChange('archive'); })
            }
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').align(Alignment.Top)
      if (this.busy) { LoadingProgress().width(NativeDesign.spinnerPage).height(NativeDesign.spinnerPage) }
      if (this.error) { Text(this.error).fontSize(NativeDesign.fontSection).fontColor(NativeDesign.danger(this.dark)) }
    }.padding({ left: 12 + this.safeLeft, right: 12 + this.safeRight,
      top: this.safeTop + 8, bottom: this.safeBottom + 8 })
      .width('100%').height('100%').backgroundColor(NativeDesign.base(this.dark))
      .foregroundColor(NativeDesign.textPrimary(this.dark))
      .transition(NativeMotion.navigationTransition(this.navigationDirection))
  }
}
