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

  assert.match(toolView, /nativeToolStructured\(this\.message, this\.workspaceRoot\)/);
  assert.match(toolView, /this\.structured\.bodyStructured[\s\S]{0,180}NativeStructuredToolView/);
  assert.match(toolView, /this\.structured\.showRawArguments[\s\S]{0,100}NativeTextContent/);
  assert.match(toolView, /this\.structured\.showRawOutput/);
  assert.match(toolView, /NativeRichContent/);
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
  assert.match(structuredView, /this\.onOpenFile\(file\.path\)/);
  assert.match(structuredView, /this\.openUrl\(source\.url\)/);
});
