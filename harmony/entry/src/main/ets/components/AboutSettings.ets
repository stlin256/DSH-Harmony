import { common } from '@kit.AbilityKit';
import { BuildInfo } from '../services/BuildInfo';
import { NativeExperience } from '../services/NativeExperience';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';
import { DSHIcon } from './DSHIcon';
import { NativeIconButton } from './NativeIconButton';

@Component
export struct AboutSettings {
  @Prop embedded: boolean = false;
  onBack: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @State private status: string = '';
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  private open(url: string): void {
    this.context.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    }).catch(() => { this.status = '无法打开链接'; });
  }

  build() {
    Scroll() {
      Column({ space: NativeDesign.spaceM }) {
        if (!this.embedded) {
        Row({ space: 8 }) {
          NativeIconButton({ glyph: 'chevron-left-outline', label: '返回设置', tone: 'primary',
            onPressed: this.onBack })
          Column({ space: 2 }) {
            Text('关于').fontSize(NativeDesign.fontHeaderTitle).fontWeight(FontWeight.Medium)
              .fontColor(NativeDesign.textPrimary(this.dark))
            Text(BuildInfo.appName).fontSize(NativeDesign.fontCaption)
              .fontColor(NativeDesign.textTertiary(this.dark))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%')
        }
        Column({ space: 8 }) {
          Image($r('app.media.app_icon')).width(72).height(72).borderRadius(NativeDesign.radiusGroup)
          Text(BuildInfo.appName).fontSize(NativeDesign.fontPageTitle).fontWeight(FontWeight.Medium)
            .fontColor(NativeDesign.textPrimary(this.dark))
          Text('版本 ' + BuildInfo.version + ' · HarmonyOS').fontSize(NativeDesign.fontCaption)
            .fontColor(NativeDesign.textTertiary(this.dark))
        }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 24, bottom: 24 })
          .borderRadius(NativeDesign.radiusGroup).backgroundColor(NativeDesign.raised(this.dark))
          .border({ width: 0.5, color: NativeDesign.border(this.dark) })
        Column({ space: 10 }) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 12 }) {
              Image($rawfile('maintainer-avatar.png')).width(48).height(48).borderRadius(24).objectFit(ImageFit.Cover)
              Column({ space: 3 }) {
                Text(BuildInfo.author).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium)
                  .fontColor(NativeDesign.textPrimary(this.dark))
                Text('github.com/' + BuildInfo.author).fontSize(NativeDesign.fontCaption)
                  .fontColor(NativeDesign.accent(this.dark))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              DSHIcon({ glyph: 'external-link-outline', glyphSize: NativeDesign.glyphControl, color: NativeDesign.textTertiary(this.dark) })
            }.width('100%')
          }.width('100%').constraintSize({ minHeight: 76 }).padding(NativeDesign.cardPadding)
            .borderRadius(NativeDesign.radiusGroup).backgroundColor(NativeDesign.raised(this.dark))
            .border({ width: 0.5, color: NativeDesign.border(this.dark) }).clip(true)
            .accessibilityText('打开作者 ' + BuildInfo.author + ' 的 GitHub 主页')
            .onClick(() => this.open(BuildInfo.authorProfile))
          Button({ type: ButtonType.Normal }) {
            Row() {
              Column({ space: 3 }) {
                Text('项目仓库').fontSize(NativeDesign.fontCompact).fontWeight(FontWeight.Medium)
                  .fontColor(NativeDesign.textPrimary(this.dark))
                Text('github.com/stlin256/DSH-Harmony').fontSize(NativeDesign.fontCaption)
                  .fontColor(NativeDesign.textTertiary(this.dark))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              DSHIcon({ glyph: 'external-link-outline', glyphSize: NativeDesign.glyphControl, color: NativeDesign.textTertiary(this.dark) })
            }.width('100%')
          }.width('100%').constraintSize({ minHeight: NativeDesign.standardRow + 4 })
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .borderRadius(NativeDesign.radiusGroup).backgroundColor(NativeDesign.raised(this.dark))
            .border({ width: 0.5, color: NativeDesign.border(this.dark) }).clip(true)
            .onClick(() => this.open(BuildInfo.repository))
          Button({ type: ButtonType.Normal }) {
            Row() {
              Column({ space: 3 }) {
                Text('报告问题').fontSize(NativeDesign.fontCompact).fontWeight(FontWeight.Medium)
                  .fontColor(NativeDesign.textPrimary(this.dark))
                Text('在 GitHub Issues 提交反馈').fontSize(NativeDesign.fontCaption)
                  .fontColor(NativeDesign.textTertiary(this.dark))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              DSHIcon({ glyph: 'external-link-outline', glyphSize: NativeDesign.glyphControl, color: NativeDesign.textTertiary(this.dark) })
            }.width('100%')
          }.width('100%').constraintSize({ minHeight: NativeDesign.standardRow + 4 })
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .borderRadius(NativeDesign.radiusGroup).backgroundColor(NativeDesign.raised(this.dark))
            .border({ width: 0.5, color: NativeDesign.border(this.dark) }).clip(true)
            .onClick(() => this.open(BuildInfo.issues))
        }.width('100%')
        Text(BuildInfo.copyright + ' · AGPL-3.0-only').fontSize(NativeDesign.fontCaption).lineHeight(18)
          .width('100%').textAlign(TextAlign.Center).padding({ top: 3, bottom: 3 })
          .fontColor(NativeDesign.textTertiary(this.dark))
        if (this.status) {
          Text(this.status).fontSize(NativeDesign.fontSection).fontColor(NativeDesign.textTertiary(this.dark))
            .width('100%').textAlign(TextAlign.Center).transition(TransitionEffect.OPACITY)
        }
      }.padding({ left: NativeDesign.pageInset, right: NativeDesign.pageInset, top: 12,
        bottom: this.safeBottom + 24 }).width('100%')
        .constraintSize({ maxWidth: 560 }).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').align(Alignment.TopStart).backgroundColor(NativeDesign.base(this.dark))
      .transition(NativeMotion.navigationTransition())
  }
}
