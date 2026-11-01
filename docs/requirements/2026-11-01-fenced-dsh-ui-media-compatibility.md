# Fenced DSH UI and Media Compatibility Requirement

Date: 2026-11-01

Status: accepted for implementation.

## User-visible problem

The native client now understands the tool-level `dsh-go/view` and
`dsh-go/media` metadata contracts. A complete structured pass must also cover
DSH assistant replies that contain a fenced `dsh-ui` view. Today those replies
fall back to a JSON code block.

Two compatibility gaps also remain in the tool-level pass:

- a tool card must require a successful result and a known root component;
- DSH media metadata is intentionally tolerant of omitted versions, inferred
  media kinds and malformed optional facts, while retaining valid content and
  cost information.

## Required behavior

- A fenced `dsh-ui` assistant block SHALL render as compact native DSH UI.
- The fence parser SHALL use the DSH-Go assistant-card budget: 16 KiB, 40
  components, depth 6 and at most 16 direct children per container.
- JSON arrays SHALL be accepted as a vertical stack. Comments and trailing
  commas MAY be repaired once before declaring the block invalid.
- Stack, row, text, metric, chart, compare, steps, callout, options and confirm
  SHALL be supported for assistant fences.
- Unknown or invalid root content SHALL fall back to the original code block.
  Unknown nested content SHALL degrade to a compact placeholder without
  failing supported siblings.
- Options and confirm blocks SHALL be interactive only for the latest idle
  assistant view. Historical, running, answered or invalidated views SHALL be
  read-only.
- An answer SHALL send visible labels only in a `[dsh-ui reply]` user message.
  Hidden option values, actions and arbitrary plugin effects SHALL never be
  transmitted.
- A `[dsh-ui reply]` user message SHALL render as a compact reply chip while
  retaining its complete text for copy and reconnect.
- Tool-level `dsh-go/view` SHALL render only from a successful result with a
  known root component. Failed or still-running records keep the raw fallback.
- Media metadata SHALL accept a missing `v` as v1 and accept later positive
  versions. Invalid optional facts SHALL be ignored without discarding valid
  items.
- When media `kind` is absent, it SHALL be inferred from the first valid item's
  MIME type. A done media record with no items SHALL be invalid.
- Media cost SHALL be exposed when it contains a finite non-negative estimate
  and a short currency label.
- The parser SHALL remain read-only. It SHALL not invoke plugin actions, load
  remote images, mutate durable records or fabricate success.
- All existing compact visual, light/dark, safe-area, reduced-motion and
  accessibility rules continue to apply.

## Compatibility and privacy

- Target the current DSH and DSH-Go structured contracts used by the pinned
  references in the research document.
- Do not copy DSH-Go source, assets, prose or implementation text.
- Do not add private hosts, credentials, real transcripts, workspace paths or
  notification content to source, tests or documentation.
- Gateway wire shapes remain unchanged.

## Acceptance gate

- Parser tests cover valid, invalid, oversized, over-depth, arrays, repaired
  JSON, unknown components, interactive options/confirm and media inference.
- Source contracts prove fenced cards and reply chips are wired into chat while
  tool cards remain read-only.
- Both default and store Release variants build.
- Device E2E remains Pending until performed on a real HarmonyOS device.
