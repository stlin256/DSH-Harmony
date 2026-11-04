# Connection banner motion implementation

Date: 2026-11-04

`NativeMotion.statusBannerTransition()` owns the effect: an asymmetric
transition built from `OPACITY` plus a small vertical offset (-6vp on entry,
-4vp on exit) animated with the existing `micro` semantic token for entry and
`exitDuration('micro')` for exit. It returns `TransitionEffect.IDENTITY` when
`NativeMotion.enabled()` is false, so reduced motion, power saving and
background execution resolve directly.

Apply it to every temporary link-state banner: the conversation reconnect
banner, the sidebar reconnect banner and the terminal stream-failure banner
with its manual retry action. The banner conditions read one helper
(`connectionRetrying()`), and the helper exposes the deterministic
`connection-retrying` Mock showcase state without affecting production
profiles.

## Verification

Source-contract tests assert the semantic helper, the asymmetric enter/leave
pair, the semantic token reuse and the transition on all three banners.
Register a `connection-retrying` Mock scene, capture dark/light in the Mock
suite, and add `scripts/device-ui-status-banner-e2e.ps1` to capture the
banner in dark, light and reduced-motion runs on the current Mock HAP. The
exit animation shares the same transition object; it is not inferred from a
single still frame.
