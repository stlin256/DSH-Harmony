# Repository Instructions

## Scope

DSH Harmony is a native HarmonyOS client and compatibility surface for DeepSeek
Harness. Preserve upstream behavior and identity while adapting layout for phone
touch, keyboard, safe areas and system Back.

## Required Workflow

For non-trivial UI or state changes:

1. Record the user requirement.
2. Research the current app and the pinned upstream reference.
3. Write or update a spec before production implementation.
4. Implement data contracts and correctness before decorative motion.
5. Add meaningful model/protocol tests.
6. Add a deterministic `mock` product fixture and screenshot scene for every
   user-visible frontend feature. Register it in
   `docs/testing/mock-feature-manifest.json`.
7. Add an interaction driver for every new action, selection, send, navigation
   or state transition, and add matching rows to the device E2E table. A static
   screenshot alone is insufficient for interactive behavior.
8. Run `node scripts/verify-mock-coverage.mjs`. Do not deliver a frontend change
   when this check fails.
9. Run `node scripts/qa.mjs pr` for a non-trivial change and keep the generated
   QA report path or run ID in the delivery summary.
10. Build the default, store and mock product variants when shared ArkUI code
   changes.
11. Device access was restored by the user on 2026-11-02. Use the connected
    phone for current visual and interaction evidence when a UI or state change
    affects native surfaces. Before ending any turn that changes UI or state,
    update `docs/testing/2026-11-01-device-visual-state-acceptance-e2e.md` with
    every affected surface, interaction, theme and fallback. Do not mark a row
    passed from static tests, pre-change screenshots or Mock coverage alone.
12. Add or update the device E2E table. Do not claim device completion without
   actual device evidence.
13. Use `node scripts/qa.mjs release --evidence <manifest>` only with current,
    clean evidence. Mapping coverage, a Pending row or a stale HAP hash is never
    device proof.
14. Keep the `Remaining device checks` section in
    `docs/testing/2026-11-01-device-visual-state-acceptance-e2e.md` current
    before pausing device work or claiming completion.

Do not put private hosts, internal addresses, credentials, cookies, signatures,
or real transcript content in source, tests, docs, logs or commits.

## Design and Motion Rules

- Use the DSH visual language: compact information density, neutral surfaces,
  precise outlines, business glyphs and DeepSeek blue as the primary accent.
- Motion follows Quiet Precision: immediate press feedback, explicit spatial
  direction, interruptible direct manipulation, and no decorative loops.
- Streaming tokens, cache refreshes, incremental history and ordinary scroll
  entries must not play item entrance animation.
- Respect `NativeExperience.reducedMotion()`. All non-essential motion must
  resolve directly to the final state.
- Use semantic motion tokens instead of new one-off durations.
- API 26 materials are enhancements. API 23 must retain full function and
  hierarchy with opaque theme surfaces.

## Device Verification Ledger

Keep these gaps explicit until a physical or emulated target proves them:

- Current-HAP rerun of the static Mock suite, subagent send, settings navigation
  and all four disclosure matrices after the composer-state correction.
- Current-HAP subagent count in the conversation title row with a long title,
  plus opening a child conversation without a false connection-lost state.
- Current-HAP live process timeline order (`reasoning -> tool -> reasoning`) in
  dark, light, maximum system font size and collapse/reopen, using
  `disclosure-process-order` and `scripts/device-ui-disclosure-e2e.ps1`.
- Current-HAP secret mask first paint, reveal/hide, raw-copy source, long
  virtual-window boundary, settings search navigation and system Back.
- Floating task-plan Dock collapsed and expanded overlay geometry, unchanged
  transcript List bounds, outside-surface scrolling, light/dark themes,
  reduced motion and maximum system font size.
- API 23 opaque-material fallback.
- Portrait and landscape layouts under maximum system font size.
- Saved-session restore, expired-session recovery and logout/relaunch with a
  real account exchange.
- Provider reconnect and session-switch restoration with a live Host stream.
- Long-stream liveness with the current HAP: `stream-long` must advance in at
  least two captures, show `STREAM-LONG-DONE` without relaunch, keep the same
  process ID and leave the composer responsive.
- Current-HAP notification level density in dark, light and maximum system
  font size: all four painted choices must stay at 32vp with a 44vp response
  region and no clipping or overlap.
