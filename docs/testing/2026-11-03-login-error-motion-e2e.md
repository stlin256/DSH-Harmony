# Login Error Motion Device E2E

Date: 2026-11-03

Requirement:
[`2026-11-03-login-error-motion.md`](../requirements/2026-11-03-login-error-motion.md)

Implementation spec:
[`2026-11-03-login-error-motion.md`](../specs/2026-11-03-login-error-motion.md)

## Device Rows

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| LOGIN-ERR-01 | Open the login form and submit an empty service address | Inline error enters with the shared `micro` transition and settles without clipping | Pending |
| LOGIN-ERR-02 | Submit again after the error is visible | Existing error clears through `micro`; the next failure replaces it without a hard jump | Pending |
| LOGIN-ERR-03 | Repeat with reduced motion | Final error geometry and copy appear directly with no intermediate animation | Pending |

## Driver

```powershell
.\scripts\device-ui-launch-notice-e2e.ps1 -Device '<device-id>'
```

Evidence is written below `artifacts/device-ui-launch-notice-e2e/`. A row is
Passed only with the current Mock HAP hash, layout dumps and screenshots from
the same physical-device run.
