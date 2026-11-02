# Structured Plan Update E2E

Date: 2026-10-31

Status: structured rows, plan-to-plan diff preview and the previous in-flow Dock
were device-checked. The corrected floating overlay requires a current-HAP
device rerun; the USB target is currently absent from HDC.

| ID | Scenario | Expected Result | Status |
| --- | --- | --- | --- |
| PLAN-UI-E2E-01 | Expand a completed `更新了计划` operation in a finished turn. | The card shows `任务计划`, status counts and task rows; no raw JSON is visible. | Passed; structured rows and status summary inspected |
| PLAN-UI-E2E-02 | Inspect completed, in-progress and pending items. | Each row has the matching green check, blue active dot or neutral pending outline. | Passed; all three marks inspected in light and dark |
| PLAN-UI-E2E-03 | Open a conversation containing a current plan. | The floating task control appears directly below the title and overlays the chat without reducing transcript viewport height. | Passed; dock bounds remained inside the transcript overlay |
| PLAN-UI-E2E-04 | Tap the floating task control. | It expands downward, shows task rows, and the chevron changes to up; a second tap collapses it. | Passed; expanded and collapsed bounds inspected |
| PLAN-UI-E2E-05 | Scroll the conversation while the floating control is collapsed and expanded. | The control remains anchored below the title and does not move with transcript content. | Passed; dock bounds stayed fixed while transcript moved |
| PLAN-UI-E2E-06 | Open a plan with many long task rows. | The expanded region stops at its bounded height and scrolls internally without covering the composer. | Passed; six-row plan stayed within the bounded dock viewport |
| PLAN-UI-E2E-07 | Switch to another Session without a plan, then return. | The floating control is absent for the empty plan and resets to collapsed when the planned Session returns. | Pending |
| PLAN-UI-E2E-08 | Expand the plan tool row while a turn is streaming. | No partial JSON flashes; the compact loading state is shown until structured data is available. | Pending |
| PLAN-UI-E2E-09 | Repeat in light, dark, reduced-transparency and reduced-motion modes. | Colors remain legible, opaque fallback is used when transparency is reduced, and expansion resolves without motion when requested. | Pending; light and dark passed, reduced settings remain |
| PLAN-UI-E2E-10 | Open a session with several `todo_write` updates and inspect their collapsed rows. | Each row shows the change from the previous complete plan as `创建／完成／更新／移除`; unchanged and malformed updates do not invent changes. | Passed; `创建 3` and `创建 1 · 完成 2` verified in light and dark |
| PLAN-UI-E2E-11 | Inspect and expand the floating plan near a non-16:9 phone viewport. | The dock is compact, close to the title, uses an opaque surface, and long rows still scroll within the bounded viewport. | Passed; compact and expanded states inspected on the target phone |
| PLAN-UI-E2E-12 | Scroll away from the bottom while a plan is present. | The circular back-to-bottom button appears above the dock layer at the bottom-right, with no plan text underneath it. | Passed; button bounds remained at the transcript bottom-right above dock z-order |
| PLAN-UI-E2E-13 | Inspect a collapsed current plan in the dedicated Mock overlay scene. | The Dock's top aligns with the transcript viewport, not a row above it, and the transcript List bounds are recorded. | Pending; no ready USB target |
| PLAN-UI-E2E-14 | Expand the Dock, then swipe from a point outside its surface. | The transcript List top and height do not change, the expanded Dock occludes messages, and the transcript scroll offset changes from the outside swipe. | Pending; no ready USB target |
| PLAN-UI-E2E-15 | Collapse the expanded Dock and repeat in light, dark, reduced-motion and maximum-font states. | The list remains stationary, the header and bounded task viewport stay readable, and reduced motion resolves without an expanding animation. | Pending; no ready USB target |
