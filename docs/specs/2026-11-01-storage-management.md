# Local Storage Management Specification

Date: 2026-11-01

## Data model

`NativeStorageUsage` reports logical retained payload bytes:

- `conversation`: transcript manifest bytes plus legacy transcript rows not
  superseded by a manifest;
- `fileBrowser`: validated workspace directory-list payloads;
- `fileContent`: workspace text and binary preview bytes;
- `imageAttachments`: app-private attachment image files;
- `navigation`: stored session, workspace and local interaction metadata;
- `total`: the validated sum of all categories.

Logical payload bytes describe retained content consistently across encrypted
relational-store rows and files. They intentionally exclude SQLite page,
free-list and encryption overhead.

## Cache usage APIs

Cache owners expose read-only scope accounting:

- `NativeTranscriptCache.usageScope(context, scope)`
- `NativeWorkspaceCache.usageScope(context, scope)`
- `NativeAttachmentCache.usageScope(context, scope)`
- `NativeMetadataCache.usage(context, origin)`

Each API uses the existing one-way authenticated cache scope. Usage queries do
not refresh `updated_at`, so opening Storage Management does not perturb LRU
eviction order.

## Aggregation and clearing

`NativeStorageManager` is the only Settings-facing coordinator.

`usageScope` opens the existing encrypted stores, reads all category totals and
returns a new `NativeStorageUsage`. A required query failure rejects the whole
read so the UI never presents a partial total as complete.

`clearScope` runs the existing cache owners in this order:

1. navigation metadata;
2. conversation transcripts;
3. workspace directory and file content;
4. image attachments.

Every owner receives the same current scope. Owners run even if a previous
owner fails; the coordinator reports failure only after the remaining work
completes. A clear does not call Host APIs, logout helpers or connection reset.

`nativeFormatStorageBytes` formats non-negative finite values with B, KiB, MiB
and GiB labels. Invalid input formats as `0 B`.

## UI

The Settings root adds a `存储管理` row under `应用` using the existing
compact list and `archive-outline` glyph.

The secondary page uses the shared left-back navigation header and DSH surface
colors. It contains:

- one total summary surface with a loading indicator;
- one grouped breakdown surface for the five usage categories;
- one transparent action surface with red `清空缓存` text;
- inline error text only when loading or clearing fails.

Opening the page starts one usage read. Repeated opens reuse the latest value
and refresh it. The action opens `showAlertDialog`; only the destructive
secondary button calls the clear operation. While clearing, the button is
disabled and shows a progress indicator. Success assigns the refreshed usage
without toast or success copy. Failure leaves previous values visible and shows
`缓存清理失败，请重试`.

Breakdown rows pass stable field keys to their ArkUI builder and resolve the
latest number through component state when rendered. Passing pre-read numeric
arguments into a builder is prohibited because ArkUI may keep those parameters
stale after the aggregate state object is replaced.

All state changes use the existing semantic micro/navigation motion tokens.

## Verification

- Model tests cover byte formatting boundaries and total aggregation.
- Source-contract tests verify accounting, clear coordination, current-scope
  use, red confirmation UI and absence of success feedback.
- Both Release product variants must build after implementation.
- The community Release HAP is installed on the connected device.
- Device E2E records usage display, confirmation cancellation, successful
  clear, retained login and retained Host content.
