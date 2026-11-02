# Live process stream ordering device E2E

Date: 2026-11-02

Status: Pending. The source/model contract and deterministic Mock scene are
available, but the current HAP has not run on a USB Ready device.

| Artifact | SHA-256 |
| --- | --- |
| Current Mock HAP | `74B23BFCF1D9DE63EFD0210FE2F02B52A8DAA98B8D05338F4245BE30162F7DDB` |
| Current Default HAP | `381A1CB3D0AE0ABE4770C2775CC629BAD3131E8D711545BE1154742283FF3408` |
| Current Store HAP | `1F51840CBC8D2543D364AD0EF9C2544DDEF428DB3EECE7376DAD080199950620` |

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
- Current PR QA: `.artifacts/qa/20261102T061552Z-b0060234/report.json`.
