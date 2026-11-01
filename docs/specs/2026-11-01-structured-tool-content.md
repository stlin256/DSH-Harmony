# Structured Tool Content Implementation Spec

Date: 2026-11-01

Status: implementation specification.

## 1. Pure parser boundary

Add `NativeToolStructured.ets` as an ArkUI-independent service. Its only input
is a projected `NativeMessage` after call/result merging. It returns a
presentation document and never mutates the message.

The document exposes:

- family and valid-record state;
- compact one-line summary and whether it is code;
- recorded file/working-directory path;
- typed read window;
- typed search matches;
- terminal facts;
- web facts and sources;
- Goal/Job/Subagent facts;
- ordered `present` deliverables;
- generic fallback need.

Every parser catches parse failure and returns either a valid summary-only model
or an invalid specialized model. Raw `args`, `output`, `metaRaw`, content blocks,
images and errors remain untouched.

## 2. Shared parsing rules

- Parse complete arguments only when the JSON root is an object.
- While arguments are incomplete, extract only a closed string value for a
  known scalar key. Never infer nested structures from partial JSON.
- Parse `metaRaw` only when it is a JSON object.
- Require positive safe integers for line numbers, offsets, byte/status counts
  and dimensions where zero is not meaningful. Non-negative integers are used
  for counts that may be zero.
- String values are trimmed only for validation and summaries. Display text
  keeps meaningful internal whitespace and newlines.
- Result-derived structured views require a settled successful call. Argument
  summaries may appear while preparing/running.
- Failed, denied, cancelled and interrupted calls bypass success statistics.
- One-line summaries collapse whitespace and cap at 160 UTF-16 code units using
  the existing native preview policy.

## 3. Family contracts

### Read

Arguments read `file_path` or `path` and optional positive `offset` / `limit`.
Successful metadata may provide:

```text
path: string
offset: positive integer
lang: string
totalLines: non-negative integer
lines: [{ number: positive integer, text: string }]
```

Line numbers must be strictly increasing. When the object is valid, render
source with the first recorded line number and metadata. If absent, parse only a
contiguous leading or clearly bounded run of `N: text` lines from the result.
Otherwise use generic detail.

### Read image

Use `meta.path`, then argument path, for the recorded file. Image content comes
only from `message.images`. Expose media type, dimensions and byte size when the
normalized attachment provides positive values.

### Search

`grep` accepts non-empty `pattern`, optional `path`, and a string `include`.
`glob` accepts non-empty `pattern` and optional `path`.

Successful search metadata may use either:

```text
paths: string[]
```

or:

```text
matches: [{
  path: string,
  matches: [{ lineNumber: positive integer, line: string }]
}]
```

Optional `total` is non-negative and `truncated` is boolean. All entries used by
the specialized view must validate. A malformed entry invalidates the result
shape and the complete generic output remains available.

### Terminal

Supported names are `bash`, `pwsh`, `exec_command`, `write_stdin`,
`terminal_send`, and other `terminal_*` names. Parse:

- `command`
- `cmd`
- `workdir`
- `cwd`
- `timeoutMs`
- `run_in_background`
- `sessionId`
- `job_id` / `jobId`

Successful result facts may come from `meta.cwd`, `meta.exitCode`,
`meta.signal`, `meta.truncated`, and `meta.jobId`. Without metadata, only an
exact legacy footer is accepted for exit code or signal. A background launch is
shown as started, not completed.

### Web

For `web_search`, accept `query` or a non-empty string array `queries`.
Successful metadata may provide:

```text
truncated: boolean
sources: [{ url, title?, snippet?, publishedAt? }]
answer?: string
```

For `web_fetch`, accept a non-empty requested `url`. Successful metadata may
provide a non-empty source/result `url` and an integer `statusCode`. Only parsed
HTTP(S) URLs receive link styling.

### Goal

Goal calls are `create_goal`, `update_goal`, and `get_goal`. Parse objective,
phase/status, blocker message, rounds, max rounds and revision when present in
arguments, metadata or a strict JSON result. A human-readable exact Harness
result may fill the same fields. Historical records are read-only.

### Job and agent families

Job calls parse stable ID, state, command, exit code/signal and truncation.
Subagent-family calls parse child ID from `meta.subagentId`, `agent_id` or an
exact `started subagent <id>` result. Display description/prompt/name and known
state. Child calls remain nested by the existing transcript tree.

Workflow, Ralph and Skill calls expose their stable name/label, description,
state and run/child counts when present.

### Present

Accept only successful `files` arrays. Each valid entry is an object with a
non-empty string `path` and an absent or string `description`. Invalid entries
are skipped while valid entries retain their original order. Resolve display
against the session workspace; use the original/absolute path as the read-only
open target.

### Questions and plan

Existing question interaction and `todo_write` plan models remain authoritative.
The structured service may expose their compact summary but does not replace
their controls or plan diff.

## 4. Generic fallback

The fallback MUST display the complete original arguments and complete result
content through the existing text/rich-content and image components. A parser
failure MUST NOT show an empty successful card.

Specialized views may omit raw arguments only when all displayed information is
derived from the same valid record and the generic inspection remains available
for unknown or malformed optional data. For this iteration, specialized rows
show typed facts first and retain raw output when the structured shape cannot
represent all result content.

## 5. UI integration

- `nativeToolDetail()` delegates compact summary selection to the structured
  service, with the old scalar extraction retained only as the generic tail.
- `NativeToolCallView` renders typed metadata/content for known families and
  keeps the current raw-detail path as fallback.
- Paths in `read`, `present`, search results and image records are workspace
  relative where the caller knows the workspace root and open through the
  existing read-only file-view stack.
- No streaming token receives an entrance animation.
- Structured updates reuse current disclosure and list identity.

## 6. Tool-group summaries

Group and process previews count families rather than listing repeated labels:
commands, edited files, read files, searches, web, agents, plans and other.
Read and edited files de-duplicate by normalized path. Failed, denied and
cancelled file calls do not claim that a file was read or changed.

## 7. Tests

Pure service tests must cover:

- read line metadata and numbered-text fallback;
- read invalid line objects falling back safely;
- search paths, grep file matches and malformed metadata;
- terminal args, cwd, exit code, signal and background receipt;
- web query/source/status shapes and invalid URLs;
- Goal, Job, Subagent, Skill, Workflow and `present` records;
- failed calls never producing success-only facts;
- unknown tools and malformed JSON preserving generic detail;
- workspace-relative present display with original open target.

Source-contract tests must confirm the typed view and generic fallback are both
wired into `NativeToolCallView`.

## 8. Build and device gate

Shared ArkUI changes require both `default` and `store` Release builds. Device
E2E remains Pending until a real-device pass records the matrix in the E2E file.
