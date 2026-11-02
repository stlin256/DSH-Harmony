# Cross-surface control visual alignment device E2E

Date: 2026-11-02

Status: Partial. Physical-device verification completed on API 26 for the
previous source-equivalent Release. A composer-state correction produced new
Release candidates that require a final current-HAP rerun. API 23,
real-account restoration, landscape and current-device image-lightbox proof
remain partial or pending.

Device: `HBN-AL80`, HarmonyOS `7.0.0.111` SP10C10, API `26`.

Previous Mock HAP SHA-256:
`893177598199A3DA33BFF36BDFFF0BD64ED808D9C56D79F9C5818D3DAAAD250B`.

Previous Default HAP SHA-256:
`7F9173B44580975674EA9C1953C89AFB7635D13E1DA7031C9658259C4BBA1986`.

Previous Store HAP SHA-256:
`BB63226FB42895102D5566D7017F83CB6EC115F376639AF6FC76919FA42B87AC`.

Current Mock HAP SHA-256:
`B76B79DFA915E7C15999E96E85C38F2DC7DB6EBF8402BD28E6F89105808D10A4`.

Current Default HAP SHA-256:
`4B9C2744CAF860FCD6AFAE63066CAAF2595DC0780047541146AF78171C0503A0`.

Current Store HAP SHA-256:
`A45FF01AB08A44EDE7E6BDE72B4BB18AF078BA56198F2402BC4007BA29F0DF9F`.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| CVA-01 | Launch and onboarding | Page inset, primary actions, inputs, option rows and headings align without oversized controls or brand overlap | Passed in dark for intro, guide, detailed install page, login and inline error; brand-mark overlap fixed in `20261102-launch-2` |
| CVA-02 | Conversation header and drawer | Back/menu, title, utility icon and drawer rows share the same hit target, icon and baseline recipes | Passed; final dark/light suite and sidebar interaction |
| CVA-03 | Composer and bottom dock | Model, image, file, send, stop, queue and attachment controls use aligned sizes and gaps | Partial; passed on the previous HAP, current-HAP subagent send rerun pending |
| CVA-04 | Plan and live-change surfaces | Task-plan disclosure is compact; progress, chips and file-change rows form one hierarchy without clipping | Partial; filename-first file cards and compact plan banner passed, while the current Normal-capsule chip correction requires a current-HAP capture |
| CVA-05 | Pending interactions | Approval, question, option, pagination and submit controls align in dark and light themes | Passed; dark/light captures plus submitted interaction |
| CVA-06 | Settings root and children | Header, compact single-line rows, fields, toggles, retry and destructive actions align across every page; DSH selector rows retain 44vp Select targets with a 60vp rhythm and visible 8vp vertical inset | Pending current-HAP dark verification after the selector-row rhythm correction; light and maximum-font reruns also Pending |
| CVA-07 | About and storage | Author/repository rows, storage metric and clear-cache action use documented roles | Passed; settings driver opened both pages and returned |
| CVA-08 | File browser | Breadcrumbs, header actions, groups and file rows share one inset and radius system | Passed; dark/light completed-browser captures |
| CVA-09 | File preview and lightbox | One target-mode icon shares the title row with copy/download/close; load-more, retry and lightbox controls align safely | Partial; source-file preview and Back passed, while the current title-row mode action and image-lightbox visual proof remain Pending |
| CVA-10 | Plugins | Search, header action, card rows, status badges, install/update and error actions align | Passed; six final plugin states |
| CVA-11 | Automation | Search, filters, task rows, form fields, day selector and action bars align | Passed; list, detail, editor, history and conflict states |
| CVA-12 | Structured transcript | Process rows, tool cards, media metadata and turn-change cards use one compact disclosure language | Passed; final transcript and file-card runs |
| CVA-13 | Large text | No label/control overlap, unintended wrap or horizontal drift | Partial; portrait at maximum system font size passed, while landscape remains Pending |
| CVA-14 | Dark theme | Borders, selected surfaces, chips and icon weights remain coherent | Passed across all affected dark captures |
| CVA-15 | Reduced motion and transparency | Alignment survives fallback surfaces; transitions resolve without changing final geometry | Passed; 13 reduced-motion surfaces, onboarding and reduced-transparency Dock |
| CVA-16 | API 23 fallback | Opaque surfaces preserve the same insets and control recipes | Pending; no API 23 target is available |
| CVA-17 | Live process order | Reasoning, tool and later reasoning remain aligned in first-appearance order without changing child identity | Pending current-HAP dark and light verification; maximum-font and collapse/reopen rerun required |
| CVA-18 | Notification level density | All four notification choices paint at 32vp inside a 44vp touch row; selected and unselected states stay aligned without clipping or overlap | Pending current-HAP dark, light and maximum-font verification |

## Evidence

- Final 68-scene suite:
  `artifacts/device-ui-mock/20261102-device-visual-final/suite-summary.json`
- Contact sheets:
  `artifacts/device-ui-mock/20261102-device-visual-final/visual-contact-1.jpg`
  through `visual-contact-4.jpg`
- Interaction manifests:
  `artifacts/device-e2e/20261102-device-dock-final/send-and-queue/manifest.json`,
  `artifacts/device-e2e/20261102-device-interaction-final/approval-question/manifest.json`,
  `artifacts/device-e2e/20261102-device-turn-change-final/completed-card/manifest.json`,
  `artifacts/device-e2e/20261102-device-mode-subagent-final/plan-lineage/manifest.json`,
  `artifacts/device-e2e/20261102-device-settings-final/appearance-persistence/manifest.json`.
- Maximum font-size contact sheet:
  `artifacts/device-e2e/20261102-large-text-2/large-text-contact.jpg`
  (seven captures from `20261102-large-text-2` plus the completed conversation
  from `20261102-large-text-1`).
- Reduced-motion onboarding:
  `artifacts/device-e2e/20261102-reduced-motion-onboarding-1`.
- Fixed launch geometry:
  `artifacts/device-e2e/20261102-launch-2`.
- PR QA:
  previous `.artifacts/qa/20261101T192208Z-eefbe49f/report.json`; current
  notification-density run
  `.artifacts/qa/20261102T121812Z-6a461bee/report.json`.

## Notification level density evidence

- Run `scripts/device-ui-settings-e2e.ps1` and open `设置 > 通知`.
- Capture dark and light `notifications-page` screenshots.
- Repeat at maximum system text size.
- Record the four choice bounds and confirm equal heights, equal widths within
  one pixel, no text clipping and no overlap with the category label.
- Confirm the 44vp touch region still changes the intended category without
  changing neighboring rows.
