import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const motion = readFileSync(new URL('harmony/entry/src/main/ets/services/NativeMotion.ets', root), 'utf8');
const workspace = readFileSync(new URL('harmony/entry/src/main/ets/components/NativeWorkspace.ets', root), 'utf8');

test('connection banners share one semantic appear/leave transition', () => {
  assert.match(motion, /static statusBannerTransition\(\): TransitionEffect \{/);
  assert.match(motion, /if \(!NativeMotion\.enabled\(\)\) return TransitionEffect\.IDENTITY;/);
  assert.match(motion, /TransitionEffect\.asymmetric\(enter, leave\)/);
  assert.match(motion, /NativeMotion\.implicit\('micro'\)/);
  assert.match(motion, /NativeMotion\.exitDuration\('micro'\)/);
  assert.match(workspace,
    /if \(this\.connectionRetrying\(\) && !this\.selected\) \{[\s\S]{0,400}\.transition\(NativeMotion\.statusBannerTransition\(\)\)/);
  assert.match(workspace,
    /if \(this\.streamFailure\) \{[\s\S]{0,900}\.transition\(NativeMotion\.statusBannerTransition\(\)\)/);
  assert.match(workspace,
    /if \(this\.connectionRetrying\(\)\) \{[\s\S]{0,900}\.transition\(NativeMotion\.statusBannerTransition\(\)\)/);
});

test('retry banner is deterministic for the Mock capture scene', () => {
  assert.match(workspace, /private connectionRetrying\(\): boolean \{/);
  assert.match(workspace, /storeShowcaseState'\) === 'connection-retrying'/);
});
