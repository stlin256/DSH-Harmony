# DSH Go-inspired frontend hardening implementation spec

Date: 2026-11-02

Requirement:
[`2026-11-02-dsh-go-frontend-hardening.md`](../requirements/2026-11-02-dsh-go-frontend-hardening.md)

Research:
[`2026-11-02-dsh-go-frontend-learnings.md`](../research/2026-11-02-dsh-go-frontend-learnings.md)

## 1. Data contracts

### 1.1 Secret spans

Create `harmony/entry/src/main/ets/services/NativeSecretMask.ets`.

```text
NativeSecretSpan
  start: number       inclusive UTF-16 offset
  end: number         exclusive UTF-16 offset
  masked: string      display value for this exact span
  kind: string        token | jwt | privateKey | urlPassword
```

Pure API:

```text
nativeSecretSpans(text: string): NativeSecretSpan[]
nativeMaskSecrets(text: string, spans?: NativeSecretSpan[]): string
nativeHasSecrets(text: string): boolean
```

Rules:

- Spans never overlap and are ordered by start offset.
- Matching is case-sensitive where credential prefixes are case-sensitive.
- Prefix tokens require a boundary before the prefix and the documented minimum
  body length.
- Tokens retain the first eight characters; the remainder becomes `*`.
- JWT retains the first eight characters of the full value.
- URL password spans contain only the password.
- Private key display preserves the BEGIN line, the END line when present and
  line breaks; body characters become `*`.
- Marks are per Unicode scalar value where feasible; CR/LF are preserved.
- The source string is never mutated or persisted.
- Marked spans become protected inline runs before Markdown parsing; their
  asterisks are never reinterpreted as emphasis delimiters.
- Virtualized text windows must not split a marked span. A long message may use
  a larger window when required to keep one credential whole.

### 1.2 Streaming repair

Create `harmony/entry/src/main/ets/services/NativeStreamMarkdown.ets`.

```text
nativeRepairStreamingMarkdown(text: string): string
```

Rules:

- Empty input returns empty input.
- Only the unfinished final block is modified.
- Track a fence across the document without reparsing earlier final blocks.
- While inside a fence, keep body text literal; hide an opening line that is
  still only an incomplete fence/info string.
- Hide an incomplete table from its header row until the delimiter row is
  usable.
- Drop a final line containing only a partial heading/list/rule/quote marker.
- Close open emphasis, strike, code and link destination in the display copy.
- Cut an unfinished image, HTML tag or marker that has no content yet.
- Appending the real closer must produce the equivalent completed visual state.

### 1.3 Settings index

Create `harmony/entry/src/main/ets/services/NativeSettingsIndex.ets`.

```text
NativeSettingsEntry
  id: string
  page: string
  title: string
  detail: string
  synonyms: string[]
  path: string
  rank: number

NativeSettingsHit
  entry: NativeSettingsEntry
  score: number
  matchedSynonym: string
```

Pure API:

```text
nativeNormalizeSettingsQuery(value: string): string
nativeSettingsEntries(): NativeSettingsEntry[]
nativeSearchSettings(query: string, limit?: number): NativeSettingsHit[]
```

Ranking:

| Match | Score |
| --- | ---: |
| exact title | 100 |
| title prefix | 80 |
| title contains | 60 |
| exact synonym | 50 |
| synonym contains | 40 |
| path/detail contains | 20 |

Add the entry's small frequency rank as a tiebreaker without allowing it to
overcome a stronger match class. Ties preserve declared index order. Limit
defaults to 20.

Initial entries:

- DSH settings: chat transcript, process display, folded replies, busy input.
- Appearance: dark, light, system, reduced motion, reduced transparency.
- Notifications: approval, failure, completion, connection, push, test.
- Cards: widget privacy and task names.
- Storage: cache pool, clear cache.
- Connection: server, account, login, logout.
- About: version, project, licenses.
- Row-level synonyms for the visible preferences on those pages.

## 2. Production UI

### 2.1 User message masking

Modify `NativeMessageView.ets`.

- Import the pure mask service.
- Add state `secretsRevealed: boolean = false`.
- Derive message-level secret presence without copying raw text into state.
- Render masked `text` and masked block text for user messages unless revealed.
- Pass raw text into the inline renderer with a `maskSecrets` display flag;
  masking belongs to the render boundary, after raw copy capture and before
  Markdown styling.
