# Native visual state acceptance and device verification

Date opened: 2026-11-01

Device verification date: 2026-11-02

Status: Partial. Two isolated API 26 Mock HAP evidence sets are qualified: the
earlier complete 115/115 visual suite and the current store-showcase/approval
density run. API 23, maximum-font and landscape runs on the final release
rebuild, real account exchange, live Host reconnect, the full preview-format
matrix and current-device image-lightbox interaction remain explicitly pending.

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
| Store-showcase Mock HAP SHA-256 | `020CCE74C12198488D896241AC7AA40BE42A0D059FD60B5C8AA7FB946F582FD7` |
| Current Community Release SHA-256 | `5768B21EA252CEDAADB242C2F21D984086AF7F755EDA7FCCD2EF6C3A19FEE710` |
| Store-showcase Store Release SHA-256 | `F877638C8AC5E5545E735026B51B7120159FD2BEF8F85160FBDB699699EACD96` |
| Device-qualified Mock HAP SHA-256 | `F23693248955498EC90306DC2D1942D2DC30F440FE449D73DDB9592FE59412CD` |
| Launch-notice Mock HAP SHA-256 | `3FE9EE11C150C2C7380B5C360C4994782A87AFB2F94162D2445950C641C0DB48` |
| Previous Default Release SHA-256 | `43E3466D0C878A07C673899B2B213E6348A0DC0424BA032E16C080D31D880E08` |
| Previous Store Release SHA-256 | `2BC7E88367F6CAD626954CDA7F9FC72FB6324702E9C6EE9AAFEFD0168DB9A6E6` |
| Previous Mock Release SHA-256 | `EED9CAB2AC4ACC6B81AAF715B5D76D5E0A1D178557A9EF03BB337805052980F3` |
| Final Default Release SHA-256 | `6824EFDE78B4468D4D26D216721D54F53C3687AE2E4FEDB80DF80B768980B378` |
| Final Store Release SHA-256 | `4066A5CB68C214CE2797474389B96FFE888F6FD5F17EDFADAA63CAFEFBAB5724` |
| Final Mock Release SHA-256 | `3FE9EE11C150C2C7380B5C360C4994782A87AFB2F94162D2445950C641C0DB48` |

## Device evidence

- Complete Mock visual suite: 115/115 scenes passed.
  `artifacts/device-e2e-final/mock-suite-clean/suite-summary.json`
- Review contact sheets covering all 115 final captures:
  `artifacts/device-e2e-final/mock-suite-clean/contact-sheets-audit/visual-01.jpeg`
  through `visual-08.jpeg`.
- Dock send, queue, material and failure interaction:
  `artifacts/device-e2e-final/dock-clean/send-and-queue/manifest.json`
- Approval and question interaction:
  `artifacts/device-e2e-final/interaction-clean/approval-question/manifest.json`
- Turn-change expansion, file preview and system Back:
  `artifacts/device-e2e-final/turn-change-clean/completed-card/manifest.json`
- Plan/subagent lineage, child return and continuable composer:
  `artifacts/device-e2e-final/mode-subagent-clean/plan-lineage/manifest.json`
- Settings appearance persistence:
  `artifacts/device-e2e-final/settings-clean/appearance-persistence/manifest.json`
- Disclosure expansion matrix:
  `artifacts/device-e2e-final/disclosure-dark-clean/disclosure-expansion-matrix/manifest.json`
- Floating task Dock:
  `artifacts/device-e2e-final/task-dock-clean/floating-overlay/manifest.json`
- Conversation scrollbar edge:
  `artifacts/device-e2e-final/conversation-chrome-clean/scrollbar-edge/manifest.json`
- Long stream:
  `artifacts/device-e2e-final/stream-long-final/stream-long-liveness/manifest.json`
- IME open/draft/close:
  `artifacts/device-e2e-final/ime-clean/composer-layout/manifest.json`
- Document preview/source and coverage fallbacks:
  `artifacts/device-e2e-final/document-mode-clean/document-mode/manifest.json`
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
- Rapid-iteration notice, logo continuity, dark/light themes, reduced motion,
  System Back and Mock logout return:
  `artifacts/device-e2e-final/launch-notice-release/iteration-notice/manifest.json`
