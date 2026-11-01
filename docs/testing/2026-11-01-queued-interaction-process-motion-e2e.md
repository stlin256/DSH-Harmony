# Device E2E: queued input, interactions and process motion

The device was offline during implementation. Automated and build checks may be
recorded here, but no row may be marked Passed without device evidence.

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| Q01 | Send one text message while a turn is running | A single queued row appears above the composer and the text is readable | Pending |
| Q02 | Queue several text and attachment messages | Count header defaults collapsed; expansion preserves order and mixed attachment blocks | Pending |
| Q03 | Remove an authoritative queue row | Only that persistent id disappears; composer draft is unchanged | Pending |
| Q04 | Steer an authoritative queue row while running | Row is promoted through Host and the queue converges without duplicate text | Pending |
| Q05 | Edit an all-text queue row | Edited row replaces the original after authoritative state arrives | Pending |
| Q06 | Try editing a mixed attachment row | Edit affordance is unavailable; images/files are not overwritten | Pending |
| Q07 | Submit while queue acknowledgement is delayed | A sending echo is shown once and reconciles by `rpcId` | Pending |
| Q08 | Receive a Host queue row without an `rpcId` | The row remains visible and supports the actions that do not require request correlation | Pending |
| I01 | Receive an approval request | Warning strip, fitted reason/tool copy, reject and allow-once actions match theme | Pending |
| I02 | Receive a multi-question request | One question is shown with `1 / N`; next/skip/submit paging works | Pending |
| I03 | Select, custom-answer and skip questions | Single/multi selection and custom input rules match upstream; final payload is accepted | Pending |
| I04 | Long formatted question detail | Copy renders as text/markdown, never as a raw JSON wall | Pending |
| I05 | Inspect available interaction actions | No “交给其他程序处理” user-facing button is present | Pending |
| P01 | New process group appears while at the tail | Group enters once with disclosure motion and viewport settles at the new tail | Pending |
| P02 | New command/read row appears in an existing live group while at tail | Row insertion animates once and followed tail remains visible | Pending |
| P03 | Stream text or tool arguments continue updating | No group insertion animation replays and no repeated unrelated scroll starts | Pending |
| P04 | New process content appears after the user scrolls up | Reading position is preserved and the existing new-content indicator appears | Pending |
| P05 | Reduced motion enabled | Queue, interaction and process states resolve directly with no decorative entrance | Pending |
| P06 | Reopen a cached conversation containing process rows | Cached rows appear without replaying entrance motion | Pending |
| C01 | Toggle light/dark while each surface is open | All queue, approval, question and process surfaces switch theme without contrast loss | Pending |
