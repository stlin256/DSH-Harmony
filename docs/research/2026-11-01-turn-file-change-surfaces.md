# Turn file-change surfaces research

Date: 2026-11-01

## Upstream baseline

The pinned upstream revision is
`f3803c96974ad4a94195fb97e5c637e9c2a3afe3`
(`0.2.2-alpha.2`). Relevant behavior is documented in
[`upstream-chat.md`](upstream-chat.md):

- `write`/`edit`/`apply_patch` records are successful only when the tool
  lifecycle is settled and the result is not failed, interrupted or denied.
- The preferred diff source is explicit `meta.diffs`, patch or
  `oldText/newText` data. Output prose is not evidence of a file mutation.
- `turn/end` owns turn completion and the transcript's turn-tail actions.
- `packages/client/ui-chat/src/client/chat/TurnTailNodeView.tsx` places
  turn-local actions in one tail. It does not itself invent file totals.

The official UI is a useful placement and ownership reference. Aggregating all
file mutations into a native per-turn card and live composer-adjacent control
is a DSH Harmony mobile extension and must not be presented as unchanged
upstream UI.

## Current native data path

1. `gateway/src/native-protocol.mjs` normalizes durable `tool/call`,
   `tool/result` and `turn/start`/`turn/end` events while retaining call
   identity, raw arguments, result/meta/content and turn/step numbers.
2. `NativeSessionModel.ets` pairs call and result rows by `callId`, preserves
   streamed tool arguments, tracks settlement and persists the projected
   transcript.
3. `NativeTranscript.ets` groups completed operations into process rows and
   emits one `turn-footer` for `turn/end`.
4. `NativeDiff.ets` already parses explicit `diffs`, patch/text diff and
   `oldText/newText` fields. It returns line rows plus added/removed counts and
   refuses failed, interrupted, denied and arbitrary-looking output.
5. `NativeToolCallView.ets` currently renders one file-mutation diff inside its
   individual operation view.

The missing layer is not transport data. It is a deterministic turn projection
that walks successful edit/write operations, separates multi-file diff rows by
path, deduplicates repeated paths and accumulates a stable summary.

## Plugin assessment

The official stopped-turn summary requires a narrow gateway bridge:

- Upstream appends a log-only `workspace/changes { turn }` event and keeps the
  actual summary on the Host, addressed by that event's sequence.
- The authenticated routes are `GET /api/changes.summary?sessionId=&seq=` and
  `GET /api/changes.diff?sessionId=&seq=&index=`.
- The summary includes Git and command-driven changes that are absent from
  individual tool arguments, plus complete totals. Its public projection omits
  the Host cwd and snapshot ids.
- The native client authenticates to the DSH Harmony gateway, not directly to
  the Host cookie. The gateway therefore adds a read-only
  `/pocket/api/native/changes/summary` bridge and validates the JSON shape
  before forwarding the public fields.

The running pill remains a local projection of successfully settled explicit
`write`/`edit`/`apply_patch`/mutating `str_replace_editor` results because DSH
does not publish a live per-turn Git summary. The completed card replaces that
fallback with the official summary when available. A 404 or unsupported route
keeps the tool projection, so older compatible Hosts remain usable.

No additional upstream session event or command-driven journal payload is
needed. File rows continue to open through the existing read-only workspace
file operation.

## Projection semantics

- Process only projected tools whose exact category is `edit` or `write`.
- Require a settled successful tool result.
- Run the existing `nativeDiff()` parser as the single source of truth.
- Split a combined diff document on `path` rows so one apply-patch call can
  contribute several files.
- Normalize slash direction for identity, preserve the Host path for opening,
  and use a case-sensitive path key because Host filesystems may be
  case-sensitive.
- Merge repeated edits by first appearance. Sum their line totals.
- Preserve first-seen file ordering and call order.
- A turn summary exists only when there is at least one file.
- Running means a live turn has no matching `turn/end`. Historical rows without
  a loaded footer are not enough to show the live control; the workspace also
  requires the session's current running/waiting state.

## Composer composition

The current composer measures its own height and positions the attachment strip
with a translated overlay. That makes independent overlays fragile. The safer
model is a natural vertical stack measured as one bottom dock:

```text
floating return-to-bottom control
live turn-change pill
attachment strip
composer
safe-area inset
```

Only the natural bottom stack consumes layout height. The live pill, attachment
strip, composer and safe-area inset form that stack. The return control remains
an independent overlay immediately above it and does not add a permanent
spacer. The dock surface extends to the full window width while its content
keeps the existing 12vp reading inset. API 26 material is a progressive
enhancement; API 23 uses the theme surface.

## Bottom material and row-measure refinement

ArkUI's `BlurStyle.Thin` is a window-oriented material and its built-in mask can
read as a solid strip when the Dock has nontrivial height. The component
materials provide the same hierarchy with less mask weight. The Dock therefore
uses `COMPONENT_ULTRA_THIN`, gradient foreground blur and a separate transparent
to bounded-alpha theme scrim. The scrim creates the visible vertical falloff
without replacing the backdrop with an opaque color.

For changed-file rows, assigning layout weights to both directory and filename
reserves columns by proportion rather than by useful content. A short filename
can therefore leave a large blank column while the directory truncates early.
The row instead measures the filename and fixed metrics first and lets the
directory shrink against actual overflow. This preserves the workspace-relative
path and filename priority without introducing a blank spacer.

