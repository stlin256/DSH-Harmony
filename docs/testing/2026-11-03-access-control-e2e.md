# DSH 权限预设与单次升权审批 device E2E

日期：2026-11-03

状态：Passed

设备：HBN-AL80 / HarmonyOS 7.0.0.111 SP10C10 / API 26

## 验收表

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| PERM-01 | Composer permission chip | Dark current permission chip is a 32vp SVG-only circular target and does not squeeze attachment/send | Passed |
| PERM-02 | Composer permission chip | Workspace-write and full-access current values show the correct business glyph | Passed |
| PERM-03 | Composer permission chip | Custom current value is visible but absent from selectable rows | Passed |
| PERM-04 | Permission menu | Menu opens upward, aligns to the composer, uses a visible scrim, and keeps current-row emphasis compact | Passed |
| PERM-05 | Full-access confirmation | Confirmation requires acknowledgement; confirm is disabled before acknowledgement and cancel performs no write | Passed |
| PERM-06 | Permission switch | Successful write stays busy until the authoritative projection changes | Passed |
| PERM-07 | Permission failure | Catalog failure keeps the last authoritative chip and closes transient menu state | Passed |
| PERM-08 | Approval card | Workspace single-use approval shows tool, reason, target scope and the one-shot boundary | Passed |
| PERM-09 | Approval card | Long reason scrolls without pushing actions off screen | Passed |
| PERM-10 | Approval card | Allow-once captures the submitting card, disables both actions, and removes it after interaction-ended | Passed |
| PERM-11 | Approval card | Disconnect removes pending approval and never displays it as allowed | Passed |
| PERM-12 | DSH settings | New-session default permission lists only Host default options and states it does not affect current sessions | Passed |
| PERM-13 | DSH settings | Default permission write uses revision and refreshes on conflict | Passed |
| PERM-14 | IME and safe area | Permission chip remains reachable above IME; 20vp minimum bottom safe inset remains correct | Passed |
| PERM-15 | Light theme | Chip, menu, full-access confirmation and approval remain legible | Passed |
| PERM-16 | Native popup chrome | Permission menu and risk confirmation show no white system outline around the window; only the card-owned semantic border remains | Passed |

## Evidence

- Device: `33Z0224801015621`, HBN-AL80, HarmonyOS 7.0.0.111 SP10C10, API 26
- Screenshots and layout dumps:
  `artifacts/device-ui-permissions-e2e/permissions/`
- Permission interaction manifest:
  `artifacts/device-ui-permissions-e2e/permissions/manifest.json` (`Passed`)
- Approval submitting evidence:
  `artifacts/device-ui-permissions-e2e/permissions/approval-submitting.jpeg`
- Settings evidence:
  `artifacts/device-ui-permissions-e2e/permissions/settings-default.jpeg`
- Mock popup chrome evidence:
  `artifacts/device-ui-permissions-e2e/permissions/menu.jpeg` and
  `confirm-before-ack.jpeg`
- Mock HAP SHA-256:
  `8AE43B85C7A92DFA09A4AC6EDBA80BB5ADF5A25DE7618E6DA9E2189F024585FC`
- Default/Community HAP SHA-256:
  `95C4C1ACCB7F7F0DC7470747791B0FE16E21F2F864B332D082DDDDAA5EE1B46F`
- Store HAP SHA-256:
  `1CC600123BDBA6B84F1E55E9D9F08F5B0E24CF2CF8FCDEA47F5BC36C6598C6BC`
- PR QA report:
  `.artifacts/qa/20261103T160022Z-4d4afc24/report.json` (`passed`)
