# Device E2E: Long Stream Render Liveness

Device evidence is required. Source tests, Mock layout mapping and compilation
do not prove live phone rendering.

## Candidate build identity

| Variant | Signed HAP | SHA-256 |
| --- | --- | --- |
| Device-qualified Mock | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` while tested | `F23693248955498EC90306DC2D1942D2DC30F440FE449D73DDB9592FE59412CD` |
| Final default Release | `harmony/entry/build/default/outputs/default/entry-default-signed.hap` | `43E3466D0C878A07C673899B2B213E6348A0DC0424BA032E16C080D31D880E08` |
| Final store Release | `harmony/entry/build/store/outputs/store/entry-store-signed.hap` | `2BC7E88367F6CAD626954CDA7F9FC72FB6324702E9C6EE9AAFEFD0168DB9A6E6` |

## Device rows

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| LSR-01 | Open `stream-long` in the Mock Release HAP | Text visibly advances across multiple captures before the final marker | Passed; paragraphs reached 1, 11, 18 and 55 |
| LSR-02 | Wait for `STREAM-LONG-DONE` without relaunching | Marker becomes visible through the live delta path; no cold launch or reconnect is required | Passed |
| LSR-03 | Keep the long stream running while the transcript follows the tail | Header, composer and Dock remain interactive; no frozen frame or reconnect banner | Passed; same PID and responsive composer |
| LSR-04 | Repeat with Markdown emphasis, links, code and completed paragraphs crossing the bounded split | Formatting remains readable and complete content is retained | Passed in the deterministic long-stream fixture |
| LSR-05 | Redirect the real Host stream through a sustained long answer | Natural token cadence continues, or the bounded repair restores it without clearing visible text | Pending |
| LSR-06 | Trigger Gateway backpressure with a throttled client | Upstream resumes automatically after the low watermark and the stream completes | Pending |

## Evidence required

- Device model, HarmonyOS/API version and exact HAP SHA-256.
- Two intermediate `stream-long` captures with timestamps.
- One final capture containing `STREAM-LONG-DONE`.
- Confirmation that the process was not restarted between captures.
- For a real Host run, timestamps for last visible delta, any repair request and
  the first restored delta.

Current Mock evidence:
`artifacts/device-e2e-final/stream-long-final/stream-long-liveness/manifest.json`.
The manifest records HAP SHA-256, device/API, stable PID, text advancement,
`STREAM-LONG-DONE`, reconnect-banner absence and composer responsiveness.
