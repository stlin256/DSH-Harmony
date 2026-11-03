# Product Display Name E2E

Date: 2026-11-03

Requirement:
[`2026-11-03-product-display-name.md`](../requirements/2026-11-03-product-display-name.md)

Implementation spec:
[`2026-11-03-product-display-name.md`](../specs/2026-11-03-product-display-name.md)

## Rows

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| NAME-U01 | Run source and model contracts | Default/Mock use `DSH Harmony`; store uses a non-empty name without case-insensitive `Harmony`; `BuildInfo` consumes the product field | Passed by `node --test gateway/test/native-models.test.mjs` |
| NAME-U02 | Build community, store and Mock Release variants | All variants build; source launcher resource is restored byte-for-byte after each run | Passed: community `29a4a238…`, store `69a99911…`, Mock `751b9748…` |
| NAME-U03 | Inspect store HAP launcher resource | Launcher label is `DSH Mobile` and contains no `Harmony` | Passed: store `resources.index` contains `DSH Mobile` and neither `DSH Harmony` nor `DSH HARMONY` |
| NAME-01 | Launch default build on device | Welcome, iteration notice, sidebar, About, widget and notification copy show `DSH Harmony` | Pending device |
| NAME-02 | Launch store build on device | Launcher, welcome, iteration notice, sidebar, About, widget and notification copy show `DSH Mobile` | Pending device |
| NAME-03 | Open image save flow in store build | Save dialog title prefix is `DSH-Mobile-`; no `Harmony` is visible | Pending device |
| NAME-04 | Open the Mock disclosure/showcase fixture | Fixture workspace title is `DSH Harmony 移动端`; no unexpected product rename occurs | Pending device |

## Driver

No new interaction driver is required for the rename itself. The existing
launch, About, widget and notification Mock scenes are the driver surfaces.
Run the product build script for each variant, then use the connected-device
test harness to capture the rows above. Do not mark device rows passed without
the matching HAP hash and screenshots.