- Current-device image-lightbox interaction evidence.
- Large-text onboarding, guide, detailed install page, login and inline error.

Never promote a Pending or Partial row from Mock coverage, source inspection,
static tests or a screenshot produced by an older HAP.

## Design, Spec and Evidence Index

- Visual baseline: [DESIGN.md](docs/DESIGN.md)
- Physical-device visual acceptance requirement:
  [2026-11-01-device-visual-state-acceptance.md](docs/requirements/2026-11-01-device-visual-state-acceptance.md)
- Physical-device visual acceptance implementation spec:
  [2026-11-01-device-visual-state-acceptance.md](docs/specs/2026-11-01-device-visual-state-acceptance.md)
- Physical-device visual acceptance and pending verification ledger:
  [2026-11-01-device-visual-state-acceptance-e2e.md](docs/testing/2026-11-01-device-visual-state-acceptance-e2e.md)
- DSH Go-inspired frontend hardening requirement:
  [2026-11-02-dsh-go-frontend-hardening.md](docs/requirements/2026-11-02-dsh-go-frontend-hardening.md)
- DSH Go frontend learning research:
  [2026-11-02-dsh-go-frontend-learnings.md](docs/research/2026-11-02-dsh-go-frontend-learnings.md)
- DSH Go-inspired frontend hardening implementation spec:
  [2026-11-02-dsh-go-frontend-hardening.md](docs/specs/2026-11-02-dsh-go-frontend-hardening.md)
- DSH Go-inspired frontend hardening device E2E:
  [2026-11-02-dsh-go-frontend-hardening-e2e.md](docs/testing/2026-11-02-dsh-go-frontend-hardening-e2e.md)
- Cross-surface control visual alignment requirement:
  [2026-11-02-control-visual-alignment.md](docs/requirements/2026-11-02-control-visual-alignment.md)
- Cross-surface control visual alignment research:
  [2026-11-02-control-visual-alignment.md](docs/research/2026-11-02-control-visual-alignment.md)
- Cross-surface control visual alignment implementation spec:
  [2026-11-02-control-visual-alignment.md](docs/specs/2026-11-02-control-visual-alignment.md)
- Cross-surface control visual alignment device E2E:
  [2026-11-02-control-visual-alignment-e2e.md](docs/testing/2026-11-02-control-visual-alignment-e2e.md)
- Live process stream ordering requirement:
  [2026-11-02-live-process-stream-order.md](docs/requirements/2026-11-02-live-process-stream-order.md)
- Live process stream ordering research:
  [2026-11-02-live-process-stream-order.md](docs/research/2026-11-02-live-process-stream-order.md)
- Live process stream ordering implementation spec:
  [2026-11-02-live-process-stream-order.md](docs/specs/2026-11-02-live-process-stream-order.md)
- Live process stream ordering device E2E:
  [2026-11-02-live-process-stream-order-e2e.md](docs/testing/2026-11-02-live-process-stream-order-e2e.md)
- Authoritative design system and motion baseline:
  [2026-11-01-dsh-harmony-design-system.md](docs/design/2026-11-01-dsh-harmony-design-system.md)
- Design-system unification requirement:
  [2026-11-01-design-system-unification.md](docs/requirements/2026-11-01-design-system-unification.md)
- Complete native UI element audit:
  [2026-11-01-design-system-audit.md](docs/research/2026-11-01-design-system-audit.md)
- Plan mode and subagent presentation requirement:
  [2026-11-01-mode-subagent-presentation.md](docs/requirements/2026-11-01-mode-subagent-presentation.md)
- Plan mode and subagent presentation research:
  [2026-11-01-mode-subagent-presentation.md](docs/research/2026-11-01-mode-subagent-presentation.md)
- Plan mode and subagent presentation implementation spec:
  [2026-11-01-mode-subagent-presentation.md](docs/specs/2026-11-01-mode-subagent-presentation.md)
- Plan mode and subagent presentation device E2E:
  [2026-11-01-mode-subagent-presentation-e2e.md](docs/testing/2026-11-01-mode-subagent-presentation-e2e.md)
- Design-system unification implementation spec:
  [2026-11-01-design-system-unification.md](docs/specs/2026-11-01-design-system-unification.md)
