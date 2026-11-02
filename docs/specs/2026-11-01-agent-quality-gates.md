# Agent Quality Gates and Automation Hardening

Requirement:
[2026-11-01-agent-quality-gates.md](../requirements/2026-11-01-agent-quality-gates.md)

Status: implemented. Portable validation, all three release builds and focused
physical-device smoke/interaction checks passed locally from a dirty working
tree. Hosted CI evidence, protected-check activation and the complete device-lab
matrix remain external gates.

## 1. Architecture

The implementation uses a thin, dependency-free quality control plane around
the existing checks:

```text
protocol.lock.json
        |
        +--> verify-protocol-lock
        +--> gateway fixtures and docs

scripts/qa.mjs
        |
        +--> verify-protocol-lock
        +--> verify-mock-coverage
        +--> verify-harmony-product-variants
        +--> publication working-tree scan
        +--> gateway test suite
        +--> <artifact-root>/<run>/report.json

device manifest
        |
        +--> evidence schema
        +--> verify-evidence
        +--> release gate
```

The artifact root defaults to `.artifacts/qa` and can be overridden with
`DSH_QA_ARTIFACT_DIR` for CI. The control plane does not invoke a device or
DevEco build in the portable profile. Device-lab execution remains a separate
self-hosted gate.

## 2. Protocol Lock

`protocol.lock.json` contains:

- upstream repository;
- pinned commit;
- DSH package version;
- wire protocol version;
- fixture directory;
- review timestamp.

`scripts/verify-protocol-lock.mjs` checks:

- lock schema and SHA-like commit format;
- `docs/NATIVE-INTERACTION-SPEC.md` revision and version;
- `NOTICE` revision;
- references in stream-recovery and structured-protocol documents;
- plugin `engines.dsh` compatibility.

The check is offline and deterministic. Protocol, NOTICE and fixture claims now
resolve to the single lock.

## 3. Protocol Correctness

### 3.1 Snapshot validation

A normalized snapshot requires:

- a safe-integer `cursor >= -1`, where `-1` is the valid empty-journal cursor;
- a non-negative safe-integer `revision`;
- a non-negative safe-integer `nextIndex`;
- a boolean `hasMore`;
- valid, contiguous event and surface-operation sequence records;
- the final sequence of a non-empty page to equal `cursor`;
- valid replace ranges and active assistant stream records.

The client applies the same opening-snapshot validation before accepting any
durable event. A missing snapshot baseline rejects live durable events instead
of silently accepting a gap. Invalid snapshots do not enter the reducer or
cache. A malformed snapshot closes the current native generation rather than
leaving an unopened stream with a healthy heartbeat.

### 3.2 Assistant end validation

- Only `committed` and `abandoned` outcomes are accepted.
- `committed` requires a non-negative safe-integer outcome sequence and an
  `assistant/message` or `assistant/attempt` event type.
- Missing, unknown or malformed outcomes invalidate the frame before reducer
  mutation.
- The reducer refuses a cleared committed stream unless settlement was actually
  registered, so partial visible output is preserved on rejection.
- When the durable assistant event arrives before `end`, the reducer verifies
  that event before clearing partial output. When `end` arrives first, partial
  output survives until the matching durable event settles it.
- A stale durable sequence may be ignored only when its raw event matches the
  journal. Different content for the same sequence raises a conflict.

### 3.3 Route parity

The client route allowlist is covered by a shared source-contract test. Tests
enumerate every route used by `NativeHarnessClient` methods and prove that the
allowlist includes each one, including
`native/changes/summary`.

### 3.4 Workspace cache scope

Cache eviction candidates include the owning `session_id`. Metadata and binary
deletes use both scope, session and path. Tests cover two sessions with the same
relative path. Cache identity is derived with SHA-256; if cookie identity cannot
be established, each process start receives a unique ephemeral scope rather
than sharing the anonymous persistent cache.

## 4. Publication Scanning

`check-publication.mjs` now checks:

