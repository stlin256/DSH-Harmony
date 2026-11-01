# Native visual state acceptance implementation spec

Requirement:
[`2026-11-01-device-visual-state-acceptance.md`](../requirements/2026-11-01-device-visual-state-acceptance.md)

Design baseline:
[`2026-11-01-dsh-harmony-design-system.md`](../design/2026-11-01-dsh-harmony-design-system.md)

Surface inventory:
[`2026-11-01-design-system-audit.md`](../research/2026-11-01-design-system-audit.md)

## 1. Evidence model

Each reviewed state produces:

- `screen.jpeg`;
- `layout.json` or an equivalent ArkUI tree;
- `manifest.json` with device, API, HAP, fixture and process identity;
- a row in the physical-device E2E table with `Passed`, `Failed` or `Pending`.

Static fixture captures are mapped through `docs/testing/mock-feature-manifest.json`.
Interaction drivers must submit, select, navigate or transition state and then
assert the resulting UI tree. The capture scripts may not claim interaction
completion from a screenshot alone.

## 2. Inventory order

1. Existing deterministic Mock states, both themes.
2. Reduced-transparency Dock states and reduced-motion navigation/overlay
   states.
3. Settings root and child pages.
4. Chat header menus, model picker, workspace picker, queue edit and session
   tools.
5. File browser, code/Markdown/HTML/PDF preview, document mode switch and image
   lightbox.
6. Launch/login/restore/error surfaces using non-secret synthetic states.
7. Large text, narrow/split layout and system Back.

## 3. Visual review

Review captures in contact sheets first, then open each suspicious or
representative capture at native resolution. A row fails when it has:

- clipped or overlapping text;
- content outside the safe area;
- a hit target or visual control that changes layout when pressed;
- incorrect light/dark semantic surface, border or text hierarchy;
- a material that does not fall back to an opaque surface;
- a loading/empty/error state without a readable next action;
- an action menu, picker or preview that loses the originating context;
- a transition that changes the result under reduced motion.

## 4. Correction loop

For each defect:

1. Record surface, fixture, theme, expected result and observed evidence.
2. Patch the shared component or semantic token before adding a local override.
3. Add or update a source/model test when the defect is contract-like.
4. Rebuild and reinstall the mock HAP.
5. Recapture the affected state in both themes and reduced-effect variants that
   apply.
6. Run Mock coverage, PR QA and all product builds.

## 5. Completion

The E2E table is the delivery record. It must list commands, run ID, evidence
paths, HAP hashes and explicit environment-bound gaps. A clean release evidence
manifest is generated only after the working tree is committed and the current
HAP hashes match the recorded evidence.

## 6. Annotation-driven correction pass

The dark-theme annotation batch for run
`20261101T152352Z-visual-acceptance-1` created 32 boxes across 20 captures.
Repeated findings are corrected through shared primitives and component
contracts:

1. Compact toolbar, notice, chip, dock and interaction controls use semantic
   dimensions below the 44 vp primary hit target. Font sizes do not shrink.
2. Filled chips and segmented choices have explicit inter-item spacing and
   clipped capsule backgrounds.
3. Vertically weighted text is prohibited inside compact columns; row content
   uses intrinsic height.
4. Live-change state is ordered above queued input. Queue input remains below
   the current turn state.
5. Dock material must span the full horizontal dock bleed while its content
   remains inset.
6. Attachment and queued-file rows use one-line compact surfaces with nearby
   remove actions.
7. The main composer keeps image, file and send controls visually compact while
   their parent row retains predictable geometry.
8. Subagent composer uses a compact single-row composition instead of an empty
   second action row.
9. Turn-change cards align to the composer's inner width and use compact
   header, file and expansion rows.
10. Approval status indicators render as filled surfaces rather than outlined
    shape primitives.
11. Question custom answers use one input surface. Pagination uses left/right
    arrows adjacent to the page count, with compact action buttons.
12. Reduced-transparency mode remains visually distinct from elevated material
    while preserving full-width fallback geometry.
13. The floating task-plan header uses the 36 vp compact semantic target without
    shrinking its labels. The active Plan chip is a clipped capsule, and a
    selected session refreshes its Plan/subagent projection baseline even when
    the session-list record does not contain those values. The deterministic
    Mock session list carries the same projection values so the executable chip
    is present before live follow delivery.

Every correction is recaptured on the connected API 26 device. A prior Mock
marker pass is not evidence for these visual corrections.
