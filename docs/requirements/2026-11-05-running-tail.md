# Running tail with authoritative timing and a continuous light sweep

Date: 2026-11-05 (revised after device feedback)

While a turn is running, the transcript itself must end with the DSH running
indicator: the whale, `深度求索中，用时 X秒 ···` and a sweeping light effect.

- Placement: the row is the very last item of the conversation flow (the same
  place DSH renders its running status), so new content grows above it and
  scrolling carries it down into the hidden area below the viewport; it is not
  a fixed dock.
- Timing: the clock is the Host's `turn/start` event time, including turns
  started from another client. Opening the app mid-turn shows the real elapsed
  time, not a count from app launch.
- Appearance and disappearance animate the row height, opacity and offset.
- The light effect is a text shader sweep that starts on the whale, crosses
  every glyph and the trailing dots, fades completely out past the row and
  only then begins the next pass; it is not a per-frame color blink.
- The whale and ellipsis are part of the same sweep timeline; the whale uses
  the authored DSH frames as static stills, sized to the 18vp control box.
- Reduced motion keeps the row static (no sweep, no entrance translation).
- Cover the behaviour with gate tests, the `stream-tail` Mock scene, the
  running-tail driver (dark, light, reduced motion, appearance/disappearance)
  and current-HAP device evidence.
