# Turn file-change surfaces device E2E

Date: 2026-11-01

Status: initial deterministic device run complete on Huawei `HBN-AL80`,
HarmonyOS API 26. Rows below only use observed device evidence; reconnect,
account isolation, API 23 and real Host summary rows remain pending.

Automated evidence in this change:

- Gateway suite: 134 tests passed, including the official `changes.summary`
  bridge, turn-change aggregation, workspace-relative filename-first
  presentation and source contracts for the narrower final card, live pill,
  reusable bottom dock, read-only file opening and reduced-motion handling.
- `default` Release build: passed.
- `store` Release build: passed.
- Device evidence: the rebuilt personal Release was installed and run through
  the fixture interaction driver. Screenshots and ArkUI bounds are stored under
  `artifacts/device-ui-turn-change-e2e/completed-card/`.

| ID | Scenario | Expected evidence | Status |
| --- | --- | --- | --- |
| TFC-01 | One successful single-file edit | Final turn card shows one file and exact `+/-`; tapping opens the read-only file preview | Pending |
| TFC-02 | Repeated edits to one path | Card still says one file and aggregates all line deltas | Pending |
| TFC-03 | One multi-file apply-patch | Card counts distinct files and shows deterministic first-three rows | Passed; four-file fixture card showed aggregate totals and first three rows |
| TFC-04 | Failed, interrupted or denied edit | No file count, total or final card is shown for that operation | Pending |
| TFC-05 | More than three files | `再显示 N 个文件` expands and collapses with interruptible motion | Passed; four-file card expanded, opened a row and returned to the same expanded card |
| TFC-06 | Live update | Running edit updates the centered pill and number-roll motion without shifting the composer | Pending |
| TFC-07 | Stop/cancel/error | Live pill hides promptly; final card state matches the turn outcome | Pending |
| TFC-08 | Attachment + live changes | Attachment strip, live pill, composer and safe area remain separate and fully reachable | Passed; two attachments and live pill stayed above a visible composer with the dock anchored on screen |
| TFC-09 | Return-to-bottom overlap | The floating circular control stays above the complete bottom dock and adds no permanent spacer | Pending |
| TFC-10 | Light/dark and reduced motion | Surfaces, outlines and semantic diff colors remain legible; motion resolves directly | Pending |
| TFC-11 | API 23 fallback | Full-width opaque bottom surface preserves hierarchy when material is unavailable | Pending |
| TFC-12 | Session switch/reconnect | No live summary leaks across sessions; final cards survive cached reopen | Pending |
| TFC-13 | Official final summary | Stopped-turn counts include command and Git-visible changes from `workspace/changes`, while an unavailable route falls back to successful tool diffs | Pending |
| TFC-14 | Official summary privacy | Native UI receives no Host cwd, snapshot identity, credential or unvalidated summary fields | Pending |
| TFC-15 | Return from a conversation-opened file | From a card row or inline file link, file A -> linked file B -> Back returns to A; the next Back returns to the conversation without revealing A's parent directory | Partial; card row -> preview -> Back returned to the expanded card; linked-file chaining remains pending |
| TFC-16 | Conditional Dock material | With only the composer, there is no full-width background. Adding a live-change pill, queue or attachment reveals material that is transparent at the top and becomes progressively frosted toward the bottom while retaining visible background variation in light and dark mode | Pending |
| TFC-17 | Long changed-file row | A deep absolute Host path renders as a workspace-relative directory plus filename; only genuine overflow truncates the directory first, and `+/-` metrics stay fixed in light and dark mode | Pending |
| TFC-18 | Short filename beside a long directory | Available row width is used before ellipsis; the row does not reserve a blank weighted filename column | Pending |
| TFC-19 | Completed card horizontal geometry | The completed change card aligns with the composer's effective content width without being covered by the transcript scrollbar | Pending |

