# Workspace preview coverage implementation spec

## Classification registry

`NativeDocumentModel` classifies a path before `NativeFilePreview` issues a
content read. Classification normalizes the basename, recognizes whole-name
developer files and then maps the final suffix.

The suffix table mirrors
`packages/util/code-language/src/index.ts` at pinned upstream commit
`f3803c96974ad4a94195fb97e5c637e9c2a3afe3`. The table remains data-driven so
the native client and syntax highlighter share one language vocabulary. It
covers TypeScript/JavaScript, shells, JSON variants, CSV, Python, Ruby, Go,
Rust, JVM languages, C-family languages, PHP, YAML, TOML, INI/config,
dotenv, logs, diff, HTTP, Markdown-family source, reStructuredText, LaTeX,
AsciiDoc, HTML/XML, CSS-family, SQL, Lua, Windows scripts, PowerShell,
R, Julia, Dart, Scala, Clojure, Erlang, Elixir, Haskell, F#, Visual Basic,
Perl, Verilog, GraphQL, Protocol Buffers, HCL, Nix, Vue, Svelte, Make, CMake
and Groovy.

Name rules add highlighting for files whose language is expressed by the whole
name: `Dockerfile*`/`Containerfile*`, `Makefile`, `GNUmakefile`,
`CMakeLists.txt`, `Gemfile`, `Rakefile`, `Vagrantfile`, `Brewfile`,
`Jenkinsfile`, `Justfile`, `Procfile`, `.env*`, `.editorconfig`, `.npmrc`,
`.prettierrc*`, `.eslintrc*`, `.babelrc*`, `.gitattributes`, `.gitignore`,
`PKGBUILD`, `APKBUILD` and related developer/configuration files.

Descriptor modes:

```text
image      -> preview
pdf        -> preview
html       -> preview | code
svg        -> preview | code
markdown   -> preview | code
delimited  -> preview(table) | code
code       -> code
text       -> code
binary     -> download-only unsupported preview
```

An unknown non-binary suffix and an extensionless unknown filename receive the
plain-text descriptor. This is the upstream fallback behavior. Known binary
groups include image formats without a native renderer, archives, office
containers, executable/object files, fonts, audio/video, databases and other
opaque packages. The reader may stat them for size but must not call
`workspaceFiles/read`. That binary registry includes common design, camera RAW,
ebook, office template, package/archive, font, database and media containers
that do not have a native renderer; adding one of those extensions to the image
set requires verified platform decoding.

## Syntax highlighting

`NativeCodeHighlight` accepts every canonical language id emitted by the
classification registry. Unrecognized or oversized sources still preserve every
character as plain text.

Markdown fences retain the established short aliases (`js`, `ts`, `sh`, `bash`,
`yml`, `py`, `md`, `patch` and related ids). The highlighter canonicalizes those
aliases before selecting comment, keyword and string rules, so expanding the
document registry does not regress chat code blocks.

INI/config/dotenv modes treat leading `#` and `;` lines as comments and recognize
keys before `=` or `:` as properties. CSV/TSV source mode preserves delimiters
and quoted strings. No highlighter path changes source text, line breaks or
selection.

## CSV and TSV model

`NativeDelimitedModel` is a pure, bounded parser with no ArkUI dependency.
Defaults are 200 rows, 32 columns and 4096 characters retained per cell. Source
content itself is not truncated; only the table projection is bounded.

The parser implements the RFC 4180 state machine:

- comma for CSV and tab for TSV;
- CRLF, LF and CR record separators;
- quote-wrapped fields containing delimiters and line breaks;
- doubled quotes inside a quoted field become one literal quote;
- empty fields and trailing empty cells are retained;
- unequal rows remain unequal in the model and are padded by the view;
- an unterminated quote is an error unless the current text page has more lines;
- malformed content after a closing quote is an error.

The first row remains data. The visual table supplies its own row numbers and
column labels instead of promoting the first row to semantic headers. Literal
values are rendered without Markdown interpretation. If a bound is reached, a
compact truncation label explains that source mode retains the complete file.

## Reader integration

`NativeFilePreview` stores the descriptor's `canPreview` contract as reader
state. For a binary descriptor it performs metadata loading only, renders
`此文件类型暂不支持预览，仍可下载` in a neutral compact state, and leaves the
download action enabled. Format limitations do not reuse the danger-colored
read-failure state or a misleading retry action.

Delimited text uses the existing paginated text cache and source reader. In
`preview` mode it renders the local table projection. In `code` mode it renders
the same text through `NativeCodeViewer`. The title-row icon switches modes and
keeps the 44vp hit target and 36vp visual container.

## Fixtures and verification

The Mock Host exposes deterministic config, CSV, TSV, malformed CSV and binary
files. The device fixture screen `preview` supports states
`text-config-preview`, `delimited-preview`, `tsv-preview`,
`delimited-error-preview` and `binary-preview`, registered in the Mock feature
manifest and captured by the static suite.

`scripts/device-ui-document-mode-e2e.ps1` covers:

- config source rendering and title-row controls;
- CSV table rendering, source toggle and restore;
- TSV table rendering;
- malformed CSV table error with source mode still available;
- binary download-only fallback without decoded text.

Device rows remain Pending until a current Mock HAP runs on a USB-ready target.
