import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';

const componentRoot = new URL('../../harmony/entry/src/main/ets/components/', import.meta.url);
const serviceRoot = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);
const readComponent = name => readFileSync(new URL(name, componentRoot), 'utf8');
const readService = name => readFileSync(new URL(name, serviceRoot), 'utf8');
const productComponents = readdirSync(componentRoot)
  .filter(name => name.endsWith('.ets') && name !== 'NativeCompatibilitySurface.ets');

test('semantic control recipes are fixed in one geometry and type scale', () => {
  const design = readService('NativeDesign.ets');
  const expected = [
    ['hitTarget', 44],
    ['compactHitTarget', 36],
    ['compactControl', 32],
    ['compactChip', 28],
    ['compactRow', 44],
    ['standardRow', 48],
    ['pickerRow', 44],
    ['doubleLineRow', 60],
    ['primaryActionHeight', 48],
    ['headerHeight', 52],
    ['radiusBadge', 6],
    ['radiusCompact', 8],
    ['radiusControl', 10],
    ['radiusRow', 12],
    ['radiusChip', 14],
    ['radiusGroup', 16],
    ['radiusSurface', 24],
    ['pageInset', 16],
    ['drawerInset', 12],
    ['rowInset', 12]
  ];
  for (const [name, value] of expected) {
    assert.match(design, new RegExp(`static ${name}: number = ${value}`), name);
  }
  for (const name of [
    'fontPageTitle', 'fontHeaderTitle', 'fontCompactTitle', 'fontBody',
    'fontCompact', 'fontSection', 'fontCaption', 'fontMicro', 'fontEmptyTitle',
    'fontMetric', 'fontBrand', 'glyphMicro', 'glyphInline', 'glyphCompact',
    'glyphControl', 'glyphControlEmphasis', 'glyphHeader', 'glyphHero',
    'glyphEmpty', 'spinnerInline', 'spinnerPage'
  ]) {
    assert.match(design, new RegExp(`static ${name}: number =`), name);
  }
});

