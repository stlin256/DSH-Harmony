# Live process text pacing device acceptance

Date: 2026-11-05. Status: model/unit verified; device capture Pending.

| ID | Surface / interaction | Status |
| --- | --- | --- |
| PROC-01 | Reasoning text inside an expanded live process group reveals progressively | Pending; source/projection verified, nested live-group capture path not reproduced deterministically |
| PROC-02 | Preparing tool arguments reveal progressively and settle to the full argument | Pending; same harness limitation |
| PROC-03 | Reduced motion shows the complete live process text without pacing | Pending; same harness limitation |

Remaining: a deterministic Mock scene for the live process strip must first
resolve the nested live-group update behaviour (the projection carries paced
children, while the captured nested list kept its first child snapshot). Until
then use a real Host turn with reasoning/tool calls as the acceptance path and
do not promote these rows from unit tests or source inspection.
