# Device E2E: Long Stream Render Liveness

Device evidence is required. Source tests, Mock layout mapping and compilation
do not prove live phone rendering.

## Candidate build identity

| Variant | Signed HAP | SHA-256 |
| --- | --- | --- |
| Mock | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` | `74B23BFCF1D9DE63EFD0210FE2F02B52A8DAA98B8D05338F4245BE30162F7DDB` |
| Default | `harmony/entry/build/default/outputs/default/entry-default-signed.hap` | `381A1CB3D0AE0ABE4770C2775CC629BAD3131E8D711545BE1154742283FF3408` |
| Store | `harmony/entry/build/store/outputs/store/entry-store-signed.hap` | `1F51840CBC8D2543D364AD0EF9C2544DDEF428DB3EECE7376DAD080199950620` |

## Device rows

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| LSR-01 | Open `stream-long` in the Mock Release HAP | Text visibly advances across multiple captures before the final marker | Pending |
| LSR-02 | Wait for `STREAM-LONG-DONE` without relaunching | Marker becomes visible through the live delta path; no cold launch or reconnect is required | Pending |
| LSR-03 | Keep the long stream running while the transcript follows the tail | Header, composer and Dock remain interactive; no frozen frame or reconnect banner | Pending |
| LSR-04 | Repeat with Markdown emphasis, links, code and completed paragraphs crossing the bounded split | Formatting remains readable and complete content is retained | Pending |
| LSR-05 | Redirect the real Host stream through a sustained long answer | Natural token cadence continues, or the bounded repair restores it without clearing visible text | Pending |
| LSR-06 | Trigger Gateway backpressure with a throttled client | Upstream resumes automatically after the low watermark and the stream completes | Pending |

## Evidence required

- Device model, HarmonyOS/API version and exact HAP SHA-256.
- Two intermediate `stream-long` captures with timestamps.
- One final capture containing `STREAM-LONG-DONE`.
- Confirmation that the process was not restarted between captures.
- For a real Host run, timestamps for last visible delta, any repair request and
  the first restored delta.