- Final default Release installed and launched on the rapid-iteration notice
  HAP:
  `artifacts/device-e2e-final/release-smoke-iteration-notice/manifest.json`
- Store showcase capture matrix, 11 current raw scenes and 28 reviewed export
  assets on Mock HAP `020CCE74…`:
  `artifacts/store-screenshots/manifest.json`
- Store showcase approval-card density, long-reason/submitting/ended/disconnected
  states and process liveness on the same Mock HAP:
  `artifacts/device-e2e/20261104-permissions-approval-density/permissions/manifest.json`
- Current Community Release installed and launched after the store build;
  installed version `0.4.8 (29)` and the app process remained alive after start.
- Previous PR QA run: `20261101T192208Z-eefbe49f`
  `.artifacts/qa/20261101T192208Z-eefbe49f/report.json`
- Selector-rhythm PR QA run: `20261102T053410Z-8f4a02be`
  `.artifacts/qa/20261102T053410Z-8f4a02be/report.json`
- Keyboard IME PR QA run: `20261102T052550Z-a8ca704d`
  `.artifacts/qa/20261102T052550Z-a8ca704d/report.json`
- Live process ordering PR QA run: `20261102T054907Z-09edfb22`
  `.artifacts/qa/20261102T054907Z-09edfb22/report.json`
- Notification density and long-stream PR QA run: `20261102T070115Z-d2ee8eb8`
  `.artifacts/qa/20261102T070115Z-d2ee8eb8/report.json`
- Subagent title-row and child-follow PR QA run: `20261102T064134Z-9ca4aa3c`
  `.artifacts/qa/20261102T064134Z-9ca4aa3c/report.json`
- Store-showcase and approval-density PR QA run: `20261103T172626Z-fd73a2b7`
  `.artifacts/qa/20261103T172626Z-fd73a2b7/report.json`
- Composer menu template Mock evidence (API 26, HAP
  `754C854D17A3286E45B6DD8D7F2242A5858E97846DFE5467724C22365D5A0C78`):
  `artifacts/device-e2e/20261104-model-menu/model-picker/manifest.json`;
  see `2026-11-04-model-picker-popup-e2e.md`.
- Connection banner motion Mock evidence (API 26, HAP
  `39E21758985730358D8C39CDB4A663BC7BAFCAF3A1FE2E83567BBFE703770AB9`):
  `artifacts/device-e2e/20261104-connection-banner/connection-banner/manifest.json`;
  see `2026-11-04-connection-banner-motion-e2e.md`.

The user's saved annotation run
`20261101T152352Z-visual-acceptance-1` contains 32 markers across 20 source
screens. Every marked screen and repeated issue was checked against the final
68-scene run. The final captures no longer reproduce the marked height,
selection-capsule, Dock ordering, pagination, file-card or modal-row defects.

## Acceptance table

