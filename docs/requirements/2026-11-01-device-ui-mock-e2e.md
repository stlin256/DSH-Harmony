# Device UI mock and bottom dock resilience requirement

Date: 2026-11-01

## User outcome

Running a task must never make the bottom dock appear to lift away from the
screen, clip its action row, or leave the composer outside the visible safe
area. The composer stays adjacent to the live-change control and the complete
dock remains anchored to the bottom edge in portrait, landscape, light, dark and
reduced-motion modes.

The application must expose deterministic UI states through HDC so phone UI can
be tested and captured without a private Host, account, transcript or network.
The same fixtures support regression checks for pending E2E rows and remain
unreachable during normal launches.

The supported test path is the dedicated `mock` product documented in
[`2026-11-01-mock-variant-coverage.md`](2026-11-01-mock-variant-coverage.md).
Community/store artifacts retain the explicit launch flag only for existing
screenshot tooling.

## Mock contract

- `storeShowcase=true` continues to select an in-memory client and never opens a
  network connection.
- `showcaseScreen` selects the existing top-level surface:
  `conversation`, `process`, `sidebar`, `browser` or `settings`.
- `showcaseState` selects an independent content/runtime state:
  `completed`, `live-change`, `attachments`, `streaming`, `empty` or
  `long-history`.
- `showcaseTheme` accepts `light`, `dark` or `system`.
- Unknown values fall back to the existing completed conversation.
- Fixture content contains no service origin, credential, real account, real
  session or real transcript.

## Bottom dock

- The live-change control, attachment tray and composer form one bottom stack.
- Entry and exit of a live-change or attachment row changes the stack height;
  the transcript viewport absorbs that height without translating the dock
  upward as an absolute overlay.
- The composer action row, stop/send control and system gesture clearance remain
  fully visible whenever the dock is visible.
- The bottom edge stays on screen with no persistent black strip, duplicate
  safe-area spacer or clipped action row.
- Return-to-bottom remains an independent control above the measured stack.
- Reduced motion and reduced transparency resolve to the same geometry.

## Test package and evidence

- Provide a repeatable script that builds, installs and launches the fixture.
- Provide a one-command synthetic E2E script that captures real-device
  screenshots and ArkUI layout dumps for configured scenarios.
- Provide repeatable interaction drivers for settings persistence and the
  completed turn-change card, including theme, notification, card and file
  preview behavior.
- Treat automated screenshots and layout dumps as device evidence for visual
  geometry. Network interruption, Passkey, system picker and notification
  delivery still require their explicit environment or user interaction.
- Update the relevant E2E tables with Pass, Fail or explicit environment
  pending evidence.
