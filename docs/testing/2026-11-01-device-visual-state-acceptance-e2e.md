# Native visual state acceptance and pending device verification

Date opened: 2026-11-01

Device hold started: 2026-11-02

Status: physical-device execution is prohibited until the user explicitly
confirms the connected phone is available again. Every row below remains
`Pending` until a rebuilt HAP produces current screenshot, ArkUI layout and
interaction evidence on the target device.

Requirement:
[`2026-11-01-device-visual-state-acceptance.md`](../requirements/2026-11-01-device-visual-state-acceptance.md)

Implementation spec:
[`2026-11-01-device-visual-state-acceptance.md`](../specs/2026-11-01-device-visual-state-acceptance.md)

## Device hold rules

- Do not run HDC, install a HAP, launch the app, capture screenshots, inspect the
  layout tree or interact with the connected phone during the hold.
- Add every newly discovered device-only check to this table before ending the
  turn that introduced or changed the behavior.
- A static source contract, model test, build result, previous screenshot,
  Mock run or coverage report is not device evidence.
- Keep completed historical evidence qualified by its original commit, HAP and
  run ID. Do not reuse it for a later working tree.

## Pending verification queue

| ID | Surface | Required device check | Status |
| --- | --- | --- | --- |
| VSA-PENDING-01 | Task-plan floating banner | Dark-theme header is 36 vp tall, remains touchable, and expands/collapses without clipping the progress or chevron | Pending |
| VSA-PENDING-02 | Plan-mode header chip | The active chip renders as a filled capsule with no rectangular highlight, clipping, or detached surface while idle, pressed and leaving | Pending |
| VSA-PENDING-03 | Turn changed-file cards | A deep Host path shows the filename first, workspace-relative directory second, fixed `+/-` metrics, and no horizontal overflow in dark and light themes | Pending |
| VSA-PENDING-04 | Turn changed-file card expansion | More than three files expands and collapses without changing row identity; card width stays aligned to the composer and clear of the transcript scrollbar | Pending |
| VSA-PENDING-05 | Conversation Dock ordering | Live turn-change state appears above queued input; queue, attachments and composer remain independently reachable | Pending |
| VSA-PENDING-06 | Conversation Dock material | Elevated material spans the full horizontal bleed and falls back to an opaque full-width surface under reduced transparency and API 23 conditions | Pending |
| VSA-PENDING-07 | Composer compact controls | Image, attachment, send, attachment-row removal and subagent-composer controls keep compact geometry without shrinking labels or overlapping | Pending |
| VSA-PENDING-08 | Automation conflict and task rows | Conflict copy, refresh/retry actions, task metadata and chips remain one-line or bounded as designed in dark and light themes | Pending |
| VSA-PENDING-09 | Plugin management rows | Action rows and status/content hierarchy remain compact, readable and free of path-driven overflow | Pending |
| VSA-PENDING-10 | Pending interaction cards | Approval and question cards use compact status/control rows; custom answer input has one surface; pagination arrows and count do not overlap | Pending |
| VSA-PENDING-11 | Plan and subagent projection restore | A valid plan projection makes the executable `计划` chip available after initial render, reconnect and session switch; no stale plan state appears for an empty target | Pending |
| VSA-PENDING-12 | Subagent lineage and composer | Capsule highlight, lineage rows, read-only states and continuable-subagent composer remain compact and usable with system Back | Pending |
| VSA-PENDING-13 | Reduced motion | Task-plan disclosure, chip removal, Dock insertion and all affected interaction transitions resolve directly to final state | Pending |
| VSA-PENDING-14 | Large text and narrow layout | All affected rows and chips remain readable without text/control overlap, clipping or safe-area intrusion | Pending |

## Latest offline evidence

Offline checks passed before the physical-device hold was lifted:

- PR QA profile: passed, including diff hygiene, protocol lock, Mock mapping,
  product variant contracts, publication scan and the full Gateway suite.
- Mock mapping: 10/10 screens, 34/34 states and 27/27 registered features.
- Source contracts: task-plan header height, Plan capsule clipping, projection
  hydration, compact interaction controls, turn-file presentation and Dock
  hierarchy passed.
- Release builds for `default`, `store` and `mock` compiled, packaged and
  signed after the final Mock projection type check.

Current local build artifacts:

| Product | HAP | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| default | `harmony/entry/build/default/outputs/default/entry-default-signed.hap` | 2,077,532 | `e392035e63f0bccb1a36cda73554535aa2f4629745ccd19b2297803069643244` |
| store | `harmony/entry/build/store/outputs/store/entry-store-signed.hap` | 2,077,601 | `f565461524123f799b40b41d7abcc1539ac4e7b08ab244b46df86cdef9b0b598` |
| mock | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` | 2,077,824 | `6d254c25bfc10921fa93a3aca60cfa5211ad8a52e1f31db42fea92fe510ccfc0` |

These hashes identify local build inputs only. They must be rebuilt after any
further source change and never substituted for screenshots or interaction
evidence from the current device run.

## Required evidence after the hold

1. Build and install the current mock HAP.
2. Capture each affected Mock scene in dark mode and any applicable light,
   reduced-motion or reduced-transparency variant.
3. Run the affected interaction drivers, including task-plan disclosure,
   plan-mode exit, Dock queue/live-change ordering and approval/question submit.
4. Inspect the combined screenshots and annotation metadata against this table.
5. Record run ID, HAP hash, device model, API level and evidence paths before
   changing a row to `Passed` or `Failed`.
6. Rebuild the final default HAP and repeat the affected conversation/header,
   turn-file and Dock checks using the delivery build.
