# Plugin Installation, Onboarding and Branded Launch E2E

Date: 2026-11-02

Device: `HBN-AL80`, HarmonyOS `7.0.0.111` SP10C10, API `26`.

Current default HAP SHA-256:
`7F9173B44580975674EA9C1953C89AFB7635D13E1DA7031C9658259C4BBA1986`.

Status: launch, guide, detailed install page, reduced-motion navigation and
inline error recovery passed on the current default build. Real credential,
saved-session restoration, Passkey, logout, light theme, landscape and API 23
cases remain pending or explicitly partial.

| ID | Scenario | Expected Result | Status |
| --- | --- | --- | --- |
| ONB-E2E-01 | Install signed community HAP with no saved session and launch | Branded intro appears with logo, name and both actions inside the display | Passed; `artifacts/device-e2e/20261102-launch-2/intro.jpeg` and JSON |
| ONB-E2E-02 | Tap the guide action | Watermark and three steps settle without clipping; reduced motion resolves immediately | Passed; current-build `guide-settled.jpeg` and `install-settled.jpeg` plus the reduced-motion early/settled sequence are in `20261102-reduced-motion-onboarding-1`; `20261102-launch-2` contains the normal-mode guide layout JSON |
| ONB-E2E-03 | Use guide copy and paste into a text field | Canonical prompt is copied without private data | Partial; copied-state UI and source contract pass, independent clipboard content is not readable through HDC |
| ONB-E2E-04 | Use guide repository action | Repository opens in the system browser | Passed; system browser focus and rendered repository evidence |
| ONB-E2E-05 | Enter native credentials and connect | Login succeeds and launch transitions to workspace | Partial; login surface and input geometry pass, real credential exchange was not run |
| ONB-E2E-06 | Relaunch with valid saved native session | Branded launch remains visible during restore and enters workspace | Pending; requires a real saved account |
| ONB-E2E-07 | Relaunch with expired native session and saved origin | Login opens with address prefilled and no editable form during restore | Pending; requires an expired real session |
| ONB-E2E-08 | Submit an invalid key, then retry with valid key | Error stays inside launch surface; copy and retry remain accessible | Partial; invalid-origin error and retry geometry pass; valid retry is Pending |
| ONB-E2E-09 | Select Passkey and complete system authentication | Passkey flow enters workspace | Pending; real authentication requires the user |
| ONB-E2E-10 | Log out, terminate and reopen | Welcome flow returns and service address remains prefilled on direct entry | Pending; requires a real signed-in session |
| ONB-E2E-11 | Repeat in light, dark, reduced motion, API 23, large text and landscape | No clipping, unreadable text, unsafe overlap or ignored animation preference | Partial; dark and reduced motion passed. Large-text launch and light/landscape/API 23 remain Pending |
| ONB-E2E-12 | Install stable tarball through DSH Plugins or `plugin_manager` | Bundle activates, version appears in Settings and survives restart | Pending; current-device install and restart are not proven by packaging checks |

## Device evidence

- Fixed launch/login geometry:
  `artifacts/device-e2e/20261102-launch-2`.
- Original overlap failure retained as negative evidence:
  `artifacts/device-e2e/20261102-launch-1/login.jpeg`.
- Reduced-motion intro, guide, detailed install page and Back:
  `artifacts/device-e2e/20261102-reduced-motion-onboarding-1`.
- Current-build guide and detailed install screenshots:
  `artifacts/device-e2e/20261102-reduced-motion-onboarding-1/guide-settled.jpeg`
  and `install-settled.jpeg`.
- Settings plugin version row:
  `artifacts/device-e2e/20261102-device-settings-final/appearance-persistence/dsh-page.jpeg`.

The login sheet now begins below the complete brand mark with at least `28vp`
clearance. On the API 26 device the observed brand-mark bottom was y `669` and
the login sheet began at y `762`, leaving about `31vp` physical clearance.

## Automated gates

- PR QA `20261101T192208Z-eefbe49f`: passed.
- Gateway test suite: passed.
- default, store and mock Release builds: passed.
- Mock mapping coverage: 10/10 screens, 34/34 states, 27/27 features.
