# Conversation stability investigation

Date: 2026-11-05

## Log access

`/data/log/faultlog` is owned by the system and is not readable by the `shell`
user on this device (`Permission denied`); `HiviewFaultLogger` exposes no dump
over `hidumper`, and the hilog ring buffer had already rotated past the midday
crashes. No crash stack could therefore be recovered from the device.

## Suspects and mitigations

- The previous running-tail revision mounted a 48-frame animated WebP inside a
  100ms rotate/scale ticker; both state churn and repeated animated decoding
  were removed or isolated. The animated resource now lives in
  `NativeRunningWhale` and is not rebuilt by sweep state.
- Timers previously kept updating while backgrounded. Both timers now require
  `nativeAppActive` and are cleared on disappear.
- The sweep timer was reduced to a single state update per 33ms; clock and
  sweep are the only per-frame work in the row.
- `NativeStreamPresentation`/`NativeStreamProcessPacer` remain the only other
  high-frequency writers; their cadence is unchanged.

## Evidence

A 180-second Mock continuous-turn sample kept the process alive in 12/12
samples; the sample predates the final revision and is recorded in
`artifacts/conversation-stress/manifest.json`. Device fault logging for
future crashes requires the user to export a faultlog or unlock the device for
`hdc` log capture.
