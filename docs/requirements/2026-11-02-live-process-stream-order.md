# Live process stream ordering requirement

Date: 2026-11-02

## Goal

While a turn is running, reasoning and tool operations MUST appear in the same
first-appearance order produced by the active assistant stream. A reasoning row
MUST NOT be moved below tools merely because reasoning is stored separately for
compatibility.

## Required behavior

1. Durable assistant blocks continue to follow `CHAT04` source-block order.
2. The active stream carries an ordered timeline of reasoning and tool parts.
   Consecutive reasoning deltas for the same part remain one row.
3. A tool call is positioned at its first timeline appearance and keeps one
   stable identity while later argument fragments update it.
4. Reconnect snapshots and encrypted local cache restoration preserve the same
   timeline order.
5. Final assistant text remains a reply row, not a work-process operation.
6. Older gateways without timeline metadata retain the aggregate fallback
   without losing reasoning or tools.
7. Reordering MUST be correctness logic, not decorative animation. Streaming
   deltas MUST NOT replay entrance animation.

## Verification

- Model tests cover reasoning -> tool -> reasoning in live deltas, snapshot
  recovery and cache restoration.
- A deterministic Mock disclosure scene renders the same sequence and is
  registered in the Mock feature manifest.
- The device driver expands the process group, proves the visible top-to-bottom
  sequence and then collapses and reopens it.
- The current-HAP device row remains Pending until physical evidence exists.
