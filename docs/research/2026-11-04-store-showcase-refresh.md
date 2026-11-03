# Store showcase refresh research

Date: 2026-11-04

## Current state

The existing capture pipeline is reproducible, but the fixture content is too
diagnostic:

- Most conversation and process scenes reuse the same release checklist.
- Automation and plugin lists contain only a small number of visible rows,
  creating large empty areas in the phone viewport.
- Portrait art places the footer at `y=1844` while the device frame can extend
  to roughly `y=1870`, so the footer collides with the screenshot.
- The portrait title, captions and feature chips are readable at native
  resolution, but several secondary labels render too small after the device
  image is reduced for store previews.

## Design direction

Use short, credible product tasks that show different kinds of work:

- plan a reusable settings state;
- diagnose a first-paint flicker;
- split a search/filter refactor across subagents;
- organize notification groups;
- review a cache fallback;
- approve one narrow-screen layout write.

Keep the DSH visual language: restrained neutral surfaces, blue as the primary
accent, compact information density, precise outlines and no marketing chrome
inside the app capture.

For portrait composition, reserve a separate footer band below the device
instead of floating copy over the canvas. Move the device upward and reduce its
target height enough to leave breathing room around the footer, while increasing
the title, subtitle, feature and footer type sizes. The result should look
intentionally composed rather than like a screenshot placed under text.
