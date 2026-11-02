# Live process stream ordering device E2E

Date: 2026-11-02

Status: Pending. The source/model contract and deterministic Mock scene are
available, but the current HAP has not run on a USB Ready device.

| Artifact | SHA-256 |
| --- | --- |
| Current Mock HAP | `2C39478C519C9D29C08031A596A001862F078240B26D918B28F5058F1D57F781` |
| Current Default HAP | `AD2127415A83DAB218D20F382B05BA2824E6DE65975CD38FE49D269E574FA881` |
| Current Store HAP | `58E2D2E7DAC259DF53501416E8A4F571372A756533F53CDB11583BBF3D206034` |

Requirement:
[`2026-11-02-live-process-stream-order.md`](../requirements/2026-11-02-live-process-stream-order.md)

Implementation spec:
[`2026-11-02-live-process-stream-order.md`](../specs/2026-11-02-live-process-stream-order.md)

| ID | Check | Expected result | Status |
| --- | --- | --- | --- |
| LPSO-01 | Live delta order | A reasoning -> tool -> reasoning stream renders in that order before settlement | Pending current-HAP verification |
| LPSO-02 | Reconnect snapshot | A reconnecting active stream restores reasoning/tool order from `streamParts` | Pending current-HAP or deterministic gateway verification |
| LPSO-03 | Cache restore | Relaunching with an in-progress cached turn preserves the same order | Pending current-HAP verification |
| LPSO-04 | Mock disclosure order | Opening `disclosure-process-order` shows first reasoning above the tool and second reasoning below it | Pending current-HAP dark verification |
| LPSO-05 | Collapse and reopen | The process group collapses and reopens without changing child identity or order | Pending current-HAP verification |

## Evidence requirements

- Run the current Mock HAP and capture collapsed, expanded, collapsed-again and
  reopened states for `disclosure-process-order`.
- Record the ArkUI bounds for `first-order-detail`, `NativeTaskDock.ets` and
  `second-order-detail` before collapse and after reopen; their visible Y
  coordinates must be strictly ordered in both states.
- Repeat the Mock scene in light theme. Maximum font size is required before
  claiming complete visual coverage.
- A source test, an older HAP or a screenshot from a different build cannot
  promote these rows to Passed.
- Current PR QA: `.artifacts/qa/20261102T054907Z-09edfb22/report.json`.
