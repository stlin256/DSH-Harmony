# Device UI mock and bottom dock resilience specification

Date: 2026-11-01

Requirement:
[`2026-11-01-device-ui-mock-e2e.md`](../requirements/2026-11-01-device-ui-mock-e2e.md)

## 1. Launch parameter isolation

`EntryAbility` validates and copies these bounded optional parameters into
`AppStorage`:

```text
storeShowcase=true
showcaseScreen=conversation|process|sidebar|browser|settings
showcaseState=completed|live-change|attachments|streaming|empty|long-history
showcaseTheme=light|dark|system
```

The dedicated `mock` product sets `storeShowcase=true` automatically through
`ProductCapabilities.supportsMockFixtures`. Community and store launches require
the explicit flag and otherwise keep the real client.

## 2. Fixture states

`StoreShowcaseClient` receives the selected fixture state in its constructor.
The state changes only its in-memory session model, draft tray and follow
snapshot:

- `completed`: completed release-check conversation with one successful
  four-file edit so the final changed-files card, overflow row and file-preview
  action can be exercised deterministically.
- `live-change`: a running turn with one successful synthetic file edit. The
  live aggregation must expose the live file-change pill.
- `attachments`: the running live-change conversation plus two ready generic
  file attachment drafts. This combines the live-change pill, attachment tray,
  composer, return-to-bottom control and safe-area geometry in one frame.
- `streaming`: a running answer with reasoning, one completed tool row and
  streamed assistant text.
- `empty`: an active running turn before any transcript row is visible.
- `long-history`: at least 80 lightweight rows for list, cache and scroll
  checks.

All fixtures use the existing `NativeHarnessClient` interface. No test-only
branches are added inside `NativeWorkspace`.

## 3. Bottom dock geometry

The bottom area remains part of the conversation column:

```text
header
transcript (layoutWeight 1)
interactions
NativeBottomConversationDock
```

The dock keeps one measured natural-height owner. The live-change row and
attachment tray may change that height; only the transcript's weighted region
may absorb the change. The dock itself must not use a top-edge translation,
fixed vertical position, percentage height or duplicate composer space.

The material layer must follow the measured content height. It must not use a
percentage-height child inside the unconstrained dock `Stack`: ArkUI expands
that child to the remaining page height, taking the complete dock from
`y=2315..2844` to `y=317..3020` when the live pill first appears. The blur
surface therefore uses the measured dock height while the content `Column`
continues to own the intrinsic size.

The `NativeTurnChangePill` row has an explicit compact height and no conflicting
minimum height. The inner composer keeps its natural height. The dock's only
bottom inset is
`NativeDesign.navigationBarMinInset`, where `nativeSafeBottom` is never lower
than 20vp. With the IME visible the composer switches to the dedicated 12vp gap.

## 4. Runtime regression guard

The live-change fixture is the canonical reproduction:

1. Launch `conversation` plus `live-change`.
2. Wait for the running turn to render.
3. Dump ArkUI bounds.
4. Assert the dock, text area, model selector and send/stop control are all
   inside `[0, displayHeight - safeBottom]`.
5. Assert no negative vertical translation is applied to the dock.
6. Repeat with `attachments`, `streaming`, `empty`, light/dark and reduced
   motion.

## 5. Commands

Add `scripts/device-ui-mock.ps1`:

- finds the ready USB device through HDC;
- optionally builds and installs the signed `mock` Release HAP;
- force-stops and launches one explicit fixture;
- waits for a stable frame;
- captures `uitest screenCap` and `uitest dumpLayout`;
- stores output under `artifacts/device-ui-mock/<state>/`.

The script records device model, API, bundle version and parameters. It rejects
normal launches and requires the literal fixture flag.

Conversation captures also run `scripts/device-ui-layout-assert.py`. The command
must find the composer `TextArea` and model selector within the display bounds.
The layout audit also rejects visible non-scrollable interactive controls whose
   bottom edge enters the final 20vp above the display edge.
The assertion log is stored with each conversation capture as
`layout-assert.txt`; a failed assertion makes the script fail.

The fixture keeps reduced-motion and reduced-transparency toggles in
`AppStorage`, so settings interaction tests receive the selected value back from
the local command instead of accepting optimistically and immediately reverting.

Add `scripts/device-ui-mock-suite.ps1` as the one-command regression entry. It
builds and installs once, runs every configured screen/state/theme pair, writes
`suite-summary.json`, and does not stop after the first failure.

Add `scripts/device-ui-settings-e2e.ps1` to exercise:

- light -> dark theme switching;
- reduce-motion row hit target and reduce-transparency switch hit target;
- persistence after returning to the settings root and reopening;
- all six settings detail pages and their Back stack;
- notification level, background monitor and card task-name persistence;
- the connected plugin version.

Add `scripts/device-ui-turn-change-e2e.ps1` to expand a four-file completed
turn, open a file row in the read-only preview, return to the same expanded
card, collapse it, and restore the overflow row.

The settings fixture mirrors successful setting writes in `AppStorage` so tests
verify current state and persistence. This behavior is selected only by
`storeShowcase=true`; production writes continue through the native bridge.

## 6. Verification

- Pure tests cover parameter validation, fixture state selection and serialized
  attachments.
- Source contracts cover fixture persistence for appearance, notification,
  background monitor and card settings.
- Source contracts prove the dock is not translated by an absolute composer
  offset and that the fixture client is unreachable without the launch flag.
- Device run captures all six states in both themes.
- default, store and mock Release products continue to build.
