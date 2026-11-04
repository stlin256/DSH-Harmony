# Stream and subagent recovery

Date: 2026-11-04

The user reports live replies freezing shortly after starting, recurring reconnect
banners until cold launch, uneven output, and child conversations failing to
load. They request implementation and explicitly replace the upstream reference
with their current local DeepSeek Harness checkout.

- Pin upstream fcc0ad462172522aaf5c93a7b2e01f6b9f0b0159 (0.2.2-rc.1).
- Recover transient connection failures without relaunch or duplicate prompts.
- Distinguish inaccessible history and protocol errors from transient transport
  loss; retain readable content and provide an explicit retry.
- Normal provider silence with a healthy connection must not reconnect.
- Show burst-delivered live text smoothly with bounded display lag. Authoritative
  data must never be paced, discarded, or changed for animation.
- Child history, continuation and stop follow the new upstream contracts.
- Cover cold child opening, parent return, quiet generation, bursts, reconnect,
  reduced motion and themes with synthetic fixtures and current device evidence.
- Never record private endpoints, credentials or real conversation contents.
