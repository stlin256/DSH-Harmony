# Rapid-Iteration Notice Launch Specification

Date: 2026-11-03

## Upstream Boundary

This is a DSH Harmony mobile launch extension. It does not change the pinned
DeepSeek Harness protocol or claim an upstream onboarding behavior. The existing
plugin onboarding and authentication flow remains the post-confirmation
destination.

## State Model

Add `NativeLaunchPhase.iterationNotice`.

`NativeLaunchFlow` owns:

```text
iterationNoticeEnabled: boolean = true
initialPhase(hasOrigin, onboardingSeen, iterationNoticeSeen, noticeEnabled?)
```

Decision order:

1. If the feature flag is enabled and the current notice version has not been
   confirmed, resolve to `iterationNotice`.
2. Otherwise use the current `afterPreferences` decision.
3. `afterPreferences` continues to require onboarding before a saved origin can
   enter `restoring`.

Persist a boolean preference named `iterationNoticeSeen`. Absence is treated as
unconfirmed. Confirmation is written and flushed before the post-notice branch
continues.

## Index Integration

- Read `iterationNoticeSeen` with the other launch preferences.
- Use `NativeLaunchFlow.initialPhase` during cold start.
- A notice result waits for the branded launch minimum and then presents the
  notice.
- Confirmation closes the notice with the semantic `brand` motion token and
  resolves the existing `intro` or `restoring` branch.
- `restoring` begins immediately after the notice content exits; it does not
  render the login form before saved-session settlement.
- Logout writes `iterationNoticeSeen=false`, resets `onboardingSeen=false` and
  resolves to `iterationNotice` while retaining the saved origin.
- System Back consumes input while `iterationNotice` is visible.

## Surface Composition

`NativeLaunchSurface` renders the notice inside the existing launch Stack:

- shared launch background and safe-area handling;
- the same `logoX`, `logoY` and `logoSize` used by `intro`;
- the same content anchor immediately below the logo;
- one compact maturity badge, horizontally centered in the notice content
  column;
- title and two short explanatory paragraphs;
- version/iteration metadata;
- one 48vp confirmation action at the bottom of the content column.

The logo is not rebuilt between phases. Content fades and translates by a
minimal 6vp while the logo remains stationary.

The notice copy is:

- badge: `快速迭代版本`
- title: `项目正在快速迭代`
- body: `当前仍有许多功能尚未完成，也可能出现 Bug 或不够顺畅的交互。`
- guidance: `遇到问题时，欢迎在项目仓库提交 Issue，帮助我们把体验做得更好。`
- action: `我已知晓，继续`

## Mock and Tests

Add Mock screen `launch` and state `iteration-notice`. The fixture bypasses the
showcase workspace and renders only the notice. Confirming it enters `intro`.

Model/source tests cover:

- feature-on first launch;
- feature-on confirmed launch with saved origin;
- feature-off regression behavior;
- confirmation persistence;
- logout reset and retained address;
- identical logo bounds between notice and intro;
- no second primary action.

Add `scripts/device-ui-launch-notice-e2e.ps1`:

1. launch dark notice fixture;
2. assert notice marker and logo bounds;
3. assert the maturity badge center matches the notice content center;
4. press system Back and assert the notice remains;
5. confirm and assert `intro` actions appear;
6. compare logo bounds before and after confirmation;
7. repeat in light theme;
8. repeat once with reduced motion;
9. launch settings fixture, navigate to service/account, confirm logout and
   assert the notice returns.

## Verification

- `node scripts/verify-mock-coverage.mjs`
- `node scripts/qa.mjs pr`
- default, store and mock Release builds
- API 26 device E2E in dark, light and reduced motion
- API 23 and maximum font remain explicit pending rows until run
