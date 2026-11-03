# Store review experience research

Date: 2026-11-04

## Existing implementation

- `ProductCapabilities` is selected by the HarmonyOS product target and already
  separates community, store and Mock behavior.
- `StoreShowcaseClient` implements the native Host contract in memory. It
  already provides sessions, workspaces, file browsing and previews, transcript
  states, permissions, plugins, automations and subagents.
- `Index.connect()` currently creates `NativeHarnessClient` and performs a Host
  state request immediately. The review decision must happen earlier.
- `NativeHostSettings` expects a writable `settingsDescribe` document and
  revision-aware `settingsSet` results.
- `NativeHttpError` already carries HTTP status and server error code, while
  `NativeWorkspace.handleError()` owns product-facing error presentation.

## Findings

1. Reusing `StoreShowcaseClient` avoids maintaining a second fake Host protocol.
2. Login activation must occur before network client construction; otherwise a
   store review login attempts an unnecessary remote request.
3. A boolean preference is sufficient to restore the in-process session. The
   credential itself must not be persisted.
4. Settings writes need in-memory revisions. Returning an empty success body
   would make the settings UI appear to save while immediately losing state.
5. Prompt failure should originate as a structured protocol error. A direct
   localized error thrown from the prompt path would bypass the normal client
   error contract.
6. The existing content is already deterministic and broad enough for product
   review. The review mode adds behavior, not a different visual language.

## Risks

- Weak fixed credentials cannot be meaningfully protected from offline password
  guessing. The digest avoids plaintext disclosure in the repository but is not
  a substitute for a production access-control system.
- Persisting review mode must be cleared on logout so the next account flow
  cannot inherit synthetic state.
- Settings revision mismatches must fail instead of silently overwriting a
  newer value.
