# Security Audit Remediation — Verification Record (2026-11-07)

Verification record for docs/specs/2026-11-07-security-audit-remediation.md.
Findings and fixes: docs/research/2026-11-07-security-audit-remediation.md.

## Environment

- HDC device access: NOT available in this round (user constraint). No device E2E
  can be captured; every device-dependent verification is recorded as an explicit
  gap below and never claimed.
- DevEco Studio 26.0.0 toolchain: available; HarmonyOS product variants
  (default, store, mock) rebuilt locally to prove the ArkTS changes compile.

## Verification matrix

| Fix | Category | Test / build evidence | Device evidence |
| --- | --- | --- | --- |
| F-B1/F-C1 64mb body + per-field caps | DoS | gateway suite: "native request magnitude caps…" (new) | n/a (server) |
| F-B2/F-C2 upload size/name/mediaType caps | DoS | same test (new) | n/a (server) |
| F-B4/F-C6 stable-code allowlist in rpcWithBytes | InfoDisclosure | "binary reads relay only stable decision codes" (new) | n/a |
| F-C3 settingsSet own-property guard | InputValidation | same magnitude-caps test | n/a |
| F-C4/C5 fullText + source caps | InputValidation | "protocol normalization applies the intended… caps" (new) | n/a |
| F-A2 auth-limiter ceremony exemption | DoS | gateway suite green (existing limiter tests) | n/a |
| F-A3 per-owner upstream cookie | AuthZ | gateway suite green (proxy-auth tests) | n/a |
| F-GB1 live-socket cap separation | Bug | gateway suite green (WS tests) | n/a |
| F-GB2 mid-stream abort teardown | Bug | gateway suite green | n/a |
| F-GB3/GB4 overview precedence + title guard | Bug/UIBug | "overview keeps one staleness precedence…" (new) | n/a |
| F-GB5/GB6 surfaceOp + event seq validation | InputValidation | "history and live events reject malformed…" (new) | n/a |
| F-GB7 expectedUpdatedAt null | Bug | native-admin-protocol test (new) | n/a |
| F-GB8/GB9 fetch deadlines + bounded summary read | Bug/DoS | gateway suite green | n/a |
| F-E1 ?section= own-property guard | InputValidation | gateway suite green | n/a (web) |
| F-E2 host-mode loginMode init | Bug | source fix; browser-only path | n/a (web) |
| F-F1 plugin pre-appFor trust + LRU | DoS | plugin host tests green (gateway suite) | n/a |
| F-D1/D2/D3 deploy hardening | Config/Secrets | config text reviewed | n/a |
| F-H1/F-I1 HTML preview egress lockdown | XSS | native-models HTML tests updated + new remote-refs assertions | GAP: re-capture HTML preview E2E |
| F-H2 bounded response budgets | DoS | ArkTS compiles (mock build) | GAP: long-file/image flows on device |
| F-H3 attachment 32MB read cap | DoS | ArkTS compiles | GAP: oversize-pick error toast on device |
| F-H4 listing bound + cache payload cap | DoS | protocol-hardening suite green | GAP: large-listing scroll on device |
| F-H7 delete-path name validation | InputValidation | protocol-hardening LRU test (fixture now uses real names) | n/a |
| F-I2 code-span secret masking | InfoDisclosure | native-models masking tests green | GAP: masked credential in backticks on device |
| F-I3 reader per-chunk table | UIBug | native-models suite green | GAP: 阅读全文 of a tabular document |
| F-I4 GFM short delimiters | Bug | native-models streaming-table tests updated | GAP: short-delimiter table render |
| F-I5 fence info strings + closer length | Bug | native-models suite green | GAP: 4-backtick fence preview |
| F-I6 diff memo content fingerprint | Bug | native-models suite green | n/a |
| F-I7 fallback excluded for tool rows | UIBug | native-models suite green | GAP: empty-output tool row |
| F-I8 binary asset budget | Bug | ArkTS compiles | GAP: >8MiB referenced asset preview |
| F-J1 ListSource full comparison | Bug | native-models suite green | GAP: mid-list process update |
| F-J2 plugin block pop guard | Bug | native-models suite green | GAP: 30-block dsh-ui card |
| F-J3 process group closed state | UIBug | native-models suite green | GAP: interrupted turn group label |
| F-J4 automation exact seconds | Bug | native-models suite green | GAP: 90s task open+save |
| F-J5 catalog shape validation | InputValidation | native-models suite green | GAP: malformed catalog error path |
| F-K1 toggle failure revert | UIBug | ArkTS compiles | GAP: failed toggle visual state |
| F-K2 entries search filter | Bug | ArkTS compiles | GAP: 运行组件 search |
| F-K3 install notice invalidation | Bug | ArkTS compiles | GAP: spec edit after pending builds |
| F-K4 dead component deleted | Config | design-system/control-alignment tests updated | n/a |
| F-G1 loopback-only cleartext | Transport | ArkTS compiles | GAP: LAN http rejection message |
| F-QA1 ReduceMotion forwarding | Bug (evidence) | script fix; no device to re-capture | GAP: ALL reduced-motion scenes re-capture |
| F-QA2 recv verification | Bug (evidence) | script fix | GAP: next suite run validates |
| F-QA3..QA11 pipeline fixes | Bug | node --check / py_compile + suite contracts | n/a |

## Product-variant builds (DevEco 26.0.0, release mode)

- [x] default (assembleHap) — BUILD SUCCESSFUL in 19 s 931 ms
- [x] store (assembleHap) — BUILD SUCCESSFUL in 29 s 920 ms
- [x] mock (assembleHap) — BUILD SUCCESSFUL in 22 s 998 ms

