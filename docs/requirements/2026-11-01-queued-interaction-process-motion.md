# Queued input, pending interaction and live process motion

## Status

Accepted for implementation. Device verification is pending because the target
phone is offline.

## User requirement

- Messages accepted while the current turn is running must appear in a compact
  queue dock above the existing bottom conversation controls.
- Each queued row must preserve its text, image and file order. A text-only row
  may be edited; mixed attachment rows must not be replaced by edited text.
- The queue dock must support remove and steer, using the Host queue identity.
- A prompt accepted locally should show a pending echo until the authoritative
  queue frame arrives, then reconcile by `rpcId`.
- Approval and question requests must use formatted native cards rather than
  exposing request JSON. Question details and option copy must remain readable.
- Question choices, custom answers, paging and actions must use the DSH Harmony
  compact neutral/blue control language.
- The question header shows its category with compact top inset and no duplicate
  top-right sequence. `1 / N` appears once in the lower-left paging row.
- The custom-answer placeholder is vertically centered. Skip and submit use
  32vp-high controls with 11fp labels.
- The Composer never shows a queue/steer selector. Sending defaults to queue;
  the settings `busyEnter` value is the only mode switch.
- The user-facing “交给其他程序处理” action must be removed. Delegation remains
  an internal lifecycle fallback only.
- A newly created process group or a newly added direct operation inside the
  current group may animate once. Streaming tokens, history paging and cache
  restoration must not animate.
- When the reader is already following the tail, a structural process insertion
  must keep the viewport at the tail after layout. If the reader has scrolled
  away, position must be preserved and the existing new-content affordance used.

## Correctness rules

- Queue state is authoritative and ordered. It is bounded before crossing the
  gateway and rejects malformed attachment references.
- Non-user context entries never enter the queue dock.
- Queue actions target the persistent item id in the selected session. No
  action may infer identity from row text.
- Pending local echo is display-only and never consumes input or creates a
  second submission.
- Approval submission still maps to the existing correlated event channel;
  continued questions still map to `answerQuestion`.
- A structural process change is distinct from stream text, reasoning and tool
  argument deltas.
- Motion resolves immediately when reduced motion, power saving or background
  execution disables animation.

## Non-goals

- No write operation on workspace files.
- No new automation, plugin or notification behavior in this change.
- No claim of device completion without a connected phone and recorded checks.
