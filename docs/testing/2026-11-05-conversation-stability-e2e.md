# Conversation stability acceptance

Date: 2026-11-05.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| CONV-STAB-01 | Continuous Mock stream | A 180-second continuous `stream-long`/`stream-tail` sample keeps the app process alive for every sample | Passed on the pre-revision Mock HAP (12/12 samples); rerun pending |

Evidence: `artifacts/conversation-stress/manifest.json`.
Device fault logs (`/data/log/faultlog`) are not readable over `hdc` for this
build profile; the fault stack for the reported midday crashes could not be
retrieved. The mitigation list in the research note covers every high-frequency
ticker introduced by the running-tail work; any recurrence needs a user-exported
faultlog.
