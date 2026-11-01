import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../../harmony/entry/src/main/ets/components/', import.meta.url);

test('structured cards and background notices are wired as read-only native surfaces', () => {
  const structured = readFileSync(new URL('NativeStructuredToolView.ets', root), 'utf8');
  const workspace = readFileSync(new URL('NativeWorkspace.ets', root), 'utf8');
  const queue = readFileSync(new URL('NativeQueueDock.ets', root), 'utf8');
  const plugin = readFileSync(new URL('NativePluginCard.ets', root), 'utf8');
  const media = readFileSync(new URL('NativeMediaCard.ets', root), 'utf8');
  const notice = readFileSync(new URL('NativeBackgroundNoticeView.ets', root), 'utf8');
  const message = readFileSync(new URL('NativeMessageView.ets', root), 'utf8');
  const dshUi = readFileSync(new URL('NativeDshUiCard.ets', root), 'utf8');
  assert.match(structured, /NativePluginCard\(\{ document: this\.document\.plugin \}\)/);
  assert.match(structured, /NativeMediaCard\(\{[\s\S]{0,120}onOpenFile: this\.onOpenFile/);
  assert.match(workspace, /message\.role === 'background-notice'[\s\S]{0,160}NativeBackgroundNoticeView/);
  assert.match(queue, /item\.sourceKind !== 'tool-jobs'/);
  assert.match(plugin, /interactive: boolean = false/);
  assert.match(plugin, /return this\.interactive && this\.canReply/);
  assert.doesNotMatch(plugin, /fetch\(|http\.request|@kit\.NetworkKit/);
  assert.match(media, /onClick\(\(\): void => \{ this\.onOpenFile\(item\.path\); \}\)/);
  assert.match(notice, /copyOption\(CopyOptions\.InApp\)/);
  assert.doesNotMatch(notice, /NativeTextContent|NativeInlineText|onCompatibility/);
  assert.match(message, /nativeDshUiReplyLabel\(this\.message\.text\)/);
  assert.match(message, /block\.language[\s\S]{0,80}dsh-ui/);
  assert.match(message, /NativeDshUiCard\(\{/);
  assert.match(dshUi, /nativeDshUiDocument\(this\.source\)/);
  assert.match(dshUi, /NativePluginCard\(\{[\s\S]{0,120}interactive: true/);
  assert.match(workspace, /sendDshUiReply\(text: string\)/);
  assert.match(workspace, /this\.client\.prompt\(id, text, 'queue', \[\], requestId\)/);
});
