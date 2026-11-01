# Cross-surface control visual alignment implementation spec

Requirement:
[`2026-11-02-control-visual-alignment.md`](../requirements/2026-11-02-control-visual-alignment.md)

Research:
[`2026-11-02-control-visual-alignment.md`](../research/2026-11-02-control-visual-alignment.md)

Design baseline:
[`2026-11-01-dsh-harmony-design-system.md`](../design/2026-11-01-dsh-harmony-design-system.md)

## 1. Token additions

`NativeDesign.ets` remains the only geometry and type source.

- Control heights: `hitTarget`, `compactHitTarget`, `compactControl`,
  `compactChip`, `compactRow`, `standardRow`, `pickerRow`, `doubleLineRow`,
  `primaryActionHeight`, `headerHeight`.
- Shape: `radiusBadge`, `radiusCompact`, `radiusControl`, `radiusRow`,
  `radiusChip`, `radiusGroup`, `radiusSurface`.
- Type: page, header, compact-title, body, compact, section, caption, micro,
  metric and brand roles.
- Glyphs: micro, inline, control, header, hero and empty roles.
- Spacing: page inset, row inset, card padding, control gap and 4/8/12/16 scale.

No product component may add a new local number for an audited control role.

## 2. Migration order

1. Replace near-duplicate text and glyph literals with role tokens.
2. Replace small radius literals with badge, compact, control, row, chip and
   group tokens.
3. Normalize button, field, chip and row heights.
4. Align page and card insets in the shared surfaces:
   launch, workspace, settings, files, plugins, automation and interactions.
5. Align loading, empty and error rows to the same inset as their idle content.
6. Add source contracts and update Mock fixtures if any named UI query changes.

## 3. Screen recipes

- Launch/login: 16vp page inset, 48vp primary action, 60vp two-line option row,
  18vp section heading and 10vp micro copy. The login, restoring and error sheet
  begins below the complete brand mark with the `spaceXXL` 28vp gap; no follow-on
  surface may clip or cover the mark.
- Workspace/drawer: 44vp icon hit region, 36vp visual container, 44vp compact
  row, 12vp row inset and one consistent chevron role.
- Composer/dock: 36vp inline control, 32vp task-plan disclosure header, 28vp
  chip, 8vp control gap and aligned attachment/queue/change surfaces.
- Settings: 16vp page inset, 48vp rows, 44vp icon controls, one field radius and
  one destructive-action recipe.
- Files: 52vp header, 44vp icon controls, 28vp breadcrumb chips, 48vp file rows.
- Plugins/automation: 52vp header, 48vp primary actions, 36vp inline controls,
  60vp two-line cards and one status-badge recipe.
- Interactions: 28vp status header, 36vp action row, 32vp input/control minimum
  and one option radius.
- Structured content: 12vp inline icon and compact caption roles; disclosure
  rows use intrinsic height with a 28/32vp minimum rather than unrelated one-off
  row heights.

## 4. Exceptions

- Media thumbnails and lightbox images keep aspect/content dimensions.
- LoadingProgress and status dots keep their semantic visual size.
- Avatar, brand mark and illustration keep explicit dimensions.
- Circle radii use half of the explicit dimension.
- The compatibility page keeps upstream web styling.

## 5. Verification

- `gateway/test/control-alignment.test.mjs` checks token presence, forbidden
  near-duplicate literals, high-risk component migration and the launch sheet
  clearance contract.
- Existing design, visual-acceptance, Mock and model tests remain green.
- `node scripts/verify-mock-coverage.mjs` remains 100%.
- PR QA and all three Release builds pass.
- Physical-device rows remain pending until the user restores device access.
