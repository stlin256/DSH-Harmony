# Connection banner motion

Date: 2026-11-04

The reconnect banner currently appears and disappears instantly. The user
requires both transitions to be animated while keeping the shell stable and
the state interruptible.

- Appearing and disappearing connection banners use one semantic motion
  token and one spatial direction (unfold from the status anchor, retract
  toward it).
- The animation never waits on the network, never loops and never delays the
  underlying connection state.
- Reduced motion, power saving and background execution resolve directly to
  the final state.
- Cover the visible banner state with a deterministic Mock scene, a device
  driver and source-contract tests; do not claim animation from a static
  screenshot alone.
