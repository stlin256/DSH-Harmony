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

API 26 physical-device evidence for the rapid-iteration launch notice uses Mock
HAP SHA-256
`3FE9EE11C150C2C7380B5C360C4994782A87AFB2F94162D2445950C641C0DB48`.
The earlier complete 115/115 visual suite remains qualified on Mock HAP SHA-256
`F23693248955498EC90306DC2D1942D2DC30F440FE449D73DDB9592FE59412CD`.
The store-showcase refresh and approval-card density evidence was captured on
Mock HAP SHA-256
`020CCE74C12198488D896241AC7AA40BE42A0D059FD60B5C8AA7FB946F582FD7`.
Do not present these isolated Mock evidence sets as one current release-HAP
claim.

- Rapid-iteration notice, logo continuity, dark/light themes, reduced motion,
  System Back and Mock logout return:
  `artifacts/device-e2e-final/launch-notice-release/iteration-notice/manifest.json`.
- Final default Release installation and launch smoke on the rapid-iteration
  notice HAP (`6824EFDE78B4468D4D26D216721D54F53C3687AE2E4FEDB80DF80B768980B378`):
  `artifacts/device-e2e-final/release-smoke-iteration-notice/manifest.json`.
- Full static Mock suite: 115/115 captured scenes passed. Review contact sheets
  live under `artifacts/device-e2e-final/mock-suite-clean/contact-sheets-audit/`.
- Subagent/title-row/navigation and child send:
  `artifacts/device-e2e-final/mode-subagent-clean/plan-lineage/manifest.json`.
- Settings density, notification geometry, storage content and preference
  persistence:
  `artifacts/device-e2e-final/settings-clean/appearance-persistence/manifest.json`.
- Secret masking/reveal, stream repair and search absence:
  `artifacts/device-e2e-final/frontend-hardening-clean/secret-stream-settings/manifest.json`.
- Approval/question controls:
  `artifacts/device-e2e-final/interaction-clean/approval-question/manifest.json`.
- Turn-change card expansion, file preview and Back:
  `artifacts/device-e2e-final/turn-change-clean/completed-card/manifest.json`.
- 31-state disclosure expansion matrix:
  `artifacts/device-e2e-final/disclosure-dark-clean/disclosure-expansion-matrix/manifest.json`.
- Long-stream liveness, stable process, final marker and responsive composer:
  `artifacts/device-e2e-final/stream-long-final/stream-long-liveness/manifest.json`.
- Floating plan Dock overlay, transcript spacer and outside-surface scrolling:
  `artifacts/device-e2e-final/task-dock-clean/floating-overlay/manifest.json`.
- Conversation scrollbar physical edge:
  `artifacts/device-e2e-final/conversation-chrome-clean/scrollbar-edge/manifest.json`.
- Store showcase density and approval-card compactness:
  `artifacts/store-screenshots/manifest.json` and
  `artifacts/device-e2e/20261104-permissions-approval-density/permissions/manifest.json`.
- Previous default Release installation/launch smoke:
  `artifacts/device-e2e-final/release-smoke/manifest.json`.
- Stream reconstruction quiet/burst, reconnect, child unavailable/retry/Back,
  dark/light and reduced motion on Mock HAP SHA-256
  `48B135A79F64D0E761D071CEADCEEBB836659FD2C8D5C11CEF70A12C0E5B1E2C`:
  `artifacts/device-e2e/20261104-stream-reconstruction/recovery/manifest.json`.
  The pre-existing long-stream and child send/stop drivers were not rerun on
  this HAP; do not treat this set as a release or live-Host qualification.
- Composer menu template (model sheet above the input with the keyboard
  closed/open, mask, no search field, permission sheet regression) on Mock
  HAP SHA-256
  `754C854D17A3286E45B6DD8D7F2242A5858E97846DFE5467724C22365D5A0C78`:
  `artifacts/device-e2e/20261104-model-menu/model-picker/manifest.json`.
