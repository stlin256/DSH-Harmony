# Store review experience

Date: 2026-11-04

## Requirement

The AppGallery store product must be reviewable without provisioning a private
DeepSeek Host. A fixed service origin and access credential combination may
enter an in-process product experience that uses the normal native screens and
interaction contracts.

The review path is available only when `ProductCapabilities` belongs to the
store product.

## User-visible behavior

1. The login screen, launch flow and error presentation remain the production
   surfaces. No review, demo, synthetic or fixture label may be visible.
2. A matching login opens a populated native workspace without issuing a
   network request or creating the normal web bridge.
3. Conversations, workspaces, files, previews, settings, notifications,
   permissions, plugins, automations, sessions and subagents use realistic
   deterministic content and remain navigable.
4. Local settings and connected DSH settings can be changed. Selecting a value
   must update the visible control and subsequent reads.
5. Sending a message shows the normal busy state, waits briefly and fails with
   a structured HTTP 402 response code `insufficient_balance`.
6. The UI translates that structured response into a concise balance message.
   The draft remains available for retry.
7. Logout exits the review session and restores the ordinary login flow.

## Security and variant constraints

- The access credential must not be stored in source, tests, docs, logs,
  preferences or commits.
- Authentication matching uses a SHA-256 digest of the normalized origin,
  newline and trimmed credential.
- Community and mock product capabilities must not enable the review path.
- A restored review session may persist only a non-secret boolean preference.

## Verification

This change is compile-gated only by the current request. A device interaction
driver and pending E2E rows are still required so the behavior can be verified
later without reconstructing the test.
