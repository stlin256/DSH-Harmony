# Rendering, navigation and startup E2E

Date: 2026-11-01

Status: implementation and automated checks complete; device rows pending user verification.

| ID | Scenario | Expected result | Result |
|---|---|---|---|
| EXT-01 | Open a conversation containing HTTP, HTTPS and mail links in light mode | Each label is blue/underlined and has a compact external-link SVG; tapping either label area or icon opens the external target | Pending |
| EXT-02 | Repeat EXT-01 in dark mode and on a link-heavy paragraph | Marker remains blue, aligns with text, wraps without an extra row and has no dark glyph edge | Pending |
| EXT-03 | Open a workspace path and a Markdown fragment | Neither receives the external-link marker | Pending |
| START-01 | Complete a conversation, terminate the app and reopen with automatic login ten times | The launch surface transitions directly into that conversation; no starter/new-conversation frame appears | Pending |
| START-02 | Open after the remembered conversation is archived on another client | Launch resolves to the session drawer or a stable error state without the old conversation flashing | Pending |
| DOCK-01 | Open a conversation with a collapsed task-plan dock | The first row and history-loading control begin immediately below the measured dock with no blank strip | Pending |
| DOCK-02 | Expand and collapse the task-plan dock while at the first row | Inset follows the rendered dock height; content remains reachable and the dock never covers it | Pending |
| BROWSER-01 | Open browser -> nested directory -> README -> linked README | Each transition enters the browser history; preview content remains readable | Pending |
| BROWSER-02 | From BROWSER-01 press system Back repeatedly | Returns linked README, README, nested directory and opening directory in reverse order; chat is not exposed early | Pending |
| BROWSER-03 | Build a long chain of 20 directory/file transitions and return | All transitions replay from compact path history without retaining directory payloads or crashing | Pending |
| BROWSER-04 | At the opening directory press Back once then again within two seconds | First shows the existing exit hint; second closes the browser | Pending |
| PDF-01 | Open a PDF from chat and file browser | PDF opens inside DSH Harmony with a continuous width-fitted page; no external document application or chooser appears; download/close stay available and no copy action is shown | Pending |
| PDF-02 | Scroll, zoom and drag an open PDF, then retry after a parse failure | PDFKit gestures remain inside the preview and a failed parse can be retried without another full remote transfer | Pending |
| PDF-03 | Open a PDF, switch between light and dark appearance without closing it | The reader container changes immediately, while authored page colors and content do not invert or otherwise change. Known device result: the internal `PdfView` canvas remains white; track for a future PDFKit update | Pending |
| HTML-01 | Open an HTML file referencing local CSS, image, script and nested CSS asset | Preview renders with those local assets; source/code toggle remains available | Pending |
| HTML-02 | Open HTML referencing a missing local asset | Main document still renders; missing optional asset does not replace the entire preview with an error | Pending |
| HTML-03 | Tap a local file anchor in rendered HTML | The target opens in the same browser/file history and Back returns to the HTML preview | Pending |
| HTML-04 | Tap an HTTP(S) anchor in rendered HTML | The target opens in the system browser without leaving the native file reader | Pending |
| HTML-05 | Open a minimal HTML file with no author background or text color in light and dark modes | Text remains readable and the page resolves from the native loading surface | Pending |
| HTML-06 | Open a desktop-authored HTML page with fixed-width containers and wide media | The mobile viewport is used; blocks, tables and media remain inside the content width without right-side clipping | Pending |
| HTML-07 | Open HTML while local and remote assets continue loading | The title row displays a compact HarmonyOS loading indicator while the rendered page remains visible and interactive without a centered blocking overlay | Pending |
| HTML-08 | Scroll the longest HTML page to its end in both themes | The final content and browser scroll bar remain above the bottom gesture safe area in the file-preview entry points | Pending |
| HTML-09 | Perform repeated high-velocity vertical flings through a long HTML document | Every fling scrolls the document directly; no native edge track, oversized scroll container or dead gesture interval appears | Pending |
| MD-01 | Open a Markdown file containing only one short paragraph in preview mode | The paragraph begins at the top content edge and remains top-aligned instead of being vertically centered | Pending |
| MD-02 | Open a Markdown file much taller than the reader, then rotate the device | Scrolling still reaches the end, and the top alignment remains correct after the viewport height changes | Pending |
| FILE-01 | Download PDF and HTML from their preview toolbars | System save picker writes the current file version; workspace remains unchanged | Pending |
| SCROLL-01 | Scroll away from the latest message | A neutral 34vp circular down-arrow appears at 60% opacity without a colored halo; the new-content dot remains visible when applicable | Pending |
| SCROLL-02 | Press and hold the return control | Opacity rises to 85% and returns to 60% after release or cancellation | Pending |
| SCROLL-03 | Tap the down-arrow after new content | The transcript returns to the latest content with the existing nonlinear motion and no sudden stop | Pending |
| REG-01 | Open Markdown, SVG, image, source, directory and Markdown table links after the changes | Existing native previews and navigation still work in light/dark modes | Pending |

