import { common } from '@kit.AbilityKit';
import { NativeHarnessClient } from '../services/NativeHarnessClient';
import {
  NativeStructuredField,
  NativeStructuredPresentedFile,
  NativeStructuredReadLine,
  NativeStructuredSearchFile,
  NativeStructuredSearchLine,
  NativeStructuredWebSource,
  NativeToolStructured
} from '../services/NativeToolStructured';
import { NativeDesign } from '../services/NativeDesign';
import { DSHIcon } from './DSHIcon';
import { NativeCodeViewer } from './NativeCodeViewer';
import { NativePluginCard } from './NativePluginCard';
import { NativeMediaCard } from './NativeMediaCard';

@Component
export struct NativeStructuredToolView {
  client: NativeHarnessClient = new NativeHarnessClient('');
  sessionId: string = '';
  document: NativeToolStructured = new NativeToolStructured();
  maxExpandedHeight: number = 240;
  onOpenFile: (path: string) => void = (_path: string): void => {};
  @StorageLink('nativeDark') private dark: boolean = false;
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  private fieldColor(field: NativeStructuredField): ResourceColor {
    if (field.tone === 'success') return NativeDesign.success(this.dark);
    if (field.tone === 'danger') return NativeDesign.danger(this.dark);
    if (field.tone === 'warning') return NativeDesign.warning(this.dark);
    if (field.tone === 'accent') return NativeDesign.accent(this.dark);
    return NativeDesign.textSecondary(this.dark);
  }

  private readCode(): string {
    const lines = this.document.read.lines;
    if (!lines.length) return '';
    const values: string[] = [];
    let expected = lines[0].number;
    lines.forEach((line: NativeStructuredReadLine): void => {
      while (expected < line.number) {
        values.push('');
        expected++;
      }
      values.push(line.text);
      expected = line.number + 1;
    });
    return values.join('\n');
  }

  private viewerHeight(): number {
    const contentHeight = Math.max(30, this.document.read.lines.length * 22 + 8);
    return Math.min(280, this.maxExpandedHeight, contentHeight);
  }

  private openUrl(url: string): void {
    if (!url) return;
    this.context.startAbility({
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    }).catch((): void => {
      this.getUIContext().getPromptAction().showToast({
        message: '无法打开此链接',
        duration: 1500
      });
    });
  }

