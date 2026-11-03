# Sidebar workspace inventory device E2E

Date: 2026-11-03

Requirement:
[`2026-11-03-sidebar-all-workspaces.md`](../requirements/2026-11-03-sidebar-all-workspaces.md)

Implementation spec:
[`2026-11-03-sidebar-all-workspaces.md`](../specs/2026-11-03-sidebar-all-workspaces.md)

## Rows

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| WSA-U01 | Run model and source contracts | Global projection returns both Mock workspaces; drawer uses empty scope; create selection forwards the chosen workspace id | Passed by `node --test gateway/test/native-models.test.mjs` |
| WSA-01 | Open the Mock sidebar in dark theme | `全部` is visible and both `DSH Harmony 移动端` and `Passkey Gateway` headers are present at the same time | Pending device |
| WSA-02 | Tap `新会话` from the unfiltered sidebar | Picker title is `选择工作区`; `全部会话` is absent and both workspace choices are available | Pending device |
| WSA-03 | Choose `Passkey Gateway` in create mode | The picker closes, session creation runs and the conversation opens | Pending device |
| WSA-04 | Reopen the sidebar, choose another workspace from the manager, then return | Both workspace groups remain visible; the drawer is not narrowed to the selected workspace | Pending device |

## Driver

```powershell
.\scripts\device-ui-workspace-scope-e2e.ps1 -Device '<device-id>'
```

Evidence is written below `artifacts/device-ui-workspace-scope-e2e/`. Rows are
Passed only with a current Mock HAP hash, layout dumps and screenshots from the
same device run.
