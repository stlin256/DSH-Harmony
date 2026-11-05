# Running tail implementation

Date: 2026-11-05 (revised)

## Data and copy

`NativeRunningStatus.ets` owns `nativeRunDuration` (1s floor,
seconds/minutes/hours), `nativeRunningLabel` (no duration before a known
start, otherwise `深度求索中，用时 X秒 ···`) and `nativeRunningElapsed`
(paused freezes the sampled elapsed value).

Authoritative start:

- Gateway `latestOpenTurnStartedAt(messages)` derives the latest
  `turn/start` without a matching `turn/end` from the opening snapshot;
  `normalizeFollow` emits it as `turnStartedAt`.
- The follow request uses `maxMessages: 32` plus
  `turnWindow: { minMessages: 8, minTurns: 1 }`.
- If the snapshot still has no start, the gateway reads one bounded
  back-page (400 records) and sends `{ type: 'turn-start', turnStartedAt }`.
- `NativeSessionModel.runningTurnStartedAt` is set from snapshots and the
  extra frame, updated on live `turn/start` / `turn/end`, cleared when idle
  and persisted in the cache record.
- `NativeWorkspace.runningTurnStartedAt()` prefers the model value and falls
  back to scanning loaded turn rows.

## Component

`NativeRunningTail.ets` takes `startedAt`, `paused` and `leaving`.

- One 1000ms clock updates the label; one 33ms timer advances a 2000ms
  sweep timeline. Both timers no-op unless the ability is active and clear on
  disappear.
- The gradient band travels from `-0.35` to `1.35`; its alpha is gated so it
  starts and ends fully invisible; the wrap is therefore unobservable.
- The whale is an 18vp `ImageAnimator` (15 colorized APNG frames, 3s loop) plus
  a static glow overlay whose opacity follows the same travel value, so light
  crosses the icon, glyphs and dots. Reduced motion uses the first frame.
- Entry animates 190ms (height/opacity/offset); the workspace keeps the row
  mounted for the 170ms leave animation, then removes it.
- Reduced motion skips both timers' visual effect: flat gradient, first whale
  frame, no translations. The clock still updates.

## Workspace integration

The row is a sibling between the transcript `Stack` and the interaction area:
rendered while `runningTailVisible && followTail`, so it stays pinned above the
composer and disappears when the user scrolls up. `syncRunningTail`
expands/contracts a `runningTailVisible` + `runningTailLeaving` pair and drives
`runningTailEnter` for the appearance/exit animation.

## Verification

`device-ui-running-tail-e2e.ps1` asserts: authoritative elapsed at launch
(9–25s for the fixture), placement above the composer, clock growth, region
animation between captures, light theme, reduced-motion static frames, and
appearance/disappearance after stopping the running turn.