- Design-system unification E2E:
  [2026-11-01-design-system-unification-e2e.md](docs/testing/2026-11-01-design-system-unification-e2e.md)
- Visual and motion design:
  [2026-10-31-dsh-harmony-visual-motion.md](docs/design/2026-10-31-dsh-harmony-visual-motion.md)
- Motion requirement:
  [2026-10-31-motion-workspace-pin-scroll-bottom.md](docs/requirements/2026-10-31-motion-workspace-pin-scroll-bottom.md)
- Motion implementation spec:
  [2026-10-31-motion-system.md](docs/specs/2026-10-31-motion-system.md)
- Pin, workspace ordering and scroll spec:
  [2026-10-31-workspace-pin-order-scroll-bottom.md](docs/specs/2026-10-31-workspace-pin-order-scroll-bottom.md)
- Self-contained plugin requirement:
  [2026-10-31-plugin-self-contained.md](docs/requirements/2026-10-31-plugin-self-contained.md)
- Self-contained plugin implementation spec:
  [2026-10-31-plugin-self-contained.md](docs/specs/2026-10-31-plugin-self-contained.md)
- Plugin activation recovery requirement:
  [2026-10-31-plugin-activation-recovery.md](docs/requirements/2026-10-31-plugin-activation-recovery.md)
- Plugin activation recovery implementation spec:
  [2026-10-31-plugin-activation-recovery.md](docs/specs/2026-10-31-plugin-activation-recovery.md)
- Plugin activation recovery device E2E:
  [2026-10-31-plugin-activation-recovery-e2e.md](docs/testing/2026-10-31-plugin-activation-recovery-e2e.md)
- Navigation and process refinement requirement:
  [2026-10-31-navigation-process-refinement.md](docs/requirements/2026-10-31-navigation-process-refinement.md)
- Navigation and process refinement spec:
  [2026-10-31-navigation-process-refinement.md](docs/specs/2026-10-31-navigation-process-refinement.md)
- Navigation and process device E2E:
  [2026-10-31-navigation-process-refinement-e2e.md](docs/testing/2026-10-31-navigation-process-refinement-e2e.md)
- HarmonyOS 7 motion research:
  [2026-10-31-harmonyos7-motion-strategy.md](docs/research/2026-10-31-harmonyos7-motion-strategy.md)
- Control motion audit:
  [2026-10-31-control-motion-audit.md](docs/research/2026-10-31-control-motion-audit.md)
- Pin, order and scroll research:
  [2026-10-31-workspace-pin-order-scroll-bottom.md](docs/research/2026-10-31-workspace-pin-order-scroll-bottom.md)
- Formal E2E checklist:
  [2026-10-31-motion-workspace-scroll-e2e.md](docs/testing/2026-10-31-motion-workspace-scroll-e2e.md)
- Settings surface, safe area and icon requirement:
  [2026-10-31-settings-safe-area-icons.md](docs/requirements/2026-10-31-settings-safe-area-icons.md)
- Settings surface implementation spec:
  [2026-10-31-settings-safe-area-icons.md](docs/specs/2026-10-31-settings-safe-area-icons.md)
- Store showcase screenshot requirement:
  [2026-10-31-store-showcase-screenshots.md](docs/requirements/2026-10-31-store-showcase-screenshots.md)
- Store showcase screenshot implementation spec:
  [2026-10-31-store-showcase-screenshots.md](docs/specs/2026-10-31-store-showcase-screenshots.md)
- Store showcase screenshot E2E:
  [2026-10-31-store-showcase-screenshots-e2e.md](docs/testing/2026-10-31-store-showcase-screenshots-e2e.md)
- AppGallery ACL-safe store variant requirement:
  [2026-10-31-store-acl-variant.md](docs/requirements/2026-10-31-store-acl-variant.md)
- AppGallery ACL-safe store variant implementation spec:
  [2026-10-31-store-acl-variant.md](docs/specs/2026-10-31-store-acl-variant.md)
- AppGallery ACL-safe store variant E2E:
  [2026-10-31-store-acl-variant-e2e.md](docs/testing/2026-10-31-store-acl-variant-e2e.md)
- AppGallery layered icon requirement:
  [2026-10-31-store-layered-icon.md](docs/requirements/2026-10-31-store-layered-icon.md)
