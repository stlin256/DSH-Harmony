# Running tail implementation

Date: 2026-11-05

## Data and copy

`NativeRunningStatus.ets` owns the pure copy rules: `nativeRunDuration`
(1s floor, seconds/minutes/hours), `nativeRunningLabel` (`深度求索中` without a
known start, otherwise `深度求索中，用时 … ···`) and `nativeRunningElapsed`
(freeze when paused). Model tests cover the formatting and the freeze.

## Component

`NativeRunningTail.ets` renders the divider plus a 28vp row: the colorized
animated whale (`running_whale_dark.webp` / `running_whale_light.webp`,
converted from the DSH APNG with the same 50ms cadence and the DSH label
colors) plus the `深度求索中，用时 … ···` line. A 100ms semantic step animates the
whale tail sway (rotate/scale around its tail) and sweeps the label between the
DSH deep-diving and shimmer tokens, matching the upstream 1.5s shimmer
cadence while keeping every pixel inside the glyphs. Reduced motion replaces
the whale with the DSH SVG path and freezes the label color.

The component owns its one-second clock and starts it when `turnKey` becomes
non-empty; `NativeWorkspace` mounts it with the current running turn and
unmounts it when the run settles, so a new turn never inherits the previous
turn's duration.
`paused` freezes the label while the connection is not live. The tail is
mounted directly after the transcript list and above the composer dock while
`model.running` is true.

## Assets and verification

The two WebP assets are bundled in `resources/base/media` and asserted to be
animated in tests. `device-ui-running-tail-e2e.ps1` drives the `stream-long`
Mock scene in dark, light and reduced motion: it checks the copy, growth of
the elapsed number, a changed tail region between frames, tail survival after
a scroll and a static region under reduced motion.
