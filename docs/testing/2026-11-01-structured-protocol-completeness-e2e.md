# Structured Protocol Completeness E2E

Device evidence is required. Parser tests and builds do not prove final layout,
navigation or system behavior.

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| PROTO-STRUCT-01 | Load a command run/done pair normally | One compact slash-command row shows command, settled status and output | Pending |
| PROTO-STRUCT-02 | Load a page where command/done is present before an older command/run | The row stays finished and does not regress to running | Pending |
| PROTO-STRUCT-03 | Expand a failed slash command | Error state and bounded result remain distinct from shell-tool failure | Pending |
| PROTO-STRUCT-04 | Trigger a background job, then let it settle | One job row shows kind, label and terminal status; late registration cannot reopen it | Pending |
| PROTO-STRUCT-05 | Receive a `tool-jobs` completion notice | Quiet read-only background notice is visible and cannot be sent, steered or withdrawn | Pending |
| PROTO-STRUCT-06 | Expand `str_replace_editor` `view`, `create`, `str_replace`, `insert` | Read/write/edit counts and Diff semantics follow the subcommand | Pending |
| PROTO-STRUCT-07 | Expand a successful plugin view using text, metric, list and progress | Read-only native card follows light/dark theme and remains compact | Pending |
| PROTO-STRUCT-08 | Open plugin view containing confirm, actions, options and an HTTP image | Controls are non-interactive, selected options are readable, no HTTP image is fetched | Pending |
| PROTO-STRUCT-09 | Open malformed or oversized plugin view | Compact invalid state appears and complete raw arguments/result remain available | Pending |
| PROTO-STRUCT-10 | Expand generated-image media metadata | Request facts, status, prompt and items appear; each file opens read-only | Pending |
| PROTO-STRUCT-11 | Expand running, failed and empty-done media metadata | Running/failed remain truthful; empty done media falls back safely | Pending |
| PROTO-STRUCT-12 | Expand generated-video metadata | Metadata and files are visible without claiming inline playback | Pending |
| PROTO-STRUCT-13 | Reopen a conversation with a `present` tool and its authoritative event | One authoritative deliverable set appears with no duplicate declared files | Pending |
| PROTO-STRUCT-14 | Open delivered files from the card | Existing multi-level read-only file stack opens and returns correctly | Pending |
| PROTO-STRUCT-15 | Stream lifecycle rows preparing through result | Identity stays stable; no repeated row, flicker or token entrance animation | Pending |
| PROTO-STRUCT-16 | Repeat all cards in light/dark and reduced-motion modes | Text, controls, states and surfaces follow tokens; essential disclosure remains usable | Pending |
| PROTO-STRUCT-17 | Build both Release products | `default` and `store` build, sign and contain shared ArkUI changes | Pending |

## Evidence to record

- Device model, HarmonyOS/API version, HAP variant and version.
- Screenshots for command, job, background notice, editor subcommands, plugin
  card, plugin fallback, generated image/video and authoritative present.
- Tap path for file opening and back-stack return.
- A short recording for streamed lifecycle transitions.
- No private host, credential, real transcript, workspace path or notification
  content.

## Automated verification (2026-11-01)

- Gateway and ArkTS service contracts: `178/178` tests passed.
- Personal Release build and signing: passed.
- Store Release build and signing: passed.
- Static source contracts verify plugin/media cards, read-only background
  notices, non-editable `tool-jobs` queue rows, editor subcommand
  classification and insert diff generation.

The device rows above remain `Pending`; compilation and service tests are not
recorded as device evidence.
