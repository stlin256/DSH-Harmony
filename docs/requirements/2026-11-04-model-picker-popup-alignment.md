# Model picker popup alignment

Date: 2026-11-04

The permission picker's secondary menu follows the composer/input position and
uses a masked popup. The model picker did not: it was anchored to the small
model chip inside the composer, so its sheet covered the input row, and with
the keyboard open its tall content was pushed behind the IME. The user
directs the model picker to reuse the permission popup as a template,
including its positioning and mask logic, and to remove the model search box.

- Both composer menus share one composer-anchored popup, mask, border and
  width behaviour; only the rendered content differs.
- The model sheet always sits fully above the input box with the keyboard
  open or closed, scrolls instead of overflowing, and has no search field.
- Dark/light, reduced motion, outside-tap dismissal and selection stay
  consistent with the permission menu.
- Cover the menu with a deterministic Mock scene and an interaction driver;
  record current-HAP device evidence before claiming completion.
- Do not record private endpoints, credentials or real conversation content.
