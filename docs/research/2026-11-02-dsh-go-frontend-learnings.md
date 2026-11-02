# DSH Go frontend learnings

Date: 2026-11-02

Reference: local DSH Go checkout at the pinned commit below

Pinned commit: `5f29f5d283c2501b4e5f1c1596f94700a010566b`

Remote: `https://github.com/ccch1mneyyy/dsh-Go.git`

## Scope

This review compares frontend engineering behavior, not visual identity. The
reference is a Flutter application; DSH Harmony is native ArkUI. A useful idea
must therefore survive a translation into pure ArkTS models, ArkUI components
and the project's existing Mock/device evidence workflow.

## What is worth adopting

### Display-only secret masking

DSH Go keeps sent text raw while replacing recognized credential spans with a
masked display. Its interaction reveals a value without changing copy or model
input. The matcher covers high-confidence provider prefixes, JWT, PEM private
key blocks and URL passwords.

DSH Harmony adoption:

- Keep raw `NativeMessage.text` and `NativeMessage.blocks`.
- Add a pure matcher that returns stable source spans and display text.
- Mask only at the render boundary.
- Add one compact reveal/hide action per completed message.
- Use a monospace inline style for masked spans.

### Streaming Markdown tail repair

DSH Go repairs only the unfinished last block before the Markdown parser sees
it. This prevents raw `**`, backticks, link destinations and table pipes from
flashing before the parser can style them. It does not play token entrance
animations.

DSH Harmony adoption:

- Add a pure `NativeStreamMarkdown` service.
- Keep completed and stored text untouched.
- Parse the repaired display value while streaming.
- Verify that appending the closer converges to the completed parse.

### Settings as searchable data

DSH Go has a settings index with stable targets, bilingual titles, synonyms,
historical names and path terms. Search normalization folds full-width ASCII
and whitespace. Ranking is deterministic and ties preserve index order.

DSH Harmony adoption:

- Move the visible destination metadata into a pure index.
- Search page and row entries in Chinese and English.
- Navigate result selection to the owning page.
- Keep the current grouped root layout and compact row heights.

### High-density behavioral tests

DSH Go combines pure model tests, geometry tests, semantics checks, light/dark
goldens, large-text cases and screenshot evidence. The useful lesson is the
test shape, not Flutter-specific golden infrastructure.

DSH Harmony adoption:

- Add pure ArkTS service tests through the existing TypeScript transpile loader.
- Add source contracts for production wiring.
- Add deterministic Mock states and screenshot scenes.
- Add real-device interaction rows for every new action.

### Explicit risk and destructive-action language

DSH Go uses confirmation models for actions that widen permissions or remove
data. DSH Harmony already uses system confirmation for cache clear and logout.
Keep that behavior and continue to review future settings actions for the same
risk boundary.

## What is not adopted

- Flutter widget structure and provider layout.
- DSH Go branded pet, whale, glass and illustration language.
- Phosphor icon geometry and one-off rounded pill treatment.
- Additional theme palettes that would dilute DSH Harmony's restrained neutral
  surfaces and single DeepSeek-blue action accent.
- Broad form/input support without a protocol contract, validation, retry and
  device interaction matrix.
- WebView or decorative shortcuts that would claim native coverage before the
  behavior exists.

## Current DSH Harmony evidence

Relevant existing implementation:

- `NativeMessageView.ets` renders user/assistant/tool messages and owns
  long-press copy.
- `NativeInlineMarkdown.ets` parses complete inline runs safely.
- `NativeDocumentModel.ets` supports headings, quotes, tables and fenced code.
- `NativeSettings.ets` owns a native grouped settings root and seven destination
  pages.
- `NativeWorkspace.ets` contains the production conversation shell.
- `storeShowcase` supplies deterministic fixture content.
- `gateway/test/native-models.test.mjs` executes pure ArkTS services under Node.

## Architecture observations

- `NativeWorkspace.ets` is roughly 3.7k lines and owns navigation, transcript,
  stream state, file preview requests, composer and dock behaviors.
- `NativeSettings.ets` is roughly 1k lines and owns seven pages plus local
  settings, host settings, storage and account actions.
- File size alone is not a defect. The risk is that new pure rules become
  trapped inside a component and cannot be tested without ArkUI.
- The first mitigation is therefore to extract secret matching, stream repair
  and settings search as pure services. A broad file split should be scheduled
  separately with regression tests.

## Pinned upstream boundary

The project's Harness interaction reference remains pinned in
`docs/NATIVE-INTERACTION-SPEC.md`. DSH Go is an adjacent frontend reference, not
an upstream identity or protocol source. Recheck the pinned Harness revision
before making equivalence claims.
