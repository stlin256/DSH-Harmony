import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { BuildInfo } from '../services/BuildInfo';
import { NativeExperience } from '../services/NativeExperience';
import { NativeLaunchPhase } from '../services/NativeLaunchFlow';
import { NativeMotion } from '../services/NativeMotion';
import { NativeDesign } from '../services/NativeDesign';
import { DSHIcon } from './DSHIcon';
import { NativeIconButton } from './NativeIconButton';

@Component
export struct NativeLaunchSurface {
  @Prop phase: string = NativeLaunchPhase.booting;
  @Prop address: string = '';
  @Prop accessKey: string = '';
  @Prop mode: string = 'native';
  @Prop showPasskey: boolean = false;
  @Prop busy: boolean = false;
  @Prop errorText: string = '';
  onAddressChange: (value: string) => void = (): void => {};
  onAccessKeyChange: (value: string) => void = (): void => {};
  onModeChange: (value: string) => void = (): void => {};
  onConnect: () => void = (): void => {};
  onConfirmIterationNotice: () => void = (): void => {};
  onOpenGuide: () => void = (): void => {};
  onCloseGuide: () => void = (): void => {};
  onOpenInstall: () => void = (): void => {};
  onCloseInstall: () => void = (): void => {};
  onDirect: () => void = (): void => {};
  onEditAddress: () => void = (): void => {};
  onRetry: () => void = (): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  @StorageLink('nativeSafeTop') private safeTop: number = 0;
  @StorageLink('nativeSafeBottom') private safeBottom: number = 0;
  @StorageLink('nativeSafeLeft') private safeLeft: number = 0;
  @StorageLink('nativeSafeRight') private safeRight: number = 0;
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 760;
  @State private brandScale: number = 0.88;
  @State private copied: string = '';
  @State private status: string = '';
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToAppear(): void {
    NativeMotion.spring(this.getUIContext(), (): void => { this.brandScale = 1; });
  }

  private primary(): string {
    return NativeDesign.accent(this.dark);
  }

  private foreground(): string {
    return NativeDesign.textPrimary(this.dark);
  }

  private secondary(): string {
    return NativeDesign.textSecondary(this.dark);
  }

  private surface(): string {
    return NativeDesign.raised(this.dark);
  }

  private raised(): string {
    return NativeDesign.field(this.dark);
  }

  private subtleStroke(): string {
    return NativeDesign.border(this.dark);
  }

  private logoSize(): number {
    return this.viewportWidth < 360 ? 80 : 92;
  }

  private contentBelowLogoTop(): number {
    return Math.max(this.safeTop + 235, this.viewportHeight * 0.345);
  }

  private cornerLogoX(): number {
    return Math.max(12, this.viewportWidth - 174);
  }

  private cornerLogoY(): number {
    return Math.max(this.safeTop + 620, this.viewportHeight - this.safeBottom - 430);
  }

  private logoX(): number {
    if (this.phase === NativeLaunchPhase.guide || this.phase === NativeLaunchPhase.install) {
      return this.cornerLogoX() + 26;
    }
    return Math.max(12, (this.viewportWidth - this.logoSize()) / 2);
  }

  private logoY(): number {
    if (this.phase === NativeLaunchPhase.guide || this.phase === NativeLaunchPhase.install) {
      return this.cornerLogoY() + 26;
    }
    if (this.phase === NativeLaunchPhase.login || this.phase === NativeLaunchPhase.restoring ||
      this.phase === NativeLaunchPhase.error) return this.safeTop + 68;
    return Math.max(this.safeTop + 72, Math.min(210, this.viewportHeight * 0.2));
  }

  private accountTop(): number {
    return this.safeTop + 68 + this.logoSize() + NativeDesign.spaceXXL;
  }

  private logoOpacity(): number {
    if (this.phase === NativeLaunchPhase.guide || this.phase === NativeLaunchPhase.install) return 0;
    if (this.phase === NativeLaunchPhase.login || this.phase === NativeLaunchPhase.restoring ||
      this.phase === NativeLaunchPhase.error) return 1;
    return this.phase === NativeLaunchPhase.booting ? this.brandScale : 1;
  }

