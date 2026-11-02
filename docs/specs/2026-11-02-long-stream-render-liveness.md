# Long Stream Render Liveness Implementation Spec

Date: 2026-11-02

Requirement:
[`2026-11-02-long-stream-render-liveness.md`](../requirements/2026-11-02-long-stream-render-liveness.md)

Research:
[`2026-11-02-long-stream-render-liveness.md`](../research/2026-11-02-long-stream-render-liveness.md)

Upstream interaction baseline:
[`NATIVE-INTERACTION-SPEC.md`](../NATIVE-INTERACTION-SPEC.md), `CHAT00`,
`CHAT04`, `READ04`, `READ06`, `VIS03`.

## 1. Incremental streaming document

Add a pure `NativeStreamingMarkdownBuffer` service.

It consumes append-only display text and exposes:

```text
changed: boolean
reset: boolean
tail: string
tailInFence: boolean
blocks: string[]       complete stable blocks
appended: string[]     blocks completed by this update
```

Rules:

- Same input is a no-op.
- If new input is not an append of the prior input, reset and rescan once.
- Resume scanning at the prior end offset; never rescan the full document for an
  ordinary delta.
- A blank line outside a fenced code block completes a stable block.
- A closed fence remains in the active tail until a following block boundary or
  bounded split.
- A non-table block may split at a newline after 4096 UTF-16 code units so a
  single long prose response cannot create an unbounded parse tail.
- Do not split an open fence or a possible table at the bounded split point.
- Concatenating all stable blocks and the tail must reproduce the input exactly.

`NativeTextContent` keeps a buffer instance and renders stable blocks separately
from the repaired tail. Unchanged blocks receive the same text value. Parse a
new table only when its block becomes stable and parse the active tail table
only after the tail changes.

The existing `nativeRepairStreamingMarkdown()` contract remains authoritative
for the unfinished tail. Final `streaming=false` rendering continues to use the
complete text.

## 2. Parse and source caching

- `NativeInlineText.changed()` caches the last text/mask pair and returns
  without rebuilding runs when neither changed.
- `NativeTextSource.set()` returns without notifying listeners when value and
  protected ranges are unchanged.
- Streaming painting does not rebuild the full virtual text source on every
  delta.
- A long-stream reader prepares the full source once when opened.

## 3. Live assistant identity

Every live assistant row created or text-patched by
`nativeTranscript()`, `nativeWithLiveText()` or
`nativeUpdateLiveAssistant()` sets `runningTurn` from the live turn state. The
text-only fast path marks its row running because it is only used for accepted
delta updates.

## 4. Progress and recovery accounting

Add pure reducers for:

- assistant progress advanced;
- delivery mismatch resolved;
- Gateway delivery resume.

`NativeWorkspace` stores the last applied reducer tuple separately from the
last Gateway tuple.

- `assistantProgressAt` changes only when the reducer tuple changes.
- Duplicate `event`, `state`, `end` or `delta` receipts do not count as new
  progress.
- A mismatch timer starts on the first unequal Gateway/reducer tuple and remains
  active while unequal.
- The timer clears only when the reducer tuple equals the current Gateway
  mismatch tuple.
- Starting a new follow clears both tuple caches.

## 5. Gateway delivery drain

Keep upstream pause/resume around the client socket high/low watermark. Add a
250 ms drain check that resumes upstream when:

- the upstream is paused for client delivery;
- the client still has buffered data at or below the low watermark;
- the upstream socket is open.

Use a lower bounded high/low pair (`128 KiB` / `32 KiB`) suitable for a phone
response stream. The interval is unrefed and cleared when the live socket
closes.

## 6. Mock and E2E coverage

Add `stream-long` to `NativeUiFixture.states`.

The Mock follow path emits one assistant stream increment every display tick,
with long Markdown-heavy text, and ends with the visible marker
`STREAM-LONG-DONE`. It uses dense revisions and indices.

A new device driver must:

1. open `stream-long`;
2. capture at least two intermediate frames;
3. poll layout dumps until `STREAM-LONG-DONE` is visible without relaunching;
4. verify the composer remains present and the reconnect banner is absent;
5. capture the completed long-stream state;
6. write a manifest with HAP hash and timestamps.

Register the state and driver in
`docs/testing/mock-feature-manifest.json`.

## 7. Automated tests

- Append-only buffer preserves exact text.
- Stable blocks are emitted at blank-line boundaries and append updates only
  scan the new tail.
- The bounded tail does not grow with completed blocks.
- Unclosed fences and possible tables are not split.
- Reset replacement converges to a full rescan.
- Live transcript rows set `runningTurn` on create and patch.
- Only a changed reducer tuple advances assistant progress.
- Only an equal current Gateway tuple clears a delivery mismatch.
- Duplicate frames do not extend assistant-progress health.
- Gateway delivery resume requires paused, low buffered amount and open upstream.
- Existing stream-order, settlement, masking and Markdown tests remain green.

## 8. Build and evidence gate

This changes shared ArkUI code. Build and sign `default`, `store` and `mock`
Release variants. Run Mock coverage and PR QA. Device completion requires a
current-HAP run and recorded screen evidence; source tests and compilation are
not device proof.
