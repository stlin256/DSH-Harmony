# Permission switch Host fix and checkbox acceptance

Date: 2026-11-05. Mock driver:
`scripts/device-ui-permissions-e2e.ps1 -SkipBuild` on Mock HAP
`2E6DDD550816E6D98E19D1B761BB0B4626F65FAE1D1124371522FB52F1AFC96E`.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| PERM-SW-01 | Real Host permission switch | `setPermissionPreset` through the native operation route returns 200 and the permission projection becomes the requested preset | Pending deployment check |
| PERM-SW-02 | Full-access risk acknowledgement | The row renders as an unchecked checkbox with the confirm action disabled; tapping it checks the box and enables the confirm action | Passed on the Mock HAP above (`artifacts/device-e2e/permission-checkbox/permissions/`) |
| PERM-SW-03 | Rejected command result | A Host error result maps to 409 (`permission/rejected`, `plan/rejected`) instead of a false success | Passed by gateway tests; pre-fix live Host returned 502 |

Evidence: `artifacts/device-e2e/permission-checkbox/permissions/manifest.json`
(dark and light confirmation, checked/unchecked captures, switching states).
The real-Host row is promoted only after the deployed plugin is verified
through the native operation route.
