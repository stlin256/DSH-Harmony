# Visual consistency and interactive Dock implementation specification

Date: 2026-11-01

Requirement:
[`2026-11-01-visual-consistency-dock-send-e2e.md`](../requirements/2026-11-01-visual-consistency-dock-send-e2e.md)

## 1. Fixture states

Extend `NativeUiFixture.states` with:

```text
dock-send-idle
dock-queue-pending
dock-queue-authoritative
dock-queue-many
dock-material-quiet
dock-material-elevated
```

The initial content is bounded and deterministic:

- `dock-send-idle` and `dock-material-quiet`: settled compact conversation.
- `dock-queue-pending`: running conversation with an empty queue; the prompt
  acknowledgement is delayed long enough to capture the local pending echo.
- `dock-queue-authoritative`: running conversation with one authoritative queue
  row.
- `dock-queue-many`: running conversation with four authoritative queue rows.
- `dock-material-elevated`: running conversation with a visible live file-change
  pill and two queued rows.

All states use the same model and reasoning-effort labels as the rest of the
showcase.

## 2. Interactive transcript contract

Add a pure `NativeShowcaseInteraction` service. It owns the current synthetic
messages, cursor, queue, running state and prompt sequence.

`snapshot()` returns a complete current frame.

`prompt(requestId, text, attachments, mode)` has two paths:

- running plus queue: create one authoritative queue item with the request ID;
- idle or steer: insert a user event, emit title and running state, stream a
  short deterministic assistant response, commit the assistant message, close
  the turn and return to idle.

Attachment preview blocks preserve submission order. Queue acknowledgement is
authoritative and carries the same `rpcId` as the local echo.

`StoreShowcaseClient.follow()` stores the active frame receiver.
`StoreShowcaseClient.prompt()`:

1. validates the request;
2. resolves with the request ID;
3. schedules admission frames after a short deterministic delay;
4. schedules stream and settle frames only for an idle/steer prompt.

Paused or replaced live sessions cancel pending fixture timers. The production
client remains unchanged.

## 3. Dock material

Return one measured-height owner. When `elevated` is true and materials are
enabled:

- render a full Dock-height material layer;
- use the system component background material as the actual blur;
- remove `linearGradientBlur` from the empty material layer;
- overlay a top-transparent, bottom-subtle theme gradient whose bottom alpha
  leaves background detail visible;
- keep `.opacity(1)` on the material and express translucency through its mask
  colors.

When materials are unavailable or transparency is reduced, do not render a
translucent material layer. The composer and elevated rows retain their normal
opaque surfaces and geometry.

## 4. Screenshot matrix

Expand the screenshot suite with:

| Screen | State | Themes |
| --- | --- | --- |
| conversation | dock-send-idle | light, dark |
| conversation | dock-queue-pending | light, dark |
| conversation | dock-queue-authoritative | light, dark |
| conversation | dock-queue-many | dark |
| conversation | dock-material-quiet | light, dark |
| conversation | dock-material-elevated | light, dark |
| conversation | dock-material-elevated, reduced transparency | light, dark |

Generate a contact sheet that places quiet and elevated captures side by side
with the reduced-transparency fallback for each theme. Preserve raw screenshots,
ArkUI layout dumps, manifest metadata and assertion logs.

## 5. Device interaction checks

Add `scripts/device-ui-dock-e2e.ps1`:

1. launch `dock-send-idle` and read the initial layout;
2. enter an ASCII test token and press the accessibility-labelled Send button;
3. wait for the deterministic response;
4. assert the composer placeholder is back, the token occurs once in the
   transcript and the deterministic assistant response is visible;
5. launch `dock-queue-pending` and send the same flow;
6. capture the local `发送中…` row before acknowledgement;
7. wait for the authoritative queue frame and assert the token occurs once while
   `发送中…` is gone;
8. capture light/dark and a layout dump after each critical state;
9. fail if the process terminates, a text count is not exactly one, the
   composer leaves the visible bounds or the Dock height reports an overflow.
10. capture quiet, elevated and reduced-transparency Dock layouts and prove that
    only elevated states own queue content while the composer remains visible.

The script exits with an environment-pending error when no ready USB device is
available; it must never mark device checks passed without evidence.

## 6. Send failure

When `prompt()` rejects while a conversation is selected, render the error as a
compact themed row inside the bottom Dock above queue rows and attachments.
The row must:

- use the shared error color, compact text and a direct close action;
- keep the draft and selected attachments;
- add no user message, queue row or successful streaming state;
- enable the Dock's elevated material only while the error is visible.

The workspace-level error line remains available on non-conversation surfaces.

## 7. Verification

- Model tests cover idle prompt frames, queue reconciliation, attachment order,
  duplicate-proof acknowledgement, malformed input rejection and in-conversation
  failure ownership.
- Source contracts cover fixture reachability, material ordering and removal of
  foreground gradient blur from the empty layer.
- Run all gateway tests.
- Build personal and store Release products.
- Run the screenshot and send scripts only when a device is ready. Store device
  results in the E2E table.