test('native product components do not reintroduce local type, glyph or spinner sizes', () => {
  for (const name of productComponents) {
    const source = readComponent(name);
    assert.doesNotMatch(source, /\.fontSize\(\d/, name + ' has a literal text role');
    assert.doesNotMatch(source, /glyphSize:\s*\d/, name + ' has a literal glyph role');
    assert.doesNotMatch(source, /LoadingProgress\(\)\.width\(\d/, name + ' has a literal spinner role');
  }
});

test('major native pages share the documented content edge', () => {
  for (const name of [
    'NativeAutomationSurface.ets',
    'NativeFileBrowser.ets',
    'NativeFilePreview.ets',
    'NativeLaunchSurface.ets',
    'NativePluginsSurface.ets',
    'NativeSettings.ets',
    'NativeWorkspace.ets'
  ]) {
    const source = readComponent(name);
    assert.match(source, /NativeDesign\.pageInset/, name + ' must consume the page inset');
  }

  const settings = readComponent('NativeSettings.ets');
  assert.doesNotMatch(settings, /left: 12 \+ this\.safeLeft/);
  assert.match(settings, /private rootHeader\(\)[\s\S]{0,360}NativeDesign\.pageInset/);
  assert.match(settings, /private pageHeader\([\s\S]{0,420}NativeDesign\.pageInset/);

  const workspace = readComponent('NativeWorkspace.ets');
  assert.match(workspace, /left: NativeDesign\.drawerInset, right: NativeDesign\.drawerInset/);

  const launch = readComponent('NativeLaunchSurface.ets');
  assert.match(launch, /private accountTop\(\): number \{[\s\S]{0,160}this\.logoSize\(\) \+ NativeDesign\.spaceXXL/);
  assert.match(launch, /top: this\.accountTop\(\)/);
});

test('files, plugin rows and settings use the shared row and field recipes', () => {
  const browser = readComponent('NativeFileBrowser.ets');
  assert.match(browser, /\.layoutWeight\(1\)\.height\(NativeDesign\.standardRow\)/);
  assert.match(browser, /\.height\(NativeDesign\.compactChip\).*NativeDesign\.radiusChip/s);

  const plugins = readComponent('NativePluginsSurface.ets');
  assert.match(plugins, /constraintSize\(\{ minHeight: NativeDesign\.doubleLineRow \}\)/);
  assert.match(plugins, /height\(NativeDesign\.compactControl\)/);
  assert.match(plugins, /height\(NativeDesign\.compactRow\)/);

  const settings = readComponent('NativeSettings.ets');
  assert.match(settings, /\.height\(NativeDesign\.standardRow\)/);
  assert.match(settings, /NativeDesign\.radiusGroup/);
  assert.match(settings, /minHeight: NativeDesign\.doubleLineRow/);
});

test('turn file rows prioritize filename and reserve fixed metrics', () => {
  const card = readComponent('NativeTurnChangesView.ets');
  const filename = card.indexOf('Text(this.fileName(file))');
  const directory = card.indexOf('Text(this.fileDirectory(file))');
  const metrics = card.indexOf("Text('+' + formattedCount(file.added))");
  assert.ok(filename >= 0 && directory > filename && metrics > directory);
  assert.match(card, /Text\(this\.fileName\(file\)\)\.fontSize\(NativeDesign\.fontSection\)/);
  assert.match(card, /Text\(this\.fileDirectory\(file\)\)\.fontSize\(NativeDesign\.fontMicro\)/);
  assert.match(card, /constraintSize\(\{ minWidth: 0 \}\)/);
  assert.doesNotMatch(card, /Text\(this\.fileDisplayPath\(file\)\)/);
});

test('diff headers prioritize filename and reserve trailing controls', () => {
  const diff = readComponent('NativeDiffBlock.ets');
  const filename = diff.indexOf('Text(this.fileName())');
  const directory = diff.indexOf('Text(this.directory())');
  const trailing = diff.indexOf('Button({ type: ButtonType.Normal })', filename);
  assert.ok(filename >= 0 && directory > filename && trailing > directory);
  assert.match(diff, /constraintSize\(\{ minWidth: 0 \}\)/);
  assert.match(diff,
    /Text\(this\.fileName\(\)\)[\s\S]{0,180}maxLines\(1\)\.textOverflow/);
  assert.match(diff,
    /constraintSize\(\{ minHeight: NativeDesign\.hitTarget \}\)\.width\('100%'\)/);
  assert.match(diff,
    /width\(NativeDesign\.compactHitTarget\)\.height\(NativeDesign\.compactHitTarget\)[\s\S]{0,140}responseRegion\(\{ x: -4, y: -4, width: NativeDesign\.hitTarget, height: NativeDesign\.hitTarget \}\)/);
});

test('expanded disclosure headers do not leave a dangling preview separator', () => {
  const process = readComponent('NativeProcessView.ets');
  const step = readComponent('NativeProcessStepView.ets');
  const tool = readComponent('NativeToolCallView.ets');
  assert.match(process, /this\.message\.detail && !this\.expanded/);
  assert.match(step, /this\.message\.detail && !this\.expanded/);
  assert.match(tool, /this\.detail && !this\.expanded/);
  assert.match(tool, /this\.preview\(\) && !this\.expanded/);
});

test('composer send state shares the subagent input contract', () => {
  const workspace = readComponent('NativeWorkspace.ets');
  assert.match(workspace,
    /private composerCanSend\(\): boolean \{[\s\S]{0,260}this\.currentSubagentInputEnabled\(\)/);
  assert.match(workspace,
    /\.backgroundColor\(NativeDesign\.accentStrong\(this\.dark\)\)[\s\S]{0,100}\.enabled\(this\.composerCanSend\(\)\)[\s\S]{0,100}\.opacity\(this\.composerCanSend\(\) \? 1 : 0\.4\)/);
});

test('conversation mode chips avoid capsule default state fills', () => {
  const workspace = readComponent('NativeWorkspace.ets');
  assert.doesNotMatch(workspace,
    /Button\(\{ type: ButtonType\.Capsule \}\)[\s\S]{0,700}(?:计划|个子智能体)/);
  assert.match(workspace,
    /Button\(\{ type: ButtonType\.Normal \}\)[\s\S]{0,240}Text\('计划'\)/);
  assert.match(workspace,
    /Button\(\{ type: ButtonType\.Normal \}\)[\s\S]{0,700}个子智能体/);
});
