# Immersive material dock implementation

Date: 2026-11-05

## Registry

`NativeMaterials.ets` owns `NativeMaterialSurface` ids,
`NATIVE_MATERIAL_SURFACES` (id, label, style, lightEffect, interactive) and the
single gate `NativeMaterials.enabled()`: API >= 26, `nativeReduceTransparency`
not set, not power saving, app active, and `getMaterialInfo().state` not
`DISABLE`. `materialFor(id)` returns `undefined` on old runtimes (attribute not
applied), `Material.empty` when disabled, and an `ImmersiveMaterial` when
enabled. Light feedback and interactive deformation are dropped under reduced
motion.

Typed `AttributeModifier` wrappers (Column/Row/Stack) apply
`systemMaterial` inside the API gate. Components attach the wrapper with their
surface id, so the maintained list is the single control point.

## Surfaces

- Bottom composer dock: the elevated scrim column now uses
  `NativeMaterialColumnModifier(BOTTOM_DOCK)` instead of a local backdrop blur.
- Floating task-plan dock: the card column uses `TASK_DOCK`.
- Both keep the existing opaque branch when `NativeExperience.materialsEnabled()`
  is false, and the gradient scrim still provides falloff over the material.

## Defaults

`减少透明效果` now defaults to ON in `NativeExperience`, settings state, review
store defaults and the Mock showcase entry. That preserves the pre-material
shell; turning the switch off enables the list. Mock capture opts in with the
new `-ImmersiveMaterial` switch (`showcaseReduceTransparency false`).

## Verification

Source tests assert the registry, the dock wiring, the default and the API
gate. The Mock suite captures immersive dark/light and default fallback through
`device-ui-material-e2e.ps1`; device rows MAT-01..03 carry the current HAP
hash. API 23 opaque fallback remains an environment gap.
