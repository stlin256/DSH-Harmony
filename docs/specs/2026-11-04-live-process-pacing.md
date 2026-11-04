# Live process text pacing implementation

Date: 2026-11-04

`NativeStreamProcessPacer` in `NativeStreamPresentation.ets` owns one
`NativeStreamPresentation` cursor for the reasoning stream, one per reasoning
part index and one per preparing tool call. `offer()` receives the authority
strings and marks the cursors; `advance()` reveals them with the existing
adaptive rate, 600ms lag cap and surrogate-pair guard; `reset()` adopts a
fresh attempt or a restored cache immediately.

`nativeTranscript` gained optional `pacedToolTexts` and `pacedPartTexts` maps
so projection consumes the displayed prefix for preparing tools and reasoning
parts without mutating durable records. `NativeWorkspace` offers the pacer on
delta frames, advances it inside the existing semantic presentation timer, and
resets it on snapshot/start/end/event cuts plus session selection/restore.
When a process reveal advances, the paint must take the full projection path
(`streamTextPatchDirty = !processAdvanced`); a text-only reveal keeps the
live-assistant tail patch.

Model tests cover monotone prefix reveal, Unicode safety, convergence,
reduced-motion immediacy and per-attempt reset. The source contract covers
the timer wiring and the live-assistant patch decision.

## Remaining

The deterministic Mock scene for a live process strip currently exposes a
separate nested-list update quirk: the live process group is projected with
growing children, but the device capture path kept the first child snapshot
in the nested list. That is not a pacer defect, so this change does not claim
device completion for the strip; real-Host reasoning/tool turns are the next
verification target.
