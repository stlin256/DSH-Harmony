# IME transcript anchoring and adaptive table layout device E2E

Date: 2026-11-03

Requirement:
[`2026-11-03-ime-transcript-table-layout.md`](../requirements/2026-11-03-ime-transcript-table-layout.md)

Implementation spec:
[`2026-11-03-ime-transcript-table-layout.md`](../specs/2026-11-03-ime-transcript-table-layout.md)

## Device rows

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| IME-T-01 | Open the completed Mock conversation in dark theme and focus the composer | Header stays fixed, transcript viewport contracts, tail row and composer move above the IME | Pending |
| IME-T-02 | Enter a draft while the keyboard is open | Tail content remains visible above the composer and is not covered | Pending |
| IME-T-03 | Dismiss and reopen the keyboard | Draft survives; header remains fixed; tail remains reachable | Pending |
| IME-T-04 | Repeat the flow in light theme | Bounds and hierarchy match the dark run | Pending |
| TABLE-T-01 | Open the TSV Mock preview | Table starts at the top-left; first cell shares the table container's left edge | Pending |
| TABLE-T-02 | Measure short and content-heavy columns | Content-heavy columns are wider, related header/data cells share widths and all bounds stay within 52-220vp | Pending |
| TABLE-T-03 | Scroll a wide CSV table horizontally and vertically | Both axes scroll without moving the preview title or toolbar | Pending |

## Drivers

```powershell
.\scripts\device-ui-ime-e2e.ps1 -Device '<device-id>'
.\scripts\device-ui-document-mode-e2e.ps1 -Device '<device-id>'
```

Evidence is written below `artifacts/device-ui-ime-e2e/` and
`artifacts/device-ui-document-mode-e2e/`. A row is Passed only with a current
Mock HAP hash, layout dumps and screenshots from the same device run.
