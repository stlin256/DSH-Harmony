# Native UI element audit

Date: 2026-11-01

## Method

The audit inspected all native presentation components under
`harmony/entry/src/main/ets/components`, the page shell in `pages/Index.ets`,
the design and motion documents, and the existing device fixture surfaces. It
counted literal colors, repeated surface selectors, font sizes, row heights,
radii and motion calls, then reviewed each surface for purpose and interaction
density. Browser export mirrors of upstream DSH remain outside this source
change and are governed by the compatibility boundary.

Status:

- **Aligned**: follows the intended compact DSH semantic hierarchy.
- **Drift**: works, but uses a local interpretation of a shared primitive.
- **Blocked**: needs a separate protocol or platform change.

## Cross-surface findings

| Area | Finding | Status | Resolution |
| --- | --- | --- | --- |
| Base surfaces | Chat used `#151517/#FFFFFF`, settings `#171719/#F5F6F8`, while several overlays used `#242527/#FFFFFF` | Drift | Semantic Base/Raised/Overlay tokens |
| Borders and dividers | 0.5 and 1vp borders reused unrelated `#3B3B3E`, `#414247`, `#E9EAEC`, `#DFE1E5` values | Drift | Separate Border and Divider tokens |
| Text hierarchy | Titles ranged from 14–24fp; captions ranged from 9–13fp with near-duplicate gray values | Drift | Page 20, header 18, body 14, compact 13, caption 11, micro 10 |
| Icon controls | Visual containers were 28/30/32/34/36/38/40vp and several were also the hit target | Drift | One 36vp visual container and 44vp hit target |
| Rows | Compact, settings, file, picker and menu rows mixed 28–70vp | Drift | 44 compact, 48 standard, 46 picker |
| Radii | 7/8/9/10/11/12/13/14/15/16/18/22/24vp | Drift | 8 compact, 10 control, 12 row, 16 group, 24 surface |
| Spacing | Page inset 10/12/16/18 and card padding 8/10/12/14/16/18 | Drift | 4/8/12/16 scale and 16 page inset |
| Motion | Most components use `NativeMotion`, but a few retain local duration literals and special-case spring timings | Drift | Add drawer, mask and scroll-return semantic tokens |
| SVG theme | `DSHIcon` mapped only a subset of colors, leaving theme-specific literal colors exposed | Drift | Central icon-tone resolver with success/warning/danger |
| Loading/empty/error | Spinner, text hierarchy and retry control differ by page | Drift | Shared semantic status rows and action recipe |
| Phone drawer selection | Session highlight depended on the wide-layout flag | Bug | Selection is layout-independent |
| Session menu | Popup requested a mask even though the menu is a local anchored surface | Bug | No popup mask; local tap-away owns dismissal |

## Surface inventory

| Surface | Elements reviewed | Main finding | Status |
| --- | --- | --- | --- |
| Launch and onboarding | Logo journey, mode buttons, inputs, guide cards, install details, connection progress, error card | Good DSH identity; local surface helpers duplicated token intent | Drift |
| Chat transcript | User/assistant messages, reasoning, tool calls, process groups, images, code, tables, diff | Compact and semantically close to DSH; disclosure hit regions were often only 28–30vp | Drift |
| Conversation header | Drawer, title, loading, three-dot trigger, reconnect banner | Controls had 36vp targets and mixed active fills | Drift |
| Drawer | Brand, search, new session, utilities, workspace groups, session rows, settings footer | Density is appropriate; current selection did not highlight on phone and several actions were undersized | Bug |
| Pinned/workspace sections | Pin marker, collapse direction, drag handle, count, all-workspaces selector | Direction is sound; row height and SVG is around compact | Drift |
| Plan/task dock | Floating task summary and expanded list | Correct separation from transcript; surface recipe should use shared raised/overlay values | Drift |
| Bottom dock | Queue, live changes, attachments, composer, model/reasoning, image/file/action buttons | Blur fallback is implemented; control dimensions and field surfaces differed | Drift |
| Pending interaction | Approval and question cards, options, custom answer, navigation | Dense content is needed, but controls were 32–38vp | Drift |
| Model picker | Search, provider/model/effort rows, close and retry | Cache-first behavior is correct; popup dimensions and visual control sizes were local | Drift |
| Session tools | Rename, model, effort, queue and queue edit | Uses a screen-like form language and default buttons | Drift |
| Workspace picker | Workspace list, archive, create, rename | Functional, but row/action hierarchy does not match settings and drawer | Drift |
| Settings root | Groups, navigation rows, loading and errors | Title and rows were larger and on a different base than chat | Drift |
| DSH settings | Plugin version and Host preferences | Data behavior is correct; cards, dividers and action sizes need token migration | Drift |
| Appearance | Theme choice and motion/transparency toggles | Three theme cards are useful; selection needs consistent accent and motion | Drift |
| Notifications | Four levels per category, push/background delivery | Four-level hierarchy is sound; level buttons were only 30vp | Drift |
| Storage | Pool total, category breakdown, destructive clear | Hierarchy is clear; destructive and retry actions need one semantic recipe | Drift |
| About | App identity, author, repository, issues, copyright | Complete; uses independent radii, borders and base surface | Drift |
| File browser | Header, breadcrumbs, folder/file groupings, download | Grouping is correct; header controls and RTL chevrons need shared primitives | Drift |
| Document viewer | Image/SVG/Markdown/HTML/code/PDF modes, download, close, more content | Strong task model; header buttons and loading placement varied | Drift |
| Image lightbox | Zoom/pan, download, close, background dismiss | Behavior is complete; control geometry should follow shared header recipe | Drift |
| Menus and dialogs | Session/utility menus, system dialogs, Toast | Menus are anchored; session popup mask contradicted the quiet overlay model | Bug |
| Desktop cards | Quick and overview cards | Separate system surface, but color resources and type scale need periodic parity checks | Aligned |
| Compatibility shell | Browser, loading, error and progress | Must retain upstream page identity; only native chrome is tokenized | Exception |

## Priority

1. **P0 correctness**: phone drawer selection, session menu mask, undersized
   disclosure/approval/queue actions and SVG theme leaks.
2. **P1 foundation**: semantic colors, geometry, typography and shared icon
   button.
3. **P1 surface migration**: settings, about, drawer, chat header, file headers,
   menus and pickers.
4. **P2 state language**: shared loading, empty, error and busy patterns.
5. **P2 motion**: semantic drawer, mask and scroll-return tokens; verify reduced
   motion/transparency on every surface.
6. **P3 fixture coverage**: light/dark and reduced-effects captures for every
   major surface family.

## Upstream boundary

The pinned upstream reference remains
`f3803c96974ad4a94195fb97e5c637e9c2a3afe3`. The audit preserves upstream
information order, disclosure semantics, DSH glyphs, neutral hierarchy and
DeepSeek blue accent. Mobile touch targets, drawer geometry, safe areas and
Harmony materials are documented mobile extensions.
