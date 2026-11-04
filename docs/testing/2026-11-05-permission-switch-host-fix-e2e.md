# Permission switch Host fix and checkbox acceptance

Date: 2026-11-05. Mock driver:
`scripts/device-ui-permissions-e2e.ps1 -SkipBuild` on Mock HAP
`2E6DDD550816E6D98E19D1B761BB0B4626F65FAE1D1124371522FB52F1AFC96E`.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| PERM-SW-01 | Real Host permission switch | `setPermissionPreset` through the native operation route returns 200 and the permission projection becomes the requested preset | Passed on deployed release `0.4.8-d2424a3-plugin-0.3.9` (DSH 0.2.2-rc.1): read-only and workspace-write returned `{accepted:true}` and the projection seq/currentValue changed; the app switch was also driven on the physical device |
| PERM-SW-02 | Full-access risk acknowledgement | The row renders as an unchecked checkbox with the confirm action disabled; tapping it checks the box and enables the confirm action | Passed on the Mock HAP above and on the physical device against the real Host (confirm disabled before the check, enabled after, full access applied) |
| PERM-SW-03 | Rejected command result | A Host error result maps to 409 (`permission/rejected`, `plan/rejected`) instead of a false success | Passed by gateway tests; pre-fix live Host returned 502 |

Evidence:

- Mock: `artifacts/device-e2e/permission-checkbox/permissions/manifest.json`
  (dark and light confirmation, checked/unchecked captures, switching
  states).
- Real device: `artifacts/device-e2e/real-permission-switch/real/manifest.json`
  on the default Release HAP
  `18525C75F5F0017FC833C463B4BD5E72341BD2615DF7BF5760AE6ECC5A1D04FC`
  with plugin `0.3.9`. The driver switched to workspace-write, then opened
  the full-access card, confirmed the checkbox gate and applied full
  access; no failure banner appeared.
