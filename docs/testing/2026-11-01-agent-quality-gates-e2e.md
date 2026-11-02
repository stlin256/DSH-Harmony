# Agent Quality Gates E2E

Status: portable implementation gate and focused device smoke passed locally.
Hosted CI and the complete device-lab matrix remain separate evidence and are
not implied by these results.

| ID | Action | Expected | Status |
| --- | --- | --- | --- |
| QG-E2E-01 | Run `node scripts/qa.mjs fast` on the current checkout | All portable checks pass and `report.json` records Git state | Passed, `20261101T144319Z-981f9b2c` |
| QG-E2E-02 | Run `node scripts/qa.mjs pr` | Fast checks and the full gateway suite pass | Passed, `20261101T144328Z-85eef99d` |
| QG-E2E-03 | Introduce a protocol-lock version mismatch | The protocol verifier fails with the document name | Passed by negative test |
| QG-E2E-04 | Exercise malformed, committed-before-end and end-before-committed terminal flows | Invalid frames are rejected; both valid orderings settle exactly once without stale partial output | Passed by protocol and reducer tests |
| QG-E2E-05 | Feed malformed opening snapshots into normalizer and reducer | Invalid snapshots are rejected before mutation; cursor `-1` is accepted | Passed by protocol test |
| QG-E2E-06 | Invoke every client native route through the route-parity test | All routes, including `native/changes/summary`, are accepted | Passed by parity test |
| QG-E2E-07 | Trim workspace caches containing the same path in two sessions | Only the selected session row is removed | Passed by cache test |
| QG-E2E-08 | Scan synthetic Windows and Unix personal paths | Both forms fail publication checks | Passed by publication test |
| QG-E2E-09 | Scan a synthetic signing-password field | Publication checks fail | Passed by publication test |
| QG-E2E-10 | Run Mock mapping with a comment-only state and an unrelated interaction driver | Both are rejected; a driver must reference a declared feature state | Passed by Mock mapping test |
| QG-E2E-11 | Validate dirty, stale, incomplete, optional-only or non-container release evidence | Evidence verification fails unless a passed mandatory step and real HAP/artifact hashes exist | Passed by evidence tests |
| QG-E2E-12 | Run CI on a pull request | Portable gate and package verification execute in hosted CI | Pending, no hosted run available |
| QG-E2E-13 | Build `default` release HAP | ArkTS/HAP packaging and signing complete | Passed |
| QG-E2E-14 | Build `store` release HAP | ArkTS/HAP packaging and signing complete | Passed |
| QG-E2E-15 | Build `mock` release HAP | ArkTS/HAP packaging and signing complete | Passed |
| QG-E2E-16 | Run full-history and working-tree publication scans | No new sensitive finding or baseline mismatch; shallow history fails closed | Passed |
| QG-E2E-17 | Query an attached HarmonyOS device with HDC | A target and API/ABI profile are available for device E2E | Passed, HUAWEI Pura 70 Pro+ / API 26 / arm64 |
| QG-E2E-18 | Run `node scripts/qa.mjs release --evidence <manifest>` with device evidence | Release evidence is complete, current and clean | Blocked, no completed device scenario evidence on a dirty tree |
| QG-E2E-19 | Run dependency audit and plugin packaging | Audit has no findings and package verifier passes | Passed, 0 vulnerabilities |
| QG-E2E-20 | Install the current mock HAP and launch a completed conversation fixture | Install and launch succeed; layout, process and screenshot assertions pass | Passed on HUAWEI Pura 70 Pro+ / API 26, bundle `0.4.7` |
| QG-E2E-21 | Run idle send, running queue, authority reconciliation, material fallback and failed-send flows on device | User message and assistant reply appear; queue rows reconcile without duplication; quiet, elevated and reduced-transparency layouts are distinct; failed send retains the draft; process stays alive | Passed; manifest reports all 11 checks true |
| QG-E2E-22 | Query hint-only composer text and the rightmost enabled send row from a layout dump | Hint fallback is used only without visible text; exact duplicate labels do not break matching; the send selector returns one semantic row | Passed by `gateway/test/device-layout-query.test.mjs` |

## Evidence

- Local Git state: `8f79a6d6864b8cecae2ee0c9d2ee636a8433fa2b`, branch `main`,
  dirty.
- Gateway suite: 230 passed, 0 failed.
- Mock mapping: 10/10 screens, 34/34 states, 27/27 registered features,
  68 static capture pairs and 5 interaction drivers. This is not device
  execution evidence.
- `default` signed HAP: 2,071,172 bytes,
  `7cab7cdaec7de04ed2b40b6a4af21c3c40ecf1982eac038af8ee1850b5f07453`.
- `store` signed HAP: 2,071,180 bytes,
  `1dd412cc6f635d46a8287440b03eef5424dd348a87a56ae5ca619058d9b0e011`.
- `mock` signed HAP: 2,071,097 bytes,
  `53e6e4c37326470de8bd09da504b6e585f6df9b66fedcefdda1d7342bc51bb70`.
- Full-history publication scanning passes only under the reviewed exact-match
  baseline for 20 legacy personal-path blobs. The baseline does not suppress
  any working-tree or staged finding, and credentials, private keys, signing
  passwords or private hosts are not baseline-eligible.
- Device profile: HUAWEI Pura 70 Pro+ (`HBN-AL80`), API 26, arm64-v8a,
  serial `33Z0224801015621`. The current mock HAP installed for interaction
  tests, then the current default HAP was reinstalled for normal use. The
  installed bundle reports `0.4.7` / `versionCode 28`.
- Device smoke:
  `artifacts/device-ui-dock-e2e/dock-send-idle-dark-conversation/manifest.json`
  reports `layoutAssertion: passed`.
- Dock interaction evidence:
  `artifacts/device-ui-dock-e2e/send-and-queue/manifest.json` reports
  `result: Passed` with all 11 interaction, material and process-liveness checks
  true. Screenshots and layout dumps are stored beside the manifest.
- Final device state: default HAP SHA-256
  `7cab7cdaec7de04ed2b40b6a4af21c3c40ecf1982eac038af8ee1850b5f07453`,
  `debug: false`, launch foreground and app process alive.

These local HAP hashes are build evidence, not release artifacts. Do not mark
QG-E2E-12 passed until hosted CI output exists. The focused device rows above do
not imply that the complete device-lab matrix, API 23/26 matrix, real protocol
traffic or visual/accessibility/performance baselines have passed.

