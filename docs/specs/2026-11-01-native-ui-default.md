# Native UI startup implementation spec

## Resolution model

Add a dependency-free `UiModePreference` service with two inputs:

- saved mode (`native`, `compatibility`, absent or invalid);
- whether the one-time default migration already completed.

Resolution rules:

1. Every valid product resolution is `native`.
2. With no completed migration, the mode and migration marker are persisted.
3. Missing, invalid or legacy compatibility values always repair to native.
4. Compatibility is no longer accepted by the native mode preference or the
   trusted `uiMode` bridge command.

The current markers are:

- mode: `uiMode`;
- migration completion: `uiModeDefaultMigratedV2`.

## Startup

`Index` starts with an in-memory default of `native`. After opening preferences,
it passes the stored mode and migration marker through
`UiModePreference.resolve`, applies native mode to `AppStorage`, and persists
the repaired mode when needed. This happens before connection restoration or
the first native workspace paint decision.

No connection, cache or authentication state is touched by the migration.

## Explicit selection

The application-settings mode picker is removed. The trusted `PocketBridge`
`uiMode` command accepts only `native`; a compatibility request is rejected.
The full-page Web surface is retained for the Passkey authentication state and
is not available as a general product mode.

## Verification

- Unit tests cover fresh install, legacy compatibility migration, restart after
  migration, invalid values and native-only bridge validation.
- ArkTS source contracts verify the native default and startup resolver are
  wired before connection restoration and verify the compatibility picker is
  absent from native settings.
- Builds cover both community and store Release variants.
- The community Release is installed on the phone and cold-start behavior is
  checked with HDC screenshot and layout evidence.

