# DSH Go-inspired frontend hardening E2E

Date: 2026-11-02

Requirement:
[`2026-11-02-dsh-go-frontend-hardening.md`](../requirements/2026-11-02-dsh-go-frontend-hardening.md)

Implementation spec:
[`2026-11-02-dsh-go-frontend-hardening.md`](../specs/2026-11-02-dsh-go-frontend-hardening.md)

Status: Implementation in progress. Source/model and Mock mapping can pass
before device evidence exists. Physical-device rows remain Pending until the
current HAP is installed on a ready USB target and the listed action is observed.

## Device matrix

| Field | Required |
| --- | --- |
| Device | HUAWEI Pura 70 Pro+ or another HarmonyOS phone with USB debugging |
| Runtime | API 26 current device; API 23 remains separate |
| Theme | Dark default; light for regression |
| Text size | Default and maximum system size |
| Input | Touch and system Back |
| Evidence | JPEG/PNG captures, layout dump, interaction manifest, HAP SHA-256 |

## Current build identity

| Variant | Signed HAP | SHA-256 |
| --- | --- | --- |
| Mock | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` | `B76B79DFA915E7C15999E96E85C38F2DC7DB6EBF8402BD28E6F89105808D10A4` |
| Default | `harmony/entry/build/default/outputs/default/entry-default-signed.hap` | `4B9C2744CAF860FCD6AFAE63066CAAF2595DC0780047541146AF78171C0503A0` |
| Store | `harmony/entry/build/store/outputs/store/entry-store-signed.hap` | `A45FF01AB08A44EDE7E6BDE72B4BB18AF078BA56198F2402BC4007BA29F0DF9F` |

Source, model, coverage and Release gates passed in PR QA
`.artifacts/qa/20261102T121812Z-6a461bee/report.json`. Device rows remain
Pending because the latest HDC target query returned `[Empty]`.

## Acceptance table

| ID | Surface | Required check | Status |
| --- | --- | --- | --- |
| FHH-01 | Completed user message with synthetic token/JWT/private key/URL password | Credentials are masked on first paint, including a token that crosses the virtual text-window boundary; surrounding text remains readable; no horizontal overflow | Pending |
| FHH-02 | Secret reveal action | Eye action reveals the selected message, label changes to hide, second tap masks again, layout does not jump | Pending |
| FHH-03 | Secret copy source | Long-press copy yields the original raw synthetic value, never the masked display | Pending |
| FHH-04 | Streaming inline Markdown | Unfinished emphasis, strike, code and link do not flash raw markers; closer arrival converges without a layout jump | Pending |
| FHH-05 | Streaming block Markdown | Partial table, heading/list marker and fence opening do not flash as malformed content | Pending |
| FHH-06 | Settings search closed | Root keeps compact 44vp search field and existing grouped index at default/max text size | Pending |
| FHH-07 | Settings search results | Chinese and English queries return ranked rows; title/path do not overlap; no-result state is compact | Pending |
| FHH-08 | Settings result navigation | Selecting a result opens the owning page; Back returns to the settings root with a usable search field | Pending |
| FHH-09 | Light theme | Search, masked inline values and reveal action remain legible and keep exact geometry | Pending |
| FHH-10 | Accessibility | Search field, clear action, result row and reveal/hide action have useful screen-reader labels and 44vp touch targets | Pending |

## Static Mock scenes

| Scene | Screen | State | Theme | Required marker |
| --- | --- | --- | --- | --- |
| FHH-S01 | conversation | secret-masked | dark | `凭据已遮蔽` |
| FHH-S02 | conversation | secret-masked | light | `凭据已遮蔽` |
| FHH-S03 | conversation | stream-repaired | dark | `流式 Markdown` |
| FHH-S04 | conversation | stream-repaired | light | `流式 Markdown` |
| FHH-S05 | settings | settings-search | dark | `搜索设置` |
| FHH-S06 | settings | settings-search | light | `搜索设置` |

Long-stream liveness has a separate animated Mock scene and device driver:
`stream-long` / `scripts/device-ui-stream-long-e2e.ps1`. Its rows are `LSR-01`
through `LSR-04` in
[`2026-11-02-long-stream-render-liveness-e2e.md`](2026-11-02-long-stream-render-liveness-e2e.md).

## Interaction manifest

Driver: `scripts/device-ui-frontend-hardening-e2e.ps1`

Expected manifest fields:

```text
device
hapSha256
secret.firstPaintMasked
secret.revealed
secret.hiddenAgain
secret.copySourceRaw
stream.noUnfinishedSuffix
settings.queryEntered
settings.resultOpened
settings.backReturned
```

## Current blockers

- At implementation start, `hdc list targets -v` reports only UART
  placeholders (`COM3`, `COM4`) and no ready USB HarmonyOS target.
- No physical-device row may move from Pending until a current Mock HAP is
  installed and the interaction driver emits matching evidence.
- API 23, landscape, real account and live Host reconnect remain outside this
  feature's Mock proof.
