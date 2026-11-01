# Fenced DSH UI and Media Compatibility Research

Date: 2026-11-01

## Reference boundary

Behavioral reference:

- DSH-Go revision
  `5f29f5d283c2501b4e5f1c1596f94700a010566b`, AGPL-3.0.
- DeepSeek Harness `@deepseek-ai/dsh-tool-present` and the current DSH event
  contracts used by the existing gateway.

DSH-Go was inspected to validate behavior and limits. No source, asset or prose
is copied into DSH Harmony.

## Remaining structured formats

### Assistant `dsh-ui` fences

DSH-Go treats a Markdown code fence with language `dsh-ui` as model-authored
native UI:

- assistant-card hard limit: 16 KiB;
- 40 rendered nodes;
- depth 6;
- 16 direct children per layout container;
- arrays are normalized to a vertical stack;
- comments and trailing commas receive one lenient JSON retry;
- the v1 model catalog is `stack`, `row`, `text`, `metric`, `chart`, `compare`,
  `steps`, `callout`, `options` and `confirm`;
- an unknown root or irreparable source becomes a code fallback;
- unknown nested content becomes a placeholder;
- options and confirm are answerable only by the latest idle assistant view;
- an answer is a readable user message beginning with `[dsh-ui reply]` and
  containing visible labels. Hidden values are never sent;
- reply messages render as compact chips;
- running, historical or already-answered cards are read-only.

DSH Harmony currently has no parser or renderer for this fence. The generic
code block is safe but loses semantics and interaction.

### Tool `dsh-go/view`

DSH-Go reads this metadata only from successful tool results and requires a
known root component. DSH Harmony already renders the v1 component catalog and
the 8 KiB tool-card budget, but its first pass could accept a running record or
an unknown root if such metadata were present.

### Generated media

DSH-Go's v1 media reader is deliberately tolerant:

- absent `v` defaults to 1 and later positive versions remain readable;
- missing kind may be inferred from the first item's video MIME;
- unknown status defaults to done;
- malformed optional item/request fields are dropped rather than invalidating
  valid media;
- a done record with no valid items is invalid;
- `cost` is exposed when its estimate is finite and non-negative;
- provenance and failure facts remain optional.

The current DSH Harmony parser is stricter than the reference and omits cost.
That is safe but loses otherwise valid historical cards.

## Design decisions

- Reuse the existing bounded plugin presentation model for both tool cards and
  assistant fences. Add an explicit read-only/interactive mode.
- Keep tool cards permanently read-only. Only assistant fences can produce a
  `[dsh-ui reply]` message.
- Derive interaction availability from message order and current runtime state;
  do not persist rendered selections in the transcript.
- Preserve the original fence source for invalid fallback and copy.
- Keep media parsing presentation-only. Do not write back inferred fields into
  the durable metadata.
- Keep all parsing bounded and independent from the gateway wire protocol.

## Remaining non-goals

- Executing arbitrary plugin actions.
- Loading HTTP images into persisted tool cards.
- Inline playback for generated video.
- Copying DSH-Go's larger plugin panel or future v2 style catalog.