- AppGallery layered icon implementation spec:
  [2026-10-31-store-layered-icon.md](docs/specs/2026-10-31-store-layered-icon.md)
- AppGallery layered icon E2E:
  [2026-10-31-store-layered-icon-e2e.md](docs/testing/2026-10-31-store-layered-icon-e2e.md)
- Chat controls and drawer requirement:
  [2026-10-31-chat-controls-refinement.md](docs/requirements/2026-10-31-chat-controls-refinement.md)
- Chat controls and drawer implementation spec:
  [2026-10-31-chat-controls-refinement.md](docs/specs/2026-10-31-chat-controls-refinement.md)
- Workspace file preview, mode switch, download and browser requirement:
  [2026-10-31-workspace-file-preview-browser.md](docs/requirements/2026-10-31-workspace-file-preview-browser.md)
- Workspace file preview implementation spec:
  [2026-10-31-workspace-file-preview-browser.md](docs/specs/2026-10-31-workspace-file-preview-browser.md)
- Workspace file preview and read-only E2E:
  [2026-10-31-workspace-file-preview-browser-e2e.md](docs/testing/2026-10-31-workspace-file-preview-browser-e2e.md)
- Sidebar scrollbar and browser-navigation requirement:
  [2026-10-31-sidebar-scrollbar-file-browser-navigation.md](docs/requirements/2026-10-31-sidebar-scrollbar-file-browser-navigation.md)
- Sidebar scrollbar and browser-navigation implementation spec:
  [2026-10-31-sidebar-scrollbar-file-browser-navigation.md](docs/specs/2026-10-31-sidebar-scrollbar-file-browser-navigation.md)
- Sidebar scrollbar and browser-navigation E2E:
  [2026-10-31-sidebar-scrollbar-file-browser-navigation-e2e.md](docs/testing/2026-10-31-sidebar-scrollbar-file-browser-navigation-e2e.md)
- Stability, settings feedback, notification prominence and composer inset
  requirement:
  [2026-10-31-stability-settings-notification-composer.md](docs/requirements/2026-10-31-stability-settings-notification-composer.md)
- Stability, settings feedback, notification prominence and composer inset
  implementation spec:
  [2026-10-31-stability-settings-notification-composer.md](docs/specs/2026-10-31-stability-settings-notification-composer.md)
- Stability, settings feedback, notification prominence and composer inset
  E2E:
  [2026-10-31-stability-settings-notification-composer-e2e.md](docs/testing/2026-10-31-stability-settings-notification-composer-e2e.md)
- Plugin installation, onboarding and branded launch requirement:
  [2026-10-31-plugin-install-onboarding-launch.md](docs/requirements/2026-10-31-plugin-install-onboarding-launch.md)
- Plugin installation, onboarding and branded launch implementation spec:
  [2026-10-31-plugin-install-onboarding-launch.md](docs/specs/2026-10-31-plugin-install-onboarding-launch.md)
- Plugin installation, onboarding and branded launch E2E:
  [2026-10-31-plugin-install-onboarding-launch-e2e.md](docs/testing/2026-10-31-plugin-install-onboarding-launch-e2e.md)
- Latest DSH stream recovery and native composer attachment requirement:
  [2026-10-31-stream-recovery-composer-attachments.md](docs/requirements/2026-10-31-stream-recovery-composer-attachments.md)
- Latest DSH stream recovery and native composer attachment implementation
  spec:
  [2026-10-31-stream-recovery-composer-attachments.md](docs/specs/2026-10-31-stream-recovery-composer-attachments.md)
- Latest DSH stream recovery and native composer attachment E2E:
  [2026-10-31-stream-recovery-composer-attachments-e2e.md](docs/testing/2026-10-31-stream-recovery-composer-attachments-e2e.md)
- Native UI startup requirement:
  [2026-11-01-native-ui-default.md](docs/requirements/2026-11-01-native-ui-default.md)
- Native UI startup implementation spec:
  [2026-11-01-native-ui-default.md](docs/specs/2026-11-01-native-ui-default.md)
- Native UI startup E2E:
  [2026-11-01-native-ui-default-e2e.md](docs/testing/2026-11-01-native-ui-default-e2e.md)
- Rendering, navigation and startup requirement:
  [2026-11-01-render-navigation-startup.md](docs/requirements/2026-11-01-render-navigation-startup.md)