  private async copy(value: string, key: string): Promise<void> {
    try {
      await pasteboard.getSystemPasteboard().setData(
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value));
      this.copied = key;
      this.status = '';
      setTimeout((): void => { this.copied = ''; }, 1400);
    } catch (_) {
      this.status = '复制失败';
    }
  }

  private open(url: string): void {
    this.context.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    }).catch((): void => { this.status = '无法打开链接'; });
  }

  @Builder
  private iconButton(glyph: string, label: string, action: () => void) {
    NativeIconButton({ glyph, label, glyphSize: NativeDesign.glyphControlEmphasis, tone: 'primary', onPressed: action })
  }

  @Builder
  private primaryButton(label: string, loading: boolean, action: () => void, controlId: string = '') {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        if (loading) LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline)
          .color(NativeDesign.textInverse(this.dark))
        Text(loading ? '正在连接' : label).fontSize(NativeDesign.fontCompactTitle).fontWeight(FontWeight.Medium)
          .fontColor(NativeDesign.textInverse(this.dark))
      }
    }
    .width('100%').height(NativeDesign.primaryActionHeight).borderRadius(NativeDesign.radiusRow)
    .backgroundColor(NativeDesign.textPrimary(this.dark))
    .id(controlId)
    .enabled(!loading)
    .onClick(action)
  }

  @Builder
  private secondaryButton(label: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Text(label).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).fontColor(this.foreground())
    }
      .width('100%').height(NativeDesign.primaryActionHeight).borderRadius(NativeDesign.radiusRow)
      .backgroundColor(this.raised())
      .onClick(action)
  }

  @Builder
  private iterationNotice() {
    Column({ space: 0 }) {
      Row({ space: 7 }) {
        DSHIcon({ glyph: 'sparkle', glyphSize: NativeDesign.glyphCompact, color: this.primary() })
        Text('快速迭代版本').fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
          .fontColor(this.primary())
      }
      .constraintSize({ minHeight: NativeDesign.compactChip })
      .padding({ left: 10, right: 11, top: 5, bottom: 5 })
      .borderRadius(NativeDesign.radiusChip)
      .backgroundColor(NativeDesign.accentSurface(this.dark))
      .border({ width: 0.5, color: this.primary() })
      .alignSelf(ItemAlign.Center)
      .id('iteration-notice-chip')
      Text('项目正在快速迭代').fontSize(NativeDesign.fontBrand).fontWeight(FontWeight.Bold)
        .fontColor(this.foreground()).margin({ top: 16 })
      Text('当前仍有许多功能尚未完成，也可能出现 Bug 或不够顺畅的交互。')
        .fontSize(NativeDesign.fontBody).lineHeight('22fp').fontColor(this.secondary())
        .width('100%').margin({ top: 10 })
      Text('遇到问题时，欢迎在项目仓库提交 Issue，帮助我们把体验做得更好。')
        .fontSize(NativeDesign.fontBody).lineHeight('22fp').fontColor(this.secondary())
        .width('100%').margin({ top: 10 })
      Blank()
      Row() {
        Text(BuildInfo.appName + ' · v' + BuildInfo.version)
          .fontSize(NativeDesign.fontCaption).fontColor(NativeDesign.textTertiary(this.dark))
          .layoutWeight(1)
        DSHIcon({ glyph: 'branch-outline', glyphSize: NativeDesign.glyphCompact,
          color: NativeDesign.textTertiary(this.dark) })
      }.width('100%').margin({ bottom: 12 })
      this.primaryButton('我已知晓，继续', false, this.onConfirmIterationNotice, 'iteration-notice-confirm')
    }
    .id('iteration-notice')
    .width('100%').height('100%')
    .padding({
      left: 28 + this.safeLeft,
      right: 28 + this.safeRight,
      top: this.contentBelowLogoTop(),
      bottom: Math.max(this.safeBottom, NativeDesign.navigationBarMinInset) + 20
    })
    .constraintSize({ maxWidth: 520 })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 6 }))
      .animation(NativeMotion.implicit('brand')))
  }

  @Builder
  private welcome() {
    Column({ space: 12 }) {
      Text(BuildInfo.appName).fontSize(NativeDesign.fontBrand).fontWeight(FontWeight.Bold).fontColor(this.foreground())
      Text('把 DeepSeek Harness 带到你的手机上').fontSize(NativeDesign.fontBody).fontColor(this.secondary())
      Blank()
      if (this.phase === NativeLaunchPhase.booting) {
        Row({ space: 8 }) {
          LoadingProgress().width(NativeDesign.spinnerInline).height(NativeDesign.spinnerInline).color(this.primary())
          Text('正在准备') .fontSize(NativeDesign.fontSection).fontColor(this.secondary())
        }.opacity(0.85)
      } else {
        this.primaryButton('开始引导', false, this.onOpenGuide)
        this.secondaryButton('直接进入', this.onDirect)
      }
    }
    .width('100%').height('100%')
    .padding({
      left: 28 + this.safeLeft,
      right: 28 + this.safeRight,
      top: this.contentBelowLogoTop(),
      bottom: this.safeBottom + 30
    })
    .constraintSize({ maxWidth: 520 })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 8 }))
      .animation(NativeMotion.implicit('surface')))
  }

  @Builder
  private guideStep(index: string, glyph: string, title: string, detail: string) {
    Row({ space: 13 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column().width(40).height(40).borderRadius(20)
          .backgroundColor(NativeDesign.selection(this.dark))
        DSHIcon({ glyph, glyphSize: NativeDesign.glyphControlEmphasis, color: this.primary() })
      }.width(40).height(40)
      Column({ space: 2 }) {
        Text(title).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).fontColor(this.foreground())
        Text(detail).fontSize(NativeDesign.fontSection).lineHeight(18).fontColor(this.secondary())
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(index).fontSize(NativeDesign.fontMicro).fontWeight(FontWeight.Medium).fontColor(this.secondary())
    }
    .width('100%').padding({ top: 10, bottom: 10 })
    .transition(NativeMotion.navigationTransition())
  }

  @Builder
  private guide() {
    Column() {
      Row({ space: 10 }) {
        this.iconButton('chevron-left-outline', '返回欢迎页', this.onCloseGuide)
        Column({ space: 1 }) {
          Text('连接 DSH').fontSize(NativeDesign.fontPageTitle).fontWeight(FontWeight.Bold).fontColor(this.foreground())
          Text('三步完成准备').fontSize(NativeDesign.fontSection).fontColor(this.secondary())
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Scroll() {
        Column({ space: 10 }) {
          Column() {
            this.guideStep('01', 'globe-outline', '打开 DSH 插件', '在侧边栏进入“插件”')
            Divider().strokeWidth(0.5).margin({ left: 53 }).color(this.subtleStroke())
            this.guideStep('02', 'download-outline', '安装 ' + BuildInfo.appName + ' 插件', '粘贴安装提示词并启用')
            Divider().strokeWidth(0.5).margin({ left: 53 }).color(this.subtleStroke())
            this.guideStep('03', 'check-outline', '连接工作空间', '返回 App，选择登录方式')
          }.width('100%').padding({ left: NativeDesign.cardPadding, right: NativeDesign.cardPadding })
            .borderRadius(NativeDesign.radiusGroup).backgroundColor(this.surface())
            .border({ width: 1, color: this.subtleStroke() })
          Button({ type: ButtonType.Normal }) {
            Row({ space: 12 }) {
              Stack({ alignContent: Alignment.Center }) {
                Column().width(36).height(36).borderRadius(18)
                  .backgroundColor(NativeDesign.accentSurface(this.dark))
                DSHIcon({ glyph: 'copy-outline', glyphSize: NativeDesign.glyphControl, color: this.primary() })
              }
              Column({ space: 3 }) {
                Text('复制安装提示词').fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).fontColor(this.foreground())
                Text('发送给 DSH 即可继续').fontSize(NativeDesign.fontCaption).fontColor(this.secondary())
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              DSHIcon({ glyph: this.copied === 'prompt' ? 'check-outline' : 'copy-outline',
                glyphSize: NativeDesign.glyphControl, color: this.copied === 'prompt' ? this.primary() : this.secondary() })
            }.width('100%')
          }
          .width('100%').constraintSize({ minHeight: NativeDesign.doubleLineRow })
          .padding({ left: NativeDesign.rowInset, right: NativeDesign.rowInset })
          .borderRadius(NativeDesign.radiusGroup).backgroundColor(this.surface()).border({ width: 1, color: this.subtleStroke() })
          .accessibilityText('复制 ' + BuildInfo.appName + ' 插件安装提示词')
          .onClick((): void => { this.copy(BuildInfo.pluginInstallPrompt, 'prompt'); })
          Row({ space: 8 }) {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 7 }) {
                DSHIcon({ glyph: 'branch-outline', glyphSize: NativeDesign.glyphControl, color: this.secondary() })
                Text('打开仓库').fontSize(NativeDesign.fontSection).fontColor(this.foreground())
              }
            }.layoutWeight(1).height(NativeDesign.hitTarget).borderRadius(NativeDesign.radiusRow).backgroundColor(this.raised())
              .onClick((): void => { this.open(BuildInfo.repository); })
            Button({ type: ButtonType.Normal }) {
              Text('详细安装说明').fontSize(NativeDesign.fontSection).fontColor(this.foreground())
            }.layoutWeight(1).height(NativeDesign.hitTarget).borderRadius(NativeDesign.radiusRow).backgroundColor(this.raised())
              .onClick(this.onOpenInstall)
          }.width('100%')
        }.width('100%').padding({ top: 20, bottom: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        .align(Alignment.Top)
      this.primaryButton('继续登录', false, this.onDirect)
      if (this.status) {
        Text(this.status).fontSize(NativeDesign.fontCaption).fontColor(this.secondary()).margin({ top: 6 })
      }
    }
    .width('100%').height('100%')
    .padding({ left: NativeDesign.pageInset + this.safeLeft, right: NativeDesign.pageInset + this.safeRight,
      top: this.safeTop + 12, bottom: this.safeBottom + 18 })
    .constraintSize({ maxWidth: 560 })
    .transition(NativeMotion.navigationTransition())
  }

  @Builder
  private installDetailRow(glyph: string, title: string, detail: string, badge: string) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column().width(38).height(38).borderRadius(19)
          .backgroundColor(NativeDesign.accentSurface(this.dark))
        DSHIcon({ glyph, glyphSize: NativeDesign.glyphControlEmphasis, color: this.primary() })
      }.width(38).height(38)
      Column({ space: 3 }) {
        Text(title).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).fontColor(this.foreground())
        Text(detail).fontSize(NativeDesign.fontCaption).lineHeight(17).fontColor(this.secondary())
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(badge).fontSize(NativeDesign.fontMicro).fontWeight(FontWeight.Medium)
        .fontColor(this.primary()).padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(NativeDesign.radiusCompact)
        .backgroundColor(NativeDesign.accentSurface(this.dark))
    }
    .width('100%').padding({ top: 12, bottom: 12 })
  }

  @Builder
  private detailCopyAction(title: string, detail: string, glyph: string, key: string, value: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width(38).height(38).borderRadius(19)
            .backgroundColor(NativeDesign.accentSurface(this.dark))
          DSHIcon({ glyph, glyphSize: NativeDesign.glyphControlEmphasis, color: this.primary() })
        }.width(38).height(38)
        Column({ space: 3 }) {
          Text(title).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).fontColor(this.foreground())
          Text(detail).fontSize(NativeDesign.fontCaption).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(this.secondary())
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        DSHIcon({ glyph: this.copied === key ? 'check-outline' : 'copy-outline',
          glyphSize: NativeDesign.glyphControl, color: this.copied === key ? this.primary() : this.secondary() })
      }.width('100%')
    }
    .width('100%').constraintSize({ minHeight: NativeDesign.doubleLineRow })
    .padding({ left: 13, right: 13 })
    .borderRadius(NativeDesign.radiusGroup).backgroundColor(this.surface()).border({ width: 1, color: this.subtleStroke() })
    .accessibilityText(title)
    .onClick((): void => { this.copy(value, key); })
  }

  @Builder
  private detailSectionTitle(title: string, caption: string) {
    Row() {
      Column({ space: 2 }) {
        Text(title).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).fontColor(this.foreground())
        Text(caption).fontSize(NativeDesign.fontCaption).fontColor(this.secondary())
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ top: 4, bottom: 2 })
  }

  @Builder
  private installDetails() {
    Column() {
      Row({ space: 10 }) {
        this.iconButton('chevron-left-outline', '返回连接引导', this.onCloseInstall)
        Column({ space: 1 }) {
          Text('详细安装说明').fontSize(NativeDesign.fontPageTitle).fontWeight(FontWeight.Bold).fontColor(this.foreground())
          Text('两种安装方式 · 一次版本核对').fontSize(NativeDesign.fontSection).fontColor(this.secondary())
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(BuildInfo.pluginArtifactVersion).fontSize(NativeDesign.fontMicro).fontWeight(FontWeight.Medium)
          .fontColor(this.secondary()).padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .borderRadius(NativeDesign.radiusBadge).backgroundColor(this.raised())
      }.width('100%')
      Scroll() {
        Column({ space: 12 }) {
          Stack({ alignContent: Alignment.Center }) {
            Image($rawfile('install-plugin-abstract.svg'))
              .width('100%').height(142).objectFit(ImageFit.Contain).opacity(0.96)
          }
          .width('100%').height(154).borderRadius(18)
          .backgroundColor(NativeDesign.accentSurface(this.dark))
          Column({ space: 8 }) {
            this.detailSectionTitle('交给 DSH 自动安装', '推荐 · Agent 会完成下载、启用与版本检查')
            this.detailCopyAction('复制安装提示词', '发送给 DSH Agent', 'agent-preset-outline',
              'detail-prompt', BuildInfo.pluginInstallPrompt)
          }.width('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 8 }) {
            this.detailSectionTitle('手动安装', '适合直接操作 DSH 插件管理器的用户')
            Text('打开 插件 → Add plugin，粘贴安装地址并启用。')
              .fontSize(NativeDesign.fontCaption).lineHeight(17).fontColor(this.secondary()).width('100%')
            this.detailCopyAction('复制插件安装地址', BuildInfo.pluginArtifactVersion,
              'download-outline', 'detail-artifact', BuildInfo.pluginArtifact)
          }.width('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 8 }) {
            this.detailSectionTitle('确认安装结果', '回到 App 前完成这两项')
            Column() {
              this.installDetailRow('api-outline', '插件已启用', '@dsh-harmony/plugin', '01')
              Divider().strokeWidth(0.5).margin({ left: 50 }).color(this.subtleStroke())
              this.installDetailRow('check-outline', '版本匹配', BuildInfo.pluginArtifactVersion, '02')
            }.width('100%').padding({ left: 14, right: 14 })
              .borderRadius(NativeDesign.radiusGroup).backgroundColor(this.surface())
              .border({ width: 1, color: this.subtleStroke() })
          }.width('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              DSHIcon({ glyph: 'question-outline', glyphSize: NativeDesign.glyphCompact, color: this.secondary() })
              Text('常见问题').fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium).fontColor(this.foreground())
            }.width('100%')
            Text('请安装 Release 中的 .tgz，不要把 plugins/dsh-harmony 源码目录直接作为 Git 插件。升级 App 时使用对应的插件版本。')
              .fontSize(NativeDesign.fontCaption).lineHeight(17).fontColor(this.secondary()).width('100%')
          }.width('100%').padding(13).borderRadius(NativeDesign.radiusGroup)
          .backgroundColor(this.raised())
          if (this.status) {
            Text(this.status).fontSize(NativeDesign.fontCaption).fontColor(this.secondary())
          }
        }.width('100%').padding({ top: 18, bottom: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        .align(Alignment.Top)
      this.primaryButton('返回连接', false, this.onCloseInstall)
    }
    .width('100%').height('100%')
    .padding({ left: NativeDesign.pageInset + this.safeLeft, right: NativeDesign.pageInset + this.safeRight,
      top: this.safeTop + 12, bottom: this.safeBottom + 18 })
    .constraintSize({ maxWidth: 560 })
    .transition(NativeMotion.navigationTransition())
  }

  @Builder
  private formLabel(value: string) {
    Text(value).fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
      .fontColor(this.secondary()).padding({ left: 2 })
  }

  @Builder
  private modeButton(label: string, detail: string, value: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text(label).fontSize(NativeDesign.fontBody).fontWeight(FontWeight.Medium).fontColor(this.foreground())
          if (detail) Text(detail).fontSize(NativeDesign.fontMicro).fontColor(this.secondary())
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.mode === value) {
          DSHIcon({ glyph: 'check-outline', glyphSize: NativeDesign.glyphControl, color: this.primary() })
        }
      }.width('100%').padding({ left: 13, right: 13 })
    }
    .width('100%').constraintSize({ minHeight: NativeDesign.doubleLineRow })
    .borderRadius(NativeDesign.radiusRow)
    .backgroundColor(this.mode === value ?
      NativeDesign.accentSurface(this.dark) : this.raised())
    .border({ width: 1, color: this.mode === value ? this.primary() : this.subtleStroke() })
    .onClick((): void => { this.onModeChange(value); })
  }

  @Builder
  private loginCard() {
    Column({ space: 13 }) {
      Row({ space: 8 }) {
        this.iconButton('chevron-left-outline', '返回欢迎页', this.onEditAddress)
        Column({ space: 2 }) {
          Text('连接工作空间').fontSize(NativeDesign.fontPageTitle).fontWeight(FontWeight.Bold).fontColor(this.foreground())
          Text('登录你的 DeepSeek Harness').fontSize(NativeDesign.fontSection).fontColor(this.secondary())
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Column({ space: 7 }) {
        this.formLabel('服务地址')
        TextInput({ text: this.address, placeholder: 'https://dsh.example.com' })
          .height(NativeDesign.standardRow).borderRadius(NativeDesign.radiusRow).type(InputType.URL)
          .backgroundColor(this.raised()).fontColor(this.foreground())
          .placeholderColor(this.secondary())
          .border({ width: 1, color: this.subtleStroke() })
          .onChange((value: string): void => { this.onAddressChange(value); })
      }.width('100%').alignItems(HorizontalAlign.Start)
      Column({ space: 8 }) {
        this.formLabel('登录方式')
        this.modeButton('访问密钥', '默认 · 局域网与公网', 'native')
        if (this.mode === 'native') {
          TextInput({ text: this.accessKey, placeholder: '输入 Harness 访问密钥' })
            .height(NativeDesign.pickerRow).borderRadius(NativeDesign.radiusRow).type(InputType.Password)
            .backgroundColor(this.raised()).fontColor(this.foreground())
            .placeholderColor(this.secondary())
            .border({ width: 1, color: this.subtleStroke() })
            .onChange((value: string): void => { this.onAccessKeyChange(value); })
        }
        if (this.showPasskey) {
          this.modeButton('Pocket ID · Passkey', '需要 HTTPS', 'passkey')
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
      if (this.errorText) {
        Row({ space: 10 }) {
          Column({ space: 3 }) {
            Text('登录失败').fontSize(NativeDesign.fontSection).fontWeight(FontWeight.Medium)
              .fontColor(NativeDesign.danger(this.dark))
            Text(this.errorText).fontSize(NativeDesign.fontCaption).lineHeight(17).maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textSecondary(this.dark))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          this.iconButton(this.copied === 'error' ? 'check-outline' : 'copy-outline', '复制错误',
            (): void => { this.copy(this.errorText, 'error'); })
        }
        .width('100%').padding(NativeDesign.spaceM).borderRadius(NativeDesign.radiusRow)
        .backgroundColor(NativeDesign.dangerSurface(this.dark))
        .border({ width: 1, color: NativeDesign.border(this.dark) })
        .id('launch-login-error')
        .transition(NativeMotion.rowTransition())
      }
      this.primaryButton('连接工作空间', this.busy, this.onConnect, 'launch-login-connect')
    }
    .id('launch-login-card')
    .width('100%').padding(18).borderRadius(NativeDesign.radiusSurface)
    .backgroundColor(this.surface()).border({ width: 1, color: this.subtleStroke() })
    .shadow({ radius: NativeExperience.materialsEnabled() ? 22 : 0,
      color: this.dark ? '#55000000' : '#16000000', offsetY: 8 })
    .constraintSize({ maxWidth: 500 })
    .transition(NativeMotion.rowTransition())
  }

  @Builder
  private connectionProgressSurface() {
    Column({ space: 22 }) {
      Image($r('app.media.app_icon'))
        .width(64).height(64).objectFit(ImageFit.Contain).opacity(0.38)
      LoadingProgress().width(NativeDesign.spinnerPage).height(NativeDesign.spinnerPage).color(this.primary())
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
    .padding({ bottom: this.safeBottom })
    .transition(TransitionEffect.OPACITY.animation(NativeMotion.implicit('surface')))
  }

  @Builder
  private errorCard() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        this.iconButton('chevron-left-outline', '返回登录', this.onEditAddress)
        Column({ space: 2 }) {
          Text('连接失败').fontSize(NativeDesign.fontPageTitle).fontWeight(FontWeight.Bold).fontColor(this.foreground())
          Text(this.address).fontSize(NativeDesign.fontCaption).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(this.secondary())
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Text(this.errorText).fontSize(NativeDesign.fontCompact).lineHeight(20).fontColor(this.secondary())
        .width('100%').padding(NativeDesign.spaceM).borderRadius(NativeDesign.radiusRow).backgroundColor(this.raised())
      Row({ space: 8 }) {
        this.iconButton(this.copied === 'error' ? 'check-outline' : 'copy-outline', '复制错误',
          (): void => { this.copy(this.errorText, 'error'); })
        Text(this.copied === 'error' ? '错误已复制' : '复制错误')
          .fontSize(NativeDesign.fontSection).fontColor(this.secondary()).layoutWeight(1)
      }.width('100%')
      this.primaryButton('重试', this.busy, this.onRetry)
      this.secondaryButton('修改地址', this.onEditAddress)
    }
    .id('launch-error-card')
    .width('100%').padding(18).borderRadius(NativeDesign.radiusSurface).backgroundColor(this.surface())
    .border({ width: 1, color: this.subtleStroke() })
    .constraintSize({ maxWidth: 500 })
    .transition(NativeMotion.rowTransition())
  }

  @Builder
  private accountSurface() {
    Scroll() {
      Column() {
        if (this.phase === NativeLaunchPhase.error) this.errorCard()
        else this.loginCard()
      }
      .width('100%').padding({ left: NativeDesign.pageInset + this.safeLeft, right: NativeDesign.pageInset + this.safeRight,
        top: this.accountTop(), bottom: this.safeBottom + 24 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%').height('100%').scrollBar(BarState.Off)
    .align(Alignment.Top)
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 8 }))
      .animation(NativeMotion.implicit('surface')))
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width('100%').height('100%')
        .linearGradient({
          angle: 160,
          colors: this.dark
            ? [['#151517', 0.0], ['#1A1B1F', 0.58], ['#141619', 1.0]]
            : [['#FFFFFF', 0.0], ['#F7F9FC', 0.58], ['#F0F4FB', 1.0]]
        })
      Column().width(260).height(260).borderRadius(130)
        .backgroundColor(NativeDesign.accentSurface(this.dark)).opacity(0.62)
        .position({ x: this.viewportWidth - 176, y: -84 })
      Column().width(190).height(190).borderRadius(95)
        .backgroundColor(NativeDesign.successSurface(this.dark)).opacity(0.45)
        .position({ x: -78, y: this.viewportHeight * 0.56 })
      if (this.phase !== NativeLaunchPhase.restoring &&
        this.phase !== NativeLaunchPhase.entering) {
        Image($r('app.media.app_icon'))
          .id('launch-brand-logo')
          .width(this.logoSize()).height(this.logoSize())
          .objectFit(ImageFit.Contain)
          .position({ x: this.logoX(), y: this.logoY() })
          .opacity(this.logoOpacity())
          .accessibilityLevel('no')
      }
      Image($r('app.media.app_icon'))
        .width(144).height(144).objectFit(ImageFit.Contain)
        .position({ x: this.cornerLogoX(), y: this.cornerLogoY() })
        .opacity(this.phase === NativeLaunchPhase.guide || this.phase === NativeLaunchPhase.install
          ? 0.10 : 0)
        .animation(NativeMotion.implicit('brand'))
        .accessibilityLevel('no')
      if (this.phase === NativeLaunchPhase.iterationNotice) {
        this.iterationNotice()
      } else if (this.phase === NativeLaunchPhase.booting || this.phase === NativeLaunchPhase.intro) {
        this.welcome()
      } else if (this.phase === NativeLaunchPhase.guide) {
        this.guide()
      } else if (this.phase === NativeLaunchPhase.install) {
        this.installDetails()
      } else if (this.phase === NativeLaunchPhase.restoring ||
        this.phase === NativeLaunchPhase.entering) {
        this.connectionProgressSurface()
      } else {
        this.accountSurface()
      }
    }
    .width('100%').height('100%')
    .clip(true)
    .onAreaChange((_old: Area, area: Area): void => {
      if (Number(area.width) > 0) this.viewportWidth = Number(area.width);
      if (Number(area.height) > 0) this.viewportHeight = Number(area.height);
    })
  }
}
