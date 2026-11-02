# DSH Go frontend hardening requirement

Date opened: 2026-11-02

Status: Active

## User requirement

Audit the remaining product gaps, identify what the frontend can learn from the
pinned DSH Go reference, write a prioritized spec, then implement the changes
incrementally with deterministic Mock fixtures and physical-device E2E.

The DSH Harmony visual identity must remain authoritative. DSH Go is a behavior
and engineering reference only; its Flutter controls, Phosphor iconography,
glass treatment, whale/pet language and other branded surfaces must not replace
DSH Harmony's compact neutral surfaces, precise outlines, business glyphs,
Quiet Precision motion or DeepSeek blue accent.

## Audit result

The highest-risk remaining gaps are:

| Priority | Gap | Current behavior | Required direction |
| --- | --- | --- | --- |
| P0 | Credential display in sent user text | A message can visibly expose a provider key, token, JWT, private key block or URL password. Long-press copies raw text correctly, but display has no mask or reveal control. | Mask only in rendered sent text. Copy, edit, queued input and model input keep the raw value. Offer an explicit reveal/hide action on completed messages. |
| P0 | Unfinished streaming Markdown | `NativeTextContent` parses each partial text value directly. An unfinished emphasis marker, link, code span or table delimiter can flash as raw syntax before its closer arrives. | Repair only the unfinished tail before parsing. The completed value must converge to the same visual result without content jumps. |
| P1 | Settings discovery | Settings root is a static seven-row index. Users must know which page contains a preference. | Add a compact, normalized Chinese/English search over stable page and row entries. Results navigate to the owning page. |
| P1 | Native coverage truth | `docs/NATIVE-COVERAGE.md` still describes many implemented native surfaces as compatibility-only. | Reconcile status with current source and tests. Keep unimplemented behavior explicit rather than presenting 100% equivalence. |
| P1 | Large component ownership | `NativeWorkspace.ets` and `NativeSettings.ets` mix transport, state projection, navigation and view code. | First extract pure, testable models. Do not perform a risky decorative file split without behavior tests. |
| P2 | DSH UI form family | The native DSH UI card handles display-oriented blocks but not the complete form/input family available in DSH Go. | Track as follow-up. Do not add write-capable remote forms without protocol, validation, retry and confirmation coverage. |
| P2 | Accessibility evidence | Semantics exist unevenly and are mostly source-contract tested. | Audit actionable controls with screen reader, large text, keyboard and switch access. Keep device rows Pending until observed. |
| P2 | Shared state primitives | Loading, empty, error, retry and destructive confirmation patterns are repeatedly local. | Extract only after the P0/P1 contracts are stable and covered. |

## Product requirements

### Secret masking

1. Recognized credentials are masked in rendered sent user messages.
2. The original text remains unchanged for copy, retry, edit and protocol input.
3. Masking is display-only and must not mutate cached transcripts.
4. The matcher covers at least:
   - `sk-`, `AIza`, GitHub, GitLab, npm, Hugging Face, AWS, Alibaba, Slack,
     Stripe and webhook-style tokens;
   - JWT-shaped values;
   - PEM private-key blocks;
   - passwords in `scheme://user:password@host` URLs.
5. A completed message with at least one recognized value exposes one compact
   reveal/hide action. The default state after mount is masked.
6. Synthetic credentials only are allowed in source, fixtures, screenshots and
   tests.
7. Masked values use an inline monospace treatment that preserves approximate
   geometry and does not shift the surrounding message when revealed.

### Streaming Markdown

1. While a message is streaming, unfinished inline emphasis, strike, code,
   link destinations, partial images/tags and partial block markers are
   repaired or held back before parsing.
2. An incomplete table remains hidden until its delimiter row is structurally
   usable, rather than flashing as a paragraph of pipe characters.
3. An open fenced code block streams its body as literal code. The opening line
   is held back only while its language/info string is still being typed.
4. Once the closer arrives, the repaired view and final parsed view must agree
   semantically and preserve reading position.
5. Repair is pure and deterministic, has no network access and never changes
   stored text.

### Settings search

1. Settings root has one compact search field using the standard 44vp row
   geometry and page inset.
2. Search normalizes case, whitespace, full-width ASCII and ideographic space.
3. Entries include stable IDs, page IDs, Chinese/English titles, descriptions,
   synonyms and parent-path terms.
4. Ranking prefers exact title, title prefix, title substring, exact synonym,
   synonym substring and path match, in that order.
5. Results are capped and ordered deterministically. Selecting a result opens
   its owning settings page.
6. Empty query restores the existing grouped settings index. No result shows a
   compact empty state with a clear action.

### Coverage and architecture

1. Update the native coverage table to reflect implemented native surfaces.
2. Keep unknown, partial and unsupported behavior visibly distinct from native
   equivalence.
3. Extract pure models before moving large ArkUI view ownership.
4. Register every new state and interaction in the Mock manifest.

## Non-goals

- Re-skinning DSH Harmony with DSH Go colors, typography, icons, glass, pets or
  decorative illustration.
- Copying Flutter widgets into ArkUI.
- Claiming native equivalence for surfaces that still rely on the compatibility
  WebView.
- Adding live secret persistence, secret logging or network access to the mask
  service.
- Marking physical-device checks passed from source tests or Mock mapping.

## Evidence and quality gates

- Requirement, research, implementation spec and E2E table exist before
  production changes.
- Pure-model tests cover mask formats, masking boundaries, copy-source
  preservation, streaming repair convergence and settings ranking.
- Deterministic Mock states cover masked messages, repaired streaming content
  and settings search results.
- Interaction drivers cover reveal/hide, settings query/result navigation and
  Back.
- `node scripts/verify-mock-coverage.mjs` passes.
- `node scripts/qa.mjs pr` passes.
- `mock`, `default` and `store` release variants build after shared ArkUI
  changes.
- Physical-device screenshots and interactions are current-HAP evidence. If no
  ready USB target exists, those rows stay Pending.
