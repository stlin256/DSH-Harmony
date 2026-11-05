# Running tail research

Date: 2026-11-05

## Upstream reference

The pinned DSH client uses a 60-frame 28x28 APNG for the whale, a 1.5s
`TextShimmer` overlay for the label and `location.turn.start.time` for the
clock. The label copy comes from `chat.deepDiving`.

## Timing source

`turn/start` is a durable Session event with `seq`, `time` and
`data.turn` (verified in the live Host session log). The native gateway now
exposes the latest open turn start in the follow snapshot
(`turnStartedAt`), requests a `turnWindow` so the opening window crosses a
turn start, and, when a long turn pushed the start outside the window, fetches
a bounded back-page and delivers a `turn-start` frame. The client stores
`runningTurnStartedAt`, also updates it from live `turn/start` / `turn/end`
events, clears it when the state stops running and persists it in the
transcript cache.

## Light sweep

ArkUI API 20+ exposes `Text.shaderStyle(ShaderStyle)`. A `LinearGradientStyle`
can be rebuilt from state at 30fps, giving a real gradient inside the glyphs
(Canvas and blend-layer attempts were rejected earlier for halo/repaint
problems). The gradient band's alpha is gated near both ends of the row so
the pass disappears before the timeline wraps, making the loop continuous.

## Icon and placement

`Shape` + `Path` measured ~14px wide on device instead of 18vp, and an animated
WebP did not advance under the sweep rebuild loop. The whale now uses ArkUI
a timer-driven frame sequence with 15 PNG frames decoded once from the DSH APNG (3s loop),
inside `NativeRunningWhale`, while the clock/sweep live in `NativeRunningLabel`, so per-frame state never rebuilds the whale. The row is a
static trailing `ListItem` after the last message; the workspace owns the
appearance/exit progress so list refreshes cannot replay it.

## Animated-WebP ticker removal

The first implementation mounted a 48-frame animated WebP inside a 100ms
rotate/scale ticker. Device feedback reported conversation jank and multiple
crashes in the same build window. The ticker and WebP were removed; the whale
is now an a timer-driven frame sequence frame loop, the sweep runs at 33ms only in the
foreground, and every timer is cleared on disappear. A 180-second continuous
Mock stream kept the process alive for 12/12 samples.
