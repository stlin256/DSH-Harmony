import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';

const services = new URL('../../harmony/entry/src/main/ets/services/', import.meta.url);

function load(name, kits = {}) {
  const source = readFileSync(new URL(name + '.ets', services), 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: {
      target: ts.ScriptTarget.ES2022,
      module: ts.ModuleKind.CommonJS
    }
  });
  const module = { exports: {} };
  vm.runInNewContext(output.outputText, {
    module,
    exports: module.exports,
    require: id => {
      if (!(id in kits) && id.startsWith('./') &&
          existsSync(new URL(id.slice(2) + '.ets', services))) {
        return load(id.slice(2), kits);
      }
      if (!(id in kits)) throw Error('Unexpected dependency: ' + id);
      return kits[id];
    }
  });
  return module.exports;
}

function transcriptModule() {
  const models = load('NativeSessionModel');
  return load('NativeTranscript', {
    './NativeSessionModel': models,
    './NativeHostSettings': {},
    './NativePlan': {
      nativePlanDiff: () => '',
      nativePlanDocument: () => ({ parsed: false, items: [] }),
      nativePlanProgress: () => ''
    }
  });
}

test('tail-only list publication skips render-key reconstruction', () => {
  const { NativeListSource } = load('NativeListSource');
  const source = new NativeListSource();
  const events = [];
  source.registerDataChangeListener({
    onDataChange: index => events.push('change:' + index),
    onDataReloaded: () => events.push('reload'),
    onDataAdded: index => events.push('add:' + index),
    onDataDeleted: index => events.push('delete:' + index),
    onDataMoved: (from, to) => events.push('move:' + from + ':' + to)
  });
  source.set([{ id: 'stable', text: 'old' }, { id: 'live', text: 'a' }],
    row => row.id);
  events.length = 0;
  source.setTail([{ id: 'stable', text: 'old' }, { id: 'live', text: 'ab' }]);
  assert.deepEqual(events, ['change:1']);
  assert.equal(source.getData(1).text, 'ab');

  events.length = 0;
  source.setTail([{ id: 'live', text: 'ab' }]);
  assert.ok(events.includes('reload'));
});

test('live text patching is limited to the final assistant row', () => {
  const models = load('NativeSessionModel');
  const { nativeUpdateLiveAssistant } = transcriptModule();
  const live = Object.assign(new models.NativeMessage(), {
    id: 'live-assistant',
    role: 'assistant',
    text: 'old'
  });
  const patched = nativeUpdateLiveAssistant([
    Object.assign(new models.NativeMessage(), { id: 'message', role: 'user', text: 'prompt' }),
    live
  ], 'new');
  assert.equal(patched.at(-1).text, 'new');
  assert.equal(patched.at(-1).runningTurn, true);
  assert.equal(live.text, 'old');

  const stale = nativeUpdateLiveAssistant([
    live,
    Object.assign(new models.NativeMessage(), { id: 'tool-result', role: 'tool', toolName: 'read' })
  ], 'new');
  assert.equal(stale, null, 'a live row before a newer structural row must not take the tail path');
});

test('native workspace invalidates text-only patching on structural or tool frames', () => {
  const workspace = readFileSync(new URL(
    '../../harmony/entry/src/main/ets/components/NativeWorkspace.ets',
    import.meta.url), 'utf8');
  assert.match(workspace,
    /const textOnly = frame\.text\.length > 0 && !frame\.reasoning && !\(frame\.toolUpdates \|\| \[\]\)\.length;/);
  assert.match(workspace,
    /this\.streamTextPatchDirty = textOnly && \(this\.paintTimer < 0 \|\| this\.streamTextPatchDirty\);/);
  assert.match(workspace,
    /\['snapshot', 'event', 'start', 'end', 'state'\]\.includes\(frame\.type\)\) \{[\s\S]{0,80}this\.streamTextPatchDirty = false;/);
  assert.match(workspace,
    /const textAdvanced = this\.presentation\.advance\(Date\.now\(\), !NativeMotion\.enabled\(\)\);/);
  assert.match(workspace,
    /const processAdvanced = this\.processPacer\.advance\(Date\.now\(\), !NativeMotion\.enabled\(\)\);/);
  assert.match(workspace,
    /if \(textAdvanced \|\| processAdvanced\) \{[\s\S]{0,420}this\.streamTextPatchDirty = !processAdvanced;/);
  // Live process text paces through the same semantic timer, while durable
  // process frames still invalidate the text-only patch path.
  assert.match(workspace,
    /this\.offerLiveProcess\(!NativeMotion\.enabled\(\)\);[\s\S]{0,120}this\.schedulePresentation\(\);/);
  assert.match(workspace,
    /if \(tailOnlyTextUpdate\)[\s\S]{0,180}this\.source\.setTail\(visible, 2\)[\s\S]{0,180}this\.source\.set\(visible/);
});

test('long streaming text is buffered into stable blocks with a bounded tail', () => {
  const { NativeStreamingMarkdownBuffer } = load('NativeStreamingMarkdown', {});
  const buffer = new NativeStreamingMarkdownBuffer();
  const source = Array.from({ length: 160 }, (_, index) =>
    `段落 ${index}: **流式内容** 与 [文档](https://example.invalid/${index})\n\n`).join('') +
    '尚未结束的 **尾部';
  let update;
  for (let end = 0; end < source.length; end += 7) {
    update = buffer.update(source.slice(0, Math.min(source.length, end + 7)));
  }
  update = buffer.update(source);
  const blocks = buffer.getBlocks();
  assert.ok(buffer.blockCount() > 100);
  assert.equal(blocks.join('') + update.tail, source);
  assert.ok(update.tail.length < 256, 'finished paragraphs must not remain in the active tail');
  assert.ok(buffer.scannedCharacters <= source.length + 7,
    'append updates must scan each completed source line once');
});

test('streaming buffer does not split fenced code or possible tables', () => {
  const { NativeStreamingMarkdownBuffer } = load('NativeStreamingMarkdown', {});
  const fenceBuffer = new NativeStreamingMarkdownBuffer();
  const fence = '```typescript\n' + 'const value = "stream";\n'.repeat(300);
  const fenceUpdate = fenceBuffer.update(fence);
  assert.equal(fenceBuffer.blockCount(), 0);
  assert.equal(fenceUpdate.tailInFence, true);
  assert.equal(fenceUpdate.tail, fence);

  const tableBuffer = new NativeStreamingMarkdownBuffer();
  const table = '| A | B |\n| --- | --- |\n' +
    Array.from({ length: 240 }, (_, index) => `| ${index} | value |\n`).join('');
  const tableUpdate = tableBuffer.update(table);
  assert.equal(tableBuffer.blockCount(), 0);
  assert.equal(tableUpdate.tail, table);
});

test('streaming buffer resets coherently when the source is replaced', () => {
  const { NativeStreamingMarkdownBuffer } = load('NativeStreamingMarkdown', {});
  const buffer = new NativeStreamingMarkdownBuffer();
  buffer.update('first paragraph\n\nsecond');
  assert.equal(buffer.blockCount(), 1);
  const reset = buffer.update('replacement');
  assert.equal(reset.reset, true);
  assert.equal(buffer.blockCount(), 0);
  assert.equal(reset.tail, 'replacement');
});
