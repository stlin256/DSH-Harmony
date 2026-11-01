# DSH Harmony Mobile

![DSH Harmony](AppScope/resources/base/media/app_icon.svg)

[简体中文](README.md)

The HarmonyOS native project lives here. The repository root README covers the product, login, plugin and notifications; this page focuses on builds and signing.

## Products

| Product | Push Kit | Background notifications | Use |
| --- | --- | --- | --- |
| `default` | Included | Delivered by Push Kit | Maintainer build; the server plugin sends pushes with the project service account |
| `store` | Push Kit SDK excluded | Optional monitoring for active tasks | AppGallery and regular developer builds |
| `mock` | Excluded | Not applicable | Frontend development and device automation; deterministic local data with no network |

All three products are named **DSH Harmony** and use bundle name `io.github.stlin256.dshharmony`. Register this app in Huawei Developer Console before requesting app signing or Push Kit capabilities. This repository does not contain signing material, service accounts or developer credentials.

## Build locally

1. Install DevEco Studio with SDK 26.
2. Copy `build-profile.example.json5` to the ignored local `build-profile.json5` and configure signing. Keep private keys outside Git.
3. Run from the Harmony project directory:

```sh
devecocli signature generate --product default
devecocli signature generate --product store
devecocli signature generate --product mock
devecocli build --product default --build-mode release
devecocli build --product store --build-mode release
devecocli build --product mock --build-mode release
```

Install on the connected device with `devecocli run --module entry@default --product default --build-mode release --skip-build`. The Mock artifact is `entry/build/mock/outputs/mock/entry-mock-signed.hap`.

Every build must pass:

```sh
node ../scripts/verify-mock-coverage.mjs
```

Every user-visible frontend feature must add a deterministic Mock state, a visual or interaction driver, an entry in `docs/testing/mock-feature-manifest.json`, and device E2E rows. The coverage gate rejects production UI work without that evidence.

## Notifications

The server plugin stores task names and a status-only projection. The `default` build uses Push Kit for completion, failure and approval reminders. The `store` build does not request Push Kit tokens. If the user enables “Monitor active tasks in background,” it requests a visible long-running task only while a task is active, polls the status, then stops. Tapping a notification opens its session.

Never commit real service URLs, credentials, signing profiles or Push Kit service-account files.
