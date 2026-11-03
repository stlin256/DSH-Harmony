# Device UI Mock and Bottom Dock E2E

Date: 2026-11-01

Device: Huawei `HBN-AL80`, HarmonyOS API 26, HDC `33Z0224801015621`

Fixture build: dedicated Mock Release. Historical evidence below was captured
before the product split and therefore does not prove the new Mock artifact;
the current product checklist remains pending in
[`2026-11-01-mock-variant-coverage-e2e.md`](2026-11-01-mock-variant-coverage-e2e.md).

## Automated evidence

The final suite ran against the rebuilt community Release HAP. All 11 selected
screen/state/theme combinations passed from a clean force-stop each time.
`artifacts/device-ui-mock/suite-summary.json` is the machine-readable run
summary.

| ID | Scenario | Expected | Result |
| --- | --- | --- | --- |
| DOCK-01 | `conversation/live-change/dark` | Live-change pill, composer and actions are inside the display; transcript remains visible | Passed; dock `[40,2315][1220,2844]`, composer `TextArea [108,2498][1153,2647]` |
| DOCK-02 | `conversation/live-change/light` | Same geometry and contrast after a theme change | Passed; dock and composer bounds match dark mode |
| DOCK-03 | `conversation/attachments/dark` | Two attachment chips, live-change pill, composer and stop action remain reachable while the natural dock grows upward | Passed; attachment tray, composer and actions remain fully visible |
| DOCK-04 | `conversation/streaming/light` | Streaming content does not move the dock outside the safe area | Passed; composer and model toolbar visible |
| DOCK-05 | `conversation/empty/dark` | A running turn with no transcript rows still reaches foreground and keeps the composer visible | Passed; startup handshake waits for a non-empty `pages/Index` layout tree |
| DOCK-06 | `conversation/long-history/light` | Long transcript ends at the stable dock and latest rows remain reachable | Passed |
| MOCK-01 | Invalid launch parameters | Unknown values normalize to a safe fixture value | Passed in model tests |
| MOCK-02 | Normal launch | Fixture client is never selected without `storeShowcase=true` | Passed in source contract tests |

## Device surfaces

| ID | Scenario | Expected | Result |
| --- | --- | --- | --- |
| SURFACE-01 | `process/completed/dark` | Process and plan rows render without terminating the app | Passed |
| SURFACE-02 | `sidebar/completed/dark` | Drawer overlay, search, groups and pinned sessions render | Passed |
| SURFACE-03 | `browser/completed/light` | Root folders precede files and download actions remain visible | Passed |
| SURFACE-04 | `settings/completed/dark` | Settings root renders in the safe area with no horizontal overflow | Passed |
| SET-01 | Open DSH settings and return | Secondary page opens and Back returns to the settings root | Passed |
| SET-02 | Open appearance and motion | Theme choices and both effect toggles are present and enabled | Passed |
| SET-03 | Toggle reduced motion | The selected state changes immediately and remains after leaving and reopening the page | Passed; full-row hit target used |
| SET-04 | Toggle reduced transparency | The selected state changes immediately and remains after leaving and reopening the page | Passed; switch hit target used |
| SET-05 | Switch light -> dark | Theme controls update selection without leaving the appearance page | Passed |
| SET-06 | Open every settings detail page | DSH, notifications, cards, storage, service/account and About open and Back returns to root | Passed |
| SET-07 | Change notification and card preferences | A notification level, background monitor and task-name switch reach the requested states | Passed |
| SET-08 | Inspect DSH settings | Connected plugin version is shown as `v0.3.6` | Passed |
| TFC-DEVICE-01 | Completed four-file turn | Card shows aggregate totals, the first three rows and an overflow row | Passed |
| TFC-DEVICE-02 | Expand and collapse four-file card | All files appear; collapse restores `再显示 1 个文件` | Passed |
| TFC-DEVICE-03 | Open a changed-file row | Read-only preview opens; Back returns to the same expanded card | Passed |

## Commands

```powershell
.\scripts\device-ui-mock-suite.ps1 `
  -Device 33Z0224801015621 `
  -SkipBuild

.\scripts\device-ui-settings-e2e.ps1 `
  -Device 33Z0224801015621 `
  -SkipBuild -SkipInstall

.\scripts\device-ui-turn-change-e2e.ps1 `
  -Device 33Z0224801015621 `
  -SkipBuild -SkipInstall
```

Screenshots, ArkUI bounds, process ID, bundle version and layout assertion
output are stored under `artifacts/device-ui-mock/<state>-<theme>-<screen>/`.
Settings interaction evidence is under
`artifacts/device-ui-settings-e2e/appearance-persistence/`; turn-change evidence
is under `artifacts/device-ui-turn-change-e2e/completed-card/`.

## Environment-bound checks

The following existing E2E rows still require their real dependency and are not
claimed by this fixture run: Passkey confirmation, notification delivery after
process termination, system image/document pickers, private Host reconnect,
stream reconnect convergence, cross-account cache isolation, API 23 material
fallback, PDFKit rendering, real plugin installation in a private profile, and
AppGallery/cloud-test results. These remain **Environment pending**; neither a
successful build nor a Mock screenshot is treated as device proof for them.