- Connection banner motion (dark, light, reduced motion, tap persistence)
  on Mock HAP SHA-256
  `39E21758985730358D8C39CDB4A663BC7BAFCAF3A1FE2E83567BBFE703770AB9`:
  `artifacts/device-e2e/20261104-connection-banner/connection-banner/manifest.json`.
- Immersive material docks (dark, light, task dock, opaque default) on Mock
  HAP SHA-256
  `F145A78BA528CF7CA30ED8297AE4D1454A78269FACEE66BB4AB6A1E324FD49D0`:
  `artifacts/device-e2e/material/material/manifest.json`.
- Plugin switch refresh and one-line feedback banner on Mock HAP
  `F97B026F23CFCF0A9216D134A43F6D259CA9099A14C1D1822977913B18E506A3`:
  `artifacts/device-e2e/plugin-toggle/plugin-toggle/manifest.json`.
- Running tail revision (authoritative Host clock, in-flow last row like the DSH
  chat, scrolls down with the content, continuous sweep, timer-driven whale from DSH APNG frames,
  appearance/disappearance) on Mock HAP
  `39CFD9C8DAE64F4D3949B10C20B1C4BF8C92E9EDE4D80C616E26434CDC39CA46`:
  `artifacts/device-e2e/running-tail/running-tail/manifest.json`.
  Live-Host observation of a Host-started turn remains Pending; the earlier
  animated-WebP ticker evidence is superseded.
- Conversation stability: 6-minute continuous-render Mock liveness sample
  18/18 (and the earlier 3-minute 12/12); device fault logs are not readable over `hdc`, so the reported midday
  crash stack remains uncollected: `artifacts/conversation-stress/manifest.json`.
- Permission switch Host fix and full-access checkbox on real Host (plugin
  `0.3.9`, default Release HAP `18525C75…`) and Mock HAP `2E6DDD55…`:
  `artifacts/device-e2e/real-permission-switch/real/manifest.json` and
  `artifacts/device-e2e/permission-checkbox/permissions/manifest.json`.

Keep these environment-bound gaps explicit until a matching target proves them:

- API 23 opaque-material fallback.
- Final-clean-HAP maximum system font size and landscape layouts.
- Saved-session restore, expired-session recovery and logout/relaunch with a
  real account exchange.
- Provider reconnect and session-switch restoration with a live Host stream.
- Real Host long-stream cadence and Gateway backpressure recovery.
- Live Host stream reconstruction: real provider pacing, child authorization,
  stale-catalog child history and network handoff.
- Live process strip pacing (reasoning/tool text) device evidence; the
  synthetic live-group capture path still needs the nested-list fix.
- Current-device image-lightbox interaction evidence.
- Workspace preview formats not present in the current fixtures, including
  JPEG/WebP/GIF/BMP/HEIC/ICO and the full extensionless-file matrix.
- Reduced-motion task Dock rerun if a final-clean-HAP artifact is required
  separately from the tested Mock HAP.
- Large-text onboarding, guide, detailed install page, login and inline error.

Never promote a Pending or Partial row from Mock coverage, source inspection,
static tests or a screenshot produced by an older HAP.

## Design, Spec and Evidence Index

- Full-project security audit and remediation requirement:
  [2026-11-07-security-audit-remediation.md](docs/requirements/2026-11-07-security-audit-remediation.md)
- Full-project security audit and remediation implementation spec:
  [2026-11-07-security-audit-remediation.md](docs/specs/2026-11-07-security-audit-remediation.md)
- Complete classified findings report (all modules, fixes and accepted risks):
  [2026-11-07-security-audit-remediation.md](docs/research/2026-11-07-security-audit-remediation.md)
- Verification record and device-evidence gaps:
  [2026-11-07-security-audit-remediation-e2e.md](docs/testing/2026-11-07-security-audit-remediation-e2e.md)
