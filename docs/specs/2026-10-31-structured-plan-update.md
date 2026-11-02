# Structured Plan Update and Floating Task List Specification

Date: 2026-10-31

Updated: 2026-11-02

## Data Projection

`NativePlan` parses `todo_write` arguments first and then a repeated JSON tool
output as a compatibility fallback. The accepted roots are:

```text
{ "todos": [...] }
{ "items": [...] }
{ "plan": [...] }
[...]
```

Each item accepts the official `content` field and the older `text` or `title`
aliases. Its status is normalized to `completed`, `in_progress` or `pending`;
an absent or unknown status projects as `pending`. Empty items and scalar array
entries are ignored. Input order is retained.

The latest parsed plan in the projected transcript owns the current floating
task list. A later empty plan is authoritative and hides the component.
Streaming or malformed JSON does not replace the last complete plan.

The summary is `已完成 n · 进行中 n · 待处理 n`, omitting zero-count segments.
The floating control and expanded process row use the same projection, so their
counts and statuses cannot disagree.

Every complete plan after the first is also compared with the preceding complete
plan by task content. The projected diff uses these rules:

- content absent from the previous plan: `创建`;
- existing content that transitions to `completed`: `完成`;
- existing content that changes to another status: `更新`;
- previous content absent from the current plan: `移除`;
- no changed content: `无变化`.

Zero-count segments are omitted. A newly created completed item counts as
`创建`; `完成` describes a transition of an item that already existed. Malformed
or incomplete plans neither receive nor replace the diff baseline. The view-only
diff is carried on the projected tool row and is used by its collapsed process
preview. The expanded structured plan continues to show current lifecycle totals.

## Plan Tool Row

`NativePlanView` follows the upstream TodoPanel hierarchy:

- checklist glyph;
- `任务计划` title;
- compact progress summary;
- one task row per item with a status mark and bounded wrapping content.

Completed tasks use the semantic green check state. In-progress tasks use the
DeepSeek blue center dot. Pending tasks use a quiet neutral outline.

`NativeToolCallView` bypasses generic argument and output rendering for
`todo_write`. Partial JSON shows `正在更新计划`; a completed malformed payload
shows `计划内容不可用`. Raw payload text is never a fallback.

## Floating Task Control

`NativeConversationDock` is a top-centered overlay child of the transcript
`Stack`. It is the reusable group for future plan-like controls and owns the
common top anchor, horizontal inset, vertical spacing, grouping semantics and
z-order. `NativeTaskDock` is its first member. The transcript `List` is the
first child of the same `Stack`; the Dock is mounted after it and before the
back-to-bottom layer. The Dock therefore paints above messages without adding a
row to the surrounding `Column` or participating in the transcript viewport's
height calculation.

The Dock wrapper uses `HitTestMode.Transparent` so its horizontal inset and
non-content area do not block transcript gestures. The task header button and
the bounded expanded task viewport continue to receive their own touch input.
The Dock layer uses `zIndex(5)`; the back-to-bottom layer remains above it at
`zIndex(6)`.

The collapsed task surface has one 32 vp row:

- checklist glyph;
- `任务计划`;
- per-status summary;
- down chevron.

After a tap, the surface expands downward into one bounded task viewport of at
most 180 vp, then a divider and compact 11 vp/16 vp status rows. The chevron
becomes an up chevron. The surrounding card grows through the semantic `surface`
motion token; the task viewport scrolls internally and uses no item entrance
loop. Because the card is an overlay, growth extends downward over messages.
Expanding or collapsing it must not change the transcript List's bounds or
current scroll offset.

The dock group uses an opaque theme surface for chat legibility across all API
levels. A restrained border and shadow separate it from scrolling content.
Reduced motion resolves expansion directly to the final state.

The component resets to collapsed when the selected Session changes. It is
removed when no current plan has items.

The circular back-to-bottom control is rendered in a separate full-transcript
alignment layer above the dock group. Its layer passes touch events outside the
button through to the transcript, and the 44 vp button is aligned to
`BottomEnd`.

## Verification

- Model tests assert parsing from arguments and output, counts, malformed-input
  inertness, latest-plan selection and empty replacement behavior.
- Source contracts assert that `todo_write` selects `NativePlanView`, skips raw
  argument/output renderers, and that the conversation mounts `NativeTaskDock`
  through `NativeConversationDock` after the transcript `List` inside the same
  Stack without adding a ListItem or a sibling layout row.
- Source contracts assert the dock's compact dimensions, bounded plan viewport
  and the back-to-bottom overlay alignment above the dock z-order.
- Source contracts assert the Dock wrapper passes non-content touches through
  and sits at a lower z-order than back-to-bottom.
- Device tests capture collapsed and expanded Dock layouts, assert that the
  transcript List bounds remain identical, scroll from a point outside the Dock
  surface, and repeat in light and dark mode plus reduced motion.
