# Agent Quality Gates and Automation Hardening

Status: implemented baseline. Portable checks and all three product builds
passed locally on 2026-11-01 from a dirty working tree. Hosted CI execution,
protected-check activation and device-lab E2E remain external completion gates.

## Problem

Before this implementation, the repository had extensive requirements, specs,
Mock fixtures, device E2E tables and source checks, but the green path was not
a reliable release gate:

- multiple documents named different upstream protocol revisions;
- CI did not compile the HarmonyOS product;
- Mock "coverage" checked source strings and E2E ID presence rather than executed
  assertions;
- device evidence was not bound to the current commit, HAP and device profile;
- publication scanning missed Windows personal paths and signing-secret fields;
- confirmed protocol and client-routing defects could survive a fully green Node
  suite.

These gaps made agent-generated changes appear complete when only a subset of
the delivery contract has been checked.

## Required Outcomes

| ID | Requirement |
| --- | --- |
| QG-01 | The repository SHALL have one machine-readable upstream protocol lock. |
| QG-02 | Documentation, package compatibility and fixture metadata SHALL NOT silently disagree with the lock. |
| QG-03 | Malformed snapshots and committed stream endings SHALL be rejected before they mutate reducer state. |
| QG-04 | Every client native endpoint SHALL be checked against the gateway route contract. |
| QG-05 | Workspace cache eviction SHALL be session-scoped for identical paths. |
| QG-06 | Publication checks SHALL detect Windows, Unix and URL-encoded personal paths, signing-secret fields and private-key material. |
| QG-07 | Mock mapping checks SHALL stop treating comments or unrelated text as interaction evidence. |
| QG-08 | Mock execution-status checks SHALL be available as a separate release gate and SHALL reject stale or incomplete evidence. |
| QG-09 | Device evidence SHALL include commit, dirty state, build variant, HAP SHA-256, device/API profile, step results and artifact hashes. |
| QG-10 | A single repository command SHALL run the fast and PR quality profiles and write a machine-readable report. |
| QG-11 | CI SHALL run the portable quality profiles and fail on regressions. |
| QG-12 | Pull requests SHALL expose mandatory quality, evidence and release checks through repository governance files. |

## Required Validation

- Existing gateway tests remain green.
- New malformed-frame, snapshot, route-parity and cache-scoping tests fail on
  the pre-fix behavior and pass after implementation.
- Publication scanner positive and negative fixtures cover both path styles and
  secret field names.
- Mock coverage tests prove that a comment-only mention does not satisfy an
  interaction requirement.
- `node scripts/qa.mjs fast` and `node scripts/qa.mjs pr` both emit a report.
- All portable checks pass on the implementation commit.

## Non-goals

- Claiming real-device completion without device evidence.
- Automating visual taste or accessibility judgment.
- Replacing the existing Mock fixtures with a second parallel registry.

