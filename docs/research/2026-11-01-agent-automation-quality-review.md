# Agent Automation and Quality Review

Status: review complete; Phase 0 and the portable portion of Phase 1 are
implemented. This document preserves the review evidence, records the current
implemented baseline and separates remaining external or device-lab risks.

Review date: 2026-11-01

## 1. Scope and method

The review covered:

- DSH protocol normalization, stream recovery, persistence and client/server
  routing contracts.
- Mock fixtures, device E2E drivers, artifact handling and failure diagnostics.
- Programmatic evaluation for correctness, layout, accessibility, visual
  regression, performance, variants and release evidence.
- CI/CD, change governance, upstream pinning and agent completion criteria.

The review phase used independent read-only subagent passes plus a local
cross-check. Production changes were made only after the review, under the
separate implementation pass described below.

## 2. Measured baselines

### 2.1 Review-time baseline

The following commands passed before hardening:

- `gateway/npm test`: 197/197 tests passed.
- `node scripts/verify-mock-coverage.mjs`: 10/10 screens, 34/34 states,
  27/27 registered features, 68 static capture pairs and 5 interaction drivers.
- `node scripts/verify-harmony-product-variants.mjs`: product capability
  contract passed.
- `node scripts/check-publication.mjs`: reachable history and staged-content
  scan passed.
- `git diff --check`: passed.

These are useful checks, but they do not currently prove:

- that ArkTS and ArkUI compile;
- that `default`, `store` and `mock` HAPs all build;
- that registered Mock interactions were executed against the current HAP;
- that performance, accessibility or visual baselines still hold;
- that evidence belongs to the current commit and build.

At review time, `HEAD` and `origin/main` were both `8f79a6d`. The working tree
was dirty.

### 2.2 Implemented baseline

On 2026-11-01, after the hardening work:

- `node scripts/qa.mjs fast` passed in
  `.artifacts/qa/20261101T144319Z-981f9b2c/report.json`.
- `node scripts/qa.mjs pr` passed in
  `.artifacts/qa/20261101T144328Z-85eef99d/report.json`.
- The gateway suite passed 231/231 tests.
- Mock mapping remained 10/10 screens, 34/34 states, 27/27 registered
  features, 68 static capture pairs and 5 interaction drivers. This remains
  registration coverage, not device execution proof.
- `default`, `store` and `mock` release HAP builds completed successfully.
- Publication scanning passed for the dirty working tree and reachable history
  under a 20-entry, exact-match legacy-history baseline.
- `npm audit --audit-level=low` reported 0 vulnerabilities.
- Plugin packaging and the generated-package verifier passed.
- `git diff --check` passed.
- The current mock HAP installed for interaction tests on HUAWEI Pura 70 Pro+
  (`HBN-AL80`, API 26, arm64-v8a) as bundle `0.4.7` / `versionCode 28`; the
  current default HAP was reinstalled afterward for normal device use.
- The focused device smoke and Dock send/queue/material/error E2E passed. The
  Dock manifest records all 11 required checks true and stores screenshots and
  layout dumps for idle, pending, authoritative, quiet, elevated,
  reduced-transparency and failed-send states.

Signed local HAP evidence:

| Product | Size (bytes) | SHA-256 |
| --- | ---: | --- |
| default | 2,071,172 | `7cab7cdaec7de04ed2b40b6a4af21c3c40ecf1982eac038af8ee1850b5f07453` |
| store | 2,071,180 | `1dd412cc6f635d46a8287440b03eef5424dd348a87a56ae5ca619058d9b0e011` |
| mock | 2,071,097 | `53e6e4c37326470de8bd09da504b6e585f6df9b66fedcefdda1d7342bc51bb70` |

These hashes are local build evidence for the dirty working tree at Git HEAD
`8f79a6d6864b8cecae2ee0c9d2ee636a8433fa2b`; they are not release artifacts.

Implemented corrections:

- One machine-readable upstream protocol lock now drives documentation,
  fixture and package compatibility checks.
