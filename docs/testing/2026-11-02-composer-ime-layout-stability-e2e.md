# Composer IME layout stability device E2E

Date: 2026-11-02

Requirement:
[`2026-11-02-composer-ime-layout-stability.md`](../requirements/2026-11-02-composer-ime-layout-stability.md)

Implementation spec:
[`2026-11-02-composer-ime-layout-stability.md`](../specs/2026-11-02-composer-ime-layout-stability.md)

## Prerequisites

- A signed Mock HAP built from the current source.
- One ready USB HarmonyOS target.
- The `dock-send-idle` deterministic fixture.
- The system soft keyboard enabled and not replaced by a hardware-only input
  method.

## Device rows

| ID | Action | Expected | Status |
| --- | --- | --- | --- |
| IME-01 | Launch `dock-send-idle` in dark theme and tap the composer. | Header title top stays fixed; IME opens; composer remains above the resized page with a 12vp gap while the closed state uses the shared 20vp baseline. | Passed |
| IME-02 | Enter an ASCII draft while the IME is open. | Draft appears once, composer does not cover the transcript header and no page-level upward shift occurs. | Passed |
| IME-03 | Dismiss the IME with system Back. | Header and composer geometry restore within one pixel; draft remains. | Passed |
| IME-04 | Reopen the IME and dismiss it again. | The same bounds and draft are preserved. | Passed |
| IME-05 | Repeat the open/dismiss flow in light theme. | Header and composer geometry remain stable in both themes. | Passed |
| IME-06 | Repeat with maximum system font size. | Header, chips and composer remain readable and do not overlap while the IME is open. | Pending |
| IME-07 | Open a drawer or settings surface, then focus a field. | The overlay follows its own avoidance policy and does not translate the underlying conversation header. | Pending |
| IME-08 | Resume from background with the IME previously dismissed. | Initial mode still uses `RESIZE`; no stale `OFFSET` translation appears. | Pending |

## Driver

```powershell
.\scripts\device-ui-ime-e2e.ps1
```

The driver writes screenshots, layout dumps and `manifest.json` under
`artifacts/device-ui-ime-e2e/composer-layout/`. It must not mark rows passed
without a ready USB target and current HAP evidence.

## Current automated evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Source contract | Passed | `node scripts/verify-keyboard-avoidance.mjs` |
| Mock mapping | Passed, `39/39` features, `76/76` states and `115` capture pairs | `node scripts/verify-mock-coverage.mjs` |
| Current PR QA | Passed | final PR QA path recorded in the delivery summary |
| Release variants | Passed | Mock, default and store HAPs built on 2026-11-02 |
| Physical device driver | Passed for IME-01 through IME-05 | `artifacts/device-e2e-final/ime-clean/composer-layout/manifest.json` |

Current HAP hashes:

- Device-qualified Mock: `F23693248955498EC90306DC2D1942D2DC30F440FE449D73DDB9592FE59412CD`
- Final default Release: `43E3466D0C878A07C673899B2B213E6348A0DC0424BA032E16C080D31D880E08`
- Final store Release: `2BC7E88367F6CAD626954CDA7F9FC72FB6324702E9C6EE9AAFEFD0168DB9A6E6`

The release builds compile with existing project-wide ArkTS warnings. IME-01
through IME-05 passed on the current API 26 phone. IME-06 maximum-font and the
separate overlay/background restore scenarios remain Pending.
