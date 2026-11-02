# PDF and HTML preview specification

Date: 2026-11-01

## Descriptors

`nativeDocumentDescriptor()` adds:

- `pdf`: kind `pdf`, no mode toggle;
- `html` / `htm`: kind `html`, language `html`, default mode `preview`, toggle
  enabled and preview supported.

The shared eye/code segmented control remains 82 vp wide and uses the existing
sliding highlight.

## PDF

PDF loading uses `NativeFileTransfer.readComplete()` with a 64 MiB ceiling and
the versioned `statFile()` identity. Bytes are written to a unique app-cache
file. `PDFKit.PdfView` reads that app-private path directly in a continuous,
single-page, width-fitted reader. The reader supports the platform's PDF zoom,
drag and scroll gestures without handing the document to another application.

The file title row owns a compact loading indicator while the PDF is parsed.
The shared top download/close toolbar remains visible over the document. The
single mode action appears only when source switching is supported; file
preview never exposes a copy action.
Parse failures stay inside the native reader with a compact retry action.
Leaving the preview releases the PDF controller and removes the app-private
materialization.

The PDF surface uses the same light or dark reader background as the surrounding
native UI. Document pages retain their authored colors: the reader does not use
PDFKit's dark render preset because that preset altered page content instead of
providing a reliable themed canvas on current firmware.

Known limitation: on the tested HarmonyOS firmware, PDFKit's internal canvas
paints white through the `PdfView` surface despite applying a themed component
background. Keep this limitation visible in device testing and revisit after a
PDFKit update. Do not re-enable `PresetRenderMode.DARKMODE` as a workaround
because it inverts authored document colors without darkening the canvas.

## HTML source and assets

HTML preview reads at most 8 MiB of complete source and shares a 32 MiB
workspace-asset budget. The number of workspace references is unbounded; the
visited-path set prevents cycles. Asset resolution accepts workspace-relative
paths and workspace-root-relative paths. It rejects traversal outside the
workspace, Internet URLs, data/blob/fragment URLs and malformed paths.

The resolver supports:

- `link[rel=stylesheet]` and nested CSS `url(...)` references;
- `script[src]`;
- `img[src]`, `source[srcset]`, `video[poster]` and media `src`;
- `object[data]` and `embed[src]`;
- ordinary local anchors as native workspace-file navigation.

Text and base64 payloads are bounded before inlining. A missing or oversized
optional asset is replaced with an inert empty value and does not fail the main
document. Absolute HTTP(S) assets are left unchanged and the sandboxed page may
load them under CSP with no referrer; absolute HTTP(S) anchors open in the
system browser. Internet assets are fetched by ArkWeb from the preview origin
and do not receive workspace API credentials.

## Web surface

`NativeHtmlPreview` uses one ArkWeb controller and an app-owned
`https://dsh-harmony.invalid/html-preview` virtual URL. Once source preparation
finishes, the component loads a revisioned instance of that URL.
`onInterceptRequest` answers it synchronously with a `WebResourceResponse`
containing the prepared HTML, UTF-8 encoding and `text/html` MIME type. The Web
component never performs a network request for this URL and no local file URL
is exposed.

This route replaces `WebviewController.loadData()`: current HarmonyOS firmware
rendered raw HTML as an empty document, URL-encoded HTML as literal `%xx` text
and Base64 data as literal Base64 text. Intercepted responses avoid all three
failure modes and support the 32 MiB bounded inline-asset budget without
depending on URL-length limits.

The component disables file access, uses automatic dark mode without forced
darkening and does not expose a JavaScript proxy. Local navigation is rewritten
to an app-only scheme and is intercepted by the component.

The generated document always includes a responsive viewport and
no-referrer policy while preserving document-authored styling.

A neutral foreground/background style is inserted at the start of `<head>`
before author CSS. It supplies a readable inherited color but lets the document
override it. `client`, `file` and custom base URLs remain disabled. The loading
state is surfaced as a 12 vp HarmonyOS loading indicator beside the file title,
matching conversation chrome. HTML content is never covered by a centered
loading card while linked assets finish. A failed main document shows a compact
native error.

ArkWeb explicitly enables mobile viewport parsing and the generated viewport
uses `viewport-fit=cover`. A final preview layout stylesheet constrains document
blocks and media to the available width, gives wide tables and preformatted
blocks horizontal overflow, includes a bottom safe-area inset and suppresses
page-level scrollbar tracks while preserving scroll gestures. The Web surface
participates in the reader column with `layoutWeight(1)`, so its scroll extent
stops above the gesture navigation area and cannot overlap the header. ArkWeb
overscroll effects are disabled because the preview is not nested in a native
scroll container and the browser-style surface must respond directly to fast
flings without exposing an edge-effect track.

## Read-only and download

Preview code never writes to the workspace. The existing top download action
uses the system save picker and the current file bytes. Cache materializations
are app-private and removable through Storage Management.

Markdown preview uses a top-aligned scroll surface whose content column has the
current viewport height as a minimum. The Markdown block column and scroll
content both resolve from `TopStart`, so a short document occupies its natural
height at the top of the reader and is never vertically centered by the
surrounding weighted layout. Content taller than the viewport keeps its natural
measured height and remains scrollable.

## Verification

- Model tests cover descriptors, relative path resolution, CSS URLs, rewrite
  ordering, srcset parsing, traversal rejection and output safety.
- Source contracts verify embedded PDFKit usage, temporary-file cleanup, bounded
  reads, local Web loading and shared download controls, mobile viewport
  parsing, theme-aware PDF container styling, preservation of authored PDF
  colors, non-blocking loading presentation, responsive width constraints and
  reader-column bounds.
- Both Release variants build.
- Device E2E checks PDF, HTML with CSS/image/script references, responsive
  desktop-authored pages, non-blocking asset loading, bottom safe area, source
  toggle, internal links and download.

