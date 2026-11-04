# Model picker popup device acceptance

Date: 2026-11-04. Driver:
`scripts/device-ui-model-menu-e2e.ps1 -SkipBuild`. Mock HAP SHA-256
`754C854D17A3286E45B6DD8D7F2242A5858E97846DFE5467724C22365D5A0C78`,
API 26. Evidence:
`artifacts/device-e2e/20261104-model-menu/model-picker/` (`manifest.json`,
layout bounds, dark screenshots for the keyboard-closed and keyboard-open
sheets, and the permission sheet regression). No live Host claim.

| ID | Surface / interaction | Status |
| --- | --- | --- |
| MP-01 | Keyboard closed: model sheet sits above the composer input, masked, no search field | Passed: sheet bottom `2468` above input top `2516`; `搜索模型` absent. |
| MP-02 | Keyboard open: model sheet stays above the input and fully visible | Passed: sheet `253..1435` above input top `1483`; fully visible above the IME. |
| MP-03 | Outside tap dismisses the sheet without changing the selection | Passed: `model-picker` absent after the mask tap. |
| MP-04 | Dismissing the sheet keeps the current model caption | Passed: System Back closes the sheet and the caption stays `DeepSeek-V4-Pro`. |
| MP-05 | Permission popup template unchanged (position, mask, width) | Passed: `permission-picker` still sits above the composer input. |

Remaining: a live Host model directory and real provider switching keep their
own pending evidence. The Mock scene only proves the synthetic directory and
the shared popup layout contract.
