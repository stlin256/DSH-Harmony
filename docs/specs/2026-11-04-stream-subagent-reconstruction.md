# Stream reconstruction implementation

Date: 2026-11-04

## Contracts and recovery

Update protocol.lock and owning references to the reviewed rc.1 checkout. Adapt
projection batches atomically after validating their complete shape, retaining
per-key sequence guards. Align child prompt and interrupt contracts; retain
durable browsing addresses. Legacy single-key projection input may be accepted
as a compatibility adapter, but the canonical tests use the new batch.

Introduce a pure recovery policy owning follow epochs, opening/link deadlines,
retry admission and bounded backoff. Retire the socket before authentication or
retry waits. Every async completion must match its epoch, including same-ID
reopening. A healthy heartbeat never causes a provider-progress timeout. Repair
only observed delivery divergence, missing opening, missing settlement or dead
link. Stop automatic retries for explicit permanent history/protocol failures;
bound repeated transient failures and expose manual retry. Publish only
allowlisted error codes, never Host messages or details.

## Presentation

Keep NativeSessionModel authoritative. A separate pure presentation cursor
consumes append-only live text, adapts release rate to arrival cadence and backlog,
and converges within a bounded interval after the last append. Never split a
UTF-16 surrogate pair. Snapshot/replacement, completed content, reduced motion
and component teardown cancel obsolete presentation work. Completed historical
content is immediate. Incremental Markdown consumes displayed prefixes, while
copy/cache retain the full authoritative text. Use a semantic streaming cadence.

Defer automatic older-history paging during active generation and resume on idle;
manual history requests remain functional. Avoid whole-history cache serialization
on every live pause. Preserve immutable completed blocks and existing row IDs.

## Verification

Model/policy tests: quiet healthy connection, absolute opening deadline, stale
epochs, bounded retries, terminal error classification, Unicode burst pacing,
replacement, completion and reduced motion. Gateway tests: current projection
batches, child prompt/stop, child history error preservation and stream recovery.

Register deterministic Mock scenes and an interaction driver for quiet/burst
streaming and child unavailable/retry/return. Verify dark/light, reduced motion,
long stream and child send/navigation on the connected phone using the final
Mock HAP. Update the central device ledger including all unproven live Host and
API 23 cases. Run mock coverage, PR QA and default/store/mock builds. No release
qualification from Mock-only evidence.
