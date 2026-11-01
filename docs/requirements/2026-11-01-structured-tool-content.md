# Structured Tool Content Requirement

Date: 2026-11-01

Status: accepted for implementation.

## User-visible problem

The native transcript can identify common tool families, but most expanded
details still present raw arguments or text results. File reads are not shown
as line-addressed source, searches are not grouped by file, terminal calls do
not expose their recorded working directory or process outcome, web results do
not distinguish sources from answer text, and Goal, Job, Subagent and deliverable
records lack a stable structured presentation.

The result is inconsistent density and makes users decode protocol-shaped data
that DeepSeek Harness already exposes with typed meaning.

## Required behavior

- `read` SHALL prefer successful result `meta.path`, `meta.offset`,
  `meta.totalLines`, `meta.lang`, and ordered `meta.lines`. Numbered result text
  is a bounded compatibility fallback. Invalid metadata SHALL fall back to the
  complete generic detail.
- `read_image` SHALL show its recorded path and authoritative image blocks.
  Image attachments SHALL never be inferred from arbitrary output text.
- `grep` and `glob` SHALL expose their pattern and search path. Successful
  structured metadata MAY present file matches, line snippets or paths. Missing,
  malformed, failed or truncated-unknown metadata SHALL retain the complete
  generic result.
- `bash`, `pwsh`, `exec_command`, `write_stdin` and `terminal_*` SHALL expose
  command, recorded working directory, timeout and background state. A strict
  terminal footer MAY expose exit code or signal. A background launch receipt
  SHALL NOT be presented as completed process output.
- `web_search` SHALL expose queries, optional answer text and typed source
  entries. `web_fetch` SHALL expose the requested URL and any strict HTTP status
  record. Only HTTP(S) URLs may receive external-link treatment.
- Goal tools SHALL expose objective, phase, blocker, round count, maximum rounds
  and revision when present. Historical calls SHALL be read-only and SHALL NOT
  replace their recorded state with a newer session projection.
- Job, Subagent, Workflow, Ralph and Skill tools SHALL expose stable IDs,
  labels/descriptions, recorded state and nested-call relationships when the
  record provides them. Unknown state SHALL remain unknown.
- `present` SHALL expose valid declared files in their original order, including
  an optional description. Paths SHALL be shown relative to the known workspace
  when possible while retaining the original target for opening.
- `todo_write`, file diffs, images, approvals and questions SHALL keep their
  existing specialized behavior.
- A parser failure SHALL be presentation-only. It SHALL NOT throw, omit the raw
  input/result, mutate the durable message, re-run a tool or fabricate success.
- Failed, denied, cancelled and interrupted calls SHALL not display successful
  result statistics or completion wording.
- Structured summaries SHALL preserve compact single-line rows and flatten
  embedded newlines.

## Compatibility and privacy

- Target the current DeepSeek Harness wire contract. Do not maintain legacy
  protocol branches that are not required by the current Host.
- Parsed data remains in app memory and the existing encrypted transcript cache.
- No private host, credential, signing value or real transcript is added to
  source, tests, screenshots, logs or documentation.

## Acceptance gate

- Pure parser tests cover valid, absent, malformed, streaming and failed cases.
- Generic fallback remains complete for every unrecognized shape.
- Both `default` and `store` Release variants build.
- Device checks are marked Pending until performed on a real HarmonyOS device.
