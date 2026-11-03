# Design system unification E2E

Date: 2026-11-01

Device result values are intentionally conservative. `Pending` means no device
evidence is recorded for that row; source/build success does not replace it.

| ID | Scenario | Expected | Light | Dark | Reduced motion | Reduced transparency | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DS-01 | Launch, guide and login | Same surface hierarchy, input and 44vp controls; no layout flash | Required | Required | Required | Pending | Pending |
| DS-02 | Restore and reconnect | Centered logo/loading only; reconnect banner uses compact warning row | Required | Required | Required | Not applicable | Pending |
| DS-03 | Chat transcript | DSH density, stable streaming, no per-token entrance motion | Required | Required | Required | Not applicable | Pending |
| DS-04 | Process disclosure | Entire compact row is tappable; latest running operation open | Required | Required | Required | Not applicable | Pending |
| DS-05 | Tool/queue approval controls | No action below 44vp; card surface and accent match design system | Required | Required | Required | Not applicable | Pending |
| DS-06 | Drawer and mask | Left-in/left-out path; mask follows the same clock; phone selection visible | Required | Required | Required | Required | Pending |
| DS-07 | Session menu | No full-screen dim mask; trigger stays highlighted; solid overlay surface | Required | Required | Required | Not applicable | Pending |
| DS-08 | Pinned and workspace collapse | Correct arrow direction, downward unfold, local reorder motion | Required | Required | Required | Not applicable | Pending |
| DS-09 | Composer dock | Full-width intended blur falloff, opaque fallback, composer remains visible | Required | Required | Required | Required | Pending |
| DS-10 | Send, queue and pending echo | One authoritative row, one pending echo and no duplicate transcript item | Required | Required | Required | Not applicable | Pending |
| DS-11 | Model picker | Anchored overlay, cached content first, no blank frame | Required | Required | Required | Not applicable | Pending |
| DS-12 | Settings root and child pages | 16vp inset, shared header direction and row recipe; no permanent top shell | Required | Required | Required | Not applicable | Pending |
| DS-13 | Notification levels | Four semantic levels, all controls at least 44vp | Required | Required | Required | Not applicable | Pending |
| DS-14 | About | App logo, local avatar, author, repository, issues and version use shared cards | Required | Required | Required | Not applicable | Pending |
| DS-15 | File browser | Folder then file groups; image/folder SVG themed; 44vp header/download controls | Required | Required | Required | Not applicable | Pending |
| DS-16 | Code/Markdown/HTML/PDF preview | Header, safe area, persistent cache and top-aligned reading | Required | Required | Required | Not applicable | Pending |
| DS-17 | Image lightbox | Top safe area, background dismiss, double-tap zoom and drag remain usable | Required | Required | Required | Not applicable | Pending |
| DS-18 | System Back and visual Back | Every nested surface returns one stack level through the same path | Required | Required | Required | Not applicable | Pending |
| DS-19 | TOAST/error | Success saves remain silent; errors stay readable and recoverable | Required | Required | Required | Not applicable | Pending |
| DS-20 | API 23 fallback | Full hierarchy and operation with opaque surfaces | Required | Required | Required | Required | Pending |
| DS-21 | API 26 material | Material is enhancement only and resolves to final state under reduced effects | Required | Required | Required | Required | Pending |

## Automated evidence

Recorded on 2026-11-01. These checks cover source contracts and build integrity;
they do not replace any device row in the matrix above.

- `node --test test/design-system.test.mjs`: 6/6 passed.
- `npm test`: 157/157 passed.
- Community Release build completed:
  `harmony/entry/build/default/outputs/default/entry-default-signed.hap`.
- Store Release build completed:
  `harmony/entry/build/store/outputs/store/entry-store-signed.hap`.
- The build reports existing ArkTS deprecation warnings and no compile errors.

Device evidence has not been collected in this worktree. Every behavioral row
therefore remains `Pending` until it is exercised on the target device in both
themes and with reduced motion/transparency where applicable.

## Required capture set

- Conversation light/dark, idle and streaming.
- Settings root and one child page light/dark.
- Drawer open with current selected session.
- Queue/approval card and model picker.
- File browser and Markdown preview.
- Bottom Dock quiet/elevated and reduced transparency.
- Large text and narrow split-screen pass.

## Device evidence fields

- Device and OS build.
- App product and version.
- Fixture or real-service scenario.
- Screenshot/layout dump path.
- Pass/fail and observed exception.
