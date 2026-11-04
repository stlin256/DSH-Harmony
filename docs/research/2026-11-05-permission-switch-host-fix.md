# Permission switch Host contract research

Date: 2026-11-05

Reproduction used the Host's local native operation route with proxy
attestation and a throwaway session; the same request shape the app sends:
`setPermissionPreset` returned `502 操作未确认，请刷新`.

Temporary gateway logging showed the upstream envelope:

```
commands/execute { code: gateway/internal,
  message: Remote payload must contain exactly one plain-object args field }
```

`gateway/src/native-harness.mjs` sent the DSH `commands/execute` RPC as a
positional array `[sessionId, line, []]`. The pinned DSH 0.2.2-rc.1 gateway
decodes `payload.args` as an object keyed by each parameter's `wire` name;
`commands/execute` declares `agentId`, `line` and `submittedAttachments`.
A direct call with `{ agentId, line, submittedAttachments: [] }` returned
`{ result: { kind: 'success', text: 'preset read-only' } }`, confirming both
the shape and that the session id is the agent id for lookup.

The same positional shape was used by `planOff`, so `/plan off` would have
failed on a real Host for the same reason. Neither run could be caught by the
existing mocks because the mock upstream accepted any `payload.args` shape.