- Store release packaging (AppGallery `.app` bundle, permission/signature checks):
  [RELEASE-PACKAGING.md](docs/RELEASE-PACKAGING.md)
- Visual baseline: [DESIGN.md](docs/DESIGN.md)
- Physical-device visual acceptance requirement:
  [2026-11-01-device-visual-state-acceptance.md](docs/requirements/2026-11-01-device-visual-state-acceptance.md)
- Physical-device visual acceptance implementation spec:
  [2026-11-01-device-visual-state-acceptance.md](docs/specs/2026-11-01-device-visual-state-acceptance.md)
- Physical-device visual acceptance and pending verification ledger:
  [2026-11-01-device-visual-state-acceptance-e2e.md](docs/testing/2026-11-01-device-visual-state-acceptance-e2e.md)
- Rapid-iteration notice requirement:
  [2026-11-03-iteration-notice-launch.md](docs/requirements/2026-11-03-iteration-notice-launch.md)
- Rapid-iteration notice implementation spec:
  [2026-11-03-iteration-notice-launch.md](docs/specs/2026-11-03-iteration-notice-launch.md)
- Rapid-iteration notice device E2E:
  [2026-11-03-iteration-notice-launch-e2e.md](docs/testing/2026-11-03-iteration-notice-launch-e2e.md)
- Login error motion requirement:
  [2026-11-03-login-error-motion.md](docs/requirements/2026-11-03-login-error-motion.md)
- Login error motion implementation spec:
  [2026-11-03-login-error-motion.md](docs/specs/2026-11-03-login-error-motion.md)
- Login error motion device E2E:
  [2026-11-03-login-error-motion-e2e.md](docs/testing/2026-11-03-login-error-motion-e2e.md)
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
- Store showcase refresh requirement:
  [2026-11-04-store-showcase-refresh.md](docs/requirements/2026-11-04-store-showcase-refresh.md)
- Store showcase refresh research:
  [2026-11-04-store-showcase-refresh.md](docs/research/2026-11-04-store-showcase-refresh.md)
- Store showcase refresh implementation spec:
  [2026-11-04-store-showcase-refresh.md](docs/specs/2026-11-04-store-showcase-refresh.md)
- Store showcase refresh E2E:
  [2026-11-04-store-showcase-refresh-e2e.md](docs/testing/2026-11-04-store-showcase-refresh-e2e.md)
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
- Workspace preview coverage requirement:
  [2026-11-02-workspace-preview-coverage.md](docs/requirements/2026-11-02-workspace-preview-coverage.md)
- Workspace preview coverage research:
  [2026-11-02-workspace-preview-coverage.md](docs/research/2026-11-02-workspace-preview-coverage.md)
- Workspace preview coverage implementation spec:
  [2026-11-02-workspace-preview-coverage.md](docs/specs/2026-11-02-workspace-preview-coverage.md)
- Workspace preview coverage device E2E:
  [2026-11-02-workspace-preview-coverage-e2e.md](docs/testing/2026-11-02-workspace-preview-coverage-e2e.md)
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
- IME transcript anchoring and adaptive table layout requirement:
  [2026-11-03-ime-transcript-table-layout.md](docs/requirements/2026-11-03-ime-transcript-table-layout.md)
- IME transcript anchoring and adaptive table layout implementation spec:
  [2026-11-03-ime-transcript-table-layout.md](docs/specs/2026-11-03-ime-transcript-table-layout.md)
- IME transcript anchoring and adaptive table layout device E2E:
  [2026-11-03-ime-transcript-table-layout-e2e.md](docs/testing/2026-11-03-ime-transcript-table-layout-e2e.md)
- Sidebar workspace inventory requirement:
  [2026-11-03-sidebar-all-workspaces.md](docs/requirements/2026-11-03-sidebar-all-workspaces.md)
- Sidebar workspace inventory implementation spec:
  [2026-11-03-sidebar-all-workspaces.md](docs/specs/2026-11-03-sidebar-all-workspaces.md)
