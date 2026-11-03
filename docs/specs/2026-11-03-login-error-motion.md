# Login Error Motion Implementation Specification

Date: 2026-11-03

Requirement:
[`2026-11-03-login-error-motion.md`](../requirements/2026-11-03-login-error-motion.md)

## State Changes

Add one `Index` helper that updates `launchError` and an optional destination
phase inside:

```text
NativeMotion.animate(context, 'micro', action)
```

`failLaunch` and the login attempt use that helper. Starting a new connection
also clears the current error through `micro`, so a repeated attempt fades the
old message before the next result is painted.

The semantic `micro` token remains 140ms and already resolves immediately when
motion is disabled by reduced-motion, power-saving or background state.

## Surface Transitions

`NativeLaunchSurface` keeps state ownership in `Index` and adds transition
effects only at render boundaries:

- login card: `NativeMotion.rowTransition()`;
- full error card: `NativeMotion.rowTransition()`;
- inline login error row: `NativeMotion.rowTransition()`.

Stable IDs `launch-login-card`, `launch-login-error`,
`launch-login-connect` and `launch-error-card` make the state transition
available to device layout evidence without changing visual hierarchy.

No component-local duplicate state is introduced. ArkUI remains free to
interrupt an in-flight transition when a newer error or success state arrives.

## Verification

- Node source contract checks the shared `micro` update path and all three
  transition boundaries.
- `device-ui-launch-notice-e2e.ps1` enters the login form, submits an empty
  address, waits for the stable inline error and records a screenshot/layout.
- The same script runs with reduced motion and only asserts final geometry.
- Default, store and mock Release variants build after the shared ArkUI change.
