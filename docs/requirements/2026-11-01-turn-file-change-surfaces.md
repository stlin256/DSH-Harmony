# Turn file-change surfaces requirement

Date: 2026-11-01

## User outcome

Every completed assistant turn that changed workspace files must end with a
compact change card in the transcript. During a running turn, the same
information must appear in a small live control immediately above the composer.
The live control hides when the turn completes or stops.

## Final turn card

- The card states how many distinct files were edited and shows aggregate
  `+added/-removed` line totals.
- It contains a readable, deterministic list of the changed files. The first
  three files are visible while collapsed; a row such as `再显示 22 个文件`
  expands the list.
- File rows show the workspace-relative directory and prioritize the filename.
  Filename and metrics measure before the directory; the directory uses only
  the width actually left after useful content, and may truncate only when the
  row truly runs out of space. Short filenames must not reserve a blank weighted
  column.
- The completed card uses the same effective width as the composer.
- A file row opens that Host workspace file in the existing read-only native
  file preview.
- A file opened directly from a conversation file link or the completed-turn
  card returns to the conversation on Back. It must not expose the file's
  parent directory as an intermediate navigation step.
- Nested file links preserve a real preview stack. For example, conversation
  file A -> linked file B -> Back returns to A, and the next Back returns to the
  conversation. A file browser flow A -> B -> Back returns to A, then to the
  containing directory.
- The card has no undo action and no separate `查看变更` action.
- The normal completed/stopped/failed state and final-answer copy action remain
  available without creating an extra footer row.
- The card supports light and dark themes and uses the compact DSH spacing and
  business glyph language.

## Live change control

- It appears only while a turn is running and has at least one successful
  explicit file mutation.
- It shows distinct file count and aggregate `+added/-removed` values.
- Numeric changes animate with a short vertical roll. The animation resolves
  directly when reduced motion is enabled.
- It uses an intrinsic, centered width and remains narrower than a full-width
  card.
- Completion, cancellation, failure settlement or stop hides it with the
  semantic disclosure motion.
- It never covers the selected-image/file attachment strip, the composer, the
  return-to-bottom control or the system gesture safe area.

## Bottom composition

- The composer area uses one reusable bottom-dock composition rather than
  independent absolute offsets.
- Attachment previews increase the dock's measured height and reserve space
  above the composer.
- The live change control sits above the attachment/composer content and below
  the return-to-bottom control.
- The return-to-bottom control never adds permanent bottom space because it is
  a floating overlay.
- The default composer state has no full-width backdrop or fixed dark strip.
  Only when a live-change pill or attachment makes the Dock gain extra content
  may API 26 show a full-width edge-to-edge material whose blur and theme scrim
  increase from a transparent top edge to a translucent frosted bottom edge.
  The bottom must retain visible background variation instead of resolving to
  a solid theme-color strip.

## Data and plugin

- Counts come only from successful edit/write operations with explicit diff
  data. Tool prose, file names in arbitrary output and failed/interrupted calls
  never create counts.
- Repeated edits to one path form one file entry and aggregate their line
  totals.
- The running counter uses successful explicit tool diffs. The completed card
  prefers DSH's authoritative `workspace/changes` announcement and
  `/api/changes.summary` record, which includes command-driven and Git-visible
  changes the tool-only projection cannot see.
- The DSH Harmony gateway must bridge that authenticated Host route because the
  native client holds the gateway session rather than the Host cookie. The
  bridge exposes no Host cwd, snapshot identity or credential.
- File preview stays read-only.

## Verification

- Add pure projection tests for success filtering, deduplication, multi-file
  patches, ordering, aggregate totals, running/final state and malformed data.
- Build `default` and `store` Release HAPs when shared ArkUI code changes.
- Add device E2E rows. They remain Pending until tested on a real device.

