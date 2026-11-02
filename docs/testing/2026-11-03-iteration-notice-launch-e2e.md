# Rapid-Iteration Notice Launch E2E

Date opened: 2026-11-03

Status: API 26 device execution passed on Mock HAP SHA-256
`3FE9EE11C150C2C7380B5C360C4994782A87AFB2F94162D2445950C641C0DB48`.
API 23, maximum font and a real-account saved-session relaunch remain pending.

Requirement:
[`2026-11-03-iteration-notice-launch.md`](../requirements/2026-11-03-iteration-notice-launch.md)

Implementation spec:
[`2026-11-03-iteration-notice-launch.md`](../specs/2026-11-03-iteration-notice-launch.md)

Driver: `scripts/device-ui-launch-notice-e2e.ps1`

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| ITER-01 | Cold launch with the feature flag enabled and notice unconfirmed | Rapid-iteration notice appears before `intro`; no login or workspace flashes underneath | Passed; first Mock fixture launch |
| ITER-02 | Inspect the notice in dark theme | Badge, title, two explanatory paragraphs and one confirmation action fit with safe insets and no clipping | Passed; `dark-notice.jpeg` |
| ITER-03 | Inspect the notice in light theme | The same hierarchy remains legible and the logo uses the light background palette | Passed; `light-notice.jpeg` |
| ITER-04 | Press system Back on the notice | The notice remains visible and input is consumed | Passed; layout retained `iteration-notice` after Back in both themes |
| ITER-05 | Confirm the notice | Existing welcome page appears with `开始引导` and `直接进入` | Passed; `dark-welcome.jpeg`, `light-welcome.jpeg` |
| ITER-06 | Compare logo bounds before and after confirmation | X, Y, width and height are identical; only the content transitions | Passed; both themes retained `[475,569][786,880]` |
| ITER-07 | Repeat confirmation with reduced motion enabled | Content resolves directly to the welcome page with identical final geometry | Passed; `reduced-motion-notice.jpeg`, `reduced-motion-welcome.jpeg` |
| ITER-08 | Open settings → service/account → logout and confirm | The application returns to the notice page while retaining the service address | Passed in Mock settings flow; `notice-after-logout.jpeg` |
| ITER-09 | Relaunch after confirmation with a saved session | Notice is skipped and the existing saved-session restoration branch runs | Pending; requires a real saved account |
| ITER-10 | Disable the source feature flag and relaunch | Previous launch order is restored without any notice phase | Automated source/model check |
| ITER-11 | API 23 and maximum font | Notice remains readable with opaque surfaces and no unsafe overlap | Pending |

## Mock Evidence

Expected output directory:
`artifacts/device-e2e-final/launch-notice-clean/iteration-notice/manifest.json`.

The manifest must record:

- device and Mock HAP SHA-256;
- dark and light notice/welcome screenshots;
- system-Back persistence;
- exact before/after logo bounds;
- reduced-motion confirmation;
- logout-to-notice transition;
- unchanged application PID at the end.

Current evidence:
`artifacts/device-e2e-final/launch-notice-release/iteration-notice/manifest.json`.
