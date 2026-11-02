# Implementation specification

## 1. Wire and model contracts

1. Add `normalizeQueuedState(value)` in `gateway/src/native-protocol.mjs` and
   `queueFromInbox(value)` for modern control projections.
2. Validate item ids, queue placement, text blocks and image/file attachment
   fields. `rpcId` is optional in the pinned upstream contract; retain it when
   present and still render rows without it. Preserve block order. Limit items
   to 50, blocks to 40 per item and total text to 64 KiB.
3. Emit `queueKnown: true` with queue-bearing state frames. Use a connection
   state publisher so status-only frames do not clobber the current queue.
4. Add `NativeQueueItem` and `NativeQueueBlock` to `NativeSessionModel`.
   `NativeFrame.queueKnown` updates `model.queue`; captured caches retain the
   last authoritative queue for immediate restoration.
5. `NativeHarnessClient.prompt` returns the generated request id. The workspace
   may add a queued local echo only when a running queue submission is accepted.
   The echo is removed when an authoritative row with the same `rpcId` arrives.

## 2. Queue dock

1. Add `NativeQueueDock` above live turn changes and attachment chips inside the
   shared `NativeBottomConversationDock`.
2. One row renders directly. Multiple rows default collapsed with an animated
   `N 条排队消息` header.
3. Preserve text, image and file block order. Images use `NativeImageView` in
   compact mode; files use a compact file chip.
4. Provide edit for all-text rows, remove for all mutable rows and steer only
   while running. Use `updateQueue` and item ids.
5. Local pending rows show `发送中…` and no actions.
6. Empty queue renders nothing and does not reserve height.

## 3. Interaction cards

1. Refactor `NativeInteraction` into a compact themed card.
2. Approval shows a warning strip, localized/formatted reason, tool subject,
   outline reject and primary allow-once actions.
3. Questions show one question at a time with one `1 / N` indicator in the lower
   paging row. Single select uses a numbered row; multi-select uses a checkbox.
   Custom input is a rounded DSH surface, vertically centers placeholder/content,
   and single-select custom input clears the selected option. The header does not
   repeat the sequence.
4. Skip records an empty answer and advances/submits. The final primary action
   submits all answers. Missing answers navigate to the first incomplete item.
5. Skip and submit use 32vp-high controls with 11fp labels. The Composer has no
   queue/steer selector; sending reads the Host `busyEnter` setting.
6. Apply `nativeStructuredText` only when a field is a complete JSON object or
   array; flatten it to readable `key: value` text. Never display the wire JSON.
7. Remove the user-facing delegate/“交给其他程序处理” button. Keep protocol
   delegate handling for lifecycle use.

## 4. Process insertion

1. Add a pure `nativeProcessStructureChange(previous, next)` helper that reports
   new group ids and groups whose direct child ids increased.
2. `renderTranscript` records those ids before updating the list source.
3. `NativeProcessView` receives a one-shot `newlyAppeared` flag. It applies
   `NativeMotion.processEntranceTransition()` only for the flagged insertion.
4. On structural process change while `followTail` is true, preserve the prior
   tail intent and schedule one post-layout `scrollEdge(Edge.Bottom)`. Do not
   schedule it when the reader is away from the tail.
5. Seed the first complete snapshot/cache restore as an animation-free
   structural baseline. Do not animate `delta`, ordinary event text, history
   prepend or cache restore.

## 5. Verification

- Protocol tests cover queue sanitation, block order, malformed attachments,
  modern inbox translation and live state forwarding.
- Model tests cover queue capture/restore and structural process change.
- Source-level ArkUI tests cover queue dock placement, item actions, removal of
  the delegate action, one-question paging and conditional transition use.
- Build both `default` and `store` Release variants after ArkTS/ArkUI changes.
- Device E2E remains pending until hardware is online.