- Snapshot, active-stream and terminal-event validation now rejects malformed
  frames before reducer/cache mutation; the legal empty-journal cursor `-1`
  remains supported. Committed-before-end clears only after the durable event is
  present, while end-before-committed preserves the partial until settlement.
- Conflicting replayed durable sequences are rejected unless their raw event
  matches the stored journal entry.
- Native route parity, session-scoped cache eviction, one-way cache identity and
  ephemeral identity fallback are covered by tests.
- Mock mapping no longer treats comments as interaction evidence and binds each
  interaction driver to a declared feature state.
- Device layout queries handle hint-only composers, duplicate text/originalText
  labels and semantic send-button discovery without hard-coded screen
  coordinates. Interaction waits use bounded layout polling.
- Publication scanning covers personal paths, encoded/UTF-16 content,
  credentials, private networks, tracked/untracked working files and exact
  reviewed historical baselines; only legacy personal filesystem paths are
  baseline-eligible, and shallow history scans fail closed.
- Device evidence has a versioned schema and a release verifier that binds Git
  state, HAP/artifact hashes, timestamps and protocol identity; it requires a
  passed mandatory step and a structural ZIP/HAP container.
- A root fast/PR/release runner, PR template, CODEOWNERS and source-check
  workflow are present.

### 2.3 Residual risks

| Gap | Current state | Next action |
| --- | --- | --- |
| Hosted CI proof | Workflow source exists; no pull-request run was available locally | Run the workflow and require its jobs in branch protection |
| Native build in CI | All three products build locally with DevEco 26.0.0; CI is still portable-only | Add a trusted Windows/DevEco self-hosted build job |
| Device E2E | HUAWEI Pura 70 Pro+ / API 26 passed the current mock-HAP smoke and Dock interaction flow, including send, queue reconciliation, material fallback, reduced transparency, failed-send draft retention and process liveness. The complete device-lab/API matrix remains unrun | Keep the focused rows as scoped evidence; execute the complete device matrix and real-protocol scenarios before release |
| Mock execution coverage | Mapping gate is strict; one focused conversation/Dock flow now has current device evidence, but most registered scenes remain mapping-only | Require current evidence manifests for every affected device scene before release |
| Visual/accessibility/performance | Still largely manual or narrow probes | Add semantic layout, hit-target, masked visual and performance baselines |
| Publication history | The 20 reviewed legacy personal-path blobs remain in public history | Accept explicitly or perform a separately approved history rewrite |
| Publication loopback | Loopback and `localhost` setup defaults are intentionally not treated as private hosts | Set `DSH_PRIVATE_HOSTS` for a concrete deployment host that must be blocked |
| Actions supply chain | Workflow uses `actions/*@v4` tags | Pin reviewed action commits and update under review |
| Protection policy | PR template and CODEOWNERS are source-controlled | Configure required checks and owners in repository settings |
| ArkTS diagnostics | All three builds pass, but existing "function may throw" warnings remain | Triage warning clusters without changing behavior blindly |
| Transcript cache validation | Restore still validates the cache envelope and required arrays rather than every nested view object | Add schema-versioned deep validation with corrupt-cache device tests |
| Legacy cache namespace | SHA-256 identity changes do not migrate or eagerly delete old FNV-scoped cache rows | Add a versioned namespace migration and one-time cleanup |

## 3. Blocking findings

The findings in sections 3 through 5 are the review-time state. The confirmed
protocol, routing, cache, mapping, publication and evidence defects were fixed
in the implementation pass; device-lab and hosted-policy gaps remain in section
2.3.

### P0: One authoritative upstream baseline is missing

The repository currently references incompatible baselines:

- `docs/NATIVE-INTERACTION-SPEC.md` pins
  `f3803c96974ad4a94195fb97e5c637e9c2a3afe3` at `0.2.2-alpha.2`.
- `docs/specs/2026-10-31-stream-recovery-composer-attachments.md` references
  `ce7073d51254c26cd63b22a60835b8f948deb447`.
- `docs/requirements/2026-11-01-structured-protocol-completeness.md` still
  names DSH `0.2.1`.