- Rendering, navigation and startup research:
  [2026-11-01-render-navigation-startup.md](docs/research/2026-11-01-render-navigation-startup.md)
- External link affordance spec:
  [2026-11-01-external-link-affordance.md](docs/specs/2026-11-01-external-link-affordance.md)
- Restored conversation startup spec:
  [2026-11-01-startup-conversation-restoration.md](docs/specs/2026-11-01-startup-conversation-restoration.md)
- Conversation dock inset spec:
  [2026-11-01-conversation-dock-inset.md](docs/specs/2026-11-01-conversation-dock-inset.md)
- File browser history spec:
  [2026-11-01-file-browser-history.md](docs/specs/2026-11-01-file-browser-history.md)
- PDF and HTML preview spec:
  [2026-11-01-pdf-html-preview.md](docs/specs/2026-11-01-pdf-html-preview.md)
- Rendering, navigation and startup E2E:
  [2026-11-01-render-navigation-startup-e2e.md](docs/testing/2026-11-01-render-navigation-startup-e2e.md)
- Default 5 GiB cache pool requirement:
  [2026-11-01-default-cache-pool.md](docs/requirements/2026-11-01-default-cache-pool.md)
- Default cache pool research:
  [2026-11-01-default-cache-pool.md](docs/research/2026-11-01-default-cache-pool.md)
- Default cache pool implementation spec:
  [2026-11-01-default-cache-pool.md](docs/specs/2026-11-01-default-cache-pool.md)
- Default cache pool E2E:
  [2026-11-01-default-cache-pool-e2e.md](docs/testing/2026-11-01-default-cache-pool-e2e.md)
- Continuous history prefetch and split transcript-cache requirement:
  [2026-10-31-history-continuous-prefetch.md](docs/requirements/2026-10-31-history-continuous-prefetch.md)
- Continuous history prefetch and split transcript-cache implementation spec:
  [2026-10-31-history-continuous-prefetch.md](docs/specs/2026-10-31-history-continuous-prefetch.md)
- Continuous history prefetch E2E:
  [2026-10-31-history-continuous-prefetch-e2e.md](docs/testing/2026-10-31-history-continuous-prefetch-e2e.md)
- Plan expansion stability and immediate file preview requirement:
  [2026-10-31-plan-expand-file-open-latency.md](docs/requirements/2026-10-31-plan-expand-file-open-latency.md)
- Plan expansion stability and immediate file preview implementation spec:
  [2026-10-31-plan-expand-file-open-latency.md](docs/specs/2026-10-31-plan-expand-file-open-latency.md)
- Plan expansion stability and immediate file preview E2E:
  [2026-10-31-plan-expand-file-open-latency-e2e.md](docs/testing/2026-10-31-plan-expand-file-open-latency-e2e.md)
- Disclosure expansion visual acceptance requirement:
  [2026-11-02-disclosure-expansion-matrix.md](docs/requirements/2026-11-02-disclosure-expansion-matrix.md)
- Disclosure expansion coverage research:
  [2026-11-02-disclosure-expansion-matrix.md](docs/research/2026-11-02-disclosure-expansion-matrix.md)
- Disclosure expansion implementation spec:
  [2026-11-02-disclosure-expansion-matrix.md](docs/specs/2026-11-02-disclosure-expansion-matrix.md)
- Disclosure expansion device E2E:
  [2026-11-02-disclosure-expansion-matrix-e2e.md](docs/testing/2026-11-02-disclosure-expansion-matrix-e2e.md)
- Chat link existence requirement:
  [2026-10-31-chat-link-existence.md](docs/requirements/2026-10-31-chat-link-existence.md)
- Chat link existence implementation spec:
  [2026-10-31-chat-link-existence.md](docs/specs/2026-10-31-chat-link-existence.md)
- Chat link existence device E2E:
  [2026-10-31-chat-link-existence-e2e.md](docs/testing/2026-10-31-chat-link-existence-e2e.md)
- Workspace file persistent cache requirement:
  [2026-11-01-workspace-file-persistent-cache.md](docs/requirements/2026-11-01-workspace-file-persistent-cache.md)
- Workspace file persistent cache implementation spec:
  [2026-11-01-workspace-file-persistent-cache.md](docs/specs/2026-11-01-workspace-file-persistent-cache.md)
