# Stream reconstruction device acceptance

Date: 2026-11-04. Driver:
`scripts/device-ui-stream-recovery-e2e.ps1 -SkipBuild`. Mock HAP SHA-256
`48B135A79F64D0E761D071CEADCEEBB836659FD2C8D5C11CEF70A12C0E5B1E2C`,
API 26. Evidence:
`artifacts/device-e2e/20261104-stream-reconstruction/` (`recovery/manifest.json`,
per-scenario screenshots and layouts). No live Host claim.

| ID | Surface / interaction | Status |
| --- | --- | --- |
| STR-R1 | Healthy heartbeat and >12-second quiet generation, then burst output | Passed current Mock HAP: dark, light and reduced-motion runs converged to `STREAM-BURST-DONE`; no reconnect banner; composer stayed usable. |
| STR-R2 | Transient transport loss, replacement snapshot, progress without restart | Passed current Mock HAP: reconnect run converged to `STREAM-RECOVERED-DONE` without an app restart; process ID stable. |
| STR-R3 | Child opening error remains readable, no endless reconnect banner | Passed current Mock HAP dark/light: child view shows `子智能体记录暂时无法读取` and no `连接中断` banner. |
| STR-R4 | Explicit child retry, loaded history, System Back to parent | Passed current Mock HAP dark/light: retry loads the child record and System Back returns to the parent without a retry banner. |
| STR-R5 | Dark/light, reduced motion, composer remains responsive | Passed current Mock HAP: dark, light and reduced-motion captures; composer accepted input while the live reply was paced. |
| STR-R6 | Existing long-stream Markdown and child send/stop regression | Pending current-HAP run: covered by the pre-existing long-stream and mode-subagent drivers, which were not rerun by this driver. |

Remaining: real Host/provider cadence, actual child authorization and stale
catalog conditions, network handoff and backpressure, API 23 opaque fallback,
maximum font and landscape, and the STR-R6 regression driver rerun. Unit or
Mock evidence cannot promote those rows.
