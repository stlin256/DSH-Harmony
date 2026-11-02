# Device E2E: Long Stream Render Liveness

Device evidence is required. Source tests, Mock layout mapping and compilation
do not prove live phone rendering.

## Candidate build identity

| Variant | Signed HAP | SHA-256 |
| --- | --- | --- |
| Mock | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` | `CBDAAC6954223145A2114B519652D7F6E333AE103A1AA385BF1A78FD7B5156B4` |
| Default | `harmony/entry/build/default/outputs/default/entry-default-signed.hap` | `12A50B4138BFE8BA3B6792C493B13B8948BC6349AFF09F27309A4717229C3878` |
| Store | `harmony/entry/build/store/outputs/store/entry-store-signed.hap` | `906B262EABDD48793AD33632EDBB4342DB39F4B1790C4410229F3D9230609CAD` |

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
