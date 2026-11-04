# Model picker popup reuse implementation

Date: 2026-11-04

## Composer popup

Keep a single `bindPopup` on the composer container (`conversation-composer`).
Introduce `composerPopupOpen()` and a `composerPopup()` builder that renders
the model picker when its state is open, otherwise the permission confirm card
or permission picker. Reuse the permission popup options verbatim:
`Placement.Top`, `enableArrow: false`, `targetSpace: 8`,
`radius: NativeDesign.radiusGroup`, `mask` with the themed mask color,
`popupColor: NativeDesign.overlay(dark)`, `backgroundBlurStyle: BlurStyle.NONE`,
`outlineWidth: 0`, `borderWidth: 0`. Dismissal on `onStateChange` must close
every menu state.

Remove the chip-level `bindPopup`; the model chip only closes other overlays
and opens `modelPickerOpen`. Permission opening must keep closing the model
state as it does today.

## Model picker content

`NativeModelPicker` keeps its directory, selection, loading and error logic.
It accepts `pickerWidth` like `NativePermissionPicker` (composer width, minimum
280vp), paints the same bordered overlay card and id (`model-picker`), and caps
its list at 278vp with `BarState.Auto` and `EdgeEffect.None`. Remove the search
field, query state and query filtering; providers and models render in
directory order.

## Verification

Add a source-contract test that the composer owns both menus and the model
picker has no search input. Register a deterministic `model-menu` Mock scene,
capture dark/light in the Mock suite, and add
`scripts/device-ui-model-menu-e2e.ps1` to assert, with the keyboard closed and
open, that the model sheet sits above the composer input, has no search field,
dismisses on outside tap and System Back while keeping the current caption, and
that the permission popup template is unchanged. Record current Mock HAP
evidence; no live Host claim.
