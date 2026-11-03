# Streaming scroll and Dock spring implementation specification

## 1. Scroll lifecycle

Add non-visual workspace state:

- `scrollMotionActive`
- `scrollMotionSettleTimer`
- `scrollTailTimer`
- `tailScrollGuardUntil`

`markScrollActivity()`:

1. returns while a return-to-bottom motion is active;
2. ignores callbacks inside the short programmatic-tail guard;
3. sets `scrollMotionActive`, `userHasScrolled` and `followTail = false`;
4. restarts a short inactivity timer.

When the inactivity timer fires, set `scrollMotionActive = false`, paint the
latest model state once and measure the current tail position.

## 2. Projection cadence

Incoming deltas continue to be accepted immediately by the session model.

- Outside scroll motion, retain the `16ms` projection cadence.
- During scroll motion, use a bounded `64ms` projection cadence.
- Structural frames still paint immediately, but must not issue an automatic
  tail scroll while scroll motion is active.
- Touch start cancels an in-flight return-to-bottom operation as it does today.

## 3. Tail scrolling

Replace per-paint zero-delay scroll calls with one coalesced
`scheduleTailScroll()` owner:

- require `followTail`, no returning animation and no active scroll motion;
- keep at most one timer;
- set `tailScrollGuardUntil` immediately before `scrollEdge`;
- clear the timer on disappearance.

Do not call `isAtEnd()` from every `onScroll` event. `onScroll` marks activity;
the settle timer performs one position check.

## 4. Dock spring

In `NativeBottomConversationDock`:

- apply `NativeMotion.disclosureParam()` to the material stack and the content
  column;
- clip the Dock's changing height;
- remove the material's independent `rowTransition()` and use an opacity
  transition on the same disclosure spring.

In `NativeWorkspace`:

- wrap live-change show/hide and optimistic queue insertion in
  `NativeMotion.disclosure()`;
- use `disclosureTransition()` for queue, live-change, attachment and error
  rows;
- keep the existing disclosure spring for expandable cards.

In `NativeQueueDock`, use disclosure transitions for inserted rows and expanded
lists. The root strip and its content use the same spring rather than a fast
row clock.

## 5. Verification

- Source contracts assert the `16/64ms` cadence, scroll-motion tail gate,
  single coalesced tail timer, programmatic-scroll guard and one Dock spring.
- Existing list tail-patching and model reducer tests remain green.
- Build community and store Release variants.
- Add a device E2E row for streaming while dragging/flinging and slow-motion Dock
  expansion. Keep it Pending without device evidence.
