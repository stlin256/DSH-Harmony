# Mobile Stream Stability Research

Date: 2026-11-01

## Observed mobile behavior

An independent mobile implementation uses a generation-aware `session/follow`
loop:

- the first item in every generation must be a snapshot;
- durable gaps are detected and repaired with `session/page`;
- every assistant-stream revision must equal the previous revision plus one;
- a snapshot is accepted only for the current mux generation;
- retired stream callbacks cannot publish into the current generation;
- normal Host stream completion reopens after a short delay;
- reconnect attempts use bounded backoff.

The observed default follow request uses `assistantStream: true`,
`maxMessages: 500` and
`turnWindow: { minMessages: 50, minTurns: 2 }`. The larger cap gives the turn
window room to choose complete turns instead of cutting at the default message
cap.

The observed client coalesces model-to-UI publication at 32 ms. It keeps
`syncing`, `resyncing` and `streamLost` separate, preserves the existing
transcript while a replacement snapshot is pending, and exposes an explicit
bounded resync.

The observed carrier uses a 15-second client ping and the Host has its own link
health. A 1.2-second quiet threshold stops the fast-output animation; it does
not declare the stream lost.

The observed behavior does not force-resync a healthy socket solely because
assistant text has stopped advancing. A conservative Harmony-specific progress
watchdog is therefore an extension, not an equivalence claim.

## Current DSH Harmony gaps

`NativeWorkspace.touchFollow()` refreshes the 15/45-second watchdog for every
incoming frame, including heartbeat data. The Gateway heartbeat contains
`cursor`, `attemptId`, `nextIndex` and `revision`, but the App immediately
returns after receiving it. This makes a live transport mask frozen assistant
delivery.

`NativeSessionModel` validates an assistant revision gap only when both the
stored and incoming revisions are greater than zero. An opening snapshot at
revision zero can therefore accept an unexpectedly jumped first revision.

Assistant deltas are visually published at 16 ms. This gives the UI more work
than the reference's 32 ms cadence while every frame is still applied
synchronously by the model. Faster refresh does not improve fidelity when the
result is main-thread backpressure.

The existing model already retains partial content through a committed end
until durable settlement, and the socket client already ignores callbacks from
a retired local generation. Those correct pieces should be preserved.

## Design consequences

- Keep exact protocol application in the session reducer.
- Separate link activity from assistant progress.
- Bind heartbeat progress to the active socket generation.
- Use the heartbeat tuple to detect delivery divergence; use the Host's running
  and waiting state to avoid repairing a legitimate tool or approval pause.
- Align visual coalescing with the proven 32 ms reference cadence.
- Keep a bounded repair path and retain the last good partial presentation.

