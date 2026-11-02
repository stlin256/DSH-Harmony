# Live process stream ordering implementation spec

Requirement:
[`2026-11-02-live-process-stream-order.md`](../requirements/2026-11-02-live-process-stream-order.md)

Research:
[`2026-11-02-live-process-stream-order.md`](../research/2026-11-02-live-process-stream-order.md)

Upstream interaction baseline:
[`NATIVE-INTERACTION-SPEC.md`](../NATIVE-INTERACTION-SPEC.md), `CHAT04`

## 1. Protocol timeline

Gateway normalization adds `streamParts`, an ordered array of:

- `{ kind: "reasoning", text }`
- `{ kind: "tool", callId, name }`
- `{ kind: "text", text }`

`compactText` emits parts by walking the active stream records in source order.
Adjacent text or reasoning runs merge; a tool call enters the timeline only at
its first appearance. Individual assistant-stream deltas emit the same shape so
the client can append without reconstructing order from aggregate fields.

`text`, `reasoning`, `toolUpdates` and `streamTools` remain for compatibility.
They are projections of the timeline, not ordering authority.

## 2. Client model

`NativeSessionModel.streamParts` stores the active timeline. Snapshot applies
replace it, deltas append or update in place, and start/end/settlement clears it
with the other live stream fields. `NativeSessionCacheRecord` persists the
timeline so a cached in-progress turn does not reorder after restart.

The reducer validates identities but does not sort by text, timestamp, call
name or arrival of the aggregate fields.

## 3. Transcript projection

When a live timeline exists, `nativeTranscript` appends live process entries in
timeline order:

1. Reasoning parts become separate `reasoning` operations with stable live ids.
2. Tool parts resolve to the current `streamTools` record by `callId`; repeated
   argument updates do not create or move a row.
3. Unrepresented aggregate tools are appended as a lossless compatibility
   fallback.
4. Live assistant text remains the reply tail.

The legacy path, where no timeline metadata exists, appends all tools and then
the aggregate reasoning. It is only a compatibility fallback.

## 4. UI and Mock coverage

`NativeProcessView` continues to consume `message.children` in array order.
No view-level sort is introduced.

A new `disclosure-process-order` scene contains reasoning, tool and reasoning
children. The existing disclosure driver opens the process group, checks row
bounds from top to bottom, verifies unique body text, captures screenshots and
exercises collapse/reopen.

## 5. Verification

- Gateway normalization tests assert stream timeline order.
- Client model tests assert delta ordering and cache restoration.
- Transcript tests assert `reasoning -> tool -> reasoning` children.
- Mock mapping remains 100%.
- Default, store and mock Release builds must pass.
- Physical-device verification is recorded as Pending until a current-HAP run.
