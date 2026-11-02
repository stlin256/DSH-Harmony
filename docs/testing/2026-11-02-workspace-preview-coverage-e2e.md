# Workspace preview coverage E2E

Status: pending device execution. No USB-ready HarmonyOS target is currently
reported by HDC.

Current Mock HAP SHA-256:
`B76B79DFA915E7C15999E96E85C38F2DC7DB6EBF8402BD28E6F89105808D10A4`.

Driver: `scripts/device-ui-document-mode-e2e.ps1`.

Portable source, model, Mock coverage and publication gates passed in
`.artifacts/qa/20261102T121812Z-6a461bee/report.json`.

| ID | Scenario | Expected evidence | Status |
| --- | --- | --- | --- |
| PREVIEW-TEXT-01 | Open `config/app.conf` from the Mock preview | INI/config source appears before any failed type probe; keys and comments are highlighted | Pending |
| PREVIEW-TEXT-02 | Open `.env`, `.ini`, `.properties`, `.cfg`, `.txt`, `.log`, `.jsonc`, `.jsonl` and `.ndjson` | Each opens in the source reader without a download-only error | Pending |
| PREVIEW-TEXT-03 | Open `LICENSE`, `.gitignore`, `.npmrc`, `Dockerfile.dev`, `Makefile` and `CMakeLists.txt` | Extensionless and dot-prefixed developer files open as readable source | Pending |
| PREVIEW-TEXT-04 | Open a mapped language outside the former short list | Source text is intact and line numbers remain aligned | Pending |
| PREVIEW-TEXT-05 | Open an unknown non-binary suffix containing UTF-8 text | Plain-text fallback renders without requiring the file to be declared as a language | Pending |
| PREVIEW-TEXT-06 | Open a known binary suffix | A compact unsupported-preview message appears and download remains available; no decoded text is shown | Pending |
| PREVIEW-DELIM-01 | Open the CSV fixture | Table is the default view; row numbers and A/B/C column labels are visible; quoted multiline content remains in one cell | Pending |
| PREVIEW-DELIM-02 | Toggle CSV table to source and back | The single title-row icon reveals literal source, then restores the table without changing toolbar height | Pending |
| PREVIEW-DELIM-03 | Open the TSV fixture | Tab-separated values render in the same bounded table | Pending |
| PREVIEW-DELIM-04 | Open CSV with escaped quotes, empty fields and uneven rows | Literal quotes and empty values remain visible; missing trailing cells are visually padded | Pending |
| PREVIEW-DELIM-05 | Open malformed quoted CSV | Table mode shows a compact parse error; source mode remains available | Pending |
| PREVIEW-DELIM-06 | Scroll a table past its right and bottom bounds | Both axes scroll without stretching the preview header or compositor | Pending |
| PREVIEW-DELIM-07 | Paginate a long CSV | New rows append in source order; table projection remains bounded and the reader stays responsive | Pending |
| PREVIEW-REG-01 | Repeat SVG, Markdown, HTML, image and PDF previews | Existing previews and their controls are unchanged | Pending |
| PREVIEW-REG-02 | Repeat config and delimited states in dark and light themes | Semantic colors, borders and title-row controls remain legible | Pending |
