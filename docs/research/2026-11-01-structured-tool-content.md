# Structured Tool Parsing Research

Date: 2026-11-01

## Reference and boundary

The DSH wire contracts and common mobile tool-card patterns were reviewed to
validate semantics, fallback behavior and information hierarchy. No external
client source, assets or implementation text is copied into DSH Harmony.

## Overall model

The compatibility model first joins preparing, running and result records by
stable `callId`. Arguments are decoded into typed fields while a call is
running. Result `meta` and content blocks are parsed only for the exact tool
family. A valid specialized model can then choose summary, parameters, source
window, Diff, images, controls and output. Anything incomplete or ambiguous
returns to a generic detail that keeps the full input and result.

This separation is important: tool-name classification, lifecycle state,
structured-data validity and the final view are independent. An unknown field
does not crash the row, and malformed optional metadata does not become a
success claim.

## Behavior already represented in DSH Harmony

| Area | Current status |
| --- | --- |
| call identity and preparing/result merge | Implemented in native transcript projection |
| file mutation Diff and aggregate turn changes | Implemented |
| `todo_write` plan and plan-to-plan diff | Implemented |
| image attachments | Authoritative result blocks are already normalized |
| approvals and user questions | Implemented as live interaction surfaces |
| Markdown, tables, fenced code and code highlighting | Implemented |
| compact process grouping | Implemented |

## Remaining structured gaps

| Family | Compatibility behavior | DSH Harmony before this change |
| --- | --- | --- |
| `read` | Prefer result line objects, language and total-line metadata; fall back to strict numbered text | Path-only summary and generic result |
| `read_image` | Authoritative image blocks plus recorded path and image facts | Images render, but path metadata is not presented |
| `grep` / `glob` | Pattern, scope, file matches, snippet lines, total and truncation | Generic argument and output |
| terminal family | Command, cwd, timeout, background receipt, output, exit/signal | Generic argument and output |
| web family | Query/URL, HTTP status, sources and optional answer | Generic argument and output |
| Goal family | Objective, phase, blocker, rounds, round cap and revision | Generic argument field |
| Job family | Stable job ID, state and output relationship | Generic argument field |
| Subagent family | Stable child ID, label/state and child-tree relationship | Child tree exists, but no typed record view |
| `present` | Ordered valid deliverable declarations and descriptions | Generic tool call |
| unknown tools | Generic complete input/result fallback | Existing behavior, to preserve |

## Parsing decisions carried into the spec

- Strict field validation wins over optimistic guessing. A partial stream may
  expose safe scalar arguments for the row summary, but it cannot create a
  successful result view.
- Only result attachments establish image content. A path string in text is not
  evidence that an image exists.
- Unknown or malformed image entries invalidate structured image metadata while
  preserving all raw content.
- Search metadata is accepted only when its shape matches paths or file matches.
  Arbitrary lines that resemble search output remain generic text.
- Terminal exit information requires a strict metadata field or an exact result
  footer. The parser never infers success from the absence of visible errors.
- Web links are actionable only for parsed `http://` and `https://` URLs.
- Goal/Job/Subagent records describe the historical call. Live session
  projections remain separate state.
- Deliverable paths are displayed workspace-relative for readability and retain
  the declared path as the read-only opening target.
