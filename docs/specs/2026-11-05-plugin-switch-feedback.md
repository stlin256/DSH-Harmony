# Plugin switch feedback and in-place refresh implementation

Date: 2026-11-05

## Switch refresh

- Installed bundle keys include the enabled state:
  `'installed:' + bundle.name + ':' + (bundle.enabled ? 'on' : 'off')`.
- Detail rows include their effective enabled state:
  `row.rowId + ':' + (entryFor(row.entryId)?.enabled ? 'on' : 'off')`.
  The refreshed authoritative inventory then recreates exactly the affected
  row, updating `Toggle.isOn` without leaving the surface.
- Bundle/detail/row toggles keep their existing busy gating and Host calls.

## Banner

`applyChange(value, key, summary)` stores an explicit one-line summary
(`已启用` / `已关闭`; install/remove/update add `已安装` / `已移除` / `已更新`).
`resultNotice` renders one `height: compactControl` row: icon, a single-line
summary with ` · 重启 DSH 后生效` suffix when needed, and a compact close
button. It uses `NativeMotion.statusBannerTransition()` for enter/exit.
`errorNotice` in the plugin and automation surfaces uses
`minHeight: compactControl`, two-line ellipsis and the same semantic banner
transition.

## Audit

The only `ToggleType.Switch` usages are the plugin surface and `NativeSettings`.
Settings uses optimistic `@State` updates and is unaffected. Other
`statusBannerTransition` banners (conversation/connection) were already
single-line. The automation error banner received the same compact treatment.