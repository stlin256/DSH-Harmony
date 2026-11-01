# Native sidebar destinations implementation spec

Date: 2026-11-01

## Architecture

### Gateway

Add a bounded `directRpc(endpoint, args, signal, timeoutMs)` beside the
existing session RPC helpers. It sends the standard `client-request` envelope
to `/api/<endpoint>` and accepts only endpoints selected by the native
operation switch.

Add operations:

- `pluginsList`
- `pluginSetEnabled`
- `pluginSetRowEnabled`
- `pluginInspect`
- `pluginInstall`
- `pluginRemove`
- `pluginVersions`
- `pluginUpdate`
- `automationList`
- `automationView`
- `automationHistory`
- `automationCreate`
- `automationEdit`
- `automationRun`
- `automationDelete`

The request-body fields are an explicit subset of the upstream method
arguments. Unknown fields and oversized values are rejected with HTTP 400.
Stable upstream refusal codes are mapped through the existing JSON error
envelope. Responses are normalized before they leave the gateway.

### Wire models

Plugin inventory:

```text
available: boolean
bundles: {
  name, official, availability, version, description, title,
  installed, enabled, removable, updatable, optional, listedByDefault,
  readOnlyReason, source, installSpec, rows[], errorCode
}[]
plugins: { entryId, moduleName, enabled, phase, title, diagnostic }[]
```

Changing operations return:

```text
changed, application, stage, target, enabled,
restartReason, errorCode, pendingBuilds[]
```

Automation catalog:

```text
available: boolean
items: {
  id, title, prompt, kind, status, scheduledAt, timeZone,
  everySeconds, expression, weekdays[], targetKind, targetSessionId,
  executionActive, updatedAt, lastDeliveryAt
}[]
```

Dates remain RFC 3339 strings. ArkTS formats them for display but never writes
localized time back as protocol data.

## Plugin behavior

The root page:

- loads the inventory when mounted and on explicit refresh;
- separates "已安装" and "可添加" using profile installation state;
- hides unsupported metadata rows;
- has a search field toggled from the header;
- shows row-level loading only during the action for that bundle or row;
- disables incompatible controls while a mutation is pending.

The detail page shows:

- localized title and manifest description;
- version, official/optional labels and source;
- rows with phase and switch where writable;
- install, update, remove and refresh controls as available;
- a native disclosure for errors and build-script approval.

Installation:

1. User enters one package spec.
2. Inspect returns accepted or refused.
3. An accepted subject shows package name/version before install.
4. Install runs with `enabled: true`.
5. Pending builds show the package names and a secondary "批准并重试" action.
6. Restart-required remains visible after refresh.

The app never presents raw shell output as the primary result.

## Automation behavior

The root page:

- defaults to the active filter;
- supports active, paused, ended and all;
- supports local search without refetch;
- sorts active tasks by next occurrence and non-active tasks by update time;
- uses a header plus button to open the native editor.

The detail page has two native sections represented by a compact segmented
control:

- Rule: formatted timing, destination, next run, last delivery, instruction;
- Records: bounded delivery history with retry and pagination.

Edit controls:

- title, instruction;
- timing kind and required fields;
- session target kind and destination;
- save, pause/resume, run now and delete.

Create supports after, every, daily, weekly and cron. At and rrule records are
viewable and editable by preserving their existing timing unless the user
chooses a supported replacement. This avoids a half-implemented universal
calendar.

`expectedUpdatedAt` is always sent on update and delete. A conflict retains the
draft and offers reload.

## Navigation

Add `adminDestination` with values `plugins`, `automation` and `more`.

- Plugins and Automation cover the workspace with a native page.
- `openDrawerDestination('plugins'|'automation')` leaves drawer state open
  underneath.
- `backToSessions` first routes Back into the admin page; the page closes
  nested detail/editor or invokes `onClose`.
- Returning from the page does not change drawer state.
- More expands inside the drawer below its row. Selecting an item collapses
  the menu and performs that item's action.

## Visual rules

- No horizontal tabs at page root.
- Page header uses a back control, title and at most two compact actions.
- Body inset starts at 12 vp and respects safe areas.
- Rows use `NativeDesign.compactRow` or `standardRow`.
- Secondary metadata uses tertiary text and one-line ellipsis.
- Primary actions use the accent color; destructive actions use danger color.
- Every icon uses `DSHIcon`; no untinted monochrome SVG resource.
- Nested transitions use `NativeMotion.navigationTransition`.
- Disclosure uses `NativeMotion.disclosure`.
- Long operation results use a bordered status card, not a modal toast.

## Failure behavior

- Inventory unavailable: a retry card; no fabricated official list.
- Plugin action refused: show stable error code plus a short local message.
- Restart required: retain the new saved state and display a persistent notice.
- Schedule conflict: retain draft, show "任务已被其他端更新", offer refresh.
- Delete: confirmation dialog. The completed row animates out only after the
  Host acknowledges deletion.
- Empty and loading states do not block Back.

## Mock contract

Extend `NativeUiFixture` with screens `plugins`, `automation` and `more`.

States:

- `plugins-list`
- `plugins-empty`
- `plugins-error`
- `plugins-detail`
- `plugins-restart`
- `plugins-install-failed`
- `automation-list`
- `automation-empty`
- `automation-detail`
- `automation-editor`
- `automation-history`
- `automation-conflict`
- `more-actions`

The mock client implements the same admin methods, so the components exercise
production state transitions rather than a separate fake UI path.

## Verification

- Gateway unit tests cover normalization, validation, success, conflict,
  unavailable, restart and malicious input.
- ArkTS model tests cover status labels, sorting, formatting and revision
  preservation.
- Mock manifest registers every screen/state and interactive driver.
- Release builds pass for default, store and mock products.
- Device rows remain Pending until executed on a connected phone.

