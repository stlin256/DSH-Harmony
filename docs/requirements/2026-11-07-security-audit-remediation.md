# Requirement: Full-Project Security Audit and Remediation (2026-11-07)

## User request

Comprehensively re-scan the entire DSH Harmony project for code vulnerabilities across
every surface — backend (gateway, deploy gateway), web frontend (gateway/public), client
(HarmonyOS ArkTS app), plugins, scripts and configuration — fully document every finding,
and then fix them.

Environment constraints stated by the user:

- No HDC device access is available in this round. Device E2E cannot be re-captured;
  any UI- or state-affecting change must record its device-verification gap in the
  device acceptance ledger instead of claiming device proof.
- DevEco Studio toolchain is available on this machine, so HarmonyOS product variants
  (default, store, mock) can still be rebuilt to prove ArkTS changes compile.
- The agent may access and modify any project content.

## Scope

1. `gateway/src` — Node.js gateway backend (auth, sessions, proxy, push, native harness,
   native protocols, admin protocol, store).
2. `deploy/pocket-id-gateway` — Pocket ID OAuth gateway backend and its deployment files.
3. `gateway/public` — browser frontend served by the gateway.
4. `plugins/` — dsh-harmony, harmony-navigation, pocket-notify Cordis plugins (host,
   client and browser-client entry points).
5. `harmony/entry/src/main/ets` — the HarmonyOS native client (services, components,
   pages, entry/form abilities, widget).
6. `harmony` module configuration — module.json5, AppScope, resources, profiles.
7. `scripts/` — host-side QA, verification and device E2E drivers.
8. Cross-cutting — committed secrets, dependency vulnerabilities, environment templates,
   deployment unit files.

## Deliverables

- A complete, classified findings report with file:line references, exploit reasoning
  and severity for every issue found (docs/research/2026-11-07-security-audit-remediation.md).
- Fixes for every actionable finding, each with regression coverage where a test surface
  exists.
- A verification record (docs/testing/2026-11-07-security-audit-remediation-e2e.md)
  including the `node scripts/qa.mjs pr` run and product-variant builds, plus explicit
  device-evidence gaps caused by the missing HDC access.

## Non-goals

- No redesign of features; remediation must be minimal-diff and preserve upstream
  behavior and identity.
- No new user-visible UI behavior. If a security fix must change visible UI, it must be
  flagged and its device gap recorded.
- No secrets, credentials, private hosts or real transcript content in source, tests,
  docs or logs.
