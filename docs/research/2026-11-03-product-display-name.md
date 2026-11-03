# Product Display Name Research

Date: 2026-11-03

## Current Shape

The app already has target-specific `ProductCapabilities.ets` files for
Passkey and Mock behavior. `BuildInfo` is the shared runtime metadata surface,
and the launcher uses `$string:app_name` from the shared AppScope resources.

The existing source had `DSH Harmony` literals in launch, settings, workspace,
widget, notification, image-save and deterministic fixture code. The launcher
resource also had a single shared value. Renaming only the launcher would leave
store builds with mixed identity.

## Design Choice

Use the existing product source-root mechanism for the runtime name. This keeps
the build variant contract in the same place as other product differences and
avoids a second capability table. `BuildInfo` is the single runtime projection
used by ArkUI components and services.

The launcher resource cannot select a target-specific value through the
current shared `AppScope` resources. The existing build script is the narrow
integration point: it can read the selected product source, update the one
resource entry for the duration of the build, and restore it afterward.

## Boundaries

The following remain stable:

- `io.github.stlin256.dshharmony`;
- `github.com/stlin256/DSH-Harmony`;
- `@dsh-harmony/plugin`;
- `dsh-harmony-plugin-<version>.tgz`;
- technical console identifiers.

The AppGallery submission name is a product display concern, not a reason to
rename the repository or protocol package.
