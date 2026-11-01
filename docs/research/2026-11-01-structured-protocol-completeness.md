# Structured Protocol Completeness Research

Date: 2026-11-01

## Reference boundary

The review covers DeepSeek Harness packages `@deepseek-ai/dsh-jobs`,
`@deepseek-ai/dsh-session` and `@deepseek-ai/dsh-tool-jobs` at
`0.2.1-rc.4`, plus common mobile information-hierarchy and fallback patterns.
No external client source, comment, asset or prose is copied into DSH Harmony.

## Current-gap audit

| Area | DSH behavior | DSH Harmony gap before this change |
| --- | --- | --- |
| `str_replace_editor` | `view` reads, `create` writes, `str_replace` and `insert` edit | Every subcommand counted as an edit; `insert` had no Diff |
| slash commands | Durable run/done pair, command id identity, success/error and output | Each event became a generic tool row; late run could regress a finished row |
| jobs | Log-only registration and settlement share `jobId`; settlement includes terminal status/cause/detail | Both events were dropped |
| background inbox | `tool-jobs` is an independent read-only notice | Non-user source was filtered out |
| plugin card | Successful result structured-view metadata, strict bounded read-only renderer | Metadata was ignored |
| generated media | Result generated-media metadata v1 uses workspace files | Metadata was ignored |
| delivered files | `deliverables/presented` is an authoritative event per successful `present` call | Only inferred tool arguments were used |

## Exact contracts

### Slash commands

```json
{"type":"command/run","data":{"commandId":"cmd-1","name":"compact","args":"","source":{"kind":"user"}}}
{"type":"command/done","data":{"commandId":"cmd-1","kind":"success","text":"Compacted 9 messages."}}
```

The done record has no command name. The pair must merge by `commandId`, and
`kind` is authoritative for success/error. A loaded result must survive an
older run record arriving later.

### Jobs

`JobRegisteredData` fields:

```text
jobId: non-empty string
owner: session id
kind: non-empty string
label: string
startedAt: epoch milliseconds
toolCall?: { callId, rootCallId }
```

`JobSettledData` repeats those fields and adds:

```text
finishedAt: epoch milliseconds
status: completed | killed | failed
cause: producer | kill | teardown
producerReported: boolean
detail?: string
```

These are log-only session events. They can be paired without pretending that
the job output stream is embedded in the event.

### `tool-jobs` inbox source

The Host creates a `user/message` with:

```json
{"kind":"tool-jobs","form":"notice","summary":"bounded one-line summary"}
```

Its content is a bounded completion notice such as
`background job <id> (...) finished ...`. It is host-authored, display-only
context, and not a human prompt.

### Plugin view v1

The tool result carries bounded structured-view metadata. For persisted tool
cards:

- maximum JSON: 8 KiB;
- maximum nodes: 40;
- maximum depth: 6;
- no data model and no invoke actions;
- tool cards are read-only, including `confirm` and `actions`;
- `options` may show their selected value but cannot change it;
- HTTP(S) images are not fetched for tool cards; malformed media is ignored;
- malformed root becomes a compact invalid-card state while raw args/result
  remain available.

The v1 semantic catalog verified from the shared schema is:

`stack`, `row`, `text`, `metric`, `chart`, `compare`, `steps`, `callout`,
`options`, `confirm`, `list`, `keyValue`, `progress`, `table`, `actions`,
`image`.

Future v2 components and unknown attributes are non-fatal. An older renderer
ignores unsupported presentation instead of rejecting the whole transcript.

### Generated media

Root contract v1:

```text
v: 1
rid?: string
kind: image | video
status?: running | done | failed   (absent means done)
job?: string
items: [{
  path, mime?, width?, height?, bytes?, duration?, poster?, codec?
}]
request?: {provider, model, label, aspect, n, quality, seconds, resolution, refs}
prompt?, revisedPrompt?, cost?, provenance?, error?
```

Strict rules used by the reference:

- a done media record with no items is invalid;
- failed records stay failed even with empty items;
- malformed optional fields do not become fabricated facts;
- generated files are opened through the workspace read-only APIs;
- poster paths are alternatives for display, not proof that the original video
  can play on HarmonyOS.

### Authoritative deliverables

`deliverables/presented` carries:

```json
{"turn":1,"callId":"call-id","files":[{"path":"...","description":"..."}]}
```

The turn must be a positive integer, `callId` must be non-empty and `files`
must be a list. Invalid file entries are skipped while valid entries retain
their original order. Re-declaration keeps the first path position and the
latest description.

## Design decisions

- Keep gateway lifecycle correctness separate from ArkTS presentation.
- Use stable host ids (`commandId`, `jobId`, `callId`) for pairing.
- Preserve raw records in cache and runtime. Structured parsing is a view
  projection only.
- Render the supported v1 plugin semantics as compact native blocks. Do not
  execute actions or fetch arbitrary plugin images.
- Render media metadata as a read-only card. Image items open the existing file
  viewer; video items remain file entries until a real player is implemented.
- Do not show absolute epoch times with a guessed locale/timezone.
