# Plugin switch feedback device acceptance

Date: 2026-11-05. Driver:
`scripts/device-ui-plugin-toggle-e2e.ps1 -SkipBuild` on the Mock product.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| PLUG-01 | Bundle switch (dark) | Closing shows the one-line `已关闭` banner and the switch is off without leaving the manager; enabling shows `已启用` and the switch is on | Passed on Mock HAP `F97B026F…`; banner 108px (~31vp), switch checked true→false→true in place |
| PLUG-02 | Bundle switch (light) | Same feedback and in-place refresh in the light theme | Passed on the same HAP, banner 108px |
| PLUG-03 | Detail row switch | Toggling a component row refreshes its switch and shows the one-line banner on the same detail page | Passed on the same HAP; `native-bridge` checked true→false with the 108px banner |

Evidence: `artifacts/device-e2e/plugin-toggle/plugin-toggle/manifest.json`
(Mock HAP `F97B026F23CFCF0A9216D134A43F6D259CA9099A14C1D1822977913B18E506A3`,
API 26, 2026-11-05).
The driver asserts the banner node height stays at the compact single-line
height and reads the switch `checked` state from the layout before/after each
tap; screenshots record the banner in both states.