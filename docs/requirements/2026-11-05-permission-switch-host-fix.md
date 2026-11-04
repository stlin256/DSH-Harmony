# Real-device permission switch failure and risk acknowledgement

Date: 2026-11-05

On the real Host a permission preset switch failed and the composer showed
`权限切换失败，请重试`. The risk acknowledgement row for full access also read
like an action button instead of a checkbox.

- The Host RPC must receive the exact wire shape its `commands/execute`
  endpoint accepts; a positional argument array is rejected by the pinned
  upstream (0.2.2-rc.1) with `Remote payload must contain exactly one
  plain-object args field`.
- A rejected command result must not be reported as accepted; the client stays
  on the authoritative projection and surfaces a conflict.
- The risk acknowledgement is a checkbox row: unchecked shows an empty box and
  a disabled confirm action; checking enables the confirm action.
- Cover the wire shape and the checkbox contract with tests and current Mock
  device evidence; prove the real Host switch through the same native
  operation route the app uses.