- `plugins/dsh-harmony/package.json` declares
  `>=0.2.2-alpha.2 <0.3.0`.

This is a real multi-baseline problem, not just documentation drift. An agent
cannot reliably decide which wire contract is authoritative.

Required correction:

- Add a machine-readable `protocol.lock.json` containing repository, commit,
  package version, wire protocol version and fixture revision.
- Make documentation, package compatibility and fixture metadata reference the
  lock rather than repeating versions manually.
- Fail the fast gate when any protocol version claim disagrees with the lock.

### P1: A malformed committed stream end clears visible partial output

`normalizeFollow()` accepts a committed `end` frame without a valid
`outcome.seq`, producing `committedSeq = -1` in
`gateway/src/native-protocol.mjs`. `NativeSessionModel` then skips settlement and
clears `streamText`, `streamReasoning` and `streamTools` in
`harmony/entry/src/main/ets/services/NativeSessionModel.ets`.

A direct reducer probe returned:

```json
{"streamText":"","settlementPending":false}
```

This can lose an already visible answer. The normalizer must reject the
malformed terminal marker so recovery starts instead of committing the loss.

### P1: Snapshot validation is too permissive

The snapshot path in `gateway/src/native-protocol.mjs` does not require a valid
`cursor`, defaults a missing revision to `0`, and preserves invalid values such
as `nextIndex = -1`. `NativeSessionModel` writes these values directly into
state.

This can disable gap detection and pollute the durable cache. Required fields
and bounds must be validated before a frame reaches the reducer.

### P1: The client endpoint allowlist blocks the change-summary route

`NativeHarnessClient.request()` uses a fixed route allowlist that does not
include `native/changes/summary`, while `turnChangeSummary()` calls that route
through the same method. A direct call resolves to `Unsupported endpoint`.

Add a client/gateway route parity test that invokes every client method rather
than checking only the gateway route.

### P1: Workspace cache trimming can delete another session's row

The LRU candidate query in
`harmony/entry/src/main/ets/services/NativeWorkspaceCache.ets` omits
`session_id`, while deletion is keyed by scope and path. The same workspace path
loaded by two sessions can therefore be removed together, and deleted-byte
accounting can diverge from the 5 GiB pool decision.

Add a two-session, same-path trim test for metadata and binary cache owners.

## 4. Automation and evidence findings

### P0: CI is not yet a meaningful merge gate for the native product

`.github/workflows/check.yml` runs gateway tests, dependency audit, plugin
packaging and publication scanning. It does not:

- run `verify-harmony-product-variants.mjs`;
- build `default`, `store` and `mock`;
- run a Hvigor compile or ArkTS type check;
- run an emulator or device smoke test;
- require the checks through protected-branch policy.

The extensive `AGENTS.md` workflow is therefore advisory, not enforced by the
platform.

### P1: The 100% Mock number is mapping coverage, not execution coverage

`scripts/verify-mock-coverage.mjs`:

- treats a quoted state string in a driver source as interaction evidence;
- requires an E2E ID row but does not require `Passed`;
- does not consume the latest execution report or artifact hashes;
- cannot detect a new action that reuses an existing screen/state without a new
  manifest entry.

A negative probe with no interaction and a `Pending` E2E row still returned
`ok: true`.

The current 100% result must be interpreted as "registered mappings are
present", not "the feature was executed and passed".

### P1: Static device captures have weak semantic assertions

The suite registers 68 static combinations, but the layout assertion is only
requested for conversation screens. Other screens can pass after a successful
launch, layout dump and screenshot without proving that their primary content
or controls exist.

The layout assertion also does not fail when a requested text matcher is
missing. It does not yet validate:

- node count or uniqueness;
- overlap and clipping;
- 44vp hit targets;
- labelled actions;
- focus order;
- expected semantic node sets.

### P1: Device evidence can be stale or internally inconsistent

The current `artifacts/device-ui-mock/suite-summary.json` contains 11 scenarios
while the suite now registers 68. The summary is written before the Dock
material pixel assertion runs.

