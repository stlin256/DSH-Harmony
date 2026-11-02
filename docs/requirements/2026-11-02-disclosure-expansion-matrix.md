# Disclosure expansion visual acceptance requirement

Date: 2026-11-02

## Goal

Every user-visible expandable native control SHALL have a deterministic Mock
fixture, a real-device click sequence, an expanded screenshot, a layout
assertion and a recorded pass or failure before visual completion is claimed.

A collapsed screenshot, a source contract or a single compound transcript does
not prove that every disclosure renders correctly after expansion.

## Scope

- Task-plan banner and body.
- Turn-level work-process container.
- Reasoning, read, search, terminal, diff, nested tool, goal, job, subagent,
  web, question, image metadata, plugin view and presented-file tool bodies.
- Direct reasoning and legacy tool rows that remain reachable.
- Long Diff expansion.
- Background-task notice.
- Multi-item queue header and rows.
- Turn-file-change card.
- Sidebar More disclosure and collapsible workspace groups.

## Required behavior

1. Each disclosure type MUST expose a unique deterministic Mock state under the
   dark theme used for annotation review.
2. The device driver MUST click the real disclosure control and assert content
   that is absent before expansion.
3. A second assertion MUST cover the expanded state. Controls that persist
   manual state MUST also be collapsed and reopened once.
4. The expanded surface MUST stay inside the safe area, avoid clipping and
   overlap, preserve stable row identity and keep every label readable.
5. Nested scrolling MUST have one scroll owner at each level. Expansion MUST
   not create horizontal overflow or move unrelated controls.
6. Arrow direction, accessibility text, press target and reduced-motion
   behavior MUST agree with the actual open state.
7. Long paths retain a filename-first hierarchy. Fixed metrics and trailing
   actions MUST not be covered by path text.
8. Source and model contracts MUST reject missing operation families or unstable
   disclosure identities.
9. Mock coverage MUST register every new state, scene, driver and E2E row.
10. Device completion requires current screenshots and layout trees from the
    installed Mock HAP. Static registration alone remains Pending.

## Edge audit

After the matrix passes, inspect:

- maximum system font size;
- empty, malformed and oversized structured payloads;
- long titles, paths, commands and output;
- scroll position before, during and after expansion;
- keyboard presence and system Back while expanded;
- reduced motion and reduced transparency;
- dark and light semantics for shared controls.

## Completion

- The disclosure matrix has no unregistered component family.
- All disclosure states are captured expanded on a physical device.
- Discovered defects are fixed in shared components and recaptured.
- `node scripts/verify-mock-coverage.mjs` passes.
- PR QA and default, store and mock Release builds pass.
- The delivery summary links the evidence root, run ID, HAP hashes and any
  explicitly environment-bound pending rows.
