# Spec: Full-Project Security Audit and Remediation (2026-11-07)

Implementation spec for the requirement recorded in
docs/requirements/2026-11-07-security-audit-remediation.md.

## Process

1. **Scan** — Parallel module-by-module audit subagents sweep every surface listed in the
   requirement. Scans are read-only; each returns a structured findings list.
2. **Document** — The Lead consolidates every finding into
   docs/research/2026-11-07-security-audit-remediation.md with severity, category,
   file:line, description, exploit scenario and proposed fix. No finding is dropped,
   including informational ones.
3. **Fix** — Fixes are applied module by module with disjoint write scopes. Every fix
   keeps the minimal diff that removes the vulnerability without changing legitimate
   behavior.
4. **Verify** — Backend fixes get node:test coverage in `gateway/test`. ArkTS fixes must
   compile in all three product variants (default, store, mock) via the local DevEco
   toolchain. `node scripts/qa.mjs pr` must pass at the end. Device-dependent evidence
   is recorded as an explicit gap, never claimed.

## Finding classification

- Severity: Critical (exploitable pre-auth or owner-level compromise), High (exploitable
  post-auth or requires specific conditions), Medium (defense-in-depth gap, hardening),
  Low (weak practice with limited reach), Info (observation, no direct exploit).
- Categories: Authentication/Authorization, Session management, Injection (SQL/command/
  header), Path traversal, XSS/HTML injection, SSRF/open proxy, DoS/resource exhaustion,
  Cryptography, Information disclosure, Input validation, Transport security,
  Configuration/deployment, Supply chain (dependencies), Secret handling.

## Remediation rules

- Preserve the security architecture already present (Host pinning, Origin checks, CSP,
  HttpOnly cookies, timing-safe comparisons, prepared SQL). Fix regressions and gaps,
  do not redesign.
- Every fix that changes request/response handling, parsing, storage or transport must
  have a regression test that fails before the fix and passes after.
- ArkTS fixes must not alter visual layout or motion; where a UI-visible change is
  unavoidable, record it and its device gap in the ledger.
- Never introduce new dependencies for a fix unless unavoidable; prefer the standard
  library of the platform in use.
- Docs, tests and logs must not contain credentials, private hosts or real transcript
  content.

## Verification checklist

- [ ] All findings documented with file:line and severity.
- [ ] All actionable findings fixed.
- [ ] `node scripts/qa.mjs pr` passes.
- [ ] Product variants build (default, store, mock) when ArkTS code changed.
- [ ] Device-evidence gaps recorded in docs/testing/2026-11-07-security-audit-remediation-e2e.md.
