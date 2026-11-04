# Immersive material dock device acceptance

Date: 2026-11-05. Driver:
`scripts/device-ui-material-e2e.ps1 -SkipBuild` on the Mock product.

| ID | Surface / interaction | Status |
| --- | --- | --- |
| MAT-01 | Dark: bottom composer dock and task dock render with the immersive material while the reduced-transparency switch is OFF | Passed on API 26 Mock HAP `F145A78BA528CF7CA30ED8297AE4D1454A78269FACEE66BB4AB6A1E324FD49D0` |
| MAT-02 | Light: the same surfaces keep hierarchy and legibility with the material | Passed on the same HAP |
| MAT-03 | Default switch ON keeps the pre-immersive opaque surfaces | Passed on the same HAP |
| MAT-04 | Floating task dock: `plan-dock-overlay` shows the material card in dark and light | Passed on the same HAP |

Evidence: `artifacts/device-e2e/material/material/manifest.json` (cases
`material-dark`, `material-light`, `material-off-dark`,
`task-dock-material-dark`, `task-dock-material-light`; API 26, time
2026-11-05). The task-dock captures live under
`artifacts/device-e2e/material/plan-dock-overlay-*-conversation-material/`.

Remaining: API 23 opaque fallback, maximum font and landscape material
geometry. Light sensing feedback is interaction-driven and cannot be proven by
a still frame; the source contract gates it behind the API and reduced-motion
checks.
