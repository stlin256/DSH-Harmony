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
| IME-01 | Launch `dock-send-idle` in dark theme and tap the composer. | Header title top stays fixed; IME opens; composer remains above the resized page. | Pending |
| IME-02 | Enter an ASCII draft while the IME is open. | Draft appears once, composer does not cover the transcript header and no page-level upward shift occurs. | Pending |
| IME-03 | Dismiss the IME with system Back. | Header and composer geometry restore within one pixel; draft remains. | Pending |
| IME-04 | Reopen the IME and dismiss it again. | The same bounds and draft are preserved. | Pending |
| IME-05 | Repeat the open/dismiss flow in light theme. | Header and composer geometry remain stable in both themes. | Pending |
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
| Mock mapping | Passed, `33/33` features and `68/68` states | `node scripts/verify-mock-coverage.mjs` |
| PR QA | Passed | `.artifacts/qa/20261102T052550Z-a8ca704d/report.json` |
| Release variants | Passed | Mock, default and store HAPs built on 2026-11-02 |
| Physical device driver | Pending | HDC reports only UART placeholders (`COM3`, `COM4`) |

Current HAP hashes:

- Mock: `093BB55AB93FD341BAE3308ADFD24F06911EC7AB25964DB2BF528089E6DC20EA`
- Default: `AB06FC3FD364638CA879FC58B80EC5CB31E9D382120D71D05C96B80B91A3994D`
- Store: `FC6DFE577E74B8CB96D2CC41900D29208A83E3D21F7FD756C422B52A1996D70D`

The release builds compile with existing project-wide ArkTS warnings. No
physical-device IME capture exists yet, so IME-01 through IME-08 remain Pending.
