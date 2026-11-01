# Native UI startup requirement

Date: 2026-11-01

## Problem

The personal Release build is installed correctly, but the application opens
the compatibility WebView instead of the native workspace. The persisted
`uiMode` key is absent on the affected device, and both the initial ArkUI state
and preference fallback currently resolve to `compatibility`.

## Requirements

- `NATIVE-DEFAULT-01` A fresh installation opens the native HarmonyOS
  workspace after successful authentication.
- `NATIVE-DEFAULT-02` An existing installation with no saved `uiMode` migrates
  to native mode once, then records that the migration occurred.
- `NATIVE-DEFAULT-03` A legacy saved `compatibility` value without an explicit
  choice marker is treated as the historical default and migrates once to
  native mode.
- `NATIVE-DEFAULT-04` Compatibility mode is withdrawn from the product UI and
  is no longer accepted from the trusted web bridge. Authentication WebViews
  remain available only for Passkey completion.
- `NATIVE-DEFAULT-05` Invalid, missing or legacy compatibility mode values fail
  closed to native and
  are repaired in preferences.
- `NATIVE-DEFAULT-06` The migration never clears the service address, login
  mode, cookies, transcript cache, workspace cache or notification settings.
- `NATIVE-DEFAULT-07` Removing the mode switch does not remove the login-method
  picker or Passkey/authentication flows.

