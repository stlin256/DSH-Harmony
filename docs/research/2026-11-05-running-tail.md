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

`Shape` + `Path` rendered the DSH fallback at its own coordinate scale, which
measured ~14px wide on device instead of 18vp. The icon now uses two authored
stills from the DSH APNG (base and glow colours) so the size and crop are
exact, with the glow still driven by the same sweep timeline. The row moved
from below the transcript list into a conditional `ListItem` after the last
message, with a parent-held exit window so the leave animation can finish.

## Animated WebP removal

The first implementation mounted a 48-frame animated WebP inside a 100ms
rotate/scale ticker. Device feedback reported conversation jank and multiple
crashes in the same build window. Animated WebP re-decodes while a transform
state changes every 100ms, and the ticker also updated backgrounded views.
That combination was removed: stills are decoded once, the sweep runs at 33ms
only in the foreground, and every timer is cleared on disappear.