- Workspace file persistent cache device E2E:
  [2026-11-01-workspace-file-persistent-cache-e2e.md](docs/testing/2026-11-01-workspace-file-persistent-cache-e2e.md)
- Versioned plugin update requirement:
  [2026-11-01-plugin-update-workflow.md](docs/requirements/2026-11-01-plugin-update-workflow.md)
- Versioned plugin update implementation spec:
  [2026-11-01-plugin-update-workflow.md](docs/specs/2026-11-01-plugin-update-workflow.md)
- Local storage management requirement:
  [2026-11-01-storage-management.md](docs/requirements/2026-11-01-storage-management.md)
- Local storage management implementation spec:
  [2026-11-01-storage-management.md](docs/specs/2026-11-01-storage-management.md)
- Local storage management device E2E:
  [2026-11-01-storage-management-e2e.md](docs/testing/2026-11-01-storage-management-e2e.md)
- Structured plan update and floating task list requirement:
  [2026-10-31-structured-plan-update.md](docs/requirements/2026-10-31-structured-plan-update.md)
- Structured plan update and floating task list implementation spec:
  [2026-10-31-structured-plan-update.md](docs/specs/2026-10-31-structured-plan-update.md)
- Structured plan update and floating task list E2E:
  [2026-10-31-structured-plan-update-e2e.md](docs/testing/2026-10-31-structured-plan-update-e2e.md)
- Navigation, intentional return, nonlinear motion and file browsing requirement:
  [2026-10-31-navigation-motion-return-polish.md](docs/requirements/2026-10-31-navigation-motion-return-polish.md)
- Navigation, intentional return, nonlinear motion and file browsing implementation spec:
  [2026-10-31-navigation-motion-return-polish.md](docs/specs/2026-10-31-navigation-motion-return-polish.md)
- Navigation, intentional return, nonlinear motion and file browsing E2E:
  [2026-10-31-navigation-motion-return-polish-e2e.md](docs/testing/2026-10-31-navigation-motion-return-polish-e2e.md)
- Native interaction baseline:
  [NATIVE-INTERACTION-SPEC.md](docs/NATIVE-INTERACTION-SPEC.md)
- Agent quality-gate requirement:
  [2026-11-01-agent-quality-gates.md](docs/requirements/2026-11-01-agent-quality-gates.md)
- Agent quality-gate implementation spec:
  [2026-11-01-agent-quality-gates.md](docs/specs/2026-11-01-agent-quality-gates.md)
- Agent quality-gate E2E:
  [2026-11-01-agent-quality-gates-e2e.md](docs/testing/2026-11-01-agent-quality-gates-e2e.md)
- Fenced DSH UI and media compatibility requirement:
  [2026-11-01-fenced-dsh-ui-media-compatibility.md](docs/requirements/2026-11-01-fenced-dsh-ui-media-compatibility.md)
- Fenced DSH UI and media compatibility research:
  [2026-11-01-fenced-dsh-ui-media-compatibility.md](docs/research/2026-11-01-fenced-dsh-ui-media-compatibility.md)
- Fenced DSH UI and media compatibility spec:
  [2026-11-01-fenced-dsh-ui-media-compatibility.md](docs/specs/2026-11-01-fenced-dsh-ui-media-compatibility.md)
- Fenced DSH UI and media compatibility E2E:
  [2026-11-01-fenced-dsh-ui-media-compatibility-e2e.md](docs/testing/2026-11-01-fenced-dsh-ui-media-compatibility-e2e.md)
- Existing shell/performance E2E:
  [2026-10-30-native-shell-performance-e2e.md](docs/testing/2026-10-30-native-shell-performance-e2e.md)
- HarmonyOS 7 platform notes: [HARMONY7.md](docs/HARMONY7.md)
- PDFKit dark-canvas known limitation:
  [2026-11-01-pdfview-dark-canvas-limitation.md](docs/research/2026-11-01-pdfview-dark-canvas-limitation.md)
- Per-turn file-change card and live bottom control requirement:
  [2026-11-01-turn-file-change-surfaces.md](docs/requirements/2026-11-01-turn-file-change-surfaces.md)
