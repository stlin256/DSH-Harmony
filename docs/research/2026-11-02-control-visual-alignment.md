# Native control alignment research

Date: 2026-11-02

## Question

Why do native screens that use the same neutral palette still feel visually
noisy, and which recurring control decisions should be consolidated first?

## Method

The audit inspected every ArkUI component under
`harmony/entry/src/main/ets/components` and the native page shell. It grouped
literal control dimensions, radii, icon sizes and text sizes, then compared them
with the authoritative design-system roles and the device screenshot inventory.

No physical device was accessed during this pass.

## Findings

| Area | Observed drift | Effect |
| --- | --- | --- |
| Text roles | 17 literal sizes from 7fp through 30fp, including 9/15/16/17/21/22fp near-duplicates | Similar labels look unrelated and scan rhythm changes between screens |
| Icons | 9/11/12/13/14/15/16/17/18/19/23/25/30/32/34fp all appear | Repeated actions and chevrons shift weight and optical alignment |
| Radii | 5/6/7/8/9/10/11/12/13/14/15/16/18vp all appear | Chips, fields, rows and cards lose a shared shape language |
| Row heights | 26/28/30/32/34/36/38/40/44/46/48/52/58/60/62vp all appear | Toolbars and list rows do not share baselines |
| Page inset | Native surfaces mix 10/12/14/16/18vp | Titles, rows and controls do not align at screen edges |
| Icon controls | Some icon-only actions are smaller than the 44vp hit target | Visual density competes with touch correctness |
| Status language | Spinner size and retry placement vary inside otherwise equivalent rows | Busy and error states look like different systems |

## Conclusions

1. The issue is primarily role drift, not palette drift.
2. Tokenizing only colors is insufficient; geometry, icon and type roles must
   also be constrained.
3. A six-level control-height scale is sufficient for the current product.
4. A single role-based type and icon scale can replace the near-duplicate
   literals without flattening hierarchy.
5. Media canvases, progress indicators, avatars, dots and brand illustration
   remain dimensional exceptions because their size encodes content or motion.

## Controlled migration

- Map repeated font sizes to named type roles.
- Map repeated glyph sizes to named optical roles.
- Map repeated small radii to badge, compact, control, row, chip and group roles.
- Convert direct control heights in audited buttons, fields and rows to the
  semantic control scale.
- Keep media dimensions explicit and document why they are exceptions.
