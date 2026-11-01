# Design system unification implementation spec

Date: 2026-11-01

Requirement:
[`2026-11-01-design-system-unification.md`](../requirements/2026-11-01-design-system-unification.md)

Research:
[`2026-11-01-design-system-audit.md`](../research/2026-11-01-design-system-audit.md)

Authoritative visual/motion baseline:
[`2026-11-01-dsh-harmony-design-system.md`](../design/2026-11-01-dsh-harmony-design-system.md)

## 1. Source contract

Add `NativeDesign.ets` with semantic static methods and metrics for:

- Base, subtle, raised, overlay, field, selection and selected surfaces.
- Primary, secondary and tertiary text.
- Accent, success, warning, danger and their surfaces.
- Border, divider and system mask.
- Compact/standard/picker row heights and 44vp hit target.
- Radius and spacing scale.
- Page/header/body/caption/micro type sizes.
- Theme-aware SVG tone resolution.

Product surfaces import these methods instead of duplicating the same ternary color
expression. Literal colors remain allowed for protocol syntax highlighting, media
canvas backgrounds and one-off system semantics when the token layer has no
reasonable meaning.

Add `NativeIconButton` as the shared 44vp hit/36vp visual icon control. Active
state paints the visual container, preserving the trigger highlight while a
menu is open.

## 2. Motion contract

Extend `NativeMotion` without breaking existing callers:

- `drawer`: 280ms.
- `mask`: 240ms.
- `scrollReturn`: 280ms.
- `exitDuration()` for the shorter return budget.
- `maskParam()` for opacity-only mask updates.

Existing `navigation`, `overlay`, `surface`, `micro` and `press` tokens retain
their meaning. New component motion must not introduce local duration values.
Reduced motion bypasses all new animations.

## 3. Correctness fixes

1. Selected session styling applies in phone and wide layouts.
2. Session menus do not request a full-screen dim mask; the anchored popup is
   dismissed by its own outside tap behavior.
3. Disclosure, queue actions, approval actions and file/header controls use at
   least a 44vp interaction region.
4. SVG semantic colors are resolved centrally for all light/dark surfaces.

## 4. Surface migration order

1. Shared shell chrome and base colors:
   `Index`, `NativeCompatibilitySurface`, `NativeLaunchSurface`.
2. High-frequency chat shell:
   `NativeWorkspace`, conversation header, drawers and bottom dock.
3. Settings family:
   `NativeSettings`, `AboutSettings`.
4. Overlay and picker family:
   `NativeActionMenu`, `NativeModelPicker`, `NativeWorkspacePicker`,
   `NativeSessionTools`.
5. Interaction family:
   `NativeQueueDock`, `NativeInteraction`, process/disclosure rows.
6. File family:
   `NativeFileBrowser`, `NativeFilePreview`, `NativeImageLightbox`,
   `NativeDocumentModeSwitch`.

Migrate semantics before decorative animation. A surface is not considered
unified if it has the correct color but a different navigation or dismiss path.

## 5. Tests

Add a source-contract test that verifies:

- `NativeDesign` exposes all required semantic families and a 44vp hit target.
- `NativeIconButton` separates 44vp hit and 36vp visual geometry.
- `DSHIcon` resolves color through `NativeDesign.iconTone`.
- Major surfaces import `NativeDesign`.
- `NativeMotion` contains drawer, mask and scroll-return tokens.
- Phone session selection no longer depends on `wide`.
- Session popup no longer uses `mask: true`.
- No selected shared header introduces a hit target below 44vp.

Run `node --test` for the gateway suite and build both Release products.

## 6. Completion evidence

The E2E table records device checks separately. Automated source/build evidence
does not mark touch, blur, theme and motion rows as device-passed.
