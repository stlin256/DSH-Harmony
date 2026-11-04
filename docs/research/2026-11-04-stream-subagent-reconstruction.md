# Stream reconstruction research

Date: 2026-11-04

Reviewed the clean local upstream checkout at
`fcc0ad462172522aaf5c93a7b2e01f6b9f0b0159`, root package 0.2.2-rc.1.
The local release tag dsh-v0.2.2-rc.1 resolves to
`66491b05e3f05ad35bcdd4f6cd7ed26041d9e3db`.

Compared with the previous ce7073d baseline:

- session-controller/src/types.ts and history/listener.ts now publish one
  projection change per event as `changes: [{ key, val }]`. Control uses the same
  batch format. Every key at the same sequence must be applied.
- subagent/src/control-types.ts removes parentSessionId and mode from the human
  prompt request. session-controller/src/client/sessions/session.ts calls
  `subagents/interruptByUser(childSessionId)` and removes parent-availability
  gating. History addresses remain parent/child/mode; WebController follow still
  validates the durable address before yielding its opening snapshot.
- Assistant baseline/revision and history pagination contracts are unchanged in
  the reviewed files. Keep dense revision and event-sequence validation.

Current native defects/risks:

- A direct invocation of nativeStreamHealthRepairReason reproduces an assistant
  timeout after 12 seconds despite a fresh heartbeat. Provider silence is not
  evidence of a broken transport. Heartbeats also postpone the pre-snapshot
  activity deadline; opening needs an independent deadline.
- Gateway history errors discard their codes and classify nearly everything as
  retryable. Client callbacks conflate handler errors and disconnections.
- Reconnect's authentication await is guarded by session ID, which is not an
  epoch and does not reject A/B/A navigation or a newer follow of the same ID.
- NativeTextContent consumes complete coalesced text without a presentation
  clock. Reasoning/tool updates may rebuild history, while automatic history
  paging and cache work compete with active generation.
- Existing Mock tests bypass actual Host address validation and NetworkKit.
  Their passing results are not evidence that the user's live failure is fixed.

Read-only device log inspection found no retained dedicated failure reason for
the reported occurrence. Do not assert a uniquely confirmed live root cause.
