# Running tail device acceptance

Date: 2026-11-05. Driver:
`scripts/device-ui-running-tail-e2e.ps1 -SkipBuild` on the Mock product.

Revision: authoritative Host clock, in-transcript placement, continuous
gradient sweep across whale/text/dots, animated APNG-derived whale and
parent-driven appearance/disappearance.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| RUN-01 | Authoritative clock (dark) | Launching mid-turn shows the Host elapsed time (not app-open time), the region animates and the icon keeps animating; the row sits above the composer inside the transcript | Pending current-device re-run (device screen locked at delivery; previous 18s→24s evidence is superseded) |
| RUN-02 | Light theme | Same copy, sweep and animated whale in the light theme | Pending current-device re-run |
| RUN-03 | Reduced motion | No sweep, no entry translation and a static whale; the clock still updates | Pending current-device re-run |
| RUN-04 | Appearance/disappearance | The row mounts when a turn starts and leaves with the 170ms height/opacity animation when the turn is stopped, without leaving the conversation | Pending current-device re-run (stop path implemented with `composer-stop`) |
| RUN-05 | Continuous output | During continuous deltas the trailing row never alternates with the streaming content (static trailing ListItem, parent-driven progress, tail timers excluded from source-tail refreshes) | Pending current-device re-run |

Evidence directory: `artifacts/device-e2e/running-tail/running-tail/manifest.json`.
An earlier HAP produced passing dark/light/reduced captures for the previous
animated-WebP ticker design; those results do not qualify this revision.
<INVALID>