Device manifests:

- use fixed output directories and overwrite prior evidence;
- hard-code `Passed` on the success path;
- do not bind evidence to commit, dirty state, HAP SHA-256, DevEco/SDK version,
  device profile or driver hash;
- may be produced with `-SkipBuild` or `-SkipInstall`.

An existing Mock manifest records bundle `0.4.6`, while the current App version
is `0.4.7`.

### P1: The publication gate has blind spots

`scripts/check-publication.mjs` passes while tracked scripts contain Windows
user-profile absolute paths. Its personal-path rule primarily covers Unix
`/home` and `/Users` forms, and its private-host denylist is optional.

It also does not treat signing fields such as `keyPassword` and `storePassword`
as forbidden content. The current real signing profile is ignored and untracked,
which is correct, but the scanner should fail before a future accidental add.

Required correction:

- detect Windows, Unix and URL-encoded personal paths;
- detect signing-secret field names and private-key material;
- test positive and negative scanner cases;
- scan a clean working-tree policy separately from reachable history.

### P1: Performance, visual and accessibility are mostly manual

The documentation defines useful metrics such as cache-first paint,
authoritative-ready time, projection p50/p95, long frames and memory. The
runtime currently lacks a content-free metrics export and persisted baseline.
The repository also contains conflicting cache-first targets of 100ms and
200ms.

The current visual check is a contact sheet plus a narrow Dock material pixel
probe, not a general baseline/diff system. Accessibility data exists in layout
dumps, but there is no gate for labels, hit targets, contrast or focus order.

### P1: Device execution is not isolated or reproducible

Current interaction drivers:

- select the first ready device;
- rely heavily on exact visible Chinese text;
- use fixed sleeps without condition polling;
- retain app data between runs;
- allow app preferences from one scenario to affect later scenarios;
- mutate the tracked Store manifest during a build instead of using an isolated
  build workspace;
- use shared remote temporary-file names.

These choices make device runs susceptible to flakiness and concurrent-agent
races.

## 5. Process and maintainability findings

- The repository has no root task runner, PR template, `CODEOWNERS`, Dependabot
  configuration or device-lab workflow.
- `AGENTS.md` lists 143 existing documentation links. Link integrity is good,
  but requirement, spec, Mock, interaction and E2E status are maintained
  separately by hand.
- The current Markdown E2E snapshot contains 442 `Pending`, 7 `Partial` and 47
  `Passed` markers. There is no machine-readable aggregate by build or device.
- 130 of 197 Node tests live in files that read Harmony source. Many execute
  transpiled service logic, which is valuable, but some only assert source
  patterns and do not provide ArkTS compile or runtime coverage.
- `NativeWorkspace.ets` is 3660 lines and `native-models.test.mjs` is 2755 lines.
  New changes should avoid growing these monoliths; split only along touched
  ownership boundaries.
- The working tree has more than 150 untracked evidence files plus a `$null`
  artifact. Local evidence and committed release evidence need separate,
  explicit directories.
- `scripts/package-plugin.mjs` uses `npm install` in the generated package
  instead of reproducing dependencies from a lockfile with `npm ci`.

## 6. Target quality model

### 6.1 Status model

Use explicit states:

- `passed`: every required assertion executed and passed;
- `failed`: product behavior failed;
- `blocked`: infrastructure or required external service unavailable;
- `not_run`: no execution evidence;
- `pending`: accepted work not yet executed.

Only `passed` may close an implementation item. `blocked`, `not_run` and
`pending` may never be rendered as green.

### 6.2 Change manifest

Create one manifest per feature or change with stable IDs shared by:

- requirement;
- upstream reference;
- research and spec;
- model/protocol tests;
- Mock scenario;
- interaction steps and assertions;
- E2E table rows;
- affected variants and device matrix;
- evidence records.

Suggested minimum shape:

