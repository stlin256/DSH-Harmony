# Permission switch Host fix and checkbox acknowledgement

Date: 2026-11-05

## Gateway

`setPermissionPreset` and `planOff` call `commands/execute` with the named
wire object `{ agentId: sessionId, line, submittedAttachments: [] }`. The
returned `command.result.kind` must be `success`; otherwise the operation
throws a stable conflict code (`permission/rejected`, `plan/rejected`) so the
guarded route answers 409 instead of a false `{ accepted: true }`. The client
keeps its existing behavior: it only leaves the busy state on the
authoritative permission projection change or on an error.

Tests assert the exact wire object for both commands and the mapped 409 for a
rejected result. The pre-fix mock accepted positional arrays, which is why the
real-Host failure was invisible in unit tests.

## Checkbox acknowledgement

The full-access risk card replaces the immediate-confirmation button with a
checkbox row: an 18vp square (semantic border when unchecked, warning/danger
fill plus `check-outline` when checked) and the label
`我已了解风险，并愿意继续`. The whole row toggles the acknowledgement; the
confirm action stays disabled until it is checked and keeps the existing
`permission-risk-ack` / `permission-confirm` ids for the interaction driver.

## Verification

- Gateway: 306 tests (named args, rejection conflict, existing permission
  routes).
- Mock device: permissions driver re-run on the current Mock HAP; PERM-05 now
  covers the checkbox row and both states are captured.
- Real Host: the same native operation route must return 200 and move the
  permission projection to `read-only` after deployment.
