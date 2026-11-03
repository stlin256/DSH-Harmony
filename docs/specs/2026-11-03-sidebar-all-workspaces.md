# Sidebar workspace inventory implementation

Date: 2026-11-03

Requirement:
[`2026-11-03-sidebar-all-workspaces.md`](../requirements/2026-11-03-sidebar-all-workspaces.md)

## Projection boundary

`NativeWorkspace.sessionsChanged()` continues to use `nativeWorkspaceRows`, but
passes an empty workspace scope. The helper retains its optional explicit scope
for callers that genuinely need one; the drawer does not.

`workspaceId` therefore becomes a creation preference, not list state. It may
still update after a workspace is chosen, but it cannot remove rows from the
drawer projection. Search, collapse, archived-session filtering, pin separation,
subagent exclusion and stable sorting remain unchanged.

The trailing drawer control always renders `全部`. Its picker remains the entry
point for workspace management and default selection.

## New-session flow

`openNewSession()` always opens `NativeWorkspacePicker` with
`workspacePickerCreate=true`. In that mode:

- the title is `选择工作区`;
- no workspace is visually preselected;
- the obsolete `全部会话` target is not rendered;
- selecting a workspace captures create intent, closes the picker and calls
  `createQuickSession(selectedWorkspaceId)`.

The picker's ordinary management mode keeps the title `工作区`. Selecting a row
there updates the creation preference and returns to the still-global drawer.
The workspace-header `+` continues to call `createQuickSession` directly because
that row already identifies the destination.

Stable layout IDs:

- `sidebar-all-workspaces`
- `sidebar-workspace-manager`
- `sidebar-new-session`
- `sidebar-workspace-<workspaceId>`
- `workspace-picker-title`
- `workspace-picker-<workspaceId>`

## Verification

`gateway/test/native-models.test.mjs` covers the global and explicitly scoped
model projections. Its source contracts cover the empty drawer scope, literal
`全部`, create intent, absence of `全部会话`, and workspace id forwarding.

`scripts/device-ui-workspace-scope-e2e.ps1` verifies the current Mock sidebar,
create picker and post-selection inventory on a physical device. A device run is
required before this behavior is marked passed.