```json
{
  "schemaVersion": 1,
  "changeId": "FEAT-...",
  "upstream": {
    "lock": "protocol.lock.json"
  },
  "documents": {
    "requirement": "docs/requirements/....md",
    "spec": "docs/specs/....md"
  },
  "tests": {
    "unit": [],
    "mock": [],
    "device": []
  },
  "variants": ["default", "store", "mock"],
  "status": "pending"
}
```

The existing Mock feature manifest can evolve into this structure rather than
being replaced by another unrelated registry.

### 6.3 Unified runner

Add one root-owned runner, for example:

```text
node scripts/qa.mjs fast
node scripts/qa.mjs pr
node scripts/qa.mjs device --changed
node scripts/qa.mjs release
```

The runner should emit:

- `run.json`;
- JUnit XML for CI;
- step-level logs;
- failure screenshots and layout dumps;
- artifact SHA-256 values;
- a non-zero exit code for every mandatory failure.

Suggested run manifest fields:

- `schemaVersion`, `runId`, timestamps;
- git SHA and dirty state;
- pinned upstream revision;
- Node, DevEco, hvigor and SDK versions;
- product, build mode, HAP/APP SHA-256;
- device serial, model, API, density, font scale, orientation and theme;
- feature, scenario, step, assertion and metric IDs;
- status, duration, retry category and failure code;
- artifact paths and hashes.

### 6.4 Gate levels

| Gate | Trigger | Mandatory checks | Target |
| --- | --- | --- | --- |
| Fast | Every commit / PR | Diff hygiene, version and protocol lock, document links, change closure, variant static contract, Mock mapping, path/secret scan | 2-5 min |
| PR | Gateway, plugin, scripts or Harmony changes | Full Node suite, audits, plugin package verification, route parity, negative contract tests | 5-15 min |
| Device | Harmony UI, transport, cache, Mock drivers or variants | Build and install default/store/mock as applicable; execute affected static and interaction scenes; validate layout, evidence and process liveness | self-hosted |
| Release | Tag or release candidate | Rerun all gates on exact SHA; clean tree; signed variants and hashes; complete device matrix; publication and provenance checks | protected environment |

Unit tests are currently fast enough to run in full. Do not add expensive
selection logic for Node tests yet. Use change selection only for slow device
scenarios, and default unknown mappings to the full suite.

## 7. Programmatic evaluation

Hard gates must be non-compensatory. A weighted score may show trends, but a
critical failure must remain `No-Go`.

Suggested dimensions:

| Dimension | Required metrics | Initial hard gate |
| --- | --- | --- |
| Protocol | contract failures, malformed frames accepted, route parity | 0 failures; 0 malformed frames accepted; all client routes supported |
| Native build | Hvigor/ArkTS compile, product variants | default/store/mock 3/3 as applicable |
| Mock execution | registered/executed, ambiguous selectors, semantic assertions | affected features 100% executed; 0 ambiguous or missing nodes |
| Layout/accessibility | off-screen, overlap, clipping, unlabeled actions, hit targets | 0 geometry failures; 0 unlabeled actions; 44vp minimum |
| Visual | masked pixel diff, SSIM, semantic node diff | same-device baseline; changed pixels <= 0.5%; SSIM >= 0.995 |
| Stream stability | repair count, duplicate/gap handling, recovery deadline | exactly one intended repair; no silent gap; no duplicate visible row |
| Performance | cache-first, cold readable, projection p95, long frames, memory | unify target first; cache-first p95 <= 100ms; projection p95 <= 16ms |
| Variants/API | install smoke, API 23/26 matrix, Store ACL | required variants and API matrix pass |
| Evidence/flake | artifact completeness, first-pass rate, flake rate | evidence hashes 100%; core first-pass 5/5; flake < 2% |

Visual baselines should begin with a small set of stable scenes. Prefer
same-device masked diffs. A baseline update requires explicit design review; it
must not happen automatically because a test produced a new image.

Infrastructure errors may receive one classified retry. Product assertion
failures must not be retried into green.

## 8. Device-lab design

Minimum device-lab contract:

- named devices with model, API, density, orientation and OS metadata;
- lease-based job scheduling;
- one unique local and remote temporary directory per run;
- app-data reset or a dedicated test profile per scenario;
- stable ArkUI test IDs before visible-text fallback;
- `waitUntil` with deadline instead of unconditional sleeps;
- unique artifact directory keyed by run and scenario;
- cleanup in `finally`;
- capture screenshot, layout JSON, selector candidates and HDC stderr on
  failure;
- classify infrastructure failure separately from product failure.

Use an emulator for broad API/theme/lang matrix coverage where possible. Keep
one physical phone for material, gesture, notification, Passkey, PDFKit and
release-signature evidence.

## 9. Agent operating contract

### Definition of Ready

A non-trivial change is ready only when it records:

- user-visible requirement and acceptance IDs;
- pinned upstream baseline;
- affected surfaces and variants;
- data/protocol contract changes;
- planned unit, Mock and device evidence;
- rollback or compatibility notes where relevant.

### Definition of Done

For a claimed feature:

1. Protocol/model tests pass, including malformed and boundary cases.
2. Default/store/mock build requirements are satisfied.
3. Every new action, selection, send, navigation and state transition has an
   interaction driver with post-condition assertions.
4. Every new screen or state has semantic layout assertions; a screenshot alone
   is insufficient.
5. The latest evidence matches the current commit, HAP hash and device profile.
6. Required device rows are `passed`; unavailable hardware is reported as
   `blocked` or `pending`, never as complete.
7. `git diff --check`, publication scanning and the applicable QA profile pass.

Agents must report:

- changed files;
- exact commands executed and their status;
- artifacts generated;
- unresolved `blocked`, `pending` or `not_run` items;
- whether device completion is actually proven.

## 10. Staged implementation

Implementation status: Phase 0 and the portable checks in Phase 1 are complete.
The self-hosted device work in Phase 2 and regression intelligence in Phase 3
remain open.

### Phase 0: Stop false-green results

- Resolve the upstream revision conflict and add `protocol.lock.json`.
- Fix the confirmed stream, snapshot, route and cache defects.
- Make missing layout matches fail.
- Parse E2E status and evidence in the Mock gate.
- Fix stale version and hash evidence.
- Add Windows path and signing-secret detection to publication scanning.
- Separate ignored local evidence from committed release evidence.

### Phase 1: Establish one enforceable fast/PR gate (portable portion complete)

- Add a root QA runner and machine-readable report.
- Add protocol golden fixtures and malformed-frame tests.
- Add client/gateway route parity tests.
- Add change-closure and evidence-schema validators.
- Add PR template, `CODEOWNERS` and protected-branch required checks.
- Wire existing static verifiers into CI.

### Phase 2: Turn the device scripts into a device lab (open)

- Add stable test IDs and a declarative step/assertion format.
- Replace fixed sleeps with condition polling.
- Add device leases, state reset, unique temp paths and cleanup.
- Add a self-hosted Windows/DevEco runner.
- Build three variants and execute affected static/interaction scenes.
- Bind every artifact to commit, HAP, device and runner configuration.

### Phase 3: Add regression intelligence (open)

- Seed same-device visual baselines for high-value scenes.
- Add accessibility and geometry assertions.
- Export content-free performance metrics and persist p50/p95 trends.
- Add flake and duration tracking.
- Add optional targeted mutation testing for protocol normalizers.
- Add scheduled upstream drift detection without making every PR network-bound.

## 11. Human review boundaries

Automation should detect regressions and provide evidence, but the following
still require explicit human sign-off:

- visual hierarchy and information density;
- copy quality and product judgment;
- motion direction, interruption feel and spring character;
- whether TalkBack announcements are understandable;
- OEM material behavior under real light, power and accessibility settings;
- real OAuth/Passkey, notification and system-picker flows;
- PDFKit and other platform-specific rendering limitations;
- AppGallery policy interpretation;
- whether a new baseline represents the intended design.

The purpose of the gate is not to automate taste. It is to ensure taste changes
are explicit, reviewed and reproducible.

