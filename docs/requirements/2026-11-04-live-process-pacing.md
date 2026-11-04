# Live process text pacing

Date: 2026-11-04

The assistant reply now reveals smoothly, but the user reports that text
inside tool cards and while the turn is still inside tool-call intervals still
stutters. The live process strip (reasoning segments and preparing tool
arguments) bypassed the display cursor: network bursts were applied to the
model and surfaced as whole chunks, and process deltas re-projected the
transcript without any reveal budget.

- Pace reasoning segments and preparing tool arguments with the same
  semantic display cursor as the assistant reply.
- Authoritative model data must never be paced, truncated or reordered; the
  cursor only owns the rendered prefix and converges within a bounded lag.
- Reveal must stay Unicode-safe, interruptible and direct under reduced
  motion, power saving and background execution.
- Keep the existing structural/tool-frame invalidation and text-only patch
  contract for the assistant row.
- Cover the pacer with model tests; device evidence for the live strip is
  still required before claiming visual completion.
