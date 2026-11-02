import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const viewer = readFileSync(new URL(
  '../../harmony/entry/src/main/ets/components/NativeCodeViewer.ets', import.meta.url), 'utf8');
const preview = readFileSync(new URL(
  '../../harmony/entry/src/main/ets/components/NativeFilePreview.ets', import.meta.url), 'utf8');

test('code viewer resets both axes when a different file reuses the reader', () => {
  assert.match(viewer, /@Prop @Watch\('identityChanged'\) identity: string/);
  assert.match(viewer, /private verticalScroller: Scroller = new Scroller\(\)/);
  assert.match(viewer, /private horizontalScroller: Scroller = new Scroller\(\)/);
  assert.match(viewer, /identityChanged\(\): void \{[\s\S]{0,120}this\.resetViewport\(\)/);
  assert.match(viewer, /verticalScroller\.scrollEdge\(Edge\.Top\)/);
  assert.match(viewer, /horizontalScroller\.scrollEdge\(Edge\.Start\)/);
  assert.match(viewer, /Scroll\(this\.verticalScroller\)/);
  assert.match(viewer, /Scroll\(this\.horizontalScroller\)/);
  assert.match(preview, /identity: this\.path/);
});

test('code viewer supports a compact embedded read surface', () => {
  assert.match(viewer, /@Prop compact: boolean = false/);
  assert.match(viewer,
    /this\.compact \? this\.lines\.length \* 22 \+ 8 : Math\.max\(44, this\.lines\.length \* 22 \+ 8\)/);
});

test('preview keeps compact breathing room above gesture navigation', () => {
  assert.match(preview, /bottom: 12 \+ Math\.max\(16, this\.safeBottom\)/);
});

test('code viewer pins horizontal position to the bottom of the text surface', () => {
  assert.match(viewer, /@State private horizontalProgress: number = 0/);
  assert.match(viewer, /private horizontalThumbWidth\(\): number/);
  assert.match(viewer, /private horizontalThumbOffset\(\): number/);
  assert.match(viewer, /private horizontalLaneHeight\(\): number[\s\S]{0,100}12 : 0/);
  assert.match(viewer, /private verticalOverflow\(\): boolean/);
  assert.match(viewer, /@State private horizontalBarVisible: boolean = false/);
  assert.match(viewer, /private bottomHorizontalScrollBar\(\)/);
  assert.match(viewer, /scrollBar\(BarState\.Off\)/);
  assert.match(viewer, /scrollBar\(this\.verticalOverflow\(\) \? BarState\.Auto : BarState\.Off\)/);
  assert.match(viewer, /this\.horizontalScroller\.currentOffset\(\)\.xOffset/);
  assert.match(viewer, /private showHorizontalBar\(\): void/);
  assert.match(viewer, /this\.horizontalBarVisible = true/);
  assert.match(viewer, /this\.horizontalBarVisible = false/);
  assert.match(viewer, /\.opacity\(this\.horizontalBarVisible \? 1 : 0\)/);
  assert.match(viewer, /private workspaceHeight\(\): number/);
  assert.match(viewer, /this\.viewerHeight/);
  assert.match(viewer, /\.height\(this\.workspaceHeight\(\)\)[\s\S]{0,120}ScrollDirection\.Horizontal/);
  assert.match(viewer, /\.width\(this\.gutterWidth\(\)\)\.height\(this\.workspaceHeight\(\)\)/);
  assert.match(viewer, /Stack\(\{ alignContent: Alignment\.BottomStart \}\)/);
  assert.match(viewer, /if \(this\.horizontalOverflow\(\)\)[\s\S]{0,80}bottomHorizontalScrollBar/);
});
