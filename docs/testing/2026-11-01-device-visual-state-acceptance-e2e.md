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
| Previous Mock HAP SHA-256 | `39781D29D1AB9083E63AFFFF52391964D19F1436633FA80036A360912F019D89` |
| Previous Default HAP SHA-256 | `088BFBAF96CC40D97382F1BB062B6A7D2932F7ACB6C06ECB78ED75AD4A3C91BE` |
| Previous Store HAP SHA-256 | `E81EB570FB7390DBFC72901B66CA6188690154EE6434F37372993297C0C80226` |
| Current Mock HAP SHA-256 | `534C5CC09A44BDD026B999491D55C9930B8DA043741A6860689C82C586331946` |
| Current Default HAP SHA-256 | `E16675606F2E73D6C02813BCBBFE5412C0C2B46235954CAB9DD60F5568293D46` |
| Current Store HAP SHA-256 | `A65E4FC385B8FB3E68516B09EFB98525762217D782C870E70C635974BF509FC4` |

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
- Selector-rhythm PR QA run: `20261102T053410Z-8f4a02be`
  `.artifacts/qa/20261102T053410Z-8f4a02be/report.json`
- Keyboard IME PR QA run: `20261102T052550Z-a8ca704d`
  `.artifacts/qa/20261102T052550Z-a8ca704d/report.json`
- Live process ordering PR QA run: `20261102T054907Z-09edfb22`
  `.artifacts/qa/20261102T054907Z-09edfb22/report.json`
- Notification density and long-stream PR QA run: `20261102T063039Z-6973e1d6`
  `.artifacts/qa/20261102T063039Z-6973e1d6/report.json`

The user's saved annotation run
`20261101T152352Z-visual-acceptance-1` contains 32 markers across 20 source
screens. Every marked screen and repeated issue was checked against the final
68-scene run. The final captures no longer reproduce the marked height,
selection-capsule, Dock ordering, pagination, file-card or modal-row defects.

## Acceptance table

| ID | Surface | Required device check | Status |
| --- | --- | --- | --- |
| VSA-01 | Floating task-plan Dock | Dark-theme Dock overlays the transcript from the top, does not reserve layout height, expands over messages and leaves gestures outside its surface scrollable | Pending current-HAP verification; previous evidence covered the superseded in-flow layout |
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
| VSA-17 | Composer IME open | Header title and chips keep their screen top; the transcript viewport and bottom Dock resize instead of the whole page translating | Pending current-HAP dark and light verification |
| VSA-18 | Composer IME close and draft | System Back restores the exact header/composer geometry and keeps the draft | Pending current-HAP verification |
| VSA-19 | DSH settings selector rhythm | `工作步骤展示`, `过程收起时机`, `收起后显示回复` and `运行时发送` retain 44vp Select targets inside 60vp rows with visible vertical spacing and no divider touching the controls | Pending current-HAP dark verification; light and maximum-font reruns also Pending |
| VSA-20 | Live process order | Reasoning, tool and later reasoning render in first-appearance order; collapse/reopen preserves child identity and order | Pending current-HAP dark and light verification; maximum-font and device run required |
| VSA-21 | Long-stream liveness | `stream-long` advances across two captures, shows `STREAM-LONG-DONE` without relaunch, keeps the same process ID and leaves the composer responsive | Pending current-HAP verification; HDC currently exposes no ready USB target |

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
- Run `scripts/device-ui-stream-long-e2e.ps1` against current Mock HAP
  `534C5CC09A44BDD026B999491D55C9930B8DA043741A6860689C82C586331946`.
  It must prove text advances in two captures, `STREAM-LONG-DONE` appears
  without relaunch, the process ID is unchanged, the reconnect banner is
  absent, and the composer remains responsive. HDC still reports only
  `COM3`/`COM4` UART placeholders as of 2026-11-02.
- The current-HAP USB target is not ready. After it returns, run
  `scripts/device-ui-disclosure-e2e.ps1` against the current Mock HAP and
  verify `disclosure-process-order` in dark and light themes, at maximum system
  font size, and through both collapse/reopen paths. The driver must compare the
  visible Y bounds for `first-order-detail`, `NativeTaskDock.ets` and
  `second-order-detail`.
- Rerun the 106-pair static Mock suite, subagent send flow, settings navigation
  and all disclosure matrices against current Mock HAP
  `534C5CC09A44BDD026B999491D55C9930B8DA043741A6860689C82C586331946`.
- Confirm the subagent composer send button becomes enabled after text entry
  and that exactly one prompt appears. The interrupted run recorded the text in
  the field while the action remained disabled.
- Confirm the plan and subagent chips each paint one continuous surface in dark
  and light themes, including while the subagent catalog contains a running
  member.
- Run `scripts/device-ui-ime-e2e.ps1` on the current Mock HAP. It must compare
  the header and composer bounds before/while the IME is open, verify the resize
  mode, type a draft, dismiss the IME, reopen it and repeat in light theme.
- Verify the composer IME flow at maximum system text size. The current
  `dock-send-idle` geometry and the new IME driver are not substitutes for that
  large-text check.
- Confirm settings root, DSH settings, storage and clear-cache single-line
  options use compact 44vp rows in dark, light and maximum system font size.
- Run `scripts/device-ui-settings-e2e.ps1` on the current Mock HAP and verify
  the four DSH Select bounds have visible vertical gaps. Capture the dark DSH
  settings page and repeat in light theme and at maximum system font size.
- Verify the floating task-plan Dock in `plan-dock-overlay`: capture collapsed
  and expanded layouts, prove the transcript List top/height are unchanged,
  swipe outside the Dock surface, and repeat in light, dark, reduced motion and
  maximum system font size. Current HDC target inventory is empty.
- API 23 material fallback requires a physical or emulated API 23 target.
- Valid saved-session restore, expired-session recovery and logout/relaunch need
  a real account exchange and must not be inferred from Mock fixtures.
- Landscape layout requires a controlled rotation run.
- Provider reconnect and session-switch restoration require a live Host stream.
- Large-text onboarding/login must be repeated before claiming that complete
  launch flow at maximum system font size.

These checks remain `Pending`; source tests and the current API 26 portrait
device run are not substitutes for them.