- Sidebar workspace inventory device E2E:
  [2026-11-03-sidebar-all-workspaces-e2e.md](docs/testing/2026-11-03-sidebar-all-workspaces-e2e.md)
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
- Product display-name requirement:
  [2026-11-03-product-display-name.md](docs/requirements/2026-11-03-product-display-name.md)
- Product display-name research:
  [2026-11-03-product-display-name.md](docs/research/2026-11-03-product-display-name.md)
- Product display-name implementation spec:
  [2026-11-03-product-display-name.md](docs/specs/2026-11-03-product-display-name.md)
- Product display-name E2E:
  [2026-11-03-product-display-name-e2e.md](docs/testing/2026-11-03-product-display-name-e2e.md)
- Native sidebar destinations requirement:
  [2026-11-01-native-sidebar-destinations.md](docs/requirements/2026-11-01-native-sidebar-destinations.md)
- Native sidebar destinations research:
  [2026-11-01-native-sidebar-destinations.md](docs/research/2026-11-01-native-sidebar-destinations.md)
- Native sidebar destinations implementation spec:
  [2026-11-01-native-sidebar-destinations.md](docs/specs/2026-11-01-native-sidebar-destinations.md)
- Native sidebar destinations device E2E:
  [2026-11-01-native-sidebar-destinations-e2e.md](docs/testing/2026-11-01-native-sidebar-destinations-e2e.md)
- Access-control requirement:
  [2026-11-03-access-control.md](docs/requirements/2026-11-03-access-control.md)
- Access-control UI research:
  [2026-11-03-access-control-ui.md](docs/research/2026-11-03-access-control-ui.md)
- Access-control implementation spec:
  [2026-11-03-access-control.md](docs/specs/2026-11-03-access-control.md)
- Access-control device E2E:
  [2026-11-03-access-control-e2e.md](docs/testing/2026-11-03-access-control-e2e.md)
- Store review experience requirement:
  [2026-11-04-store-review-demo.md](docs/requirements/2026-11-04-store-review-demo.md)
- Store review experience research:
  [2026-11-04-store-review-demo.md](docs/research/2026-11-04-store-review-demo.md)
- Store review experience implementation spec:
  [2026-11-04-store-review-demo.md](docs/specs/2026-11-04-store-review-demo.md)
- Store review experience device E2E:
  [2026-11-04-store-review-demo-e2e.md](docs/testing/2026-11-04-store-review-demo-e2e.md)
- Stream and subagent recovery requirement:
  [2026-11-04-stream-subagent-reconstruction.md](docs/requirements/2026-11-04-stream-subagent-reconstruction.md)
- Stream reconstruction research:
  [2026-11-04-stream-subagent-reconstruction.md](docs/research/2026-11-04-stream-subagent-reconstruction.md)
- Stream reconstruction implementation spec:
  [2026-11-04-stream-subagent-reconstruction.md](docs/specs/2026-11-04-stream-subagent-reconstruction.md)
- Stream reconstruction device E2E:
  [2026-11-04-stream-subagent-reconstruction-e2e.md](docs/testing/2026-11-04-stream-subagent-reconstruction-e2e.md)
- Model picker popup alignment requirement:
  [2026-11-04-model-picker-popup-alignment.md](docs/requirements/2026-11-04-model-picker-popup-alignment.md)
- Model picker popup reuse implementation spec:
  [2026-11-04-model-picker-popup-alignment.md](docs/specs/2026-11-04-model-picker-popup-alignment.md)
- Model picker popup device E2E:
  [2026-11-04-model-picker-popup-e2e.md](docs/testing/2026-11-04-model-picker-popup-e2e.md)
- Connection banner motion requirement:
  [2026-11-04-connection-banner-motion.md](docs/requirements/2026-11-04-connection-banner-motion.md)
- Connection banner motion implementation spec:
  [2026-11-04-connection-banner-motion.md](docs/specs/2026-11-04-connection-banner-motion.md)
