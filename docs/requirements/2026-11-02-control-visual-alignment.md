# Cross-surface control visual alignment requirement

Date: 2026-11-02

## Goal

Every native DSH Harmony screen SHALL use one coherent control language. Controls
with the same role must share height, horizontal padding, radius, icon size,
label size and surface treatment. The result must feel quieter and more orderly
without reducing information density or weakening touch access.

## Scope

- Launch, onboarding, login, restore, connection progress and error surfaces.
- Conversation header, drawer, session rows, workspace groups and action menus.
- Composer, attachments, queue, live changes, plan dock and pending interactions.
- Settings root, all child pages, About and storage management.
- File browser, previews, document mode switch and image lightbox.
- Plugin management, automation management and reusable plugin cards.
- Transcript process rows, tool cards, structured content, turn-change cards and
  task-plan disclosures.
- Shared icon, menu, picker, status, loading, empty and error controls.

The compatibility-mode DSH web page remains an upstream visual exception.

## Required behavior

1. Product components MUST express control geometry through `NativeDesign`
   semantic tokens. New one-off control heights, radii, glyph sizes or text
   roles are prohibited.
2. A control family MUST use one recipe across every screen:
   - 44vp icon hit region with a 36vp visual container;
   - 48vp primary action and standard list row;
   - 44vp compact row and field;
   - 36vp compact inline action;
   - 32vp dense control;
   - 28vp chip;
   - 60vp two-line row.
3. Page-level surfaces MUST share one horizontal inset. Internal rows, headers,
   forms and status rows MUST align to the same content edge. A nested surface
   may add its own padding, but it MUST NOT make sibling controls start on
   different vertical lines without a semantic reason.
4. Type MUST use the documented role scale only. Arbitrary 9/15/16/17/21/22fp
   local decisions are not allowed. Hero and metric exceptions must be named
   tokens.
5. Icons MUST use the shared micro, inline, control, header, hero and empty
   roles. Repeated controls must not differ by one or two vp without semantic
   meaning.
6. Chips, badges, fields, rows, cards and overlays MUST use the shared radius
   scale. Dynamic circles remain tied to half of their explicit dimension.
7. Adjacent controls MUST use a consistent 8vp gap unless geometry is dictated
   by a segmented control, attachment strip or safe-area constraint.
8. `设置 > DSH 设置` selector rows MUST keep the 44vp Select touch target while
   using a 60vp row rhythm and 8vp vertical inset. Dividers MUST sit at the row
   boundary with visible breathing room, not against the Select surface.
9. Busy, loading, empty and error states MUST preserve the same control inset,
   label hierarchy and recovery action placement as their idle state.
10. Visual alignment MUST apply in light and dark themes, large text, narrow
   layout, reduced motion, reduced transparency and API 23 fallbacks.
11. Source contracts and Mock mapping MUST cover every migrated control family.
    A static pass is not physical-device evidence.

## Non-goals

- Changing Host state, protocol, authentication, cache or business behavior.
- Making every control the same size regardless of role.
- Copying desktop DSH spacing into phone surfaces.
- Restyling the upstream compatibility page.
- Treating static layout trees or screenshots from an older HAP as current
  physical-device evidence.

## Completion

- The authoritative design-system document contains the final control recipes.
- All native control surfaces consume semantic geometry and typography roles.
- A source contract rejects new hardcoded control roles in the audited surfaces.
- Mock coverage remains 100%.
- PR QA passes and default, store and mock Release builds succeed.
- Every changed surface is listed in the pending physical-device ledger and is
  not marked passed without current device screenshot and ArkUI layout evidence.
