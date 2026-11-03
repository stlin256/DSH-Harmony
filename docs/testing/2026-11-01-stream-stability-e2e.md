# Device E2E: Stream Stability

Device evidence is required. Source tests and compilation prove contracts, not
live-network stability.

## Automated and remote evidence

Recorded on 2026-11-01:

- Gateway and native model tests: `151/151` passed.
- Community and Store Release variants compiled and signed.
- Plugin `0.3.7` was deployed to a versioned remote release. The native probe
  authenticated, received sessions over protocol `2`, opened the live channel
  successfully, and logged out.
- Remote preflight reported Harness reachable with no running sessions during
  deployment.
- No HarmonyOS target was online, so none of the device rows below are marked
  as passed.

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| STAB-01 | Start a long assistant response over the normal foreground connection | Text continues without a manual cold launch; no partial-to-empty flash | Pending |
| STAB-02 | Suppress assistant frames while continuing valid heartbeats | One repair begins after the assistant-progress deadline; the snapshot restores the latest text | Pending |
| STAB-03 | Suppress all valid frames | Exactly one link repair begins at the foreground deadline; no parallel sockets appear | Pending |
| STAB-04 | Let a tool run without an active assistant attempt for longer than 12 seconds | The App remains attached and does not reconnect during the ordinary tool gap | Pending |
| STAB-05 | Keep an approval or question open for longer than 12 seconds | The App remains attached and does not report a stream stall | Pending |
| STAB-06 | Inject an assistant revision/index gap | The visible partial remains until an authoritative snapshot replaces it as one coherent attempt | Pending |
| STAB-07 | Drag and fling during active streaming | Frames stay ordered; rendering remains responsive at the 32/64 ms cadence; the list follows direct manipulation | Pending |
| STAB-08 | Background with background monitoring enabled during a long response | A stalled active attempt repairs within the background deadline without clearing cached text | Pending |
| STAB-09 | Resume from a delivered completion notification or app switch | The completed response is already reconciled without first rendering a new-session frame | Pending |

## Evidence to record

- Device model, HarmonyOS/API version, HAP variant and version.
- Approximate network path category without recording private hosts.
- Recovery timestamps for the last visible delta, repair start and snapshot
  application.
- A screen recording for at least STAB-01, STAB-02 and STAB-07.

