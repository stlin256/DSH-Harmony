# Live process stream ordering device E2E

Date: 2026-11-02

Status: Pending. The source/model contract and deterministic Mock scene are
available, but the current HAP has not run on a USB Ready device.

| Artifact | SHA-256 |
| --- | --- |
| Current Mock HAP | `6DBC521844CBF9522E45F4F9C70719846EC5EC8AD47ECDE79049D77C7A72C736` |
| Current Default HAP | `FB33D17A9EE44300E197E8FC3FAC19D109D3C76BEBE28A78B7DDFB7783428AA6` |
| Current Store HAP | `9AE9D41370ED3E32127B9D0051617203B79228EEE431C9B96A85AF6A14DE6056` |

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
- Current PR QA: `.artifacts/qa/20261102T063039Z-6973e1d6/report.json`.