- Per-turn file-change data and UI research:
  [2026-11-01-turn-file-change-surfaces.md](docs/research/2026-11-01-turn-file-change-surfaces.md)
- Per-turn file-change surfaces implementation spec:
  [2026-11-01-turn-file-change-surfaces.md](docs/specs/2026-11-01-turn-file-change-surfaces.md)
- Per-turn file-change surfaces device E2E:
  [2026-11-01-turn-file-change-surfaces-e2e.md](docs/testing/2026-11-01-turn-file-change-surfaces-e2e.md)
- Live process, title and streaming requirement:
  [2026-11-01-live-process-title-streaming.md](docs/requirements/2026-11-01-live-process-title-streaming.md)
- Live process, title and streaming research:
  [2026-11-01-live-process-title-streaming.md](docs/research/2026-11-01-live-process-title-streaming.md)
- Live process, title and streaming implementation spec:
  [2026-11-01-live-process-title-streaming.md](docs/specs/2026-11-01-live-process-title-streaming.md)
- Live process, title and streaming device E2E:
  [2026-11-01-live-process-title-streaming-e2e.md](docs/testing/2026-11-01-live-process-title-streaming-e2e.md)
- Device UI mock and bottom dock requirement:
  [2026-11-01-device-ui-mock-e2e.md](docs/requirements/2026-11-01-device-ui-mock-e2e.md)
- Device UI mock and bottom dock implementation spec:
  [2026-11-01-device-ui-mock-e2e.md](docs/specs/2026-11-01-device-ui-mock-e2e.md)
- Device UI mock and bottom dock E2E:
  [2026-11-01-device-ui-mock-e2e.md](docs/testing/2026-11-01-device-ui-mock-e2e.md)
- Mock variant and frontend coverage requirement:
  [2026-11-01-mock-variant-coverage.md](docs/requirements/2026-11-01-mock-variant-coverage.md)
- Mock variant and frontend coverage research:
  [2026-11-01-mock-variant-coverage.md](docs/research/2026-11-01-mock-variant-coverage.md)
- Mock variant and frontend coverage implementation spec:
  [2026-11-01-mock-variant-coverage.md](docs/specs/2026-11-01-mock-variant-coverage.md)
- Mock variant and frontend coverage E2E:
  [2026-11-01-mock-variant-coverage-e2e.md](docs/testing/2026-11-01-mock-variant-coverage-e2e.md)
- Queued input, pending interaction and live process motion requirement:
  [2026-11-01-queued-interaction-process-motion.md](docs/requirements/2026-11-01-queued-interaction-process-motion.md)
- Queue, interaction and process motion research:
  [2026-11-01-queued-interaction-process-motion.md](docs/research/2026-11-01-queued-interaction-process-motion.md)
- Queue, interaction and process motion implementation spec:
  [2026-11-01-queued-interaction-process-motion.md](docs/specs/2026-11-01-queued-interaction-process-motion.md)
- Queue, interaction and process motion device E2E:
  [2026-11-01-queued-interaction-process-motion-e2e.md](docs/testing/2026-11-01-queued-interaction-process-motion-e2e.md)
- Visual consistency and interactive Dock requirement:
  [2026-11-01-visual-consistency-dock-send-e2e.md](docs/requirements/2026-11-01-visual-consistency-dock-send-e2e.md)
- Visual consistency, Mock and Dock research:
  [2026-11-01-visual-consistency-dock-send-e2e.md](docs/research/2026-11-01-visual-consistency-dock-send-e2e.md)
- Visual consistency, interactive Mock and Dock material implementation spec:
  [2026-11-01-visual-consistency-dock-send-e2e.md](docs/specs/2026-11-01-visual-consistency-dock-send-e2e.md)
- Visual consistency, screenshot and Dock send E2E:
  [2026-11-01-visual-consistency-dock-send-e2e.md](docs/testing/2026-11-01-visual-consistency-dock-send-e2e.md)
- Composer IME layout stability requirement:
  [2026-11-02-composer-ime-layout-stability.md](docs/requirements/2026-11-02-composer-ime-layout-stability.md)
- Composer IME layout stability implementation spec:
  [2026-11-02-composer-ime-layout-stability.md](docs/specs/2026-11-02-composer-ime-layout-stability.md)
