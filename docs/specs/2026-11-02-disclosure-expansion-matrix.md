# Disclosure expansion matrix implementation spec

Requirement:
[`2026-11-02-disclosure-expansion-matrix.md`](../requirements/2026-11-02-disclosure-expansion-matrix.md)

Research:
[`2026-11-02-disclosure-expansion-matrix.md`](../research/2026-11-02-disclosure-expansion-matrix.md)

## 1. Mock workbench

Add a `disclosure` fixture screen. It mounts `NativeDisclosureFixture` above the
normal workspace shell and uses the same dark theme and safe-area values as the
product.

The workbench:

- renders one stable state heading;
- mounts the production disclosure component;
- does not pre-open inner controls;
- uses no private Host, account or transcript data.

The sidebar disclosures continue to use the real drawer because their geometry
and gesture ownership live in `NativeWorkspace`.

## 2. State matrix

| State | Disclosure under test | Expanded-only assertion |
| --- | --- | --- |
| `disclosure-task-plan` | Task plan | Expanded plan item |
| `disclosure-process-reasoning` | Process container + reasoning | Reasoning paragraph |
| `disclosure-process-read` | Process + structured read | Line-numbered source |
| `disclosure-process-search` | Process + structured search | Matching path and line |
| `disclosure-process-terminal` | Process + terminal | Exit status and output |
| `disclosure-process-diff` | Process + edit + long Diff | Hidden middle Diff line |
| `disclosure-process-nested` | Process + PTC parent + child | Child structured result |
| `disclosure-process-malformed` | Process + malformed structured result | Raw fallback is readable |
| `disclosure-process-empty` | Process + successful empty result | Explicit empty-result row |
| `disclosure-process-oversized` | Process + bounded oversized plugin view | Truncation marker and bounded body |
| `disclosure-process-web` | Structured web result | Source and answer |
| `disclosure-process-web-fetch` | Structured fetched page | HTTP status and fetched body |
| `disclosure-process-goal` | Structured goal | Objective and round |
| `disclosure-process-job` | Structured background job | Job id and status |
| `disclosure-process-job-lifecycle` | Job lifecycle event | Lifecycle detail and call identity |
| `disclosure-process-read-image` | Structured image read | Authoritative dimensions |
| `disclosure-process-command` | Slash-command result | Command result text |
| `disclosure-process-subagent` | Structured subagent | Child id and mode |
| `disclosure-process-present` | Structured delivered files | Filename-first delivery row |
| `disclosure-process-image` | Structured image metadata | Dimensions and media type |
| `disclosure-process-question` | Structured question result | Question and options |
| `disclosure-process-plugin` | Plugin/DSH UI card | Plugin view title and body |
| `disclosure-reasoning` | Direct reasoning row | Full reasoning body |
| `disclosure-legacy-tool` | Legacy tool row | Full tool output |
| `disclosure-diff` | Standalone long Diff | Hidden middle Diff line |
| `disclosure-background-notice` | Background notice | Full notice body |
| `disclosure-queue` | Multi-item queue | Seeded queue rows |
| `disclosure-sidebar-more` | Drawer More | File browser and settings |
| `disclosure-sidebar-group` | Workspace group | Child session visibility |

The exact state names and markers are declared in `NativeUiFixture.ets`,
`device-ui-mock.ps1`, `device-ui-mock-suite.ps1` and
`device-ui-disclosure-e2e.ps1`.

## 3. Interaction assertions

`device-ui-disclosure-e2e.ps1`:

1. launches each deterministic state without reinstalling between scenarios;
2. dumps a collapsed layout;
3. asserts that expanded-only content is absent;
4. clicks the real header or operation row;
5. waits for and asserts expanded-only content;
6. captures a native-resolution screenshot and expanded layout;
7. collapses and reopens controls that persist manual state;
8. verifies the app process remains alive.

The file-change row remains covered by `device-ui-turn-change-e2e.ps1` and is
referenced by the disclosure E2E ledger rather than duplicated.

## 4. Component corrections

Shared components must:

- expose readable expanded/collapsed accessibility labels;
- keep the header arrow and the accessibility state synchronized;
- use one vertical scroll owner for expanded bodies;
- preserve disclosure identity across projection updates;
- keep unexpanded content absent from the accessibility and visible layout tree;
- keep filenames and fixed trailing metrics outside the flexible path ellipsis;
- clamp long bodies without clipping the final line at maximum font size.

No workbench-only visual wrapper may mask a component defect.

## 5. Verification

- Add source/model contracts for matrix completeness, accessibility labels and
  stable identities.
- Run `node scripts/verify-mock-coverage.mjs`.
- Run targeted Gateway tests.
- Run `node scripts/qa.mjs pr`.
- Build default, store and mock Release variants.
- Run the disclosure driver on the connected API 26 device.
- Inspect every expanded capture before marking the matrix passed.

## 6. Edge audit

Run representative maximum-font states for the task plan, process operation,
long Diff, queue, background notice and sidebar. Reduced-motion runs assert the
same final geometry. Light-theme review checks shared semantic surfaces; dark is
the annotation baseline.
