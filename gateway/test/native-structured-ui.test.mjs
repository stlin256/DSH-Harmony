import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('structured tool rows render before generic argument and output fallback', () => {
  const toolView = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeToolCallView.ets', import.meta.url), 'utf8');
  const processView = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeProcessView.ets', import.meta.url), 'utf8');
  const processStep = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeProcessStepView.ets', import.meta.url), 'utf8');
  const structuredView = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeStructuredToolView.ets', import.meta.url), 'utf8');
  const pluginCard = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativePluginCard.ets', import.meta.url), 'utf8');

  assert.match(toolView, /nativeToolStructured\(this\.message, this\.workspaceRoot\)/);
  assert.match(toolView, /this\.structured\.bodyStructured[\s\S]{0,180}NativeStructuredToolView/);
  assert.match(toolView, /this\.structured\.showRawArguments[\s\S]{0,100}NativeTextContent/);
  assert.match(toolView, /this\.structured\.showRawOutput/);
  assert.match(toolView, /NativeRichContent/);
  assert.match(toolView, /private hasRenderableBody\(\): boolean/);
  assert.match(toolView, /工具没有返回内容/);
  assert.match(toolView, /onOpenFile: this\.onOpenFile/);
  assert.match(processView, /workspaceRoot: this\.workspaceRoot/);
  assert.match(processStep,
    /NativeToolCallView\(\{[\s\S]{0,160}workspaceRoot: this\.workspaceRoot/);
  assert.match(toolView,
    /NativeNestedToolRow\(\{[\s\S]{0,180}workspaceRoot: this\.workspaceRoot/);
  const nested = toolView.slice(toolView.indexOf('struct NativeNestedToolRow'));
  assert.match(nested, /@Prop @Watch\('changed'\) message: NativeMessage/);
  assert.match(nested,
    /private changed\(\): void \{\s*this\.structured = nativeToolStructured/);
  assert.match(structuredView, /NativeCodeViewer\(/);
  assert.match(structuredView,
    /this\.document\.read\.lines\.length \* 22 \+ 8[\s\S]{0,160}Math\.min\(280, this\.maxExpandedHeight, contentHeight\)/);
  assert.match(structuredView, /compact: true/);
  assert.match(structuredView, /private commandRow\(field: NativeStructuredField\)/);
  assert.match(structuredView,
    /Text\(field\.value\)\.width\('100%'\)\.fontSize\(NativeDesign\.fontMicro\)[\s\S]{0,100}lineHeight\('16fp'\)/);
  assert.match(structuredView,
    /field\.label === '命令'[\s\S]{0,80}this\.commandRow\(field\)/);
  assert.match(structuredView, /this\.onOpenFile\(file\.path\)/);
  assert.match(structuredView, /this\.openUrl\(source\.url\)/);
  assert.match(structuredView,
    /Text\(file\.name \|\| file\.display \|\| file\.path\)[\s\S]{0,500}Text\(file\.directory\)/);
  assert.match(structuredView,
    /Text\(this\.document\.displayName \|\| this\.document\.displayPath \|\| this\.document\.path\)[\s\S]{0,500}Text\(this\.document\.displayDirectory\)/);
  assert.match(pluginCard, /block\.kind === 'metrics' \|\| block\.kind === 'metric'/);
  assert.match(pluginCard, /this\.metricsBlock\(block\)/);
  assert.match(pluginCard,
    /Text\(this\.document\.title \|\| '插件卡片'\)[\s\S]{0,420}this\.document\.truncated[\s\S]{0,220}Text\('内容已截断'\)/);
});

test('terminal output uses the compact monospace text density', () => {
  const textContent = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeTextContent.ets', import.meta.url), 'utf8');
  const toolView = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeToolCallView.ets', import.meta.url), 'utf8');

  assert.match(textContent, /@Prop denseMonospace: boolean = false/);
  assert.match(textContent,
    /fontSize\(this\.denseMonospace \? NativeDesign\.fontMicro : NativeDesign\.fontSection\)/);
  assert.match(textContent,
    /lineHeight\(this\.denseMonospace \? '16fp' : '22fp'\)/);
  assert.match(toolView,
    /denseMonospace: this\.structured\.family === 'terminal'/);
});
