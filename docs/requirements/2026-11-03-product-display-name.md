# Product Display Name Requirement

Date opened: 2026-11-03

Status: implemented; source contracts, model tests and all three Release build
variants passed. Device rows remain pending until the phone is connected again.

## User Requirement

- `NAME-REQ-01` AppGallery does not allow the app display name to contain
  `Harmony`. The store product must use a store-safe display name.
- `NAME-REQ-02` The display name must be variableized in every user-visible
  app location so changing one product configuration is sufficient.
- `NAME-REQ-03` The default and Mock products continue to use `DSH Harmony`.
  The store product uses `DSH Mobile`.
- `NAME-REQ-04` The launcher label, first-launch surfaces, workspace header,
  About settings, widgets, notifications, image-save title and deterministic
  Mock fixtures use the same product display name.
- `NAME-REQ-05` Technical identifiers remain stable: bundle name, repository
  URL, npm package name and plugin package name must not be renamed.
- `NAME-REQ-06` Product builds must synchronize the launcher `app_name`
  resource from the selected product configuration and restore the source
  resource after the build, including on failure.

## Constraints

- This is a display-name configuration, not a second app identity.
- Do not introduce a separate visual language or a new navigation surface.
- Long store names must remain safe in existing compact controls; do not rely on
  the current `DSH Harmony` width.
- Source and test artifacts must not contain private hosts, credentials or
  transcript content.

## Acceptance

- Default and Mock display `DSH Harmony`; store displays `DSH Mobile` and has no
  case-insensitive `Harmony` substring in its display-name value.
- `BuildInfo.appName` resolves from `ProductCapabilities.appDisplayName`.
- A store Release HAP has the store launcher label and store-safe in-app copy.
- Launcher resource restoration is verified after both successful and failed
  builds.
- Source contracts cover the variant field, launcher synchronization, and the
  user-visible consumers.
- Device evidence is recorded before any device row is marked passed.
