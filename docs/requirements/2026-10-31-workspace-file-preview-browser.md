# Workspace file preview and read-only browser

## User requirements

- PNG, JPEG, WebP, GIF, BMP, HEIC, ICO and other image formats supported by
  HarmonyOS ImageKit must open as images in the workspace reader. A decode or
  size-limit failure must remain a file-reader error; it must not be mislabeled
  as unsupported workspace content.
- SVG opens in rendered preview mode by default and can switch to a highlighted
  source-code mode with line numbers.
- Markdown opens in rendered preview mode by default and can switch to a
  highlighted source-code mode with line numbers.
- The SVG, Markdown and HTML preview/source switch is one icon action inside the
  preview title toolbar. It does not reserve a second row below the title.
  Preview mode shows the code glyph to switch to source; source mode shows the
  eye glyph to restore rendering. The icon keeps the shared 44vp hit target and
  36vp visual container. Reduced motion affects only the content transition.
- File preview never exposes a copy-path or copy-file action. The mode switch
  occupies the former copy slot and is present only when both preview and source
  modes are supported.
- Every supported image and code file is viewable. Supported image formats are
  decoded through the platform image decoder. Code and text use a selectable
  source reader with a fixed-width line-number gutter and syntax highlighting
  for known languages.
- Code mode starts at the first line whenever a different file target is
  opened, even when a short file follows a previously scrolled long file.
- Short source content starts on the first text row rather than being vertically
  centered.
- A long source line exposes a horizontal scroll position track pinned to the
  bottom of the text surface, below the source viewport rather than directly
  below the last visible line.
- The horizontal pan surface and line-number separator fill the reader height.
  A short file can be panned from any empty row, rather than only from the text
  row itself.
- The preview surface respects the bottom system inset with additional compact
  breathing room.
- Every file preview has a download control in its top toolbar. Download writes
  the original workspace bytes to a location chosen through the HarmonyOS
  document save picker.
- The chat overflow menu always contains `文件浏览`. It opens the current
  session workspace root unless another directory was successfully opened
  during this app process, in which case it opens the last directory for that
  session.
- Every regular file row in the workspace browser has its own download control.
  Activating that control saves the file and does not also open the row.
- Workspace files are strictly read-only. The App and gateway may call only the
  upstream workspace file stat, list, text-read and byte-read capabilities.
  There must be no create, upload, rename, edit, delete or other write route for
  workspace files.
- Directory history is process-local UI state, scoped by session. It must not be
  persisted as a server setting or used across different workspaces.

## Acceptance criteria

- A valid PNG and a valid SVG both render inside the native file reader.
- SVG starts in preview mode; tapping the single code icon in the title toolbar
  reveals source and real line numbers; tapping the eye icon restores the
  rendered SVG without adding or collapsing a second toolbar row.
- Markdown starts in preview mode; code mode preserves line numbers across
  additional text pages, and preview restores headings, links, tables, quotes
  and fenced code blocks.
- Opening a short source file directly after a scrolled long file paints line 1
  at the top of the reader.
- Unknown binary files expose download and a short unsupported-preview message;
  they do not display decoded XML or replacement text as if it were the file.
- The top download control saves exactly the original bytes and never writes
  into the remote workspace.
- A file row download target is at least 44vp square, does not open the file,
  and remains aligned without crowding the filename.
- The chat overflow list opens the last visited directory for the active
  session after a successful directory navigation; otherwise it opens root.
- Root browsing continues to send `.` to `workspaceFiles/list`.
- Back closes the file reader or browser before closing the chat.

## Privacy and compatibility

- No deployment origin, credential, cookie, signature, transcript or private
  path is added to source, tests or documentation.
- API 23 keeps full reader/browser functionality with opaque theme surfaces.
- File downloads use the system picker and do not require broad storage access.
