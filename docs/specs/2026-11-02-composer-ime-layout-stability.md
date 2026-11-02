# Composer IME layout stability implementation specification

Requirement:
[`2026-11-02-composer-ime-layout-stability.md`](../requirements/2026-11-02-composer-ime-layout-stability.md)

Upstream interaction reference:
[`NATIVE-INTERACTION-SPEC.md`](../NATIVE-INTERACTION-SPEC.md)

## 1. Root cause contract

ArkUI's `UIContext.setKeyboardAvoidMode()` defaults to `OFFSET`. In that mode
the page itself moves up when the IME is displayed. `RESIZE` instead gives the
page a smaller layout height and keeps the page origin fixed.

`Index.uiMode` defaults to `native`. When the persisted `uiMode` also resolves
to `native`, the `@Watch('modeChanged')` callback has no value transition to
observe. Keyboard mode must therefore not be configured only inside
`modeChanged()`.

## 2. Single application point

Add one idempotent `applyKeyboardAvoidMode()` method:

```text
native  -> KeyboardAvoidMode.RESIZE
other   -> KeyboardAvoidMode.OFFSET
```

Call it:

1. at the start of `aboutToAppear()`;
2. immediately after the saved/showcase mode is resolved;
3. from `modeChanged()`.

The page remains a full-height percentage layout. Do not add a page-level
`translate`, fixed keyboard padding or a duplicate keyboard-height state.

## 3. Visual invariants

With the IME open:

- the conversation header title and action row retain their top bounds;
- the transcript Stack begins at the same offset below the header;
- the bottom composer Dock remains fully visible above the IME;
- the IME-visible Dock uses a 12vp bottom gap; when the IME is hidden it returns
  to the shared 20vp page-safe baseline;
- only the transcript `layoutWeight(1)` area contracts;
- no header, chip, drawer scrim or page surface is shifted as a unit.

After dismissal, the initial header and composer top bounds are restored within
one device pixel. The draft remains in the TextArea and in the client draft map.

## 4. Verification

`scripts/verify-keyboard-avoidance.mjs` enforces the initialization and mode
channels as a source contract. `scripts/device-ui-ime-e2e.ps1` launches the
deterministic `dock-send-idle` fixture, focuses the composer, reads the ArkUI
layout before and while the IME is open, types a draft, dismisses the IME and
repeats in light and dark themes.

The device driver must fail when:

- the composer does not move above the IME;
- the header title's top bound changes by more than one pixel;
- the composer bottom leaves the resized root;
- the draft disappears; or
- the process exits.

The driver must report environment-pending when no ready USB target exists.
Rows in the device E2E table remain Pending until a matching HAP hash and
captured layouts exist.
