# Running tail device acceptance

Date: 2026-11-05. Driver:
`scripts/device-ui-running-tail-e2e.ps1 -SkipBuild` on the Mock product.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| RUN-01 | Running tail dark | `深度求索中，用时 X秒 ···` appears after the last message, the elapsed number grows and the tail region animates between frames | Passed on Mock HAP `3F187D64…`: elapsed 9s -> 15s, tail region changed (delta 2.19) |
| RUN-02 | Running tail light | Same copy and whale line remain legible in the light theme | Passed on the same HAP (`light-live.jpeg`) |
| RUN-03 | Reduced motion | Static whale path and static text; two captures of the tail region are identical | Passed on the same HAP (`staticRegion=true`) |

Evidence: `artifacts/device-e2e/running-tail/running-tail/manifest.json`
(Mock HAP `3F187D64E6050776A801D6366E0A091C1BE3F060A24652247CDDB9D76F0E7653`,
API 26, 2026-11-05).
The wholesale WebP animation and the scroll interaction are captured by the
driver; a still cannot prove motion, so animation is asserted from two
region crops and reduced motion from two identical crops.
