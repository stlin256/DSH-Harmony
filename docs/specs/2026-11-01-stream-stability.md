# Stream Stability Implementation Spec

Date: 2026-11-01

Status: implementation specification.

## 1. Strict assistant revision contract

The opening snapshot establishes the revision baseline, including baseline
zero. Every subsequent `start`, `delta` or `end` frame must carry a safe integer
revision equal to `streamRevision + 1`.

- Reject a missing, negative, duplicate or skipped revision.
- A stale delta whose index is below `nextIndex` remains a duplicate only when
  its revision was already consumed.
- `start` replaces the active baseline and resets `nextIndex` to zero only after
  its revision is accepted.
- `delta` requires the active `attemptId` and exact `nextIndex`.
- `end` requires the active `attemptId`, exact terminal index and next revision.
- The normalizer omits malformed assistant frames so the transport can treat
  them as protocol errors rather than feeding incomplete state to the reducer.
- The Gateway closes the current follow generation when an assistant frame is
  malformed. The App retains the visible partial and repairs from a new
  snapshot instead of leaving a healthy socket with a frozen transcript.

Snapshot application remains atomic. It replaces active partial text,
reasoning, tools, attempt identity, revision and next index in one reducer
mutation. Loaded durable history is retained under the existing replacement and
boundary rules.

## 2. Heartbeat contract

The Gateway heartbeat remains an operational frame and is never projected into
the transcript:

```text
type: heartbeat
generation: opaque socket generation
cursor: last durable sequence observed by the Gateway
attemptId: current assistant attempt, or empty
nextIndex: next dense assistant index
revision: current assistant revision
stateKnown: true
running: authoritative connection running state
waiting: authoritative pending-input state
```

The App binds the first heartbeat generation to the current follow generation.
A heartbeat carrying a different generation is stale and cannot refresh live
health. Starting a new follow clears all bound heartbeat progress.

## 3. Three independent health signals

### Link health

Any valid frame, including heartbeat, refreshes `followLinkActivityAt`.
Foreground repair follows 15 seconds without a valid frame; background repair
follows 45 seconds.

### Delivery progress

The App compares the heartbeat tuple

```text
(attemptId, revision, nextIndex, cursor)
```

with the reducer tuple and with the previous heartbeat tuple.

- A changed Gateway tuple proves Host progress and refreshes
  `assistantProgressAt`.
- A reducer tuple equal to the heartbeat tuple proves the view has consumed
  that progress.
- An unequal tuple starts a `deliveryMismatchAt` timer. A mismatch that remains
  stable for 2.5 seconds requests one repair.
- Equal tuples clear the mismatch timer.

### Assistant stall

An active assistant attempt may repair after 12 seconds without a changed
delivery tuple only when all are true:

- `stateKnown` is true;
- `running` is true;
- `waiting` is false;
- `attemptId` is non-empty.

An empty attempt is an ordinary tool/control gap. A waiting state is an
approval or question pause. Neither starts an assistant-stall repair.
Background uses 38 seconds for the same active-attempt check.

## 4. Repair behavior

The health loop runs every 2.5 seconds while foregrounded and 5 seconds while
backgrounded. It computes the earliest applicable deadline and starts at most
one `reconnect(id)`.

Repair:

1. clears the current follow timers;
2. preserves cached durable rows and the visible partial;
3. invalidates the old local socket generation;
4. opens one new follow generation;
5. accepts its opening snapshot as the new progress baseline;
6. resets retry/error state only after the snapshot is applied.

Repeated failures continue through the existing capped exponential backoff.
Late frames from the old socket cannot affect the selected session.

The App may log only the repair category (`link_timeout`,
`assistant_progress_timeout` or `delivery_mismatch`) and numeric metadata. It
must not log transcript content, tool arguments or credentials.

## 5. Visual cadence and cache pressure

- Apply every socket frame synchronously in `NativeSessionModel`.
- Coalesce text-only assistant paints at 32 ms, matching the reference cadence.
- Continue to use 64 ms while direct scroll motion is active.
- Non-delta structural frames publish without an additional timer.
- Streaming text receives no entrance animation.
- Full transcript cache snapshots are not written on every streamed paint. The
  existing 500 ms quiet-window scheduler remains, but a changed streaming frame
  postpones it. This keeps cache serialization away from a busy frame loop.

## 6. Automated tests

- Missing, zero-after-baseline, duplicate and skipped assistant revisions are
  rejected; dense revisions from a zero baseline are accepted.
- Heartbeats alone refresh link health but do not refresh assistant progress.
- A changed heartbeat tuple refreshes progress.
- A stable heartbeat/reducer mismatch requests exactly one repair.
- An active running attempt with unchanged progress requests repair at the
  foreground threshold.
- Tool gaps (`attemptId` empty) and waiting states do not request repair.
- Starting another follow invalidates old heartbeat generation state.
- Text-only paint coalescing is 32 ms and remains 64 ms during direct scroll.
- Existing durable `seq`, snapshot replacement, committed settlement, partial
  preservation and capped backoff tests remain green.

## 7. Build and evidence gate

This changes shared ArkUI code, so both `default` and `store` Release variants
must build. Device E2E remains pending until evidence is captured.

## 8. Long-stream follow-up

The 2026-11-02 physical-device report showed that transport health alone is not
enough to prevent a visual freeze. Incremental Markdown block rendering,
explicit live-row state, reducer-tuple progress accounting and Gateway drain
fallback are specified in
[`2026-11-02-long-stream-render-liveness.md`](2026-11-02-long-stream-render-liveness.md).

