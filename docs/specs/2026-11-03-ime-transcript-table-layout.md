# IME transcript anchoring and adaptive table layout implementation

Date: 2026-11-03

Requirement:
[`2026-11-03-ime-transcript-table-layout.md`](../requirements/2026-11-03-ime-transcript-table-layout.md)

## 1. IME transcript anchor

`WindowAppearance` continues to publish `nativeImeVisible` and
`nativeImeHeight`. `NativeWorkspace` subscribes to `nativeImeVisible`, and its
transcript `onAreaChange` now distinguishes resize from ordinary content
growth.

When the viewport becomes shorter while the IME is visible and `followTail` is
true:

1. update `transcriptViewportHeight`;
2. arm the existing tail-scroll guard;
3. schedule the existing `Scroller.scrollEdge(Edge.Bottom)` path.

The path runs after the layout pass, so the transcript tail and composer share
the resized page instead of leaving the old transcript position behind. The
condition preserves the reading position of a user who scrolled away from the
tail. No page-level `translate`, manual IME height padding or second viewport
owner is introduced.

The final visible `ListItem` receives `transcript-tail-row` for layout evidence.

## 2. Adaptive table sizing

Add the dependency-free `NativeTableLayout.ets` model:

- count CJK, full-width and supplementary glyphs as two half-width units;
- measure the widest physical line in multiline cells;
- derive a data-column width from the widest header or cell value;
- clamp data columns to 72-220vp;
- derive a compact row-number width from the row-count digits, clamped to
  52-72vp.

`NativeDelimitedPreview` calculates a width for every projected column and
passes the complete array to `NativeTable`. `NativeTable` applies one width to
all header and body cells in that column. File-preview tables pass
`layoutId: delimited-table` and focus cells expose stable IDs for layout
assertions.

The horizontal table Scroll and the surrounding vertical preview Scroll align
to `TopStart`. A narrow table therefore begins at the left edge instead of
being centered, while a wide table keeps the existing two-axis scrolling.

## 3. Verification

Model tests cover short, long, CJK, multiline and bounded widths plus the row
number column.

`scripts/device-ui-ime-e2e.ps1` uses the completed conversation fixture and
asserts:

- the header stays fixed;
- the tail transcript row moves upward when the IME opens;
- the tail remains above the composer;
- the draft survives IME dismissal.

`scripts/device-ui-document-mode-e2e.ps1` asserts:

- the table container and first column share the same left edge;
- header cell widths match their column data cells;
- a content-heavy column is wider than a short column;
- every width remains inside the configured bounds.
