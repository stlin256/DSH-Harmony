# Device E2E: streaming scroll and Dock spring

Device evidence is required. Compilation and source tests do not prove perceived
smoothness.

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| SSD-01 | Drag upward during active text streaming | Content follows the finger; it is not pulled to the bottom by incoming deltas | Pending |
| SSD-02 | Fling during active streaming | The list coasts without repeated stalls, jumps or tail snapping | Pending |
| SSD-03 | Stop scrolling away from the bottom | Latest text is current once, the reader remains in place and the return-to-bottom action appears | Pending |
| SSD-04 | Scroll back to the bottom | Tail following resumes and the next delta stays anchored | Pending |
| SSD-05 | Queue row insertion | Dock height, material and row expand together with one spring | Pending |
| SSD-06 | Live changed-file pill insertion | No first-frame flash, material step or separate fast fade | Pending |
| SSD-07 | Attachment tray insertion/removal | The composer remains attached to the moving Dock edge | Pending |
| SSD-08 | Reduced motion | Insertions and scroll recovery resolve directly without spring or delay | Pending |
| SSD-09 | API 23 opacity fallback | No blur-specific flicker; expansion still uses the same layout spring | Pending |

## Evidence

- Record the device model, API version, HAP version and process ID.
- Capture before, mid-animation and settled screenshots for at least queue and
  live-change insertion.
- Capture a screen recording or frame trace for one drag and one fling during
  streaming.
