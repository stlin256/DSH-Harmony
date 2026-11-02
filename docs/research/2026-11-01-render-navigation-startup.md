# Rendering, navigation and startup research

Date: 2026-11-01

## External link rendering

`NativeInlineText` renders a styled ArkUI `Text` containing `Span` children.
External links already invoke the system view-data ability, but the existing
`DSHIcon` is a sibling custom component and cannot be nested inside that text
flow. ArkUI `ImageSpan` supports SVG resources inside `Text`, applies a drawing
color filter and owns its own click callback. A dedicated glyph can therefore
remain inline with mixed Markdown runs without turning the paragraph into a
brittle row of independent wrapping controls.

## Startup race

`Index.connect()` currently sets `ready = true` and immediately starts the
launch-surface exit. `NativeWorkspace` is mounted as that exit begins. Its
`reload()` can then paint cached session metadata, set `loading = false`, await
the encrypted route, and only afterwards select the remembered conversation.
That creates a visible interval in which the workspace's no-selection surface
is underneath the fading launch layer.

The fix needs a first-navigation readiness signal from `NativeWorkspace`.
Network login success is not enough: the remembered route must be resolved, and
the launch surface must wait for either a valid conversation selection or a
resolved no-conversation state.

## Dock overlap

Conversation uses a `Stack` whose `List` starts at the same top edge as the
floating `NativeConversationDock`. Initial implementation used
`contentStartOffset(number)`, but device evidence showed that a list initially
scrolled to the bottom could still paint its first item beneath the dock. The
same experiment with top List padding also failed because the bottom-anchored
scroll position continued to place the first item under the overlay. The dock
must be a sibling row above the transcript `Stack`; the List then owns only the
remaining viewport. This avoids a fake lazy row while keeping visible content
below either the collapsed 32-vp control or its expanded plan height.

## File browser navigation

`NativeFileBrowser` currently owns one `navigationPath` and one `previewPath`.
Its Back method closes that preview or calls `parent()`. Workspace file links
inside Markdown publish a global `nativeFileViewPayload`; `NativeWorkspace`
currently treats every such publication as a new root overlay, unmounting the
browser. The result is a single-level browser and a broken Back chain.

The browser needs one compact history stack. Entries contain only `kind` and
`path`, while directory data remains in `NativeWorkspaceCache`. File-link
publications made while a browser is active must be forwarded into that stack
instead of replacing the root overlay.

## PDF and HTML

HarmonyOS Preview Kit supports PDF and HTML file URIs and exposes
`canPreview()` and `openPreview()`. The existing read-only byte service can
materialize a versioned PDF in the app cache and hand its sandbox URI to Preview
Kit.

ArkWeb can render HTML from `WebviewController.loadData()`. The current session
file API can return complete bytes only through the bounded
`NativeFileTransfer.readComplete()` loop. Rendering a server URL directly would
require a new authenticated file-serving protocol and would expose workspace
paths in resource URLs. Inlining local resources into a generated document
keeps authentication in the existing app client and avoids path-bearing URLs.

HTML references require a separate bounded resolver for stylesheets, scripts,
images, fonts and media. CSS can itself contain nested `url(...)` assets.
Arbitrary Internet resources should not be fetched by the app because workspace
HTML must not gain an authenticated backend-fetch primitive; only
workspace-local references are inlined. External navigation links still open in
the system browser.

## Upstream boundary

These are mobile extensions around the pinned DSH rendering and navigation
semantics. They do not claim feature parity with upstream desktop behavior.