- `copyMessage()` continues to read the original `message.text` and block text.
- Add one action row below a completed user message when secrets exist:
  - eye glyph plus `显示凭据` while masked;
  - eye/check glyph plus `隐藏凭据` while revealed;
  - 44vp hit target, 32vp visual control language, no nested card.
- Accessibility text must describe the action and the masked/revealed state.
- Do not allow the action for transient queued rows; this component only handles
  sent messages.
- Route long text through protected ranges in `NativeTextSource` so a 4096
  UTF-16 window cannot split a recognized credential.

### 2.2 Streaming text

Modify `NativeTextContent.ets`.

- Add `@Prop @Watch('changed') streaming: boolean = false`.
- Compute `renderedText = streaming ? nativeRepairStreamingMarkdown(text) : text`.
- Feed `renderedText` to source virtualization and table parsing.
- Keep copy operations bound to the raw `text`.

Modify `NativeMessageView.ets`.

- Pass `streaming: this.message.runningTurn` for ordinary message text and
  blocks.
- Pass `streaming: this.runningReasoning` for reasoning text.
- Do not add item entrance animation.

### 2.3 Settings search

Modify `NativeSettings.ets`.

- Import the pure settings index.
- Add `settingsQuery: string`.
- Place a search field below the root header, before the grouped list.
- Search field:
  - 44vp height;
  - field background;
  - 16vp page inset via the existing content column;
  - leading search glyph;
  - one clear icon action when non-empty;
  - screen-reader label `搜索设置`.
- Non-empty query replaces grouped navigation with ranked results.
- Result row:
  - 44vp minimum;
  - title on the left;
  - page path/detail on the right, single line and ellipsized;
  - opens the result page and clears the query.
- Empty results show one compact line and a clear action.
- Preserve current row heights, divider inset, radius and surface colors.
- In Mock state `settings-search`, initialize query `通知` so screenshot evidence
  is deterministic.

## 3. Mock and interaction coverage

Add `NativeUiFixture.states`:

- `secret-masked`
- `stream-repaired`
- `settings-search`

Mock content:

- `secret-masked`: completed user message containing synthetic examples for a
  prefixed token, JWT, URL password and private key. No real credential.
- `stream-repaired`: running assistant message ending in unfinished emphasis,
  link, code and a partial table. The static frame must not expose raw syntax
  that the repair contract removes.
- `settings-search`: settings root opened with query `通知`, showing ranked
  results.

Add one interaction driver
`scripts/device-ui-frontend-hardening-e2e.ps1` covering:

1. Secret default mask, reveal, hide and raw-copy source contract.
2. Streaming repair scene marker and absence of unfinished raw suffix.
3. Settings search input, query results, result navigation and Back.

Register the three states and actions in
`docs/testing/mock-feature-manifest.json`.

## 4. Documentation

- Add this hardening E2E table to the repository index in `AGENTS.md`.
- Add the secret/stream/search rules to the authoritative design-system
  document.
- Reconcile `docs/NATIVE-COVERAGE.md` with actual native surfaces. Use
  `Native`, `Partial`, `Compatibility` and `Pending verification` accurately.
- Keep unresolved device checks in
  `docs/testing/2026-11-01-device-visual-state-acceptance-e2e.md`.

## 5. Tests

Pure model tests in `gateway/test/native-models.test.mjs`:

- all supported token families and boundaries;
- Unicode/newline preservation;
- PEM header/body/end handling;
- URL password-only masking;
- no masking for ordinary prose or low-confidence assignments;
- raw source remains unchanged;
- streaming repair for emphasis, strike, code, links, images, tags, headings,
  lists, fences and tables;
- append/convergence behavior;
- settings normalization, ranking, stable tie order, result limit and
  Chinese/English synonyms.

Source-contract tests:

- production passes `streaming` from message state;
- copy uses raw message text;
- reveal action is available only when secrets exist;
- settings search uses the pure index and opens result pages.

## 6. Commands and gates

```powershell
node scripts/verify-mock-coverage.mjs
node scripts/qa.mjs pr
. .\scripts\resolve-deveco-home.ps1
$ide = Resolve-DevEcoHome
& .\scripts\build-harmony.ps1 -DevEcoHome $ide -Product mock -BuildMode release
& .\scripts\build-harmony.ps1 -DevEcoHome $ide -Product default -BuildMode release
& .\scripts\build-harmony.ps1 -DevEcoHome $ide -Product store -BuildMode release
```

Device runs are valid only when `hdc list targets -v` reports a ready USB
target. UART placeholders are not a phone.
