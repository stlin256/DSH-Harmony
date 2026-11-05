# Running tail device acceptance

Date: 2026-11-05. Driver:
`scripts/device-ui-running-tail-e2e.ps1 -SkipBuild` on the Mock product.

Revision: authoritative Host clock, pinned-above-composer placement (hidden while
scrolling up), continuous
gradient sweep across whale/text/dots, native ImageAnimator whale built from
the DSH APNG frames and parent-driven appearance/disappearance.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| RUN-01 | Authoritative clock (dark) | Launching mid-turn shows the Host elapsed time (not app-open time), the region animates and the icon keeps animating; the row stays pinned above the composer while following | Passed on Mock HAP `61BE2BB9…`: clock 18s→25s, whale animated between 500ms frames, row above the composer |
| RUN-02 | Light theme | Same copy, sweep and animated whale in the light theme | Passed on the same HAP (`light-live.jpeg`, elapsed 18s) |
| RUN-03 | Reduced motion | No sweep, no entry translation and a static whale; the clock still updates | Passed on the same HAP (`staticRegion=true`) |
| RUN-04 | Appearance/disappearance | The row mounts when a turn starts and leaves with the 170ms height/opacity animation when the turn is stopped, without leaving the conversation | Passed on the same HAP (`appeared=true`, `disappeared=true` after `composer-stop`) |
| RUN-05 | Continuous output | During continuous deltas a newly appended line must not push the running row out of view; the pinned row keeps its place and only disappears when the user scrolls up | Passed during the `stream-tail` continuous pump: label stayed present above the composer across captures |

Evidence directory: `artifacts/device-e2e/running-tail/running-tail/manifest.json`.
Current evidence: Mock HAP `61BE2BB9852CB5DAB68A6B868F73F3421DEBD67DCFEC8B5412B5C7DB109EF8F0`, API 26, 2026-11-05, result Passed.
<INVALID>