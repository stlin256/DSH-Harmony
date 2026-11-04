# Plugin switch feedback, compact banner and in-place refresh

Date: 2026-11-05

In the plugin manager, closing or enabling a plugin must show an explicit
`已关闭` / `已启用` result banner. The banner is one compact line (not a
multi-line block) with a semantic entrance/exit animation. Toggling a plugin
or a plugin row must refresh the switch in place instead of requiring the user
to leave and re-enter the manager.

- Cover bundle switches, detail-page bundle switches and per-row switches.
- Audit the rest of the app for the same stale-switch pattern (stable ForEach
  keys with refreshed list data) and for one-line banners that reserve
  multi-line height; fix the same class wherever it exists.
- Keep the banner readable, single-line with ellipsis and a close affordance.
- Verify on the current Mock HAP with dark/light and detail-row cases.