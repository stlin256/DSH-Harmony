# Conversation stability acceptance

Date: 2026-11-05.

| ID | Surface | Expected result | Status |
| --- | --- | --- | --- |
| CONV-STAB-01 | Continuous Mock stream | Continuous rendering keeps the app process alive for every sample | Passed on Mock HAP `69107958…` (6 min, 18/18 samples, no crash lines); PSS parser still pending |
| CONV-STAB-02 | Scroll/stream jank | The running-tail clock does not rescan the transcript per frame (cached by event cursor) | Passed via source contract and the 6-minute stress run |

Evidence: `artifacts/stress2/manifest.json` (6 min, 18/18) and the earlier
`artifacts/conversation-stress/manifest.json`.
Device fault logs (`/data/log/faultlog`) are not readable over `hdc` for this
build profile; the fault stack for the reported midday crashes could not be
retrieved. The mitigation list in the research note covers every high-frequency
ticker introduced by the running-tail work; any recurrence needs a user-exported
faultlog.
