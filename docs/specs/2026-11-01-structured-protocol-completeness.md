# Structured Protocol Completeness Implementation Spec

Date: 2026-11-01

Status: implementation specification.

## 1. Gateway protocol model

Extend `gateway/src/native-protocol.mjs` without reading or mutating Host
records after normalization.

### Commands

- Normalize `command/run` as a tool-start row with:
  `callId=commandId`, `toolName="slash_command"`, `phase="start"`,
  `text=args`, `eventType=command/run`.
- Normalize `command/done` as a tool-result row with the same call id and tool
  name, `phase="result"`, `text=text`, `failed=(kind!=="success")`,
  `eventType=command/done`.
- Keep the complete event data in `metaRaw` for pure parsing.

### Jobs

- Normalize `job/registered` and `job/settled` to the stable tool identity
  `job_lifecycle`.
- Registration is `phase="start"` and a non-failed running state.
- Settlement is `phase="result"`, failed for `failed` or `killed`, and keeps
  `detail`, `cause`, `producerReported`, timestamps and tool-call references in
  `metaRaw`.
- Use `callId=jobId` for the job row and retain the creating
  `toolCall.callId/rootCallId` inside metadata. A job is not merged into the
  original tool invocation.

### Inbox and deliverables

- Accept `tool-jobs` user messages as `role="background-notice"` with
  `sourceKind="tool-jobs"` and display-only content.
- Continue filtering user-approval, plan-mode, working-directory, subagent and
  other model-only engine notes.
- Normalize `deliverables/presented` as `role="detail"` with
  `eventType`, `callId`, `turn` and serialized event data in `detail`.
- `queueFromInbox` accepts `source.kind=user` and
  `source.kind=tool-jobs`; normalized queue rows retain `sourceKind` and
  `sourceForm`.

## 2. Transcript pairing

`NativeTranscript.ets` owns view-level lifecycle joins.

- A command or job result already present never regresses to running when a
  start record is merged later.
- Merge arguments/name/metadata from starts while retaining a terminal result,
  failure bit and result text.
- `deliverables/presented` rows are collected by call id. After call merging,
  attach the authoritative event payload to the matching `present` tool row.
  The durable detail row is not rendered.
- Background notices are independent rows. They are not grouped as tool
  process, not user-authored and not editable.

Add `NativeMessage.authoritativeRaw` as a serialized, view-safe copy of the
authoritative deliverable event. Existing cache serialization carries it
through normal object serialization.

## 3. Editor classification

Classification accepts both tool name and arguments.

```text
str_replace_editor command=view         -> read
str_replace_editor command=create       -> write
str_replace_editor command=str_replace  -> edit
str_replace_editor command=insert       -> edit
other/unknown                           -> tools
```

For `insert`, Diff generation treats the inserted text as an addition with the
target path. If exact before/after context is absent, counts and path remain
valid and no unchanged content is invented.

## 4. Pure structured parser

Extend `NativeToolStructured.ets` with:

- `command`: slash-command name, args, settled state, success/error, output.
- `jobLifecycle`: job id, kind, label, status, progress, detail, cause,
  producer acknowledgement and creating call ids.
- `plugin`: bounded plugin-view document.
- `media`: bounded generated-media document.
- `present`: authoritative declaration preference.

All result-derived data requires a settled successful tool row unless the
contract explicitly permits running/failed media metadata.

## 5. Plugin-view parser and renderer

### Document shape

The parser produces bounded, non-recursive presentation blocks:

- text;
- metric group;
- progress;
- callout;
- list;
- key/value;
- table;
- chart summary;
- compare;
- steps;
- read-only options;
- image caption/placeholder.

`stack` flattens vertically. `row` groups direct metric children in one compact
metric group; non-metric children flatten with bounded indentation.

### Validation and fallback

1. Require a JSON object root and a known string `type`.
2. Serialize once; reject when UTF-8 JSON bytes exceed 8192.
3. Traverse in source order; stop adding nodes after 40 and ignore nodes deeper
   than 6.
4. Validate each handled component's required scalar/array fields.
5. Ignore unknown attributes, styles, icons, colors and future action effects.
6. Never fetch an HTTP(S) image from a persisted card.
7. Never render interactive `confirm` or `actions`.
8. If the root is malformed, expose `invalid=true` and keep raw fallback.

## 6. Media parser and renderer

- Parse only `meta["dsh-go/media"]`.
- Require `v=1`, valid kind, valid status/default done, and bounded string
  fields.
- Validate item paths and optional positive dimensions, non-negative byte
  counts, finite duration and poster/codec strings.
- A successful done image with no valid items is invalid.
- A failed record remains failed and displays the terminal error when known.
- Render request label/model/aspect/count/quality/resolution seconds, prompt,
  status, items and failure with the shared compact card language.
- Item taps call the existing read-only file opener. Do not auto-fetch bytes in
  the parser. Do not claim inline video playback.

## 7. Background notice UI

Add a compact `background-notice` row:

- semantic job glyph;
- fixed title `后台任务`;
- optional one-line source summary when available;
- expanded display-only body with selection/copy;
- no send, steer, withdraw, Markdown execution or web-link activation.

The row uses shared appearance, spacing, disclosure motion and reduced-motion
policy.

## 8. Tests

Gateway:

- command run/done success and error;
- done-before-run normalization and late-run preservation at transcript level;
- job registration/settlement and inverted order;
- tool-jobs notice visibility while engine notes remain hidden;
- deliverable event normalization and inbox source preservation.

ArkTS services:

- all editor subcommands and insert Diff;
- command and job structured records;
- command/job done-before-run merge;
- authoritative deliverable replaces inferred declarations;
- plugin view valid catalog, unknown future type, malformed root, oversized
  JSON, over-budget and over-depth;
- plugin actions/confirm are non-interactive and options are read-only;
- media valid image/video/running/failed/malformed/oversized;
- raw fallback remains available.

Source contracts:

- `NativeStructuredToolView` wires plugin/media cards.
- `NativeWorkspace` wires background notices.
- all nine `str_replace_editor` paths use the category helper with arguments.

## 9. Build and device gate

Shared ArkUI changes require both `default` and `store` Release builds. Device
E2E remains Pending until a real HarmonyOS device records the matrix.
