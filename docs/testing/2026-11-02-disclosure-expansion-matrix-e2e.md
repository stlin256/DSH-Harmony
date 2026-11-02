# Disclosure expansion matrix device E2E

Date opened: 2026-11-02

Status: Partial. The standard dark, light, reduced-transparency and
reduced-motion matrices passed 26/26 on Mock HAP
`BA8A8F8B516735A32D3C5A9B36BBD6B002BFE96D0806F6B016186AB78CE43039`.
The subsequent composer-state fix produced a new Release candidate and requires
a final current-HAP rerun. The USB device disappeared during that rerun and has
not yet returned to HDC. Landscape and API 23 remain explicitly pending.

Requirement:
[`2026-11-02-disclosure-expansion-matrix.md`](../requirements/2026-11-02-disclosure-expansion-matrix.md)

Implementation spec:
[`2026-11-02-disclosure-expansion-matrix.md`](../specs/2026-11-02-disclosure-expansion-matrix.md)

## Device

| Field | Value |
| --- | --- |
| Device | `HBN-AL80` / HUAWEI Pura 70 Pro+ |
| Serial | `33Z0224801015621` |
| OS | HarmonyOS `7.0.0.111` SP10C10 |
| Runtime API | `26` |

## Matrix

| ID | Surface | Required device check | Status |
| --- | --- | --- | --- |
| DXM-01 | Task plan | Header opens and closes; body scrolls within the compact plan surface | Passed |
| DXM-02 | Process container | Header opens and closes; operation rows remain visible and stable | Passed |
| DXM-03 | Reasoning operation | Reasoning body replaces the collapsed preview without clipping | Passed |
| DXM-04 | Structured read | Line-numbered code renders with the expected source line | Passed |
| DXM-05 | Structured search | Path and matching line render without losing the file name | Passed |
| DXM-06 | Terminal result | Command, working directory, exit status and output remain readable | Passed |
| DXM-07 | Long Diff | The hidden middle line appears only after expansion and remains within the scroll container | Passed |
| DXM-08 | Nested tool | Parent expansion reveals the child row; child expansion reveals its body | Passed |
| DXM-09 | Web result | Sources and answer text use one bounded vertical body | Passed |
| DXM-10 | Goal result | Objective, phase and round fields remain aligned | Passed |
| DXM-11 | Background job | Job identity, status, command and exit code remain readable | Passed |
| DXM-12 | Subagent result | Child identity and run metadata remain aligned | Passed |
| DXM-13 | Presented files | Filename is primary, path is secondary and fixed rows do not overflow | Passed |
| DXM-14 | Image metadata | Type, dimensions and byte count render without blank body space | Passed |
| DXM-15 | Question result | Question and option summary remain readable | Passed |
| DXM-16 | Plugin result | Valid plugin view renders; unsupported elements use safe fallback | Passed |
| DXM-17 | Direct reasoning | Legacy reasoning row opens and closes without a duplicate header | Passed |
| DXM-18 | Legacy tool row | Tool summary opens to its full output | Passed |
| DXM-19 | Background notice | Long monospace notice scrolls within its surface | Passed |
| DXM-20 | Queue | Multi-item header expands rows and collapse/reopen preserves row identity | Passed |
| DXM-21 | Sidebar More | More opens file browser/settings and system Back returns without clipped rows | Passed |
| DXM-22 | Workspace group | Group collapses and reopens with stable child visibility and chevron direction | Passed |
| DXM-23 | Turn file changes | Existing four-file expansion driver remains green on the current HAP | Passed |
| DXM-24 | Edge states | Maximum font, reduced motion, malformed payloads and long text have no clipping or overlap | Partial; portrait maximum-font and reduced-motion passed, landscape pending |
| DXM-25 | Malformed structured result | Invalid structured metadata falls back to readable raw output without a blank body | Passed |
| DXM-26 | Empty structured result | Successful tool with no displayable body renders an explicit empty-result row | Passed |
| DXM-27 | Oversized plugin result | Oversized view is bounded, reports truncation and does not overflow the disclosure | Passed |
| DXM-28 | Fetched page | URL, HTTP status and fetched body remain readable | Pending current-HAP rerun |
| DXM-29 | Job lifecycle | Status, detail and call identity remain bounded | Pending current-HAP rerun |
| DXM-30 | Read image | Authoritative dimensions render without a blank body | Pending current-HAP rerun |
| DXM-31 | Slash command | Command result uses the structured command body | Pending current-HAP rerun |
| DXM-32 | Live process order | Reasoning, tool and later reasoning render in first-appearance order and survive collapse/reopen | Pending current-HAP verification |

