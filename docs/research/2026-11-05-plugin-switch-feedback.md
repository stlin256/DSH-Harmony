# Plugin switch stale state and banner research

Date: 2026-11-05

## Stale switch

`NativePluginsSurface` rendered the bundle list with `ForEach` keys
`'installed:' + bundle.name` and detail rows with `row.rowId`. After a toggle,
`refresh(true)` replaced `inventory`/`selected`, but ArkUI does not rebuild a
`ForEach` item whose key is unchanged; the existing row kept its initial
`Toggle(isOn)` value. Leaving and re-opening the manager remounted the surface,
which is why the state only appeared correct after a navigation round trip.

Settings switches (`NativeSettings.toggleRow`) do not have this bug: they are
direct builders over `@State` values and `setting()` updates the local value
optimistically before the Host round trip. Only the plugin list/detail rows
were affected.

## Banner

`resultNotice` stacked an application label and a second `DSH 重启后生效` line
inside a padded `Column`, reserving roughly three text lines for a one-line
result. The label also came from `nativePluginApplication()` (`重启后生效`, `已应用`)
and never stated `已关闭`/`已启用`.

`errorNotice` in the plugin and automation surfaces used
`minHeight: compactHitTarget` plus `maxLines(4)`/`rowTransition`, producing the
same over-tall status strip for short errors.