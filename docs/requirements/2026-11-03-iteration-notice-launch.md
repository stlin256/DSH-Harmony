# Rapid-Iteration Notice Before First Launch

Date opened: 2026-11-03

Status: implemented; API 26 dark/light/reduced-motion/Mock-logout paths passed.
API 23, maximum font and a real-account saved-session relaunch remain pending.

## User Requirement

- `ITER-REQ-01` Add a polished notice page before the existing first-launch
  welcome page.
- `ITER-REQ-02` The notice page logo must use the same size and position as the
  existing welcome page so confirmation transitions do not move or rescale the
  brand mark.
- `ITER-REQ-03` Explain that DSH Harmony is in a rapid-iteration phase, some
  features are not implemented yet, bugs and imperfect interactions may exist,
  and users should open an Issue in the repository when they encounter a
  problem.
- `ITER-REQ-04` Provide one clear confirmation action. Confirming enters the
  existing welcome page without bypassing saved-session restoration rules.
- `ITER-REQ-05` Confirmed logout returns to the notice page before the welcome
  or login flow.
- `ITER-REQ-06` The notice adapts to system light and dark appearance.
- `ITER-REQ-07` A source-level feature flag controls the notice. The flag is on
  for the current build.
- `ITER-REQ-08` The `快速迭代版本` badge is horizontally centered within the
  notice content column. It is not left-aligned with the body copy.

## Behavior

- The notice is a launch phase, not a normal application page or a blocking
  modal over the workspace.
- On a cold launch, an unconfirmed notice appears before `intro`. After
  confirmation, the saved origin and onboarding preference choose the existing
  `intro` or `restoring` branch.
- The confirmation is persisted locally. A later cold launch with saved
  authentication continues directly to `restoring` after the notice has been
  confirmed.
- Logout resets the notice confirmation together with onboarding and cached
  session state. The retained service address is not cleared.
- System Back cannot dismiss the notice. The user must explicitly confirm it.
- The Issue suggestion is explanatory copy in this screen; it does not add a
  second primary action or open an external browser without a dedicated,
  accessible control.

## Constraints

- Keep the text concise and calm. The page explains maturity honestly without
  presenting a long changelog or an implementation tutorial.
- Use the current launch background, product logo, DSH neutral surfaces and
  DeepSeek blue accent. Do not introduce a separate illustration or visual
  identity.
- Preserve a 20vp bottom-safe baseline and system-bar insets.
- Reduced motion resolves the phase change immediately with identical final
  geometry.
- API 23 remains fully readable with opaque theme surfaces.

## Acceptance

- Dark and light screenshots show the notice without clipping or unsafe areas.
- Confirming keeps the logo bounds unchanged and reveals the existing welcome
  page.
- A deterministic Mock state covers the notice, and a device interaction driver
  confirms the phase transition.
- Redirecting the feature flag off restores the previous launch order.
- Source/model tests cover first launch, confirmed cold launch, feature-off
  behavior and logout reset.
- A Mock settings logout flow returns to the notice page.
- The default, store and mock Release variants build after shared ArkUI changes.
- Device evidence is recorded before any device row is marked passed.