- Composer IME layout stability device E2E:
  [2026-11-02-composer-ime-layout-stability-e2e.md](docs/testing/2026-11-02-composer-ime-layout-stability-e2e.md)
- Streaming scroll and Dock spring requirement:
  [2026-11-01-stream-scroll-dock-spring.md](docs/requirements/2026-11-01-stream-scroll-dock-spring.md)
- Streaming scroll and Dock spring research:
  [2026-11-01-stream-scroll-dock-spring.md](docs/research/2026-11-01-stream-scroll-dock-spring.md)
- Streaming scroll and Dock spring implementation spec:
  [2026-11-01-stream-scroll-dock-spring.md](docs/specs/2026-11-01-stream-scroll-dock-spring.md)
- Streaming scroll and Dock spring device E2E:
  [2026-11-01-stream-scroll-dock-spring-e2e.md](docs/testing/2026-11-01-stream-scroll-dock-spring-e2e.md)
- Stream stability requirement:
  [2026-11-01-stream-stability.md](docs/requirements/2026-11-01-stream-stability.md)
- Mobile stream stability research:
  [2026-11-01-stream-stability.md](docs/research/2026-11-01-stream-stability.md)
- Stream stability implementation spec:
  [2026-11-01-stream-stability.md](docs/specs/2026-11-01-stream-stability.md)
- Stream stability device E2E:
  [2026-11-01-stream-stability-e2e.md](docs/testing/2026-11-01-stream-stability-e2e.md)
- Long-stream render liveness requirement:
  [2026-11-02-long-stream-render-liveness.md](docs/requirements/2026-11-02-long-stream-render-liveness.md)
- Long-stream render liveness research:
  [2026-11-02-long-stream-render-liveness.md](docs/research/2026-11-02-long-stream-render-liveness.md)
- Long-stream render liveness implementation spec:
  [2026-11-02-long-stream-render-liveness.md](docs/specs/2026-11-02-long-stream-render-liveness.md)
- Long-stream render liveness device E2E:
  [2026-11-02-long-stream-render-liveness-e2e.md](docs/testing/2026-11-02-long-stream-render-liveness-e2e.md)
- Structured tool-content requirement:
  [2026-11-01-structured-tool-content.md](docs/requirements/2026-11-01-structured-tool-content.md)
- Structured tool-content research:
  [2026-11-01-structured-tool-content.md](docs/research/2026-11-01-structured-tool-content.md)
- Structured tool-content implementation spec:
  [2026-11-01-structured-tool-content.md](docs/specs/2026-11-01-structured-tool-content.md)
- Structured tool-content E2E:
  [2026-11-01-structured-tool-content-e2e.md](docs/testing/2026-11-01-structured-tool-content-e2e.md)
- Structured protocol completeness requirement:
  [2026-11-01-structured-protocol-completeness.md](docs/requirements/2026-11-01-structured-protocol-completeness.md)
- Structured protocol completeness research:
  [2026-11-01-structured-protocol-completeness.md](docs/research/2026-11-01-structured-protocol-completeness.md)
- Structured protocol completeness implementation spec:
  [2026-11-01-structured-protocol-completeness.md](docs/specs/2026-11-01-structured-protocol-completeness.md)
- Structured protocol completeness E2E:
  [2026-11-01-structured-protocol-completeness-e2e.md](docs/testing/2026-11-01-structured-protocol-completeness-e2e.md)
- Native sidebar destinations requirement:
  [2026-11-01-native-sidebar-destinations.md](docs/requirements/2026-11-01-native-sidebar-destinations.md)
- Native sidebar destinations research:
  [2026-11-01-native-sidebar-destinations.md](docs/research/2026-11-01-native-sidebar-destinations.md)
- Native sidebar destinations implementation spec:
  [2026-11-01-native-sidebar-destinations.md](docs/specs/2026-11-01-native-sidebar-destinations.md)
- Native sidebar destinations device E2E:
  [2026-11-01-native-sidebar-destinations-e2e.md](docs/testing/2026-11-01-native-sidebar-destinations-e2e.md)

## Upstream Tracking

- Upstream interaction reference is pinned in `docs/NATIVE-INTERACTION-SPEC.md`.
- Recheck the pinned revision before making an equivalence claim.
- Keep mobile-only extensions labeled as mobile extensions; do not present them
  as upstream behavior.

