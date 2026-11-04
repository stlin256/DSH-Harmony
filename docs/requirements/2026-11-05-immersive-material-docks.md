# Immersive system material on composer docks

Date: 2026-11-05

The shell should adopt HarmonyOS immersive system materials (and their light
sensing feedback) on appropriate floating controls: the bottom composer dock
and the floating task-plan dock. The reduce-transparency switch must default to
ON so a fresh install keeps the current pre-immersive appearance; opting out of
reduce transparency enables the materials. All surfaces that carry the material
attribute live in one maintained list so the switch governs them together.

- Use the API-26 `uiMaterial.ImmersiveMaterial` with `systemMaterial` behind a
  runtime API gate; keep API 23 fully functional with opaque surfaces.
- Light sensing feedback follows `lightEffect`; reduced motion disables it and
  the interactive deformation.
- Default `减少透明效果` is ON; the settings toggle still controls the whole list.
- Keep the component list in `NativeMaterials.ets`; adding a surface there and
  attaching its modifier is the only required wiring.
- Cover the registry and the default with source tests and current-HAP device
  evidence; no live Host claim.
