# Store review experience implementation

Date: 2026-11-04

Requirement:
[`2026-11-04-store-review-demo.md`](../requirements/2026-11-04-store-review-demo.md)

## 1. Product capability gate

Add the following fields to every product capability implementation:

```typescript
static readonly supportsStoreReview: boolean
static readonly storeReviewOrigin: string
static readonly storeReviewCredentialSha256: string
```

Only the store product sets `supportsStoreReview=true`, supplies the normalized
HTTPS origin and contains the precomputed SHA-256 digest. Community and mock
products use `false` and empty strings.

The digest input is:

```text
normalized origin + "\n" + trimmed access credential
```

The credential is never stored by the application.

## 2. Login and restoration

`Index.connect()` performs the review decision after origin validation but
before it creates the real `NativeHarnessClient`.

The review path is selected when either:

- the entered credential digest matches; or
- the same review origin is restored and the non-secret
  `storeReviewMode` preference is true.

Activation:

1. Sets showcase state without changing the visual shell.
2. Creates `StoreShowcaseClient('showcase-plan', true)`.
3. Uses the native workspace with keyboard resize behavior.
4. Persists origin, native mode and `storeReviewMode=true`.
5. Does not create `PocketBridge`, fetch cookies or issue a network request.

Logout clears `storeReviewMode`, removes showcase selection, resets caches and
returns to the existing post-logout launch flow.

## 3. Review behavior

`StoreShowcaseClient` gets a constructor `reviewMode` flag. In review mode:

- all existing deterministic native surfaces remain available;
- `prompt()` waits 1200 ms and throws
  `NativeHttpError(402, 'insufficient_balance')`;
- no success message is appended and the caller keeps the draft.

`NativeWorkspace.handleError()` maps this exact status/code pair to
`账户余额不足，请充值后重试`.

Attachment uploads override the inherited transport method. They validate the
session/name, return an in-memory receipt and never create an HTTP task or read
cookies.

Review-visible fixture copy must not identify the experience as Mock, sample,
synthetic or a demonstration. The ordinary product language, session titles,
file contents, plugin inventory and automation history remain in place.

Plugin and automation admin operations mutate the in-process inventory. Enable,
row enable, install, update, remove, create, edit, run, active-state changes and
delete are visible on the next list/detail/history read. Automation edits and
deletes validate `expectedUpdatedAt` and return
`NativeHttpError(409, 'schedule_conflict')` for stale revisions.

## 4. Mutable DSH settings

The client owns current values and per-namespace revisions for:

```text
ui-chat: transcriptView, collapseTiming, foldedReplies
ui-conversation: busyEnter
permission: defaultPreset
```

`settingsDescribe` returns the current values. `settingsSet` validates namespace,
field, value and revision, updates one namespace and returns a complete
`NativeSettingsNamespace` body with the next revision.

Local theme, reduced motion, reduced transparency, notification levels, card
details and background monitoring keep using the existing local settings path.
Reduced motion and transparency update `nativeUserReduceMotion` and
`nativeReduceTransparency` so the current UI responds immediately. Their review
values are isolated from the ordinary persisted experience preferences. Logout
calls `NativeExperience.refresh(context)` after clearing review mode so ordinary
login cannot inherit review theme, motion or material state.

## 5. Testability

Login inputs and the review workspace controls receive stable layout ids. The
pending device driver takes the credential from
`DSH_STORE_REVIEW_ACCESS_KEY`, transfers it through a temporary device file and
types it with a device-side `cat` substitution. The credential never appears in
a process argument, layout dump or artifact. The driver covers entry, settings,
file browsing and preview mode, plugin mutation, automation mutation, local and
in-session DSH settings mutation, local presentation persistence, structured
balance failure with draft retention, cold restore, logout clearing and a second
cold launch that must remain on the ordinary login surface.

Executable contracts verify variant isolation, trigger ordering, the digest
when the external credential is supplied, structured balance failure, mutable
settings revisions, in-memory uploads, mutable plugin/automation catalogs and
credential-safe driver structure. They also exercise a stale settings write so
the device driver does not need an artificial second-client revision race.

This change is compiled for community, store and mock Release variants. Device
execution is intentionally deferred by the current request.
