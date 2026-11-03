# Store showcase refresh device E2E

Date: 2026-11-04

## Device identity

| Field | Value |
| --- | --- |
| Device | `HBN-AL80` / HUAWEI Pura 70 Pro+ |
| Serial | `33Z0224801015621` |
| OS | HarmonyOS `7.0.0.111` SP10C10 |
| Runtime API | `26` |
| Product | Mock |
| Mock HAP SHA-256 | `020CCE74C12198488D896241AC7AA40BE42A0D059FD60B5C8AA7FB946F582FD7` |

## Acceptance

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| SHOT-R1 | Capture pipeline | One command builds/installs Mock, captures every matrix row and writes the manifest | Passed; current Mock HAP, 11 raw scenes and manifest written |
| SHOT-R2 | Mock variety | Conversation, process, lineage, preview and approval scenes use different credible work scenarios | Passed; current device captures reviewed across seven `showcase-*` states |
| SHOT-R3 | List density | Automation and plugin mock inventories render populated lists without large empty states | Passed; current dark automation and plugin captures reviewed |
| SHOT-R4 | Portrait layout | Footer is below the device frame; no text overlaps the phone screenshot | Passed; all 14 portrait composites reviewed at 1080x1920 |
| SHOT-R5 | Typography | Title, subtitle, feature labels and footer remain readable at 1080x1920 | Passed; all portrait composites reviewed after the type/layout refresh |
| SHOT-R6 | Export set | Ten curated 1920x1080 and ten curated 1080x1920 images exist with valid dimensions and size | Passed; 10 AppGallery landscape and 10 AppGallery portrait files validated |
| SHOT-R7 | README | README uses product release voice and points to the refreshed curated assets | Passed; Chinese and English README plus store-artifact README updated |
| SHOT-R8 | Conversation density | Featured marketing conversations show prior context, the active work process and a complete final answer without a large empty region | Passed; light/dark conversation, process and subagent captures reviewed |
| SHOT-R9 | Preview density | Configuration preview contains several readable sections and fills the preview viewport; table fixtures contain at least fifteen populated rows | Passed; corrected preview starts at line 1 and CSV/TSV fixtures contain 21/15 rows |
| SHOT-R10 | Workspace density | File browser root and representative folders expose multiple files and nested directories | Passed; deterministic fixture contains multi-level directories and credible product files |
| SHOT-R11 | Changed-file fold | Marketing cards aggregate at least four changed files, show three rows while collapsed and expose the overflow disclosure | Passed; marketing cards show `再显示 1 个文件` and current approval/card regression passed |

## Evidence

- Capture manifest, device identity, HAP hash and 11-scene matrix:
  `artifacts/store-screenshots/manifest.json`
- Current raw device captures:
  `artifacts/store-screenshots/raw/`
- Fourteen reviewed 1080x1920 and fourteen reviewed 1920x1080 composites:
  `artifacts/store-screenshots/final/`
- Ten AppGallery portrait and ten AppGallery landscape exports:
  `artifacts/store-screenshots/final/appgallery-portrait/` and
  `artifacts/store-screenshots/final/appgallery-landscape/`
- Permission/approval compactness and post-capture process liveness:
  `artifacts/device-e2e/20261104-permissions-approval-density/permissions/manifest.json`
- Final PR QA:
  `.artifacts/qa/20261103T172626Z-fd73a2b7/report.json`

The current evidence proves the API 26 portrait, default-font Mock surface.
Landscape product layouts, API 23, maximum system font, real accounts and live
Host streams remain outside this run.
