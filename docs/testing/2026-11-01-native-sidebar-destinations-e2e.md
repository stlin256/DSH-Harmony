# Native sidebar destinations E2E

Date: 2026-11-01

Status values: Pending, Pass, Fail, Blocked.

| ID | Scenario | Expected | Device |
| --- | --- | --- | --- |
| NSD-01 | Open Plugins from drawer | Native plugin page opens; drawer origin remains available | Pending |
| NSD-02 | Return from Plugins | Nested surfaces close first, then the open drawer returns | Pending |
| NSD-03 | Search plugin inventory | List filters by title, package, description and row id | Pending |
| NSD-04 | Open plugin detail | Title, description, version, source and rows are complete | Pending |
| NSD-05 | Toggle bundle | Switch updates optimistically only during acknowledged action | Pending |
| NSD-06 | Toggle plugin row | Row state reflects Host outcome and failed rows remain readable | Pending |
| NSD-07 | Inspect and install plugin | Accepted subject appears before install; refusal stays editable | Pending |
| NSD-08 | Pending build scripts | Packages are named; approve-and-retry is available | Pending |
| NSD-09 | Restart-required plugin change | Notice remains after refresh and is not lost | Pending |
| NSD-10 | Remove plugin | Destructive confirmation is required and cancellation is safe | Pending |
| NSD-11 | Open Automation from drawer | Native task list opens at active filter | Pending |
| NSD-12 | Filter automation | Active, paused, ended and all produce correct rows | Pending |
| NSD-13 | Search automation | Search checks title, instruction, session and rule | Pending |
| NSD-14 | Open task detail | Rule and delivery records are available | Pending |
| NSD-15 | Create supported task | after/every/daily/weekly/cron form creates through Host | Pending |
| NSD-16 | Edit task | Save sends exact `expectedUpdatedAt` and updates detail | Pending |
| NSD-17 | Revision conflict | Draft remains and refresh offer appears | Pending |
| NSD-18 | Pause/resume task | Status changes and list reorders | Pending |
| NSD-19 | Run now | Execution-pending and delivery outcomes are distinct | Pending |
| NSD-20 | Delete task | Confirmation is required; row disappears after ack | Pending |
| NSD-21 | Delivery history | Page loads records and older cursor | Pending |
| NSD-22 | Open More | Native menu expands under the launcher with motion | Pending |
| NSD-23 | Dismiss More | Menu closes without changing drawer state | Pending |
| NSD-24 | More actions | Each shown action executes its native destination | Pending |
| NSD-25 | Light and dark theme | Text, surfaces, outlines and icons use active theme tokens | Pending |
| NSD-26 | Reduced motion | Navigation and disclosure resolve directly to final state | Pending |
| NSD-27 | System Back stack | System and visible Back take the same stack | Pending |
| NSD-28 | Offline operation | Existing content remains; retry state is shown | Pending |
| NSD-29 | Mock coverage | Manifest verifies all new screens, states and drivers | Pending |
| NSD-30 | Release variants | default, store and mock release builds pass | Pending |