| ID | Surface | Required device check | Status |
| --- | --- | --- | --- |
| VSA-01 | Floating task-plan Dock | Dark-theme Dock overlays the transcript from the top, does not reserve layout height, expands over messages and leaves gestures outside its surface scrollable | Passed; dark/light collapsed/expanded geometry and outside-surface swipe |
| VSA-02 | Plan exit action | The header has no standalone Plan chip; active mode exposes “退出计划模式” in the overflow menu until authority reports inactive | Passed; `plan-visible`, `plan-removed` and `plan-error-after` |
| VSA-03 | Turn changed-file cards | Filename is the primary line, workspace-relative directory is secondary, fixed metrics remain visible and no horizontal overflow occurs | Passed; dark/light captures and `completed-card` layout assertions |
| VSA-04 | Turn changed-file card expansion | Four files expand and collapse without changing row identity; preview opens and Back returns to the expanded card | Passed; `20261102-device-turn-change-final` |
| VSA-05 | Conversation Dock ordering | Live change row stays above queued input; queue, attachments and composer remain reachable | Passed; `20261102-device-dock-final` |
| VSA-06 | Conversation Dock material | Elevated material spans the horizontal bleed and falls back under reduced transparency | Partial; passed on API 26, while API 23 fallback remains Pending |
| VSA-07 | Composer compact controls | Image, attachment, send, stop, queue and subagent controls keep compact geometry without overlap | Passed on API 26; subagent send and IME flows verified |
| VSA-08 | Automation conflict and task rows | Conflict, action, task metadata and chips stay compact and readable | Passed; final dark/light and maximum-font captures |
| VSA-09 | Plugin management rows | Action rows and status hierarchy remain readable without path-driven overflow | Passed; final dark/light and maximum-font captures |
| VSA-10 | Pending interaction cards | Approval and question cards use compact controls; custom answer, pagination and submit do not overlap | Passed; static dark/light plus submitted interaction |
| VSA-11 | Plan and subagent projection | Plan chip removal waits for provider projection and failure preserves the chip | Partial; projection removal and failure passed, while reconnect and session-switch restoration remain Pending |
| VSA-12 | Subagent lineage and composer | Capsule, external read-only row, read-only modes, continuable composer and system Back remain usable | Partial; previous HAP passed, current HAP disabled after text entry and is awaiting rerun |
| VSA-13 | Reduced motion | Affected disclosures, Dock transitions and onboarding resolve directly to the final state | Passed; 13 representative surfaces plus onboarding frames |
| VSA-14 | Large text | Rows and controls remain readable without overlap, clipping or safe-area intrusion | Partial; portrait at maximum `超大` passed, while landscape remains Pending |
| VSA-15 | Plan and subagent mode chips | Both chips render one continuous semantic surface without a split default-button fill | Passed; current dark/light Mock captures and pressed state |
| VSA-16 | Settings single-line options | Root navigation and single-line setting fields render as compact 44vp intrinsic rows without clipping or excess vertical space | Passed at API 26 default font; maximum font remains Pending |
| VSA-17 | Composer IME open | Header title and chips keep their screen top; the transcript viewport and bottom Dock resize instead of the whole page translating | Passed; dark/light bounds comparison |
| VSA-18 | Composer IME close and draft | System Back restores the exact header/composer geometry and keeps the draft | Passed |
| VSA-19 | DSH settings selector rhythm | `工作步骤展示`, `过程收起时机`, `收起后显示回复` and `运行时发送` retain 44vp Select targets inside 60vp rows with visible vertical spacing and no divider touching the controls | Passed; recorded 55/55/88px row gaps, minimum 54px |
| VSA-20 | Live process order | Reasoning, tool and later reasoning render in first-appearance order; collapse/reopen preserves child identity and order | Passed for `disclosure-process-order`; live Host order remains Pending |
| VSA-21 | Long-stream liveness | `stream-long` advances across two captures, shows `STREAM-LONG-DONE` without relaunch, keeps the same process ID and leaves the composer responsive | Passed |
| VSA-22 | Subagent count in title row | A single branch glyph plus numeric count shares the title row with no long label or chevron; long titles truncate first and loading/more actions remain inside their 44vp targets without overflow | Passed; 4 and 128 counts verified |
| VSA-23 | Child conversation load | Opening a continuable child follows the subagent address without activation, renders its history and does not show a false connection-lost state | Passed with current fixture interaction and child send |
| VSA-24 | Document preview/source toggle | SVG, Markdown and HTML expose one title-row icon action instead of a second toolbar row; the glyph names the target mode and toggling preserves header height and reading space | Passed for SVG; Markdown/HTML maximum-font evidence remains Pending |
| VSA-25 | Global bottom navigation inset | Every native page, drawer, overlay, preview, lightbox and composer keeps interactive controls at least 20vp above the display edge in all covered themes and states; an IME-raised composer uses a 12vp gap | Passed for the current API 26 default-font Mock matrix; API 23, maximum font and landscape remain Pending |
| VSA-26 | Conversation scrollbar edge | The transcript scroll container reaches the physical right edge while body text keeps its page inset; a swipe moves content and preserves the process | Passed |
| VSA-27 | Rapid-iteration notice launch gate | The first-run notice precedes welcome, keeps the shared logo bounds stable, remains on System Back, adapts to light/dark themes, resolves under reduced motion and reappears after logout | Passed on API 26 default-font Mock HAP `3FE9EE11…`; API 23, maximum font, landscape and real-account saved-session relaunch remain Pending |
| VSA-28 | Store showcase density | Device Mock scenes provide populated conversations, process histories, permission cards, automation/plugin lists and a substantial file preview; portrait composites preserve readable type and keep footer copy clear of the phone frame | Passed on API 26 default-font Mock HAP `020CCE74…`; all 14 portrait and 14 landscape composites reviewed |
| VSA-29 | Approval card density | The one-shot approval card keeps mode, target scope, reason and countdown without the removed explanatory footer; long reason, submitting, ended, disconnected and light-theme states remain usable | Passed on API 26 default-font Mock HAP `020CCE74…` |
| VSA-30 | Final variant restore | After building and checking the store variant, the Community Release installs over the device build, launches and leaves a live process | Passed on API 26; Community HAP `5768B21E…`, version `0.4.8 (29)` |
| VSA-31 | Store review experience | Store-only activation opens populated native sessions, settings, permissions, plugins, automation and file previews without a review label; mutable settings and the structured insufficient-balance response render correctly | Pending; current request is compile-gated and the device driver has not been run |
| VSA-32 | Composer menu template | Model and permission sheets share one masked composer-anchored popup; the model sheet stays above the input with the keyboard closed and open, has no search field, dismisses on outside tap and Back, keeps the caption and leaves the permission sheet unchanged | Passed on API 26 Mock HAP `754C854D…`; live Host model switching remains Pending |
| VSA-33 | Connection banner motion | Reconnect and stream-failure banners unfold from their status anchor and retract toward it with one semantic asymmetric transition; reduced motion resolves directly and a background tap does not drop the banner | Passed on API 26 Mock HAP `39E21758…`; live Host reconnect cadence remains Pending |