## Evidence

Previous source-equivalent evidence:

- Current Mock Release HAP SHA-256:
  `BA8A8F8B516735A32D3C5A9B36BBD6B002BFE96D0806F6B016186AB78CE43039`
- Standard dark matrix: 26/26 passed.
  `artifacts/device-e2e/20261102-disclosure-standard-current-hap/disclosure-expansion-matrix/manifest.json`
- Light matrix: 26/26 passed.
  `artifacts/device-e2e/20261102-disclosure-light-current-hap/disclosure-expansion-matrix/manifest.json`
- Reduced-transparency matrix: 26/26 passed.
  `artifacts/device-e2e/20261102-disclosure-reduced-transparency-current-hap/disclosure-expansion-matrix/manifest.json`
- Reduced-motion matrix: 26/26 passed.
  `artifacts/device-e2e/20261102-disclosure-reduced-motion-current-hap/disclosure-expansion-matrix/manifest.json`
- Expanded contact sheets visually reviewed:
  `contact-sheets/expanded-01.jpeg` through `expanded-05.jpeg` under each
  current matrix directory.
- Complete static Mock suite: 94/94 passed.
  `artifacts/device-ui-mock/20261102-device-visual-current-hap/suite-summary.json`
- Static visual contact sheets:
  `artifacts/device-ui-mock/20261102-device-visual-current-hap/visual-contact-sheets/visual-01.jpeg`
  through `visual-08.jpeg`.
- Turn file-change expansion and preview/Back:
  `artifacts/device-e2e/20261102-turn-change-current-hap/completed-card/manifest.json`
- Default/store/mock Release SHA-256:
  `7AB38FC4293EC72BE6F632675240B68526BE4FCA72CF533C9EE8D27A9BDE0AC8`,
  `DBC58F1258ED6A97B34C29AEF09AE99F567832B7131CBFF608F2F93D56B438A2`,
  `BA8A8F8B516735A32D3C5A9B36BBD6B002BFE96D0806F6B016186AB78CE43039`.
- PR QA: `.artifacts/qa/20261102T004436Z-02ef9668/report.json`.

## Current-HAP final gate

The current Release candidates below include the shared composer send-state
correction. They are not yet device-qualified until the full static suite,
subagent interaction driver, settings driver and disclosure matrices are rerun
against this exact Mock HAP:

- Mock: `534C5CC09A44BDD026B999491D55C9930B8DA043741A6860689C82C586331946`
- Default: `E16675606F2E73D6C02813BCBBFE5412C0C2B46235954CAB9DD60F5568293D46`
- Store: `A65E4FC385B8FB3E68516B09EFB98525762217D782C870E70C635974BF509FC4`

The latest portable PR QA is
`.artifacts/qa/20261102T063039Z-6973e1d6/report.json` (Passed).

The interrupted run recorded a disabled subagent send button after text entry.
The new HAP resumes Mock Host follow after `pause()` and centralizes the
composer send eligibility contract. The device driver now waits for an enabled
right-side composer action instead of clicking a disabled visual target.
Device proof is Pending until the physical send flow passes on the current HAP.

Maximum-font and API 23 evidence remain environment-bound. They are not
inferred from Mock mapping or the current portrait API 26 matrix.
