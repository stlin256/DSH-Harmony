# Immersive material API research

Date: 2026-11-05. Reviewed the local DevEco Studio 26.0.0 SDK
(`sdk/default/openharmony/ets`).

- `@ohos.arkui.uiMaterial` (API 26, `SystemCapability.ArkUI.ArkUI.Full`,
  stagemodelonly) provides `Material`, `ImmersiveMaterial`, `ImmersiveOptions`
  and `Material.empty`.
- `ImmersiveOptions`: `style` (`ULTRA_THIN=0`, `THIN=1`, `REGULAR=2`,
  `THICK=3`, `ULTRA_THICK=4`), `materialColor`, `colorInvert`, `applyShadow`,
  `interactive`, and `lightEffect` (`{ color }`) — the last is the light
  sensing interaction feedback (沉浸光感).
- `uiMaterial.getMaterialInfo().state` and `MaterialState.DISABLE` gate
  application-level policy; `isImmersiveMaterialSupported()` is a device
  capability check; both are resolved only after the runtime API gate.
- Components consume the material with `CommonMethod.systemMaterial(material)`;
  `Material.empty` disables it per component.
- The module already declares `ohos.arkui.UIMaterial.state: default`, so custom
  components decide per surface; no manifest change is required.
- Device safety: current runtime is API 26; `compatibleSdkVersion` is
  6.1.0(23), so every material object and attribute must stay behind
  `deviceInfo.sdkApiVersion >= 26`; API 23 uses the existing opaque surfaces.
- The existing `materialsEnabled()` policy already folds in reduce-transparency,
  power saving, background state and the material-state metadata; the new
  registry reuses the same conditions.
