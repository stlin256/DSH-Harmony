# Structured Protocol Completeness Requirement

Date: 2026-11-01

Status: accepted for implementation.

## User-visible problem

The first native structured-tool pass covers common filesystem, terminal, web,
goal, agent and deliverable records. Current DeepSeek Harness also emits
structured command, background-job, inbox-notice, plugin-card and generated
media records. Several of those are currently dropped, flattened into generic
tool rows, or can regress from a completed state to running when their paired
events arrive out of order.

The native client must parse the remaining structured wire content without
losing the complete generic fallback.

## Required behavior

- `str_replace_editor` SHALL classify `view` as a read, `create` as a write,
  and both `str_replace` and `insert` as edits. The editor path SHALL be the
  stable target. Invalid or unknown subcommands SHALL remain generic.
- `command/run` and `command/done` SHALL fold by `commandId`. A result that is
  already known SHALL remain settled when its earlier run is loaded later.
  Success, error, slash-command name, arguments and result text SHALL remain
  visibly distinct from shell tools.
- `job/registered` and `job/settled` SHALL fold by `jobId`. The row SHALL expose
  kind, label, status, progress when represented, terminal detail, start/finish
  time and the creating call relationship when known. A settlement SHALL not
  be overwritten by a late registration record.
- `user/message` records whose host source is
  `{kind: "tool-jobs", form: "notice"}` SHALL remain visible as a quiet,
  read-only background-task notice. Repeated JSON in a human-authored source
  SHALL not impersonate that source.
- A successful tool result with bounded structured-view metadata SHALL render
  a read-only plugin card. The parser SHALL enforce an 8 KiB JSON budget, 40
  nodes and depth 6. `confirm` and `actions` SHALL not become interactive in a
  historical tool card. `options` SHALL be shown as read-only selected values.
  Unknown types, attributes, icons, colors and future components SHALL degrade
  without breaking the surrounding row or claiming success.
- A tool result with valid generated-media metadata v1 SHALL expose generated
  image/video metadata: stable request id, job id, status, request facts,
  prompt, items, failure and provenance when present. A completed image with no
  items is invalid. Failed media remains failed. Files open through the
  existing read-only workspace file stack. Video playback SHALL not be claimed
  unless a player exists.
- `deliverables/presented` SHALL be treated as the authoritative declaration
  for its `{turn, callId, files}`. Valid files SHALL replace, rather than
  duplicate, declarations inferred from the matching successful `present`
  tool call.
- `tool-jobs` notices waiting in the host queue SHALL retain their source kind
  and remain display-only. They SHALL not be editable, steerable, withdrawable
  or rendered as a human prompt.
- Malformed structured metadata SHALL be presentation-only. The complete raw
  arguments, result and error remain available. The parser SHALL not throw,
  mutate durable records or fabricate success.
- Typed rendering SHALL follow the existing compact DSH visual language,
  light/dark tokens, semantic glyphs, reduced motion and accessibility rules.
- Host timestamps SHALL not be rendered as local labels until their timezone
  semantics are proved. They remain available to data contracts for ordering.

## Compatibility and privacy

- Target the current DSH 0.2.1 event shapes and the supported structured
  compatibility contracts used by current Hosts.
- Do not copy another client's source, assets, copy or implementation text.
- Do not add private hosts, credentials, signatures, real transcripts or
  private screenshots to source, fixtures, docs or commits.

## Acceptance gate

- Gateway tests cover command pairing, done-before-run, job lifecycle merging,
  source filtering, inbox notices and authoritative deliverable records.
- Pure parser tests cover all editor subcommands, valid/invalid/bounded plugin
  views, valid/invalid/failed media and authoritative present declarations.
- Source-contract tests prove typed cards are wired with raw fallback.
- Both `default` and `store` Release variants build.
- Device E2E remains Pending until performed on a real HarmonyOS device.