- Connection banner motion device E2E:
  [2026-11-04-connection-banner-motion-e2e.md](docs/testing/2026-11-04-connection-banner-motion-e2e.md)
- Live process text pacing requirement:
  [2026-11-04-live-process-pacing.md](docs/requirements/2026-11-04-live-process-pacing.md)
- Live process text pacing implementation spec:
  [2026-11-04-live-process-pacing.md](docs/specs/2026-11-04-live-process-pacing.md)
- Live process text pacing device acceptance:
  [2026-11-04-live-process-pacing-e2e.md](docs/testing/2026-11-04-live-process-pacing-e2e.md)
- Immersive material docks requirement:
  [2026-11-05-immersive-material-docks.md](docs/requirements/2026-11-05-immersive-material-docks.md)
- Immersive material API research:
  [2026-11-05-immersive-material-docks.md](docs/research/2026-11-05-immersive-material-docks.md)
- Immersive material dock implementation spec:
  [2026-11-05-immersive-material-docks.md](docs/specs/2026-11-05-immersive-material-docks.md)
- Immersive material dock device acceptance:
  [2026-11-05-immersive-material-docks-e2e.md](docs/testing/2026-11-05-immersive-material-docks-e2e.md)
- Permission switch Host contract fix requirement:
  [2026-11-05-permission-switch-host-fix.md](docs/requirements/2026-11-05-permission-switch-host-fix.md)
- Permission switch Host contract research:
  [2026-11-05-permission-switch-host-fix.md](docs/research/2026-11-05-permission-switch-host-fix.md)
- Permission switch Host contract spec:
  [2026-11-05-permission-switch-host-fix.md](docs/specs/2026-11-05-permission-switch-host-fix.md)
- Permission switch and checkbox device acceptance:
  [2026-11-05-permission-switch-host-fix-e2e.md](docs/testing/2026-11-05-permission-switch-host-fix-e2e.md)
- Running tail requirement:
  [2026-11-05-running-tail.md](docs/requirements/2026-11-05-running-tail.md)
- Running tail research:
  [2026-11-05-running-tail.md](docs/research/2026-11-05-running-tail.md)
- Running tail implementation spec:
  [2026-11-05-running-tail.md](docs/specs/2026-11-05-running-tail.md)
- Running tail device acceptance:
  [2026-11-05-running-tail-e2e.md](docs/testing/2026-11-05-running-tail-e2e.md)
- Plugin switch feedback requirement:
  [2026-11-05-plugin-switch-feedback.md](docs/requirements/2026-11-05-plugin-switch-feedback.md)
- Plugin switch feedback research:
  [2026-11-05-plugin-switch-feedback.md](docs/research/2026-11-05-plugin-switch-feedback.md)
- Plugin switch feedback implementation spec:
  [2026-11-05-plugin-switch-feedback.md](docs/specs/2026-11-05-plugin-switch-feedback.md)
- Plugin switch feedback device acceptance:
  [2026-11-05-plugin-switch-feedback-e2e.md](docs/testing/2026-11-05-plugin-switch-feedback-e2e.md)
- Conversation stability requirement:
  [2026-11-05-conversation-stability.md](docs/requirements/2026-11-05-conversation-stability.md)
- Conversation stability research:
  [2026-11-05-conversation-stability.md](docs/research/2026-11-05-conversation-stability.md)
- Conversation stability implementation spec:
  [2026-11-05-conversation-stability.md](docs/specs/2026-11-05-conversation-stability.md)
- Conversation stability acceptance:
  [2026-11-05-conversation-stability-e2e.md](docs/testing/2026-11-05-conversation-stability-e2e.md)

## Upstream Tracking

- Upstream interaction reference is pinned in `docs/NATIVE-INTERACTION-SPEC.md`.
- Recheck the pinned revision before making an equivalence claim.
- Keep mobile-only extensions labeled as mobile extensions; do not present them
  as upstream behavior.

