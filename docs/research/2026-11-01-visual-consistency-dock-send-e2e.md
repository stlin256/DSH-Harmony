# Visual consistency and interactive Dock research

Date: 2026-11-01

## Scope

Read-only inspection covered `NativeWorkspace`, `NativeSettings`,
`NativeBottomConversationDock`, `NativeQueueDock`, `NativeInteraction`,
`NativeWorkspacePicker`, `NativeSessionTools`, file preview/browser surfaces,
the `StoreShowcaseClient`, existing device capture scripts and the currently
available device screenshots.

## Visual consistency audit

Status meanings:

- Aligned: already follows the main conversation's semantic surface and control
  language.
- Minor drift: functional but uses a one-off surface, spacing or glyph.
- Needs work: visibly behaves like a separate form or lacks the shared compact
  feedback pattern.

| Surface | Finding | Status | Next action |
| --- | --- | --- | --- |
| Conversation, tool process, queue and turn changes | Neutral surfaces, compact rows, blue primary accent and DSH glyphs agree with the design baseline | Aligned | Keep as visual reference |
| Drawer and session list | Compact hierarchy and interaction-time ordering agree; a few semantic items still use placeholder text glyphs | Minor drift | Replace placeholder plugin/file/more glyphs with shared DSH icons in a focused icon pass |
| Settings root and child pages | Shared card radius and palette are close to the main surface | Minor drift | Centralize the slightly different settings base and card tokens when the next settings refactor lands |
| About page | Uses a different raised-surface value from the settings groups | Minor drift | Reuse the settings raised token |
| Workspace picker | Full-page form controls, default-looking buttons and inconsistent section spacing make it feel detached from the native shell | Needs work | Rebuild with the settings row, 44vp action and shared motion primitives |
| Legacy session tools | Default buttons, dense top bar and mixed radius/color values do not match the compact conversation dock | Needs work | Rebuild queue/model/session subpages with shared DSH controls |
| File browser | Folder/file grouping and row language are aligned | Aligned | Add image variants to visual regression matrix |
| File previews and lightbox | Read-only preview behavior is aligned; viewer headers vary in compactness | Minor drift | Normalize header action size, loading placement and safe-area bottom inset |
| Model picker, menus and interactions | Shared neutral surfaces and primary action hierarchy are aligned | Aligned | Add deterministic approval/question fixtures |
| Loading, empty and recoverable error states | Text and availability vary by owner | Needs work | Introduce shared compact status-row recipes |
| Legacy compatibility surface | Retained for protocol fallback; it has a different shell language | Needs work | Audit only after native-only product policy permits removal |

The requested work in this change records this list and fixes the Dock/Mock
infrastructure. The unrelated surface rebuilds should not be mixed into the same
commit because they touch navigation and interaction behavior.

## Why send appeared broken in the Mock

`NativeWorkspace.send()` displays a local pending echo only when the selected
session is already running and uses queue mode. For an idle send it relies on
subsequent Host events or snapshots.

`StoreShowcaseClient.prompt()` returned a fixed string and did not mutate any
transcript, queue or live state. `follow()` also sent one snapshot and had no
later frames. As a result, the composer could clear while the visible transcript
and queue stayed unchanged. This is a fixture-contract defect rather than the
normal network client's send path.

## Why blur could look like a solid strip

`NativeBottomConversationDock` used:

- a real component background material;
- a `linearGradientBlur` on an otherwise empty material layer;
- a second increasing theme scrim whose bottom alpha was high enough to read as
  a solid band.

HarmonyOS documents `linearGradientBlur` as a foreground blur. Applying it to an
empty layer cannot produce a gradient-strength backdrop blur. The visible falloff
came primarily from the scrim. The implementation should use an actual backdrop
material and keep the gradient scrim translucent enough that transcript colors
remain visible.

The SDK also notes that screenshot output can differ for foreground blur and
background effects. Device evidence therefore needs both source-level capability
checks and paired screenshots; pixel heuristics alone cannot prove exact blur
radii.

## Existing automation gaps

- The suite captures static fixture states but never presses Send.
- The layout assertion checks composer visibility only; it cannot prove a sent
  message was inserted or a queue row replaced a pending echo.
- Quiet and elevated Dock states are not captured as a comparable pair.
- Reduced-transparency fallback is not part of the screenshot matrix.
- There is no post-send count assertion that catches duplicate queue rows.
