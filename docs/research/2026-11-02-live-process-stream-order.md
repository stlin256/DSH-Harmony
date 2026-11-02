# Live process stream ordering research

Date: 2026-11-02

Upstream baseline:
[`NATIVE-INTERACTION-SPEC.md`](../NATIVE-INTERACTION-SPEC.md), `CHAT04`

## Current behavior

The upstream active assistant stream is an ordered sequence of text, reasoning
and tool-call records. Gateway normalization previously accumulated text,
reasoning and tool updates into separate values.

`nativeTranscript` then appended every live tool before the aggregate live
reasoning. A reasoning block that appeared first in the source stream therefore
moved below the tool row while the turn was running. Durable assistant messages
already preserved block order, so the defect was isolated to the live path and
its reconnect/cache projections.

## Required model

- The ordered active stream is authoritative for live reasoning/tool placement.
- Aggregate `reasoning`, `text` and `streamTools` remain compatibility
  projections and cannot independently determine process order.
- Snapshot compaction must walk source records in order.
- Incremental deltas append the matching timeline part.
- One tool call occupies the position of its first appearance and later argument
  fragments update that same identity.
- Cache restore must preserve the timeline.

## Coverage consequence

The existing single-reasoning disclosure scenes cannot detect order inversion.
A deterministic scene with reasoning -> tool -> reasoning is required. Its
device driver must compare visible Y coordinates rather than only assert that
all three labels exist.
