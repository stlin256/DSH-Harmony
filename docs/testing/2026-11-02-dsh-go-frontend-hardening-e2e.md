# DSH Go-inspired frontend hardening E2E

Date: 2026-11-02

Requirement:
[`2026-11-02-dsh-go-frontend-hardening.md`](../requirements/2026-11-02-dsh-go-frontend-hardening.md)

Implementation spec:
[`2026-11-02-dsh-go-frontend-hardening.md`](../specs/2026-11-02-dsh-go-frontend-hardening.md)

Status: Passed on API 26 at the default system font size for the current Mock
HAP. Maximum system font size and live-Host reconnect remain separate gaps.

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
| Device-qualified Mock | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` while tested | `F23693248955498EC90306DC2D1942D2DC30F440FE449D73DDB9592FE59412CD` |
| Final default Release | `harmony/entry/build/default/outputs/default/entry-default-signed.hap` | `43E3466D0C878A07C673899B2B213E6348A0DC0424BA032E16C080D31D880E08` |
| Final store Release | `harmony/entry/build/store/outputs/store/entry-store-signed.hap` | `2BC7E88367F6CAD626954CDA7F9FC72FB6324702E9C6EE9AAFEFD0168DB9A6E6` |
| Final Mock Release | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` | `EED9CAB2AC4ACC6B81AAF715B5D76D5E0A1D178557A9EF03BB337805052980F3` |

The final release rebuild has the same product source as the device-qualified
Mock artifact. Do not relabel a rebuilt unsigned-signature hash as the exact
interaction evidence above.

## Acceptance table

| ID | Surface | Required check | Status |
| --- | --- | --- | --- |
| FHH-01 | Completed user message with synthetic token/JWT/private key/URL password | Credentials are masked on first paint; surrounding text remains readable; no horizontal overflow | Passed |
| FHH-02 | Secret reveal action | Eye action reveals the selected message, label changes to hide, second tap masks again, layout does not jump | Passed |
| FHH-03 | Secret copy source | Copy path remains the original raw synthetic value, never the masked display | Passed source contract |
| FHH-04 | Streaming inline Markdown | Unfinished inline markers do not flash as raw syntax; repaired content remains bounded | Passed |
| FHH-05 | Streaming block Markdown | Partial table/fence states are held back and the final fixture has no unfinished suffix | Passed |
| FHH-06 | Settings root | No search field or search placeholder remains; grouped navigation is the only root mode | Passed |
| FHH-07 | Settings groups | DSH Harmony and application groups remain compact without overlap or dead space | Passed |
| FHH-08 | Settings navigation | Each grouped row opens its owning page and Back returns to the grouped root | Passed |
| FHH-09 | Light theme | Masked values, reveal action and grouped settings remain legible | Passed via static paired captures |
| FHH-10 | Accessibility | Reveal/hide and settings rows retain useful labels and 44vp targets | Partial; source semantics pass, maximum text remains Pending |

## Static Mock scenes

| Scene | Screen | State | Theme | Required marker |
| --- | --- | --- | --- | --- |
| FHH-S01 | conversation | secret-masked | dark | `凭据已遮蔽` |
| FHH-S02 | conversation | secret-masked | light | `凭据已遮蔽` |
| FHH-S03 | conversation | stream-repaired | dark | `流式 Markdown` |
| FHH-S04 | conversation | stream-repaired | light | `流式 Markdown` |
| FHH-S05 | settings | completed | dark | grouped index with no `搜索设置` |
| FHH-S06 | settings | completed | light | grouped index with no `搜索设置` |

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
settings.searchAbsent
settings.groupedNavigationVisible
```

## Current evidence

`artifacts/device-e2e-final/frontend-hardening-clean/secret-stream-settings/manifest.json`
records the exact HAP hash, masked/revealed/hidden states, stream repair and
search absence. The reviewed images are in the same directory.

## Remaining blockers

- API 23, landscape, maximum system font size, real account and live Host
  reconnect remain outside this feature's Mock proof.
