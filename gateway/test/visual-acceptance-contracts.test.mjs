import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const componentRoot = new URL('../../harmony/entry/src/main/ets/components/', import.meta.url);
const serviceRoot = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);
const readComponent = (name) => readFileSync(new URL(name, componentRoot), 'utf8');
const readService = (name) => readFileSync(new URL(name, serviceRoot), 'utf8');

test('compact visual controls use semantic dimensions', () => {
  const design = readService('NativeDesign.ets');
  assert.match(design, /compactHitTarget: number = 36/);
  assert.match(design, /compactControl: number = 32/);
  assert.match(design, /compactChip: number = 28/);

  for (const component of ['NativeAutomationSurface.ets', 'NativePluginsSurface.ets']) {
    const source = readComponent(component);
    assert.match(source, /Button\(actionLabel[\s\S]{0,120}height\(NativeDesign\.compactHitTarget\)/);
    assert.match(source, /Button\(this\.conflict \? '刷新' : '重试'|Button\('重试'/);
    assert.match(source, /height\(NativeDesign\.compactControl\)/);
  }

  const automation = readComponent('NativeAutomationSurface.ets');
  assert.match(automation, /Button\(label[\s\S]{0,100}height\(NativeDesign\.compactChip\)/);
  assert.match(
    automation,
    /Text\(nativeAutomationRule\(task\)\)\.fontSize\(NativeDesign\.fontCaption\)\.maxLines\(1\)/,
  );
  assert.doesNotMatch(
    automation,
    /Text\(nativeAutomationRule\(task\)\)\.fontSize\(11\)\.layoutWeight\(1\)/,
  );
});

test('dock ordering and material fallback preserve hierarchy and full bleed', () => {
  const workspace = readComponent('NativeWorkspace.ets');
  const pill = workspace.indexOf('NativeTurnChangePill({');
  const queue = workspace.indexOf('NativeQueueDock({');
  assert.ok(pill >= 0 && queue > pill, 'live turn state must precede queued input');

  const dock = readComponent('NativeBottomConversationDock.ets');
  assert.match(dock, /this\.elevated && NativeExperience\.materialsEnabled\(\)/);
  assert.match(dock, /else if \(this\.elevated\)/);
  assert.match(dock, /margin\(\{ left: -this\.horizontalBleed, right: -this\.horizontalBleed \}\)/);
  assert.match(dock, /backgroundColor\(NativeDesign\.subtleSurface\(this\.dark\)\)/);
});

test('turn change cards prioritize filenames and align to composer width', () => {
  const workspace = readComponent('NativeWorkspace.ets');
  assert.match(
    workspace,
    /Row\(\) \{\s*NativeTurnChangesCard\(\{[\s\S]{0,900}\}\.width\('100%'\)\.padding\(\{ left: 12, right: 12 \}\)/,
  );

  const card = readComponent('NativeTurnChangesView.ets');
  const filename = card.indexOf('Text(this.fileName(file))');
  const directory = card.indexOf('Text(this.fileDirectory(file))');
  const metrics = card.indexOf("Text('+' + formattedCount(file.added))");
  assert.ok(filename >= 0 && directory > filename && metrics > directory,
    'filename and fixed metrics must appear before the secondary directory line');
  assert.match(card, /height\(NativeDesign\.compactHitTarget\)\.width\('100%'\)/);
  assert.match(card, /height\(NativeDesign\.compactControl\)/);
});

test('interaction cards use compact, correct controls', () => {
  const interaction = readComponent('NativeInteraction.ets');
  const approvalBranch = interaction.indexOf("if (this.frame.interaction === 'approval/request')");
  const callBranch = interaction.indexOf('if (this.frame.callId)');
  assert.ok(approvalBranch >= 0 && callBranch > approvalBranch,
    'approval submissions must not fall through the generic question call branch');
  assert.match(interaction, /Text\(''\)\.width\(8\)\.height\(8\)\.borderRadius\(4\)/);
  assert.match(interaction, /height\(NativeDesign\.compactChip\)/);
  assert.match(interaction, /height\(NativeDesign\.compactHitTarget\)/);
  assert.match(interaction, /glyph: 'chevron-right-outline'/);
  assert.match(interaction, /TextArea\(\{ text: this\.answerFor\(question\.id\)\.custom/);
  assert.doesNotMatch(
    interaction,
    /TextArea\(\{ text: this\.answerFor\(question\.id\)\.custom[\s\S]{0,220}borderRadius\(NativeDesign\.radiusRow\)/,
  );

  const showcase = readService('StoreShowcaseClient.ets');
  assert.match(showcase, /if \(operation === 'answerQuestion'\)[\s\S]{0,220}return 'true'/);
});

test('composer and attachment surfaces remain compact without shrinking type', () => {
  const workspace = readComponent('NativeWorkspace.ets');
  assert.match(workspace, /TextArea\(\{ text: this\.draft, placeholder: '发送消息…' \}\)\.height\(NativeDesign\.compactHitTarget\)/);
  assert.match(workspace, /width\(NativeDesign\.compactHitTarget\)\.height\(NativeDesign\.compactHitTarget\)/);
  assert.match(workspace, /height\(NativeDesign\.compactHitTarget\)\.padding\(\{ left: 7, right: 2 \}\)/);
  assert.match(workspace, /if \(\(this\.subagentCatalog\?\.length \|\| 0\) > 0\) \{[\s\S]{0,1600}\.clip\(true\)/);
});

test('task plan header and mode chip stay compact and clipped', () => {
  const dock = readComponent('NativeTaskDock.ets');
  assert.match(
    dock,
    /\.height\(NativeDesign\.compactControl\)\.width\('100%'\)\.padding\(0\)\.borderRadius\(0\)/,
  );
  assert.match(dock, /constraintSize\(\{ maxWidth: 620 \}\)\.clip\(true\)/);

  const workspace = readComponent('NativeWorkspace.ets');
  assert.match(
    workspace,
    /if \(nativePlanTargetActive\(this\.planProjection\)\) \{\s*Button\(\{ type: ButtonType\.Normal \}\)/,
  );
  assert.match(
    workspace,
    /\.borderRadius\(NativeDesign\.radiusChip\)[\s\S]{0,320}\.clip\(true\)[\s\S]{0,220}\.accessibilityText\('计划模式已开启，点击关闭'\)/,
  );
});
