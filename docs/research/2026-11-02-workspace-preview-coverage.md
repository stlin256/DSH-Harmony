# Workspace preview support audit

Date: 2026-11-02

Upstream reference is the separately checked-out `dsh-upstream-reference`
repository at `f3803c96974ad4a94195fb97e5c637e9c2a3afe3`.

## Current gaps found

- The native code-language map contained only a small subset of the upstream
  suffix table. Configuration formats such as `conf`, `cfg`, `ini`,
  `properties` and `env` were absent.
- Unknown suffixes were first treated as `unknown`, then changed to `text` only
  after a successful text request. That made their initial semantic state wrong
  and made failed reads indistinguishable from declared binary files.
- The descriptor exposed `canPreview`, but the reader did not use it to short
  circuit declared binary content.
- Syntax highlighting accepted a smaller language vocabulary than the document
  classifier, so expanded extensions would otherwise fall back to plain text.
- CSV and TSV had no native table projection. They could only appear as source
  text after the generic fallback.

## Upstream behavior reviewed

`packages/util/code-language/src/index.ts` is the authoritative extension table.
It maps more than 100 suffixes to canonical language ids. Relevant examples:

- `ini`: `ini`, `conf`, `cfg`, `properties`;
- `dotenv`: `env`;
- `log`: `log`;
- `json`: `json`, `jsonc`, `jsonl`, `ndjson`, `ipynb`;
- `csv`: `csv`;
- script, JVM, systems, functional, shell, markup, build and infrastructure
  languages represented in the native registry.

`ui-sidebar-documentpreview` behavior establishes these boundaries:

- Code/text registrations use paged text.
- Unknown non-binary suffixes use plain text after UTF-8/NUL validation.
- Declared binary suffixes without a renderer show unsupported preview without
  reading bytes as text.
- CSV/TSV use a spreadsheet renderer by default and retain alternative source
  views.
- The CSV/TSV parser preserves quoted separators, escaped quotes, multiline
  fields, empty fields and unequal row lengths.

## Native support matrix

| Family | Native behavior | Default | Source fallback |
| --- | --- | --- | --- |
| PNG/JPEG/WebP/GIF/BMP/ICO/DNG/HEIC/HEIF/AVIF | ImageKit decode and pan/zoom | Preview | No |
| SVG | Rendered image | Preview | Yes |
| Markdown | Block preview | Preview | Yes |
| HTML | Isolated native HTML preview | Preview | Yes |
| PDF | PDFKit reader | Preview | No |
| Code and configuration | Line-numbered, selectable, highlighted reader | Source | Not applicable |
| Plain text and unknown non-binary suffixes | Plain source reader | Source | Not applicable |
| CSV/TSV | Bounded literal table with row/column labels | Table | Yes |
| Office, archives, executable/object, fonts, audio/video and databases | Unsupported-preview state with download retained | Download only | No |

This matrix is deliberately conservative. Formats without a native renderer are
not claimed as previewable merely because a third-party browser implementation
exists upstream.

## Delimited parsing decisions

The native parser is local and read-only. It retains all source pages while the
table projection is capped at 200 rows, 32 columns and 4096 characters per
retained cell. The view supplies row numbers and A/B/C column labels, so the
first source row remains data.

An unterminated quoted field is an error when the current page is final. While
more pages remain, the parser keeps prior complete rows and marks the table
incomplete. This prevents a page boundary inside a multiline CSV cell from
flashing a permanent parse failure.

## Coverage and evidence limits

Mock states cover configuration source, CSV table/source switching, TSV, malformed
CSV and binary download-only fallback. Source and model tests cover suffix
classification, comment/property highlighting, RFC 4180 parsing and bounded cell
projection.

No USB-ready HarmonyOS target was available during this audit. Screenshots,
computed dimensions and on-device scrolling/selection behavior remain Pending in
the workspace preview coverage E2E table.
