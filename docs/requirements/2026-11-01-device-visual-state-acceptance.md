# Native visual state acceptance on physical device

Date: 2026-11-01

## Requirement

The connected HarmonyOS phone SHALL be used to capture, inspect, record and
correct the visual state of every native surface in the design-system audit.

Acceptance is based on device evidence. Source contracts, build output,
screenshot presence and mock mapping coverage do not prove that a visual state
is usable on a real device.

## Scope

- Launch, onboarding, login, restore and connection error surfaces.
- Conversation transcript, streaming, long content, Markdown, code, table,
  Diff, files, images and structured tool content.
- Conversation header, drawer, session groups, selected rows, anchors and
  action menus.
- Bottom dock, attachments, queue, live changes, plan, process and pending
  interactions.
- Settings root and every native child page.
- File browser, document modes, empty/loading/error rows and image lightbox.
- Plugin management, automation management and the More menu.
- Light and dark themes, reduced motion where motion changes the final state,
  and reduced transparency where material is used.

The upstream compatibility page remains an upstream visual exception. Host
authentication, notification delivery and API 23 behavior still require their
own real dependencies and cannot be inferred from the API 26 fixture device.

## Acceptance rules

1. Every reviewed state has a screenshot and ArkUI layout dump tied to the
   installed HAP, commit, device and fixture parameters.
2. Screenshots are visually inspected for clipping, overlap, safe-area
   violations, unreadable hierarchy, unstyled native controls, wrong theme
   tokens and material fallback.
3. Every action, selection, menu, navigation or state transition has an
   interaction driver and an assertion in the device E2E table.
4. A discovered visual defect is recorded before it is fixed. The E2E row stays
   failed until a rebuilt HAP is recaptured and inspected.
5. The final delivery includes the run ID, evidence root, QA report, default,
   store and mock build results, and an honest statement of environment-bound
   rows that remain pending.