(The wrapper script reports exit code 1 from trailing PowerShell state; hvigor
itself reported BUILD SUCCESSFUL for all three variants and the fresh
signed HAP artifacts were confirmed on disk.)

The packed plugin was regenerated with `node scripts/package-plugin.mjs` and
passed the packed-plugin verification ("Packed plugin host, browser factory and
static assets passed"), so the deployable tarball carries the fixed gateway and
web assets.

## QA run

- `node scripts/qa.mjs pr` PASSED all 7 steps (diff hygiene, protocol lock, mock
  coverage, keyboard avoidance, product variants, publication scan, gateway
  test suite). Run id: `20261106T183242Z-5ee448b2`, report:
  `.artifacts/qa/20261106T183242Z-5ee448b2/report.json`.

## Device round (2026-11-07, HDC restored)

Device: HBN-AL80, API 26, USB `33Z0224801015621`. Mock HAP built from this
working tree with DevEco 26.0.0 (release).

### Verified on device

| Finding | Evidence |
| --- | --- |
| F-QA1 reduced-motion forwarding | `iteration-notice-dark-launch-reduced-motion/manifest.json` now records `reduceMotion: true` (it was always `false` before the fix) |
| F-I2 code-span secret masking | `secret-masked-dark-conversation` renders masked credentials (`eyJhbGci****…`, `ops-user:********@`), with the 显示凭据 control present |
| F-DEV1 plugin scrollbar edge | plugin list and detail captured in dark/light; the bar now renders on the physical edge like the transcript |
| F-DEV2 assertion stderr handling | all plugin/automation scenarios pass after the shared Invoke-LayoutQuery fix |
| F-DEV3 sidebar lazy-list assertion | `completed-dark-sidebar` / `completed-light-sidebar` pass with `sidebar-workspace-workspace-gateway` present after the drawer scroll |
| F-DEV4 dark Dock material | `dock-material-elevated-dark-conversation` passes with entry separation 8.86 |
| F-DEV5 PowerShell encoding | `node scripts/verify-powershell-encoding.mjs` passes (28 scripts) and is now a `qa.mjs fast` step |
| F-DEV6 composer identification | `interaction-question` dark and light pass with the stable `composer-input` id |
| F-QA2 recv verification | every capture in this round carries manifest + screen.jpeg + layout.json |

### Second device pass (2026-11-07 evening)

| Finding | Evidence |
| --- | --- |
| F-DEV9 permission confirm fill | dark: acknowledged action is `#FFB3261E` solid with white type, unchecked is neutral `field()`; light theme verified with the same neutral disabled state |
| F-DEV10 showcase scene timing | the six previously flaky scenes (model-menu dark/light, plugins-restart, showcase-subagent, approval-workspace-once, disclosure-sidebar-group) pass individually with `-ResetData` |
| F-DEV1 scrollbar edge | plugin list/detail dark and light still pass after the colour change |
| `qa.mjs fast` | passed (run `20261107T112201Z-06dde568`) |

### HTML preview device evidence (F-H1/F-I1)

A deterministic `html-preview` fixture was added (docs/preview.html in the Mock
workspace, registered as `surface.file-preview-html` with state `html-preview`)
so the preview's security contract is proven on device instead of by source
inspection alone.

| Check | Evidence |
| --- | --- |
| Scripts still execute (user requirement) | the fixture writes `DSH_SCRIPT_RAN` from an inline script; the captured layout asserts that marker is present, and the screenshot shows it rendered |
| Authored remote asset stays a normal request | the fixture's `<img src="https://images.example.invalid/banner.png">` renders as a normal image slot (unresolvable test domain) |
| Script-composed egress blocked | CSP `connect-src 'none'`, `frame-src 'none'`, `form-action 'none'` plus the request-interceptor authored-URL allowlist; captured in dark and light |
| Scenes | `html-preview-dark-preview` and `html-preview-light-preview` both pass their marker + bottom-safe assertions |

### Baseline cross-check

A HAP built from the unmodified ArkTS tree was installed and captured for the
sidebar scenario: it failed identically, proving the sidebar failure was a
suite/assertion defect (lazy list below the first viewport), not an ArkTS
regression introduced by this audit.

## Device-evidence gaps (no HDC this round)

Every row below must be re-captured on a physical device before any release
claim; none of them is claimed as verified today:

1. HTML preview (F-H1/F-I1/F-I8): the spec'd device E2E scene "HTML with
   CSS/image/script references" plus a remote-asset page and a >8 MiB binary
   asset page must be re-captured against the new interceptor/CSP.
2. Reduced-motion evidence (F-QA1): every previously captured reduced-motion
   scene (including launch/iteration-notice) was captured with normal motion
   because the suite never forwarded the flag; all such rows are INVALID until
   re-captured with the fixed script.
3. Transcript/display fixes (F-I2, F-I3, F-I4, F-I5, F-I7, F-J1, F-J2, F-J3):
   masked credentials in backticks, 阅读全文 on a table document, short-delimiter
   tables, 4-backtick fences, empty tool rows, mid-list streaming updates,
   30-block plugin cards, interrupted-turn process groups.
4. Plugin surface (F-K1, F-K2, F-K3): failed toggle revert, entry search
   filtering, install-spec edit after a pending-builds notice.
5. Composer/origin (F-G1, F-H3): LAN http rejection message, oversize
   attachment pick error.
6. Model directory (F-J5) and automation (F-J4): malformed-catalog error path,
   90-second interval preservation.
7. Large-listing flows (F-H2, F-H4): long file reads, oversized directory
   listings.

The "Remaining device checks" section of
docs/testing/2026-11-01-device-visual-state-acceptance-e2e.md is updated with
the same list.