## Remaining device checks

- Stream/subagent reconstruction: STR-R1-R5 passed on Mock HAP SHA-256
  `48B135A79F64D0E761D071CEADCEEBB836659FD2C8D5C11CEF70A12C0E5B1E2C`
  (`artifacts/device-e2e/20261104-stream-reconstruction/recovery/manifest.json`):
  quiet-then-burst, reconnect, child unavailable/retry/Back, dark/light,
  reduced motion and composer input. STR-R6 (long-stream and child send/stop
  regression) still needs the pre-existing drivers rerun on a current HAP.
  See `2026-11-04-stream-subagent-reconstruction-e2e.md`.
  Real Host child authorization, network handoff, provider cadence and gateway
  backpressure remain Pending independently of synthetic device results.

- API 23 material fallback requires a physical or emulated API 23 target.
- Valid saved-session restore, expired-session recovery and logout/relaunch need
  a real account exchange and must not be inferred from Mock fixtures.
- Final-clean-HAP maximum-font and landscape layouts require controlled runs.
- Provider reconnect, real-Host long-stream cadence and session-switch
  restoration require a live Host stream.
- Current-device image-lightbox interaction still requires the target device.
- JPEG/WebP/GIF/BMP/HEIC/ICO and the full extensionless-file preview matrix
  remain outside the current deterministic fixtures.
- Large-text onboarding/login must be repeated before claiming that complete
  launch flow at maximum system font size.
- Reduced-motion task Dock can be rerun when a final-clean-HAP artifact must be
  qualified independently from the tested Mock HAP.
- The rapid-iteration notice still needs API 23, maximum-font and landscape
  runs, plus a real-account saved-session relaunch after confirmation.
- Store-showcase landscape exports were reviewed as generated images, not as
  live app landscape layouts; live landscape behavior remains Pending.
- The store review experience still requires the pending driver run in
  [`2026-11-04-store-review-demo-e2e.md`](2026-11-04-store-review-demo-e2e.md)
  on a store Release HAP, including restore, settings mutation, send failure
  and logout.

These environment-bound checks remain `Pending`; source tests and the current
API 26 portrait default-font device run are not substitutes for them.
