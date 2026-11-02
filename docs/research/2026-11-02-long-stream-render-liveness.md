# Long Stream Render Liveness Research

Date: 2026-11-02

Upstream baseline:
[`NATIVE-INTERACTION-SPEC.md`](../NATIVE-INTERACTION-SPEC.md), `CHAT00`,
`CHAT04`, `READ04`, `READ06` and `VIS03`.

## Reproduction characteristics

The current device report is not a clean transport timeout:

- Some new text appears, then painting becomes uneven.
- Painting can stop completely while the Host turn continues.
- A cold launch can recover content that was produced before the freeze.
- The existing assistant-progress watchdog is a timer on the same UI runtime, so
  a blocked render transaction cannot repair itself promptly.

## Current hot path

Every visible text delta passes through all of the following before the next
paint:

1. `nativeRepairStreamingMarkdown()` scans and splits the complete reply.
2. `NativeTextSource.set()` rebuilds offsets for the complete reply.
3. `nativeMarkdownTable()` rechecks the complete reply.
4. `NativeInlineText.changed()` reparses the complete reply into all inline
   runs.
5. ArkUI rebuilds the `ForEach` span collection for that reply.

The cost of each step grows with the final answer length. With repeated paint
ticks, this is approximately quadratic work over a turn. Plain prose has a
fast path, but code, links and emphasis are common in agent replies and defeat
it. A low-risk parser optimization cannot fix the growing text-source and table
work by itself.

## Existing recovery gaps

- The live rows created by `nativeTranscript()` and `nativeWithLiveText()` did
  not explicitly set `runningTurn`, so the streaming repair branch could be
  disabled on the first paint.
- `trackAppliedProgress()` refreshed assistant progress for duplicate frames,
  reducing its value as a stall signal.
- A reducer update could clear a delivery mismatch merely because a mismatch
  timer existed, without matching the current Gateway tuple.
- Gateway upstream pause/resume depended on a send callback crossing the low
  watermark. A periodic drain check is a small defensive fallback.

## Design consequence

Keep protocol application exact and synchronous. Make the UI boundary
incremental:

- retain completed, visually stable Markdown blocks;
- only repair and parse the unfinished tail;
- parse a newly completed block once;
- cache unchanged inline runs and text-source reloads;
- keep the live row explicitly running;
- tighten recovery accounting and add a Gateway drain fallback.

The final completed rendering still uses the authoritative full text and
Markdown table path.
