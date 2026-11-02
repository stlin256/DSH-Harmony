# Native visual state acceptance and device verification

Date opened: 2026-11-01

Device verification date: 2026-11-02

Status: Partial. The previous source-equivalent Mock HAP passed the complete
visual suite and affected interaction drivers on the physical phone. After a
composer-state correction, the current Release candidates require a final
current-HAP device rerun. The USB device disappeared during that run and has
not yet returned to HDC. API 23, a real account session, landscape, reconnect
conditions and additional visual proof remain explicitly pending.

Requirement:
[`2026-11-01-device-visual-state-acceptance.md`](../requirements/2026-11-01-device-visual-state-acceptance.md)

Implementation spec:
[`2026-11-01-device-visual-state-acceptance.md`](../specs/2026-11-01-device-visual-state-acceptance.md)

## Device and evidence identity

| Field | Value |
| --- | --- |
| Device | `HBN-AL80` / HUAWEI Pura 70 Pro+ |
| Serial | `33Z0224801015621` |
| OS | HarmonyOS `7.0.0.111` SP10C10 |
| Runtime API | `26` |
| API 23 device | Not available |
| Mock evidence HAP | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` |
| Previous Mock HAP SHA-256 | `893177598199A3DA33BFF36BDFFF0BD64ED808D9C56D79F9C5818D3DAAAD250B` |
| Previous Default HAP SHA-256 | `7F9173B44580975674EA9C1953C89AFB7635D13E1DA7031C9658259C4BBA1986` |
| Previous Store HAP SHA-256 | `BB63226FB42895102D5566D7017F83CB6EC115F376639AF6FC76919FA42B87AC` |
| Current Mock HAP SHA-256 | `39781D29D1AB9083E63AFFFF52391964D19F1436633FA80036A360912F019D89` |
| Current Default HAP SHA-256 | `088BFBAF96CC40D97382F1BB062B6A7D2932F7ACB6C06ECB78ED75AD4A3C91BE` |
| Current Store HAP SHA-256 | `E81EB570FB7390DBFC72901B66CA6188690154EE6434F37372993297C0C80226` |

## Device evidence

- Complete Mock visual suite: 68/68 scenes passed.
  `artifacts/device-ui-mock/20261102-device-visual-final/suite-summary.json`
- Review contact sheets covering all 68 final captures:
  `artifacts/device-ui-mock/20261102-device-visual-final/visual-contact-1.jpg`
  through `visual-contact-4.jpg`.
- Dock send, queue, material and failure interaction:
  `artifacts/device-e2e/20261102-device-dock-final/send-and-queue/manifest.json`
- Approval and question interaction:
  `artifacts/device-e2e/20261102-device-interaction-final/approval-question/manifest.json`
- Turn-change expansion, file preview and system Back:
  `artifacts/device-e2e/20261102-device-turn-change-final/completed-card/manifest.json`
- Plan/subagent lineage, child return and continuable composer:
  `artifacts/device-e2e/20261102-device-mode-subagent-final/plan-lineage/manifest.json`
- Settings appearance persistence:
  `artifacts/device-e2e/20261102-device-settings-final/appearance-persistence/manifest.json`
- Reduced motion across 13 representative surfaces:
  `artifacts/device-e2e/20261102-reduced-motion-1`
- Reduced-motion onboarding, guide, detailed install page and Back:
  `artifacts/device-e2e/20261102-reduced-motion-onboarding-1`
- Maximum system font size (`超大`) across eight high-risk dark surfaces:
  `artifacts/device-e2e/20261102-large-text-2/large-text-contact.jpg`
  (seven captures from `20261102-large-text-2` plus the completed conversation
  from `20261102-large-text-1`)
- Fixed launch/login geometry:
  `artifacts/device-e2e/20261102-launch-2`
- Previous PR QA run: `20261101T192208Z-eefbe49f`
  `.artifacts/qa/20261101T192208Z-eefbe49f/report.json`
- Current portable PR QA run: `20261102T015713Z-2cd32021`
  `.artifacts/qa/20261102T015713Z-2cd32021/report.json`

The user's saved annotation run
`20261101T152352Z-visual-acceptance-1` contains 32 markers across 20 source
screens. Every marked screen and repeated issue was checked against the final
68-scene run. The final captures no longer reproduce the marked height,
selection-capsule, Dock ordering, pagination, file-card or modal-row defects.

## Acceptance table

| ID | Surface | Required device check | Status |
| --- | --- | --- | --- |
| VSA-01 | Task-plan banner | Dark-theme banner is compact, readable and touchable without transcript drawing behind it | Passed; final `plan-subagent` and `completed` captures show the banner in normal conversation flow |
| VSA-02 | Plan-mode header chip | Active chip is one filled capsule with no rectangular highlight or detached surface | Passed; final dark and light captures plus `plan-visible` interaction |
| VSA-03 | Turn changed-file cards | Filename is the primary line, workspace-relative directory is secondary, fixed metrics remain visible and no horizontal overflow occurs | Passed; dark/light captures and `completed-card` layout assertions |
| VSA-04 | Turn changed-file card expansion | Four files expand and collapse without changing row identity; preview opens and Back returns to the expanded card | Passed; `20261102-device-turn-change-final` |
| VSA-05 | Conversation Dock ordering | Live change row stays above queued input; queue, attachments and composer remain reachable | Passed; `20261102-device-dock-final` |
| VSA-06 | Conversation Dock material | Elevated material spans the horizontal bleed and falls back under reduced transparency | Partial; passed on API 26, while API 23 fallback remains Pending |
| VSA-07 | Composer compact controls | Image, attachment, send, stop, queue and subagent controls keep compact geometry without overlap | Partial; geometry passed on the previous HAP, current subagent send-state rerun pending |
| VSA-08 | Automation conflict and task rows | Conflict, action, task metadata and chips stay compact and readable | Passed; final dark/light and maximum-font captures |
| VSA-09 | Plugin management rows | Action rows and status hierarchy remain readable without path-driven overflow | Passed; final dark/light and maximum-font captures |
| VSA-10 | Pending interaction cards | Approval and question cards use compact controls; custom answer, pagination and submit do not overlap | Passed; static dark/light plus submitted interaction |
| VSA-11 | Plan and subagent projection | Plan chip removal waits for provider projection and failure preserves the chip | Partial; projection removal and failure passed, while reconnect and session-switch restoration remain Pending |
| VSA-12 | Subagent lineage and composer | Capsule, external read-only row, read-only modes, continuable composer and system Back remain usable | Partial; previous HAP passed, current HAP disabled after text entry and is awaiting rerun |
| VSA-13 | Reduced motion | Affected disclosures, Dock transitions and onboarding resolve directly to the final state | Passed; 13 representative surfaces plus onboarding frames |
| VSA-14 | Large text | Rows and controls remain readable without overlap, clipping or safe-area intrusion | Partial; portrait at maximum `超大` passed, while landscape remains Pending |
| VSA-15 | Plan and subagent mode chips | Both chips render one continuous semantic surface without a split default-button fill | Pending current-HAP dark and light verification after moving both controls to explicit Normal capsules |
| VSA-16 | Settings single-line options | Root navigation and single-line setting fields render as compact 44vp intrinsic rows without clipping or excess vertical space | Pending current-HAP dark, light and maximum-font verification |

## Remaining device checks

- Run `scripts/device-ui-frontend-hardening-e2e.ps1` against the current Mock
  HAP once a ready USB target appears. It must verify the default masked
  credential message, reveal/hide, raw-copy source contract, repaired streaming
  Markdown, settings search, result navigation and system Back.
- Capture dark and light screenshots for `secret-masked`, `stream-repaired` and
  `settings-search` from the current HAP. The new rows are FHH-01 through
  FHH-10 in `docs/testing/2026-11-02-dsh-go-frontend-hardening-e2e.md`.
- Repeat the new settings search at maximum system text size and verify the
  search field, clear action, result path and reveal/hide action keep 44vp
  targets without overlap.
- HDC currently reports only UART placeholders (`COM3`, `COM4`) after a server
  restart, so none of the FHH device rows is passed.
- Rerun the 104-pair static Mock suite, subagent send flow, settings navigation
  and all disclosure matrices against current Mock HAP
  `39781D29D1AB9083E63AFFFF52391964D19F1436633FA80036A360912F019D89`.
- Confirm the subagent composer send button becomes enabled after text entry
  and that exactly one prompt appears. The interrupted run recorded the text in
  the field while the action remained disabled.
- Confirm the plan and subagent chips each paint one continuous surface in dark
  and light themes, including while the subagent catalog contains a running
  member.
- Confirm settings root, DSH settings, storage and clear-cache single-line
  options use compact 44vp rows in dark, light and maximum system font size.
- API 23 material fallback requires a physical or emulated API 23 target.
- Valid saved-session restore, expired-session recovery and logout/relaunch need
  a real account exchange and must not be inferred from Mock fixtures.
- Landscape layout requires a controlled rotation run.
- Provider reconnect and session-switch restoration require a live Host stream.
- Large-text onboarding/login must be repeated before claiming that complete
  launch flow at maximum system font size.

These checks remain `Pending`; source tests and the current API 26 portrait
device run are not substitutes for them.
