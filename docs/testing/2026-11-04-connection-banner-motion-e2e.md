# Connection banner motion device acceptance

Date: 2026-11-05. Driver:
`scripts/device-ui-status-banner-e2e.ps1 -SkipBuild`. Mock HAP SHA-256
`39E21758985730358D8C39CDB4A663BC7BAFCAF3A1FE2E83567BBFE703770AB9`,
API 26. Evidence:
`artifacts/device-e2e/20261104-connection-banner/connection-banner/`
(`manifest.json` and dark/light/reduced-motion screenshots). No live Host
claim.

| ID | Surface / interaction | Status |
| --- | --- | --- |
| BAN-01 | Dark theme reconnect banner appears and retracts with the shared transition | Passed: banner at `[162,341][608,388]`, one node, persists after an outside tap. |
| BAN-02 | Light theme reconnect banner uses the same motion and geometry | Passed: same banner geometry in the light theme. |
| BAN-03 | Reduced motion resolves the banner directly to its final state | Passed: banner present at the same bounds with `ReduceMotion` set. |

The exit half of the transition is the asymmetric leave defined once in
`NativeMotion.statusBannerTransition()` and covered by the source contract; the
device runs prove the banner state, theme and reduced-motion fallback. A live
Host reconnect cadence remains separate pending evidence.
