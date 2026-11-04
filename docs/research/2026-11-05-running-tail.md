# Running tail research (DSH web chat)

Date: 2026-11-05. Inspected the pinned DSH 0.2.2-rc.1 client packages on the
Host (`@deepseek-ai/dsh-client-ui-chat`, `@deepseek-ai/dsh-client-ui-theme`,
`@deepseek-ai/dsh-web-frontend`).

## Structure

- `RunningStatus` renders a 0.5px divider, then a 28px content row with 6px
  gap: `RunningWhaleTail` plus `TextShimmer(label)`.
- Locale: `chat.deepDiving` = `深度求索中`; `chat.deepDivingFor` =
  `深度求索中，用时 {duration} ···`; durations use
  `{seconds}秒` / `{minutes}分{seconds}秒`, hours after 60 minutes.
- The clock uses the turn's authoritative start time; before it arrives the
  label stays `深度求索中`. It ticks every second with a 1s floor, freezes
  while disconnected and resolves immediately under reduced motion.

## Whale

- Animated form: APNG `running-whale@2x-*.png`, 28x28, 60 frames x 50ms,
  used as an alpha mask filled with the label color.
- Static fallback: SVG path
  `M8.844 13.742C8.967 12.328 8.45 10.4 ... 4.926 13.742` in a 16x16
  viewBox, 1px stroke.

## Text shimmer

- A duplicate text layer in `--dsw-alias-label-shimmer` is clipped by a
  105deg gradient mask and swept by `translate(-100%) -> translate(100%)`.
- Timing: 1.5s duration, 0.3s delay, `steps(48, end)`, infinite; the sweep
  completes by 66.6667% and holds. Reduced motion hides the decoration layer.
- Tokens: light label `#345EBA` (deepseek-500 70% + blue-950), light shimmer
  highlight black 30%; dark label `#7D9ADE`, dark shimmer highlight white
  45%. The animated mask is filled with the label color.

Source locations: `dsh-client-ui-chat/lib/client.js` (`RunningStatus`,
`RunningWhaleTail`), `dsh-web-frontend/dist/assets/*.css` (`_sweep_`,
`_dsh-row-shimmer-sweep_`), `dsh-client-ui-theme/lib/client.js` (tokens).
