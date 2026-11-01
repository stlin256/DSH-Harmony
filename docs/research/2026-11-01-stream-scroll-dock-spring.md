# Streaming scroll and Dock spring research

## Current streaming path

`NativeWorkspace` coalesces all incoming tokens into a `16ms` paint timer. The
fast path correctly updates only the live assistant row, but it still publishes
a lazy-list tail change on every frame. `paint()` then schedules
`scrollEdge(Edge.Bottom)` through a zero-delay timer even while the user is
dragging the list. A long or expensive live row therefore performs list layout,
Markdown projection and a competing scroll command during direct manipulation.

`onScroll` also calls `isAtEnd()` for nearly every scroll callback before the
button visibility is debounced. This adds avoidable render-thread work during a
fling.

## Proposed streaming schedule

- Keep `16ms` coalescing when the reader is not scrolling.
- Mark transcript scroll motion from `onScrollFrameBegin`, movement touch events
  and `onScroll`, but ignore scroll events caused by the app's own tail command.
- While scroll motion is active, project text at a bounded background cadence
  and never issue a tail scroll.
- After scroll events become quiet, paint the latest model state, measure
  whether the reader is at the end, and only then resume following or expose the
  return-to-bottom action.
- Coalesce the tail scroll command itself so delayed layout callbacks cannot
  queue multiple scroll requests.

## Current Dock expansion path

The bottom Dock measures its natural content height and renders a material at
that height. The material has a disclosure spring, but the content column itself
has no shared height animation. Queue, change, attachment and error rows use the
faster `rowTransition()` while the live-change state changes inside a `micro`
transaction. The result is three clocks: fast child entry, measured-height
update and spring material resize.

## Proposed Dock schedule

- Use one `NativeMotion.disclosure()` transaction for state changes initiated by
  code.
- Apply `NativeMotion.disclosureParam()` to the measured material and the
  content column so height and clipping resolve together.
- Use `disclosureTransition()` for every control that can add height.
- Remove the material's independent row transition; the material is a surface
  of the Dock rather than an entering child.
- Keep reduced-motion behavior immediate.

## Verification limits

Source-level checks prove timer and animation wiring, not perceived smoothness.
Device evidence must capture a fling during active streaming plus slow-motion
screenshots or frame-time data for the Dock expansion.
