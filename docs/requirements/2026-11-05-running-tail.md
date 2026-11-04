# Running tail with whale animation and elapsed line

Date: 2026-11-05

While a turn is running, the transcript should end with the same running
indicator as the DeepSeek Harness web chat: the animated whale tail, the
`深度求索中，用时 X秒 ···` line and the shimmering text animation. Until the
current turn's own content arrives, no duration is guessed.

- Copy the DSH whale asset and SVG fallback; animate the whale in ArkUI and
  reproduce the 1.5s text shimmer.
- Clock rules from the upstream client: start when the running turn is known,
  update every second, show at least 1 second, compact seconds/minutes and
  hours after 60 minutes; freeze while disconnected and never show a duration
  for a previous turn.
- Reduced motion resolves to the static whale path and static text.
- Keep the line above the composer dock, directly after the last transcript
  row, and cover it with model tests, a deterministic Mock scene, an
  interaction driver and current-HAP device evidence.
