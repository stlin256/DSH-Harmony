# Queue and interaction source research

## Upstream baseline

The implementation follows the pinned DeepSeek Harness interaction revision in
`docs/NATIVE-INTERACTION-SPEC.md`.

- `packages/api/session-controller/src/state/controller.ts` publishes
  `SessionState.queue` as `{ id, placement, rpcId?, content }`. `next-turn`
  entries use placement `queued`; `next-step` uses `steering` or `context`.
- `packages/client/ui-conversation/src/client/queue/QueueDock.tsx` renders the
  single row directly, collapses multiple rows behind a count header, preserves
  ordered image/file blocks, disables editing for mixed content, supports edit,
  remove and steer, and shows pending local submissions until inbox admission.
- `packages/client/ui-approval/src/client/ApprovalCard.tsx` uses a warning strip,
  a compact subject/headline/description body and reject plus primary allow
  actions.
- `packages/client/ui-user-questions/src/client/QuestionComposer.tsx` pages one
  question at a time, uses numbered single-select or checkbox multi-select rows,
  a compact custom field, skip and next/submit actions, and holds drafts while
  the request moves between live channels.

## Current DSH Harmony findings

- The gateway state bridge currently forwards only `running` and `waiting`, so
  the App cannot recover the queue even though the upstream projection exposes
  it.
- Modern Host control baselines may expose `inbox` without the per-session state
  observer. The bridge must translate both sources into one bounded queue wire
  contract.
- `NativeSessionModel` has no queue state and the bottom composer only renders
  attachments, live change pill and input controls.
- `NativeInteraction` renders every question at once and still presents a
  user-facing delegate action. Its generic controls do not match the current
  DSH Harmony surfaces.
- Transcript projection already groups direct operations, but the view has no
  structural insertion identity. Treating every model repaint as an insertion
  would animate stream tokens and history replacement.
- Tail following exists, but a structural list update can paint before the new
  row has completed layout. A single post-layout tail settlement is needed.

## Data mapping decision

The gateway emits:

```text
state {
  running,
  waiting,
  queueKnown,
  queue: [
    {
      id,
      placement: "queued",
      rpcId?,
      blocks: [
        { kind: "text", text },
        { kind: "image", image: ImageAttachmentRef },
        { kind: "file", file: FileAttachmentRef }
      ]
    }
  ]
}
```

Unknown content blocks, non-queue placements and malformed attachments are
discarded. Text and array sizes are bounded to avoid making a control frame an
unbounded data channel.

The App caches the authoritative queue as display state. Queue frames without
`queueKnown` update only running/waiting; this prevents a status event from
incorrectly clearing the dock.

## Motion mapping

- A structural process change is the addition of a stable process-group id or a
  new direct child id in an existing group.
- Process insertion uses the existing disclosure spring and one opacity plus
  small downward translation. It is not replayed for token deltas.
- The parent schedules a tail settlement only while `followTail` is true.
  Reading away from the tail remains untouched.