  @Builder
  private fieldRow(field: NativeStructuredField) {
    Row({ space: 8 }) {
      Text(field.label).width(52).fontSize(NativeDesign.fontMicro).fontColor(NativeDesign.textTertiary(this.dark))
        .textAlign(TextAlign.End)
      Text(field.value).layoutWeight(1).fontSize(NativeDesign.fontCaption)
        .fontFamily(field.code ? 'Noto Sans Mono, monospace' : 'HarmonyOS Sans')
        .fontColor(this.fieldColor(field)).copyOption(CopyOptions.InApp)
        .maxLines(field.code ? 2 : 3).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private commandRow(field: NativeStructuredField) {
    Column({ space: 2 }) {
      Text(field.label).fontSize(NativeDesign.fontMicro)
        .fontColor(NativeDesign.textTertiary(this.dark))
      Text(field.value).width('100%').fontSize(NativeDesign.fontMicro)
        .lineHeight('16fp').fontFamily('Noto Sans Mono, monospace')
        .fontColor(this.fieldColor(field)).copyOption(CopyOptions.InApp)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private targetRow() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 7 }) {
        DSHIcon({ glyph: 'file-outline', glyphSize: NativeDesign.glyphCompact,
          color: NativeDesign.textTertiary(this.dark) })
        Column({ space: 1 }) {
          Text(this.document.displayName || this.document.displayPath || this.document.path)
            .fontSize(NativeDesign.fontCaption).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.accent(this.dark))
          if (this.document.displayDirectory) {
            Text(this.document.displayDirectory).fontSize(NativeDesign.fontMicro).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontFamily('Noto Sans Mono, monospace')
              .fontColor(NativeDesign.textTertiary(this.dark))
          }
        }.layoutWeight(1).constraintSize({ minWidth: 0 }).alignItems(HorizontalAlign.Start)
        DSHIcon({ glyph: 'chevron-right-outline', glyphSize: NativeDesign.glyphInline,
          color: NativeDesign.textTertiary(this.dark) })
      }.width('100%')
    }.height(NativeDesign.compactHitTarget).width('100%').padding({ left: 4, right: 4 })
      .borderRadius(NativeDesign.radiusCompact).backgroundColor(NativeDesign.field(this.dark))
      .accessibilityText('打开文件 ' + (this.document.displayPath || this.document.path))
      .onClick((): void => { this.onOpenFile(this.document.path); })
  }

  @Builder
  private searchMatch(line: NativeStructuredSearchLine) {
    Row({ space: 8 }) {
      Text(line.number.toString()).width(38).fontSize(NativeDesign.fontMicro).textAlign(TextAlign.End)
        .fontFamily('Noto Sans Mono, monospace').fontColor(NativeDesign.textTertiary(this.dark))
      Text(line.text).layoutWeight(1).fontSize(NativeDesign.fontCaption).maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontFamily('Noto Sans Mono, monospace').copyOption(CopyOptions.InApp)
        .fontColor(NativeDesign.textSecondary(this.dark))
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private searchFile(file: NativeStructuredSearchFile) {
    Column({ space: 4 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 7 }) {
          DSHIcon({ glyph: 'file-outline', glyphSize: NativeDesign.glyphCompact,
            color: NativeDesign.textTertiary(this.dark) })
          Column({ space: 1 }) {
            Text(file.name || file.display || file.path).fontSize(NativeDesign.fontCaption)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.accent(this.dark))
            if (file.directory) {
              Text(file.directory).fontSize(NativeDesign.fontMicro).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontFamily('Noto Sans Mono, monospace')
                .fontColor(NativeDesign.textTertiary(this.dark))
            }
          }.layoutWeight(1).constraintSize({ minWidth: 0 }).alignItems(HorizontalAlign.Start)
          DSHIcon({ glyph: 'chevron-right-outline', glyphSize: NativeDesign.glyphInline,
            color: NativeDesign.textTertiary(this.dark) })
        }.width('100%')
      }.height(NativeDesign.compactHitTarget).width('100%').padding({ left: 2, right: 2 })
        .backgroundColor(Color.Transparent)
        .accessibilityText('打开文件 ' + (file.display || file.path))
        .onClick((): void => { this.onOpenFile(file.path); })
      if (file.matches.length) {
        Column({ space: 3 }) {
          ForEach(file.matches, (line: NativeStructuredSearchLine) => {
            this.searchMatch(line)
          }, (line: NativeStructuredSearchLine) => file.path + ':' + line.number)
        }.width('100%').padding({ left: 4, right: 4, bottom: 4 })
      }
    }.width('100%').padding({ top: 2, bottom: 2 }).borderRadius(NativeDesign.radiusCompact)
      .backgroundColor(NativeDesign.field(this.dark))
  }

  @Builder
  private sourceRow(source: NativeStructuredWebSource) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        DSHIcon({ glyph: 'globe-outline', glyphSize: NativeDesign.glyphCompact,
          color: NativeDesign.textTertiary(this.dark) })
        Column({ space: 2 }) {
          Text(source.title || source.url).fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textPrimary(this.dark))
          Text(source.url).fontSize(NativeDesign.fontMicro).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.accent(this.dark))
          if (source.snippet) {
            Text(source.snippet).fontSize(NativeDesign.fontMicro).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textTertiary(this.dark))
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        DSHIcon({ glyph: 'external-link-outline', glyphSize: NativeDesign.glyphInline,
          color: NativeDesign.textTertiary(this.dark) })
      }.width('100%').alignItems(VerticalAlign.Top)
    }.width('100%').constraintSize({ minHeight: 42 }).padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .borderRadius(NativeDesign.radiusCompact).backgroundColor(NativeDesign.field(this.dark))
      .onClick((): void => { this.openUrl(source.url); })
  }

  @Builder
  private presentedRow(file: NativeStructuredPresentedFile) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        DSHIcon({ glyph: 'file-outline', glyphSize: NativeDesign.glyphCompact,
          color: NativeDesign.textTertiary(this.dark) })
        Column({ space: 2 }) {
          Text(file.name || file.display).fontSize(NativeDesign.fontCaption).fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(NativeDesign.textPrimary(this.dark))
          Text(file.display).fontSize(NativeDesign.fontMicro).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontFamily('Noto Sans Mono, monospace')
            .fontColor(NativeDesign.textTertiary(this.dark))
          if (file.description) {
            Text(file.description).fontSize(NativeDesign.fontMicro).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(NativeDesign.textSecondary(this.dark))
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        DSHIcon({ glyph: 'chevron-right-outline', glyphSize: NativeDesign.glyphInline,
          color: NativeDesign.textTertiary(this.dark) })
      }.width('100%').alignItems(VerticalAlign.Top)
    }.width('100%').constraintSize({ minHeight: 42 }).padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .borderRadius(NativeDesign.radiusCompact).backgroundColor(NativeDesign.field(this.dark))
      .onClick((): void => { this.onOpenFile(file.path); })
  }

  build() {
    Column({ space: 6 }) {
      if (this.document.plugin.present) {
        NativePluginCard({ document: this.document.plugin })
      }
      if (this.document.media.present) {
        NativeMediaCard({
          document: this.document.media,
          onOpenFile: this.onOpenFile
        })
      }
      if (this.document.path &&
        (this.document.family === 'read' || this.document.family === 'image')) {
        this.targetRow()
      }
      if (this.document.fields.length) {
        Column({ space: 4 }) {
          ForEach(this.document.fields, (field: NativeStructuredField) => {
            if (field.label === '命令') {
              this.commandRow(field)
            } else {
              this.fieldRow(field)
            }
          }, (field: NativeStructuredField, index: number) => field.label + ':' + index)
        }.width('100%')
      }
      if (this.document.read.valid) {
        NativeCodeViewer({
          code: this.readCode(),
          language: this.document.read.language,
          startNumber: this.document.read.lines[0].number,
          identity: this.document.path + ':' + this.document.read.offset + ':' +
            this.document.read.lines.length,
          compact: true
        }).width('100%').height(this.viewerHeight())
      }
      if (this.document.search.paths.length || this.document.search.files.length) {
        Column({ space: 4 }) {
          ForEach(this.document.search.paths, (file: NativeStructuredSearchFile) => {
            this.searchFile(file)
          }, (file: NativeStructuredSearchFile, index: number) => 'path:' + file.path + ':' + index)
          ForEach(this.document.search.files, (file: NativeStructuredSearchFile) => {
            this.searchFile(file)
          }, (file: NativeStructuredSearchFile, index: number) => 'file:' + file.path + ':' + index)
        }.width('100%')
      }
      if (this.document.sources.length) {
        Column({ space: 4 }) {
          ForEach(this.document.sources, (source: NativeStructuredWebSource) => {
            this.sourceRow(source)
          }, (source: NativeStructuredWebSource, index: number) =>
            source.url + ':' + index)
        }.width('100%')
      }
      if (this.document.presented.length) {
        Column({ space: 4 }) {
          ForEach(this.document.presented, (file: NativeStructuredPresentedFile) => {
            this.presentedRow(file)
          }, (file: NativeStructuredPresentedFile, index: number) =>
            file.path + ':' + index)
        }.width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
