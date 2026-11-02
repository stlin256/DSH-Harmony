# Live process stream ordering device E2E

Date: 2026-11-02

Status: Pending. The source/model contract and deterministic Mock scene are
available, but the current HAP has not run on a USB Ready device.

| Artifact | SHA-256 |
| --- | --- |
| Device-qualified Mock HAP | `F23693248955498EC90306DC2D1942D2DC30F440FE449D73DDB9592FE59412CD` |
| Final default Release | `43E3466D0C878A07C673899B2B213E6348A0DC0424BA032E16C080D31D880E08` |
| Final store Release | `2BC7E88367F6CAD626954CDA7F9FC72FB6324702E9C6EE9AAFEFD0168DB9A6E6` |

Requirement:
[`2026-11-02-live-process-stream-order.md`](../requirements/2026-11-02-live-process-stream-order.md)

Implementation spec:
[`2026-11-02-live-process-stream-order.md`](../specs/2026-11-02-live-process-stream-order.md)

| ID | Check | Expected result | Status |
| --- | --- | --- | --- |
| LPSO-01 | Live delta order | A reasoning -> tool -> reasoning stream renders in that order before settlement | Pending current-HAP verification |
| LPSO-02 | Reconnect snapshot | A reconnecting active stream restores reasoning/tool order from `streamParts` | Pending current-HAP or deterministic gateway verification |
| LPSO-03 | Cache restore | Relaunching with an in-progress cached turn preserves the same order | Pending current-HAP verification |
| LPSO-04 | Mock disclosure order | Opening `disclosure-process-order` shows first reasoning above the tool and second reasoning below it | Passed; Y bounds recorded 730 < 845 < 960 |
| LPSO-05 | Collapse and reopen | The process group collapses and reopens without changing child identity or order | Passed; identical reopened order |

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
- Current PR QA: `.artifacts/qa/20261102T121812Z-6a461bee/report.json`.
