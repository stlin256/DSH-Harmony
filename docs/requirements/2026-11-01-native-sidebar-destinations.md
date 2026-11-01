# Native sidebar destinations

Date: 2026-11-01

## Requirement

The three global sidebar entries must open complete native HarmonyOS
surfaces:

- Plugins opens a native bundle and plugin manager.
- Automation opens a native task catalog, detail and editor.
- More opens a native anchored action menu.

The current `功能未开放` placeholder is not an acceptable fallback for any of
these entries.

## Product behavior

### Plugins

The page must show the Host's installed and installation-provided bundles and
their plugin rows. It must support:

- compact search, loading, empty, unavailable and error states;
- bundle detail with localized name, description, version, source and rows;
- bundle and row enablement;
- inspection and installation of a package spec;
- update checks and update installation where the Host marks a bundle
  updatable;
- removal with confirmation;
- restart-required, pending build-script approval, cancelled and failed
  outcomes.

The first native release does not present a remote plugin marketplace. It
exposes the canonical DSH bundle inventory and the package install path already
provided by the Host.

### Automation

The page must use the Host schedule catalog rather than a local-only list. It
must support:

- status filtering for active, paused, ended and all tasks;
- search by title, instruction, session id and rule summary;
- a compact task row sorted by next occurrence;
- native detail with rule and delivery-history views;
- create and edit for one-shot, fixed interval, daily, weekly and cron rules;
- destination choices for an existing session, one reusable new session and a
  fresh session per delivery;
- pause, resume, run now and delete;
- revision conflicts and malformed-input errors without silently discarding a
  draft.

### More

More follows the upstream semantic: it is an anchored menu of secondary
destinations, not a fourth full-page section. It stays attached to the drawer,
contains only actions that the native app can execute, and dismisses without
leaving stale overlays.

## Navigation and state

- Opening Plugins or Automation keeps the logical drawer origin. Back closes
  nested plugin/automation surfaces first, then the destination page, and
  finally returns to the open drawer.
- Returning from More uses the drawer itself, with no unrelated root hop.
- System Back and visible navigation affordances share the same stack.
- Loading does not replace cached content when a safe cached snapshot exists.
- Destructive actions require confirmation.
- Unsaved automation edits require discard confirmation.

## Gateway boundary

Native operations remain fixed POST operations under
`/pocket/api/native/operation`. The gateway must not expose a generic Remote
proxy. It validates and bounds every plugin and schedule argument, normalizes
all response fields consumed by ArkUI, strips diagnostics that are not needed
for the user action, and maps stable conflict and input codes.

## Visual and motion direction

The surfaces use the existing DSH Harmony design tokens:

- compact 44–48 vp rows with precise outline or quiet field surfaces;
- DeepSeek blue only for primary actions, selection and focus;
- business glyphs with theme-aware tinting;
- immediate press feedback and interruptible navigation;
- one spatial navigation motion per page transition;
- disclosure and operation-result transitions use shared motion tokens;
- reduced motion resolves directly to final state.

## Out of scope

- A third-party plugin marketplace.
- Plugin-specific configuration forms that have no safe native schema.
- Live event subscriptions for plugin and schedule changes. The first version
  refreshes after mutations and exposes manual retry/refresh.

