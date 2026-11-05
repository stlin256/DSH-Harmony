# Running tail device acceptance

Date: 2026-11-05. Driver:
`scripts/device-ui-running-tail-e2e.ps1 -SkipBuild` on the Mock product.

Revision: authoritative Host clock, in-flow placement at the very end of the
conversation (scrolls down with the content like the DSH chat), continuous
gradient sweep across whale/text/dots, native ImageAnimator whale built from
the DSH APNG frames and parent-driven appearance/disappearance.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| RUN-01 | Authoritative clock (dark) | Launching mid-turn shows the Host elapsed time (not app-open time), the region animates and the icon keeps animating; the row is the last conversation row above the composer and scrolls with the transcript | Passed on Mock HAP `39CFD9C8…`: clock 18s→25s, whale animated between 500ms frames, row above the composer |
| RUN-02 | Light theme | Same copy, sweep and animated whale in the light theme | Passed on the same HAP (`light-live.jpeg`, elapsed 18s) |
| RUN-03 | Reduced motion | No sweep, no entry translation and a static whale; the clock still updates | Passed on the same HAP (`staticRegion=true`) |
| RUN-04 | Appearance/disappearance | The row mounts when a turn starts and leaves with the 170ms height/opacity animation when the turn is stopped, without leaving the conversation | Passed on the same HAP (`appeared=true`, `disappeared=true` after `composer-stop`) |
| RUN-06 | Scroll-away | Scrolling up carries the row down with the transcript instead of pinning it | Passed on the same HAP (`stream-long`: row moved/left with content) |
| RUN-05 | Continuous output | During continuous deltas a newly appended line must not push the running row out of view or duplicate it; the stable last row keeps its place and follows the transcript when scrolling | Passed during the `stream-tail` continuous pump and the `stream-long` scroll-away case |

Evidence directory: `artifacts/device-e2e/running-tail/running-tail/manifest.json`.
Current evidence: Mock HAP `39CFD9C8DAE64F4D3949B10C20B1C4BF8C92E9EDE4D80C616E26434CDC39CA46`, API 26, 2026-11-05, result Passed.
<INVALID>