- `C:\Users\<name>\`, `C:/Users/<name>/` and URL-encoded variants;
- `/home/<name>/` and `/Users/<name>/`;
- `keyPassword:` and `storePassword:` assignments without accepting ambiguous
  placeholders;
- common credential files, tokens, private keys, non-loopback IPv4/IPv6 private
  networks and local-only domains;
- UTF-8, UTF-16 and mixed percent-encoded text;
- tracked and untracked working-tree files, staged blobs and reachable history;
- shallow repositories are rejected for full-history scans.

Tests invoke exported scanner functions with synthetic positive and negative
fixtures. No real path or secret enters test source.

Loopback and `localhost` development examples are intentionally allowed because
the repository uses them as public setup defaults; concrete non-loopback private
hosts remain covered. A deployment-specific host can also be supplied through
`DSH_PRIVATE_HOSTS`.

Historical findings use `scripts/publication-baseline.json`. Entries are exact
`object + reason + count` matches and apply only to reachable history. Working
tree and staged scans never consume the baseline; a new blob/reason or an
increased count still fails. Only the reviewed `personal filesystem path`
category is baseline-eligible; credentials, private keys, signing passwords and
private hosts cannot be suppressed.

## 5. Mock Mapping

`verify-mock-coverage.mjs` strengthens interaction mapping evidence:

- remove comment-only lines before source matching;
- match states only in scenario declarations or `-State` arguments;
- require an interaction command and an assertion command in an interaction
  driver;
- require each interaction driver to reference a declared feature state,
  including explicit settled-fixture state assignments;
- retain the existing static screenshot mapping check;
- rename output to make clear this is mapping coverage.

Execution evidence is checked separately in `verify-evidence.mjs`, so mapping
coverage cannot claim that a device interaction ran or passed.

## 6. Evidence Schema

The versioned JSON Schema covers:

- schema version and run identity;
- git and upstream identity;
- host/toolchain identity;
- build and device identity;
- feature/scenario/steps/assertions;
- status and failure classification;
- metrics;
- artifacts with SHA-256 values.

`verify-evidence.mjs` validates a manifest and, in release mode, requires:

- a clean working tree matching the current Git HEAD;
- `passed` overall status;
- at least one passed mandatory step;
- no `pending`, `blocked`, `not_run` or `failed` mandatory steps;
- a current, complete HAP SHA-256, `.hap` path and ZIP/HAP container header;
- hashed regular-file artifacts that stay inside the repository;
- evidence generated within the last 24 hours and not in the future;
- no symlinked or escaped evidence paths;
- no unknown fields or duplicate feature/artifact identities;
- current protocol lock revision and version.

Release mode reads the HAP and every artifact and recomputes its SHA-256. The
container check is structural smoke validation, not a substitute for HarmonyOS
signature verification. The QA release profile cannot run without
`--evidence <manifest>`.

## 7. Unified Runner

Root `package.json` scripts invoke `scripts/qa.mjs`.

Profiles:

- `fast`: portable static, publication, protocol, Mock mapping and variant
  contracts.
- `pr`: `fast` plus the full gateway Node suite.
- `release`: `pr` plus mandatory evidence validation through
  `--evidence <path>`.

Every profile writes:

- `<artifact-root>/<timestamp>-<run-id>/report.json`;
- per-step stdout and stderr files;
- duration and exit status;
- toolchain and git metadata.

The runner must not hide a failed step behind later steps. It records the
failure and exits non-zero.

## 8. CI and Governance

The source-check workflow:

- pins the Node major;
- runs the portable PR profile;
- keeps dependency audit and package verification;
- runs full-history publication scanning after packaging;
- uploads the QA report from `artifacts/qa/` and fails if no report exists.

Add:

- `.github/PULL_REQUEST_TEMPLATE.md`;
- `.github/CODEOWNERS`.

Protected-branch configuration and hosted workflow execution remain
repository-owner actions and cannot be proven by source files alone.

## 9. Test Strategy

The implementation splits tests by failure domain:

- `gateway/test/protocol-hardening.test.mjs` (4 tests): malformed snapshots,
  committed ends, client/gateway route parity and session-scoped cache eviction.
- `gateway/test/qa-runner.test.mjs` (7 tests): profile composition, CLI
  validation, artifact containment, report aggregation and failure handling.
- `gateway/test/quality-evidence.test.mjs` (10 tests): comment-only Mock mapping,
  schema shape, stale/dirty/incomplete evidence, file hashes and thresholds.
- `gateway/test/quality-publication.test.mjs` (11 tests): protocol lock identity,
  personal paths, encoded and UTF-16 content, credentials, private networks,
  staged paths and history-baseline behavior.
- `gateway/test/device-layout-query.test.mjs`: hint-only composer fallback,
  duplicate visible-text handling and semantic rightmost send-row selection.
- Existing native model and harness suites retain the broad ArkTS/source
  contract regression coverage.

The final local gateway run reports 231/231 passing tests.

No new user-visible UI is introduced, so no new screenshot-only feature scene is
required. Existing Mock and device E2E mappings remain valid.

## 10. Acceptance

Local implementation acceptance is met:

- `node scripts/qa.mjs fast` passed in report
  `20261101T144319Z-981f9b2c`.
- `node scripts/qa.mjs pr` passed in report
  `20261101T144328Z-85eef99d`.
- The new negative tests fail on the pre-fix behavior they cover.
- `default`, `store` and `mock` release HAP builds passed.
- Publication scans pass for the working tree and reachable history under the
  reviewed legacy-history baseline.
- The current mock HAP installed for interaction tests as bundle `0.4.7` /
  `versionCode 28` on HUAWEI Pura 70 Pro+ (`HBN-AL80`), API 26, arm64-v8a;
  the current default HAP was reinstalled afterward for normal device use.
- The focused conversation smoke passed. Dock device E2E passed idle send,
  running queue, authority reconciliation, quiet/elevated/reduced-transparency
  material states, failed-send draft retention and process liveness.
- Tests and documentation contain synthetic examples rather than real private
  paths, hosts, tokens or signing passwords.

External acceptance remains open:

- the hosted workflow has not yet run on a pull request;
- protected-branch required-check configuration is not source-controlled;
- the complete device-lab/API matrix and real protocol recovery scenarios remain
  incomplete;
- visual, accessibility and performance baselines remain future device-lab
  work rather than portable release evidence.

