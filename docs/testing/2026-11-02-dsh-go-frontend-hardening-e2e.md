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
| Mock | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` | `2C39478C519C9D29C08031A596A001862F078240B26D918B28F5058F1D57F781` |
| Default | `harmony/entry/build/default/outputs/default/entry-default-signed.hap` | `AD2127415A83DAB218D20F382B05BA2824E6DE65975CD38FE49D269E574FA881` |
| Store | `harmony/entry/build/store/outputs/store/entry-store-signed.hap` | `58E2D2E7DAC259DF53501416E8A4F571372A756533F53CDB11583BBF3D206034` |

Source, model, coverage and Release gates passed in PR QA
`.artifacts/qa/20261102T054907Z-09edfb22/report.json`. Device rows remain
Pending because HDC currently reports only UART placeholders `COM3` and `COM4`.

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
