import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';

const root = new URL('../../harmony/entry/src/main/ets/', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');

test('semantic design source owns colors, geometry, typography and icon tones', () => {
  const source = read('services/NativeDesign.ets');
  for (const token of [
    'base(', 'subtleSurface(', 'raised(', 'overlay(', 'field(', 'selection(',
    'selectedSurface(', 'border(', 'divider(', 'textPrimary(', 'textSecondary(',
    'textTertiary(', 'textInverse(', 'accent(', 'accentStrong(', 'accentSurface(',
    'success(', 'successSurface(', 'warning(', 'warningSurface(', 'danger(',
    'dangerSurface(', 'mask(', 'iconTone('
  ]) {
    assert.match(source, new RegExp(token.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
  assert.match(source, /static hitTarget: number = 44/);
  assert.match(source, /static visualIconContainer: number = 36/);
  assert.match(source, /static compactRow: number = 44/);
  assert.match(source, /static standardRow: number = 48/);
  assert.match(source, /static pickerRow: number = 44/);
  assert.match(source, /static doubleLineRow: number = 60/);
  assert.match(source, /static primaryActionHeight: number = 48/);
  assert.match(source, /static radiusControl: number = 10/);
  assert.match(source, /static radiusRow: number = 12/);
  assert.match(source, /static radiusGroup: number = 16/);
  for (const token of [
    'fontPageTitle', 'fontHeaderTitle', 'fontCompactTitle', 'fontBody',
    'fontCompact', 'fontSection', 'fontCaption', 'fontMicro', 'fontEmptyTitle',
    'fontMetric', 'fontBrand', 'glyphMicro', 'glyphInline', 'glyphCompact',
    'glyphControl', 'glyphControlEmphasis', 'glyphHeader', 'glyphHero',
    'glyphEmpty', 'spinnerInline', 'spinnerPage'
  ]) {
    assert.match(source, new RegExp('static ' + token + ':'), token);
  }
});

test('shared icon button separates the 44vp hit target from its 36vp visual', () => {
  const source = read('components/NativeIconButton.ets');
  assert.match(source, /NativeDesign\.visualIconContainer/);
  assert.match(source, /NativeDesign\.hitTarget/);
  assert.match(source, /backgroundColor\(this\.active \? NativeDesign\.selection/);
  assert.match(source, /NativeMotion\.implicit\('press'\)/);
  const icon = read('components/DSHIcon.ets');
  assert.match(icon, /NativeDesign\.iconTone/);
});

test('drawer, overlay, interaction and file surfaces consume the semantic layer', () => {
  for (const path of [
    'pages/Index.ets',
    'components/NativeWorkspace.ets',
    'components/NativeSettings.ets',
    'components/AboutSettings.ets',
    'components/NativeMessageView.ets',
    'components/NativeQueueDock.ets',
    'components/NativeInteraction.ets',
    'components/NativeFileBrowser.ets',
    'components/NativeFilePreview.ets',
    'components/NativeImageLightbox.ets'
  ]) {
    assert.match(read(path), /NativeDesign/, path + ' must import NativeDesign');
  }
});

test('motion has one semantic source and reduced-motion bypasses every token', () => {
  const source = read('services/NativeMotion.ets');
  for (const token of [
    'press', 'micro', 'overlay', 'navigation', 'drawer', 'surface', 'mask',
    'scrollReturn', 'brand'
  ]) {
    assert.match(source, new RegExp("'" + token + "'"));
  }
  assert.match(source, /if \(!NativeMotion\.enabled\(\)\) return \{ duration: 0 \}/);
  assert.match(source, /static maskParam\(\)/);
  assert.match(source, /static drawerTransition\(\)/);

  const components = [
    'components/NativeWorkspace.ets',
    'components/NativeFileBrowser.ets',
    'components/NativeFilePreview.ets',
    'components/NativeQueueDock.ets',
    'components/NativeInteraction.ets',
    'components/NativeTaskDock.ets'
  ].map(read).join('\n');
  assert.doesNotMatch(components, /\.animateTo\(\s*\{\s*duration:\s*\d+/,
    'product components must use NativeMotion instead of local durations');
});

test('phone selection and anchored menus cannot regress to desktop/modal behavior', () => {
  const source = read('components/NativeWorkspace.ets');
  assert.match(source, /private selectionSurface\(\): string \{[\s\S]{0,120}NativeDesign\.selection/);
  assert.match(source, /backgroundColor\(this\.selected === row\.session\.id \?[\s\S]{0,80}this\.selectionSurface\(\)/);
  assert.doesNotMatch(source, /mask:\s*true/);
  assert.match(source, /mask:\s*false/);
  assert.match(source,
    /this\.menuId === row\.session\.id \? this\.primaryText\(\) : this\.tertiaryText\(\)/);
});

test('raw colors remain limited to documented media, syntax, shadow and brand exceptions', () => {
  const allowed = new Set([
    'components/DSHIcon.ets',
    'components/NativeCodeBlock.ets',
    'components/NativeCodeViewer.ets',
    'components/NativeImageLightbox.ets',
    'components/NativeWorkspace.ets',
    'components/NativeTurnChangesView.ets',
    'components/NativeTaskDock.ets',
    'components/NativeLaunchSurface.ets'
  ]);
  const componentDir = new URL('components/', root);
  for (const name of readdirSync(componentDir).filter(value => value.endsWith('.ets'))) {
    const path = 'components/' + name;
    const source = read(path);
    if (/#[0-9A-Fa-f]{6,8}/.test(source)) {
      assert.ok(allowed.has(path), path + ' contains undocumented raw colors');
    }
  }
});
