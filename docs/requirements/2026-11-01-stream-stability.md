# Stream Stability Requirement

Date: 2026-11-01

Status: accepted for implementation.

## User-visible problem

Native chat can show part of an assistant response and then stop updating while
the task continues remotely. Reopening the app loads the completed response,
which proves that the missing data remains available from the Host and the App
has lost or stopped applying the live continuation.

The client must remain attached to an active response without requiring a cold
launch. A reconnect must preserve the visible partial answer until the
authoritative snapshot is ready. Connection repair copy stays concise and does
not expose protocol details.

## Required behavior

- A live follow generation starts with an authoritative snapshot.
- Durable events are applied only in contiguous `seq` order.
- Assistant frames use dense, strict `revision + 1` continuity, including when
  the opening snapshot revision is zero.
- A gap, retired generation, or heartbeat/delivery mismatch starts one bounded
  snapshot repair. It must not start parallel sockets or a reconnect storm.
- Heartbeats prove that the transport is alive. They do not by themselves prove
  that assistant text is still being delivered.
- When the Host reports a running active attempt and heartbeats keep arriving
  without any new assistant or durable progress, the client performs one
  conservative snapshot repair. Legitimate approval, question and tool waits
  must not be treated as a stalled assistant stream.
- Partial text, reasoning and tools survive repair. A fresh snapshot replaces
  them atomically only after the active attempt identity is accepted.
- Visual publishing may be coarser than protocol application. Protocol frames
  remain synchronous; bursts are coalesced to reduce main-thread pressure.
- The behavior targets the current DSH contract only.

## Out of scope

- Automatically resending a prompt whose acceptance is uncertain.
- Treating every quiet period as a network failure.
- Copying another client's source or assets. Compatibility research is limited
  to protocol and recovery design.

