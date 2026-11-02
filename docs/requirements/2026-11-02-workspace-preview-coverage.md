# Workspace preview coverage expansion

## User requirements

- Common configuration and plain-text files must open in the native reader even
  when their suffix is not a programming language. This explicitly includes
  `.conf`, `.cfg`, `.ini`, `.properties`, `.env`, `.txt` and `.log`.
- Preview classification must happen before any content request. A known text
  file must not first appear as unsupported or unknown.
- The preview registry must follow the pinned upstream code-language extension
  table instead of maintaining a small hand-picked language list.
- Extensionless and dot-prefixed developer files must be readable. Examples
  include `LICENSE`, `README`, `CHANGELOG`, `.gitignore`, `.editorconfig`,
  `.npmrc`, `Dockerfile`, `Makefile`, `CMakeLists.txt`, `Gemfile` and
  `Jenkinsfile`.
- Unknown suffixes that are not declared binary must fall back to the plain-text
  reader. Read failure or invalid text may still produce the download-only
  message.
- Known binary suffixes without a native renderer must show a compact
  unsupported-preview state and keep download available without issuing a text
  read.
- CSV and TSV must have a native table preview by default and retain a
  source-code mode. The parser must preserve literal values, quoted separators,
  escaped quotes, multiline fields, empty fields and uneven rows.
- Table rendering must be bounded for phone memory and layout. The source remains
  available through the existing paged text reader.
- The existing title-row preview/source icon remains the only mode control.

## Acceptance criteria

- Opening a `.conf` file shows highlighted INI-style source immediately and
  does not require a failed type probe first.
- Opening `.txt`, `.log`, `.jsonc`, `.jsonl`, shell/config aliases and the
  supported upstream language suffixes opens the source reader.
- Opening `LICENSE`, `.gitignore`, `.npmrc` or `Dockerfile.dev` opens the source
  reader with an appropriate language or plain-text fallback.
- Opening a CSV or TSV shows a table with row numbers and column labels; the
  title-row icon reveals the original source and restores the table.
- A quoted multiline CSV cell remains one cell. Escaped quotes appear literally.
  Uneven rows are padded visually without dropping source data.
- A malformed quoted field produces a compact table error while source mode
  remains accessible.
- A known binary file shows download-only unsupported preview and never displays
  decoded replacement characters as file content.
- Existing SVG, Markdown, HTML, image and PDF behavior remains unchanged.

## Privacy and compatibility

- No workspace content is sent to a parser service. CSV/TSV parsing is local and
  read-only.
- No credentials, private hosts, cookies or real transcript content are added to
  fixtures, tests or documentation.
- API 23 retains the same behavior with opaque surfaces.
