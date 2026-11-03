# Store review experience E2E

Date opened: 2026-11-04

Status: implementation is compile-gated for this change. Device execution has
not been requested or performed.

Requirement:
[`2026-11-04-store-review-demo.md`](../requirements/2026-11-04-store-review-demo.md)

Specification:
[`2026-11-04-store-review-demo.md`](../specs/2026-11-04-store-review-demo.md)

Driver: `scripts/device-ui-store-review-e2e.ps1`

The driver expects the credential through
`DSH_STORE_REVIEW_ACCESS_KEY`. It must never contain or write the credential to
an artifact. The script writes a process-scoped temporary file, sends it to the
device over `hdc file send`, types it with a device-side `cat` substitution and
removes both files in `finally`. It does not dump layout between password input
and Connect.

| ID | Scenario | Expected | Result |
| --- | --- | --- | --- |
| SR-01 | Community product with matching origin and credential | Ordinary Host login path remains active and no in-process review state is selected | Pending device |
| SR-02 | Store product with a non-matching credential | Normal Host authentication path runs; review state is not stored | Pending device |
| SR-03 | Store product with matching origin and credential | Native workspace opens without a remote Host deployment or review label | Pending device |
| SR-04 | Cold relaunch after review entry | Native workspace restores from the non-secret review preference | Pending device |
| SR-05 | Browse sessions, file browser, preview, plugins, automation, permissions and subagents | Populated production surfaces remain navigable with deterministic content | Pending device |
| SR-06 | Change DSH chat, conversation and permission settings | Selection updates immediately; leaving and reopening shows the same value; revision advances | Pending device |
| SR-07 | Change local theme, notifications, cards and background monitor | Existing local controls retain their normal behavior | Pending device |
| SR-08 | Send a message | Composer shows busy state for about 1200 ms, then displays the insufficient-balance message; draft remains | Pending device |
| SR-09 | Logout from review and relaunch | Review preference is cleared and the ordinary post-logout launch flow appears | Pending device |
| SR-10 | Toggle plugins, install/update/remove and reopen inventory | Later inventory reads reflect the changed installed, enabled and version state | Pending device |
| SR-11 | Create, edit, run, pause and delete an automation | Later catalog/detail/history reads reflect the mutation; stale revisions report conflict | Pending device |
| SR-12 | Attach a file | Upload resolves locally with a receipt and no Host request or cookie read occurs | Pending device |
| SR-13 | Toggle reduced motion/transparency, card details, notifications and background monitor | Controls update immediately and affect their runtime state without writing ordinary review presentation keys | Pending device |

`SR-06` revision conflicts are covered by the executable client contract. The
device driver must not manufacture a second settings client solely to race the
revision counter. `SR-12` is also exercised by the executable in-process upload
contract; a device attachment flow remains Pending.

The device driver additionally checks:

- a directory switch plus config preview/source mode;
- plugin toggle, version update, removal and installation;
- automation run, pause, create, edit and delete;
- local appearance/notification/card mutation and all writable DSH namespaces;
- cold restore of the review session and local presentation values;
- logout followed by a second cold launch that stays on ordinary login.

## Compile evidence

The delivery must record successful Release builds for:

- community/default;
- store;
- mock.

No row above may be promoted from build success or Mock screenshots alone.
