# Store showcase screenshot E2E

Date: 2026-11-03

Historical status: superseded on 2026-11-04 by
[`2026-11-04-store-showcase-refresh-e2e.md`](2026-11-04-store-showcase-refresh-e2e.md).
The newer run replaced the settings-only light scene with a dedicated approval
scene, retained settings as scene 11, expanded the fixture content and changed
the export count. This table is retained as the earlier baseline; use the newer
document for current asset names, counts and HAP identity.

Device: `HBN-AL80`, serial `33Z0224801015621`, HarmonyOS API `26`.

Mock Release HAP SHA-256:
`FE5AEF43AFA733BE726A36BCF5627E7396ADAF16F90D6B6DAC8267CAD01ADF18`.

| ID | Scenario | Expected | Evidence |
| --- | --- | --- | --- |
| SHOT-01 | Build Mock and community Release products | Signed Mock and community HAPs build successfully | Passed; Mock build completed before capture, and community Release `0.4.7` (`versionCode 28`) was reinstalled afterward with `debug: false` |
| SHOT-02 | Normal app launch | No fixture client or synthetic content is selected without showcase routing | Passed by build and source inspection; the installed community Release was launched after capture |
| SHOT-03 | Capture conversation and floating task plan, light | Native conversation opens with deterministic plan-overlay content and no clipping | Passed; `raw/01-conversation-light.png` and both composed orientations inspected |
| SHOT-04 | Capture complete work process, light and dark | Expanded work process and result render in first-appearance order | Passed; `raw/02-process-light.png` and `raw/07-process-dark.png` inspected after switching from a collapsed fixture-only view to the product process scene |
| SHOT-05 | Capture plan and subagent lineage, light | Lineage sheet opens over the selected session with known and unavailable modes | Passed; `raw/03-lineage-light.png` and composed orientations inspected |
| SHOT-06 | Capture workspace file preview, light | A configuration file opens directly with its path, line numbers and readable text | Passed; `raw/04-preview-light.png` and composed orientations inspected |
| SHOT-07 | Capture settings, light | Native settings opens without login or private host | Passed; `raw/05-settings-light.png` and composed orientations inspected |
| SHOT-08 | Capture dark plan and subagent title | Plan state and subagent count remain legible in the title and conversation | Passed; `raw/06-conversation-dark.png` and composed orientations inspected |
| SHOT-09 | Capture continuable subagent, dark | Subagent context, read-only/continuable state and composer render correctly | Passed; `raw/08-subagent-dark.png` and composed orientations inspected |
| SHOT-10 | Capture automation and plugins, dark | Native automation rows and plugin controls render with readable status hierarchy | Passed; `raw/09-automation-dark.png` and `raw/10-plugins-dark.png` inspected |
| SHOT-11 | Compose all artwork | Ten listing scenes plus paired appearance, desktop cards and open source are generated in both orientations | Passed; 26 PNGs generated, including ten curated images in each AppGallery upload folder |
| SHOT-12 | Review composed output | Text remains inside its container; punctuation does not start a new line; device framing does not obscure content | Passed after full-size review; punctuation wrapping was corrected and `03-lineage-light-1080x1920.png` was re-inspected |
| SHOT-13 | Validate artwork files | Every PNG has expected dimensions and is below 5 MB | Passed programmatically for all 26 PNGs |
| SHOT-14 | Privacy scan | No deployment host, account, cookie, token or real transcript appears in output | Passed by source and output review; only synthetic product content is present |
| SHOT-15 | Confirm README product copy | README does not mention compatibility mode or two-product switching | Passed; Chinese and English README searches return no matches |
