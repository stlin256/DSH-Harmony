# Visual consistency and interactive Dock E2E

Date: 2026-11-01

The USB device was offline during implementation. Automated model, source,
test-suite and build checks may be recorded here. Device rows remain Pending
until screenshots and post-send layout dumps exist.

## Visual consistency audit

| ID | Surface | Expected | Status |
| --- | --- | --- | --- |
| V01 | Conversation | Reference compact hierarchy remains stable | Automated baseline |
| V02 | Drawer/session list | Placeholder glyphs are the only known icon drift | Audited |
| V03 | Settings/about | Base and raised-token drift is documented | Audited |
| V04 | Workspace picker | Requires rebuild with shared rows/actions | Backlog |
| V05 | Session tools | Requires rebuild with shared compact controls | Backlog |
| V06 | File browser/preview | Grouping and theme remain aligned | Automated baseline |
| V07 | Loading/empty/error rows | Need a shared compact status recipe | Backlog |
| V08 | Compatibility shell | Retained fallback still has a separate visual language | Backlog |

## Mock and screenshot checks

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| M01 | `dock-send-idle` | Send inserts one user message, streams one response and settles | Pending device |
| M02 | `dock-queue-pending` | Local sending echo appears exactly once | Pending device |
| M03 | Queue acknowledgement | Pending echo reconciles to one authoritative row by `rpcId` | Pending device |
| M04 | `dock-queue-authoritative` | One formatted queue row is visible; send remains available | Pending device |
| M05 | `dock-queue-many` | Four rows default collapsed with an animated count header | Pending device |
| M06 | `dock-material-quiet` | Composer has no elevated material | Pending device |
| M07 | `dock-material-elevated` | Material appears only with elevated Dock content | Pending device |
| M08 | Light/dark paired captures | Geometry matches; theme changes surfaces, text and glyphs together | Pending device |
| M09 | Reduced transparency | Actual material is removed and controls remain readable | Pending device |
| M10 | Prompt failure | Error is visible and no false queue or successful bubble remains | Pending device |

## Build and automated verification

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| A01 | Gateway tests | 145/145 tests pass | Passed 2026-11-01 |
| A02 | Personal Release | Signed HAP builds | Passed 2026-11-01 |
| A03 | Store Release | Signed HAP builds | Passed 2026-11-01 |
| A04 | Fixture isolation | Showcase client unreachable without explicit launch flag | Passed 2026-11-01 |

## Evidence commands

```powershell
cd gateway
npm test

cd ..
.\scripts\build-harmony.ps1 -Product default -BuildMode release
.\scripts\build-harmony.ps1 -Product store -BuildMode release

.\scripts\device-ui-mock-suite.ps1
.\scripts\device-ui-dock-e2e.ps1
```

Device screenshots and layout dumps belong under
`artifacts/device-ui-mock/` and `artifacts/device-ui-dock-e2e/`. These generated
artifacts are local evidence and are not committed.
