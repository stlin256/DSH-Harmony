# Conversation dock inset specification

Date: 2026-11-01

## List contract

The task-plan dock occupies its own row in the conversation `Column`, directly
above the transcript `Stack`. The transcript `List` receives the remaining
height and clips its scroll content to that viewport, so content cannot paint
beneath the dock. The dock retains its centered floating-card surface, border,
shadow and disclosure motion, but it is not derived from the scroll content or
overlaid on it.

No spacer row, translated content or duplicate lazy item is introduced.
`contentStartOffset()` and top List padding were both rejected after device
evidence showed that a list initially positioned at the bottom could still
paint its first item beneath a fixed overlay.

The existing history button remains part of the transcript content. Expanding
the plan reduces transcript viewport height and retains the current tail-follow
behavior.

## Verification

- Source contracts verify the dock row precedes the transcript viewport and no
  spacer item is introduced.
- The transcript viewport clips content outside its measured bounds.
- The height and plan lifecycle tests remain green.
- Both Release variants build.
- Device E2E checks collapsed and expanded docks at initial load, first-message
  top and while history is loading. The first message bounds must not intersect
  the dock bounds.

