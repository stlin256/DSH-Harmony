# Sidebar workspace inventory and new-session choice

Date: 2026-11-03

## User outcome

The session drawer is a global inventory. It always shows every workspace and
every visible session, regardless of which workspace was most recently selected.
Selecting a workspace must not turn the drawer into a one-workspace filter.

Creating a session still requires an explicit workspace. Choosing `新会话` opens
the workspace picker, and choosing a workspace there creates the session in that
workspace immediately.

## Required behavior

- `SIDEBAR-WS-01` The drawer projects all workspace groups in Host order.
- `SIDEBAR-WS-02` The drawer header always shows the literal `全部`; it never
  displays the selected workspace as an active filter label.
- `SIDEBAR-WS-03` Selecting a workspace for creation does not hide other
  workspace groups or their sessions.
- `SIDEBAR-WS-04` Global pinned sessions, collapsed groups, search, archived
  sessions and unassigned `其他会话` keep their existing behavior.
- `SIDEBAR-WS-05` `新会话` requires a workspace choice even when one workspace
  exists. The picker does not offer an `全部会话` creation target.
- `SIDEBAR-WS-06` Choosing a workspace in create mode creates and opens the new
  session in that workspace without a second tap on `新会话`.
- `SIDEBAR-WS-07` The per-workspace `+` action remains an explicit direct-create
  shortcut for that workspace.

## Acceptance

- Model tests prove that an empty projection scope returns both workspace groups
  and that an explicitly requested scope still filters for other callers.
- Source contracts prove the drawer passes an empty scope, the create picker has
  no all-session option and the chosen workspace id reaches `client.create`.
- Device E2E proves both Mock workspaces remain visible before and after choosing
  a workspace, and that the new-session picker creates from the chosen row.
