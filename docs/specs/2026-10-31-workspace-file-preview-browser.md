# Workspace file preview and read-only browser implementation spec

## Document model

`NativeDocumentModel` classifies a workspace path before any content request.
Classification is based on a normalized, lowercase extension and does not use
the response body as a type oracle.

```text
image     -> platform-decoded preview only
svg       -> preview | code
markdown  -> preview | code
delimited -> preview(table) | code
code      -> code
text      -> code
binary    -> download-only error surface
```

The image set includes the platform-supported raster/container extensions used
by the reader: PNG, JPEG, WEBP, GIF, BMP, ICO, DNG, HEIC and HEIF. SVG is handled
as a switchable document. The code mapping covers JavaScript, TypeScript,
ArkTS, JSON, shell, PowerShell, Python, Go, Rust, Java, Kotlin, Swift, C/C++,
C#, HTML/XML, CSS-family, YAML, TOML, INI/config, dotenv, log, JSON variants,
CSV/TSV, Markdown, diff/patch and the wider pinned upstream language table.
Common extensionless and dot-prefixed developer files are recognized by name.
An unknown non-binary suffix still falls back to the text reader. Known binary
suffixes use the download-only descriptor and do not issue a text read.

The model also provides pure helpers for source line numbering and a small
block projection used by Markdown preview. These helpers contain no ArkUI
dependencies so the gateway model suite can test their contracts.

## Reader data flow

The reader first calls `workspaceFiles/stat`. Image and SVG preview requests
read complete byte windows from `readBytes`, advancing by the returned window
length and stopping at `eof`. Every window must retain the initial file version.
A configured preview ceiling prevents unbounded bitmap memory use; an image
above the ceiling remains downloadable.

The byte endpoint carries window metadata in `X-DSH-File-Window`, but HarmonyOS
does not expose that custom response header consistently through
`requestInStream` across devices. The App therefore accepts the header as a
`string` or one-value `string[]`. If the platform omits the header, the App
derives offset, version and EOF from the preceding `stat` result and the
observed streamed byte count. EOF is
`offset + received >= stat.bytes`; this also handles an empty file and a file
whose final window ends exactly on the 2 MiB boundary. Header metadata remains
authoritative when present and is still validated against protocol version and
requested offset.

The fallback never treats image bytes as text and never starts decode until the
observed byte count equals `stat.bytes`. A missing version, short aggregate
read, changed version or oversized preview remains a compact preview error with
download available.

PixelMap decoding uses `image.createImageSource(ArrayBuffer)` and a bounded
`createPixelMap` size. ImageSource explicitly supports SVG in API 23's platform
contract. PixelMaps and ImageSources are released when the path changes or the
reader disappears.

Text, Markdown and SVG code requests use the existing paginated
`workspaceFiles/read` endpoint. Additional pages append in source order. Code
line numbers start at the response offset, so pagination never restarts the
gutter at one.

There is no text-to-image fallback. A failed image decode reports a compact
image error and leaves download available. A declared binary suffix skips the
text read and reports download-only. A failed read for an unknown suffix is
considered a binary/unsupported preview rather than evidence that the file is an
image.

## Mode switch and views

`NativeDocumentModeSwitch` is one `NativeIconButton` placed in
`NativeFilePreview`'s 52vp title toolbar, before copy/download/close. It never
creates a second row. The button keeps a 44vp interaction target and 36vp visual
container. Preview mode presents `code-outline.svg` with the label
`切换到源码`; source mode presents `eye-outline.svg` with the label
`切换到渲染预览`. Tapping either icon changes only the document mode.

The icon is neutral shell chrome rather than a persistent selected state; the
rendered content or source body communicates the active mode. This keeps the
toolbar visually consistent with copy, download and close while maximizing
vertical reading space.

SVG, Markdown, HTML, CSV and TSV begin with `mode = preview`. A mode change is
local UI state and survives additional-page loads. CSV/TSV preview is a bounded,
literal table projection with row numbers and column labels; source mode shows
the unchanged paged text. Images, PDF and ordinary code files do not show the
switch because they have only one meaningful mode.

`NativeCodeViewer` renders a two-column source surface. The gutter column and
the horizontally scrollable code column share a fixed 22vp line rhythm. Each
source line is highlighted with the existing `nativeHighlightCode` language
mapping. A long line scrolls horizontally instead of wrapping, while the outer
reader scrolls vertically. The code body remains selectable.

`NativeCodeViewer` owns vertical and horizontal `Scroller` instances. First
appearance and target-identity changes reset both axes to their start, including
after a short file reuses the component after a long file. Content growth for
the same target preserves the reader position.

The platform horizontal scroll bar remains off because its position follows the
source content height. `NativeCodeViewer` renders a custom position track at
the bottom of the reader viewport. The track reflects the visible-to-total
source width ratio and follows `Scroller.currentOffset()` while the user pans
horizontally. The source surface reserves a compact bottom lane for this track,
using the track's full hit-box height so the final source row remains readable
when the vertical reader is scrolled to the end. The track contains only a
thumb, sits two vp above the reader edge, and follows the same transient
behavior as the platform vertical bar: it fades in while horizontal scrolling
is active and fades out after scrolling stops. Reduced motion resolves the
visibility change directly. Short files keep their content top-aligned while
the horizontal track, when needed, remains anchored to the bottom of the text
surface.

The horizontal `Scroll` and the gutter column use the larger of the source
content height and the measured reader height. Short files therefore expose a
full-height horizontal pan target and a full-height line-number separator,
including the empty area below their last source row. Long files continue to
grow with their content and remain vertically scrollable through the outer
reader.

Markdown preview is a block projection over the complete loaded text. It keeps
ordered blocks for headings, quotes, fenced code, tables and paragraphs.
Inline links use the existing authenticated link surface. Fenced code uses the
same syntax highlighting as chat. Pagination appends before re-projecting, so
block order is stable.

## Download

`NativeFileTransfer` owns both full-byte preview loading and user-directed
downloads. Its download path:

```text
DocumentViewPicker.save
-> open selected local URI
-> loop readBytes (up to 2 MiB per window)
-> verify version, offset and eof
-> write each returned window directly
```

Bytes are not accumulated for downloads. Cancelling the picker exits without a
toast. A failed read or local write shows one short error. Temporary app-cache
files are neither required nor created by workspace downloads.

The preview toolbar and each regular file row share this service. The row
download button stops click propagation so the row does not also open the file.

The preview root includes the reported system bottom inset and a compact
minimum clearance when gesture-navigation devices report a zero-height inset.

## Browser history and utility menu

`NativeHarnessClient` keeps an in-memory `sessionId -> last successful directory`
map. `NativeFileBrowser.load` records a directory only after a successful list
response. Opening a file from a transcript records the file's parent directory.
The map is cleared with the rest of the in-memory client state at logout.

`nativeUtilityMenu` always projects `files` first with the `browse-outline`
glyph. Existing capability-gated export actions follow it. The workspace menu
handler closes the overflow surface and opens:

```text
kind: browser
sessionId: active session
path: client.lastBrowsePath(active session) or ''
```

Empty history maps to workspace root, which the gateway translates to `.` for
the upstream list call.

## Read-only boundary

Workspace file support is limited to:

```text
workspaceFiles/stat
workspaceFiles/list
workspaceFiles/read
workspaceFiles/readBytes
```

The App has no workspace-file write API. The gateway exposes no workspace-file
write endpoint and rejects unsupported paths through the fixed native route
allowlist. Download destinations are local user-selected URIs and are outside
the workspace mutation boundary.
