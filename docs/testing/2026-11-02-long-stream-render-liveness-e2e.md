# Device E2E: Long Stream Render Liveness

Device evidence is required. Source tests, Mock layout mapping and compilation
do not prove live phone rendering.

## Candidate build identity

| Variant | Signed HAP | SHA-256 |
| --- | --- | --- |
| Mock | `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap` | `534C5CC09A44BDD026B999491D55C9930B8DA043741A6860689C82C586331946` |
| Default | `harmony/entry/build/default/outputs/default/entry-default-signed.hap` | `E16675606F2E73D6C02813BCBBFE5412C0C2B46235954CAB9DD60F5568293D46` |
| Store | `harmony/entry/build/store/outputs/store/entry-store-signed.hap` | `A65E4FC385B8FB3E68516B09EFB98525762217D782C870E70C635974BF509FC4` |

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
