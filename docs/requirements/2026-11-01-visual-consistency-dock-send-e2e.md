# Visual consistency audit and interactive Dock regression coverage

Date: 2026-11-01

## User outcome

- Record which native surfaces still diverge from the main conversation's
  compact DSH visual language.
- Make the synthetic UI client interactive enough to prove that pressing Send
  creates a visible user message, pending queue echo, authoritative queue row or
  settled response without a network or private Host.
- Expand deterministic screenshots to cover quiet, queued, attachment and live
  change Dock states in light, dark and reduced-transparency modes.
- Prevent a regression from passing only because an element exists in source:
  the device flow must inspect the post-send ArkUI tree and capture the visible
  result.

## Visual invariants

- Base, Raised and Overlay surfaces keep the hierarchy defined by
  `docs/DESIGN.md`.
- Primary actions and focus use DeepSeek blue. Neutral controls do not introduce
  a second accent palette.
- List rows use a full-row hit target, compact 10-15fp text, a 44vp minimum touch
  area and the shared DSH glyph vocabulary.
- Loading, empty and recoverable error states occupy a stable compact row rather
  than replacing the page or shifting the Dock.
- Dark mode changes foreground, stroke, icon and surface tokens together.
- The bottom Dock material is present only when elevated content is visible.
  Reduced transparency and unavailable material support resolve to a readable
  surface without a translucent black strip.

## Interactive Mock contract

- Fixture launches remain unreachable without `storeShowcase=true`.
- `showcaseState` adds:
  `dock-send-idle`, `dock-queue-pending`, `dock-queue-authoritative`,
  `dock-queue-many`, `dock-material-quiet` and `dock-material-elevated`.
- Sending from an idle fixture inserts a user message, updates the title,
  streams a short deterministic answer and settles the turn.
- Sending from a running queue fixture shows one local `发送中…` echo, then
  reconciles it with an authoritative row carrying the same `rpcId`.
- Repeated acknowledgement frames never duplicate a visible queued message.
- A failed prompt exposes an error and leaves no successful local echo.
- Fixture content contains no private origin, account, credential or transcript.

## Dock material verification

- Quiet state: composer is visible without the elevated material.
- Elevated state: queue, attachment or live-change content enables one material
  layer and does not move the Dock outside the safe area.
- The material must use real background material or backdrop blur. A foreground
  gradient blur attached to an empty layer does not satisfy the requirement.
- The bottom scrim may become more opaque toward the bottom, but it must retain
  visible background variation in its upper region.
- Light and dark captures use the same content and viewport so differences are
  attributable to theme rather than unrelated scrolling.

## Non-goals

- The Mock does not emulate the real WebSocket protocol beyond the frames needed
  for deterministic send, queue, settle and failure checks.
- A screenshot is not evidence for real Host reconnection, Passkey, Push Kit,
  system pickers or server-side queue mutation.
