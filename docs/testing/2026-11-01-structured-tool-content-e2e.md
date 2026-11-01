# Structured Tool Content E2E

Device evidence is required. Parser tests and builds do not prove the final
layout or navigation behavior.

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| TOOL-STRUCT-01 | Expand a successful `read` with line metadata | Path, range, language, total lines and numbered source display without raw JSON | Pending |
| TOOL-STRUCT-02 | Expand a legacy numbered `read` result | Source window is parsed only when the numbered run is unambiguous | Pending |
| TOOL-STRUCT-03 | Expand `grep` with file matches | Pattern and scope display once; file groups and line snippets remain readable | Pending |
| TOOL-STRUCT-04 | Expand `glob` with paths | Path list uses the compact structured list and opens read-only files | Pending |
| TOOL-STRUCT-05 | Expand a terminal with cwd and exit code | Command, cwd, timeout/background state and outcome are visible; output remains complete | Pending |
| TOOL-STRUCT-06 | Expand a background-shell launch receipt | UI says it started the job and does not claim process completion | Pending |
| TOOL-STRUCT-07 | Expand `web_search` with sources | Queries, answer and strict HTTP(S) source list display without fabricated links | Pending |
| TOOL-STRUCT-08 | Expand `web_fetch` with status | URL and HTTP status display; only the parsed web URL is actionable | Pending |
| TOOL-STRUCT-09 | Expand Goal tools | Objective, phase, blocker, rounds and revision are structured; newer live projection does not rewrite the historical row | Pending |
| TOOL-STRUCT-10 | Expand Job/Subagent/Skill/Workflow rows | Stable ID, label/state and known relationships display compactly | Pending |
| TOOL-STRUCT-11 | Expand `present` | Valid deliverables appear in declaration order with descriptions; malformed entries are skipped | Pending |
| TOOL-STRUCT-12 | Open a `present`, search or read target | Existing read-only file stack opens the target and returns to chat | Pending |
| TOOL-STRUCT-13 | Expand a failed tool with otherwise valid-looking metadata | Failure remains authoritative; no success-only statistics or completion wording appear | Pending |
| TOOL-STRUCT-14 | Expand unknown or malformed tool data | Complete raw args/result remain available and the app does not crash | Pending |
| TOOL-STRUCT-15 | Stream a structured tool from preparing through result | Row identity stays stable; no repeated bubble, flicker or token entrance animation | Pending |
| TOOL-STRUCT-16 | Repeat read/edit calls on the same paths | Group summary de-duplicates successful files and counts failed calls separately | Pending |
| TOOL-STRUCT-17 | Open the structured transcript in light and dark themes | Text, metadata, success/danger states and readable surfaces follow the active theme | Pending |
| TOOL-STRUCT-18 | Build both Release products | `default` and `store` build, sign and contain shared ArkUI changes | Pending |

## Evidence to record

- Device model, HarmonyOS/API version, HAP variant and version.
- Screenshots for read, search, terminal, web, present and generic fallback.
- Tap path evidence for TOOL-STRUCT-12.
- A short recording for TOOL-STRUCT-15, including preparing and settled states.
- No real private hostname, credential, workspace path or transcript content.
