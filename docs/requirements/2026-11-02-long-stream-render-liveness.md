# Long Stream Render Liveness Requirement

Date: 2026-11-02

Status: accepted for implementation.

## User-visible problem

On the physical phone, a live assistant answer can arrive in a few uneven
bursts, stop repainting, and only show the missing continuation after a cold
launch. The Host continues producing data, so a new App process can render the
newer snapshot.

Text must remain visibly live for the whole turn. The App cannot require a cold
launch, a session switch or manual reconnect to reveal content that has already
arrived.

## Required behavior

- Every accepted assistant delta remains in the model; no visual optimization
  may truncate, reorder or discard streamed content.
- Visual publishing may coalesce several deltas, but the published amount must
  continue to advance while deltas keep arriving.
- Work per paint must be bounded by the unfinished Markdown tail and newly
  completed blocks, not by the complete length of the growing answer.
- A live assistant row must be marked as a running turn on every path that
  creates or patches it. Streaming repair cannot depend on timing or reconnect.
- Link activity, Host delivery progress and client paint progress are distinct.
  Repeated or duplicate frames do not count as assistant progress.
- A stable heartbeat/reducer mismatch starts one bounded repair; only a reducer
  tuple equal to the current Gateway tuple may clear that mismatch.
- If the client socket buffer reaches its pause threshold, upstream delivery
  must resume from a bounded drain check even when no new send callback arrives.
- The physical-device acceptance must use a long, Markdown-heavy stream and
  prove that a final visible marker appears without restarting the App.

## Out of scope

- Replacing native Markdown with a WebView.
- Reducing the protocol to non-streaming responses.
- Treating the absence of a network frame as proof that rendering is healthy.
- Changing the DSH visual language or adding decorative stream motion.
