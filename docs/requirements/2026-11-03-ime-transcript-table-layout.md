# IME transcript anchoring and adaptive table layout

Date: 2026-11-03

## User outcome

When the software keyboard opens from the conversation composer, the input
Dock and the visible transcript must rise together. The transcript may not stay
at its old vertical position and let the keyboard or composer cover the latest
text.

CSV and TSV previews must align to the top-left and size each column from its
content instead of applying one fixed width to every column.

## Required behavior

- `IME-LAYOUT-01` The conversation continues to use ArkUI `RESIZE`; the page
  header remains anchored while the available transcript viewport contracts.
- `IME-LAYOUT-02` When the user was following the transcript tail before the
  keyboard opened, the viewport resize re-anchors the transcript to the bottom
  so the latest text stays above the composer.
- `IME-LAYOUT-03` The transcript content, not only the composer, moves upward
  enough to remain fully visible above the IME.
- `IME-LAYOUT-04` A user who had deliberately scrolled away from the tail keeps
  that reading position.
- `IME-LAYOUT-05` Dismissing the keyboard retains the draft and restores normal
  viewport geometry without introducing a page-level translation.
- `TABLE-LAYOUT-01` CSV and TSV table content starts at the preview viewport's
  top-left edge; it is not horizontally or vertically centered.
- `TABLE-LAYOUT-02` Row-number and data columns use content-aware widths with
  fixed lower and upper bounds so short values stay compact and long values get
  enough room.
- `TABLE-LAYOUT-03` Wide tables scroll horizontally while the page continues to
  scroll vertically. Table sizing does not move the preview title or toolbar.
- `TABLE-LAYOUT-04` Header, row-number and data cells in the same column retain
  identical widths.

## Acceptance

- A physical-device layout dump proves the tail transcript row moves upward
  while the IME is visible and remains above the composer.
- The same run proves the header does not translate and the draft survives close
  and reopen.
- A CSV/TSV device run proves the first table cell starts at the table's left
  edge and that content-heavy columns are wider than short columns while all
  widths stay within the configured bounds.
- Static model tests cover steady-width, wide-character, multiline and bounded
  column measurement.
