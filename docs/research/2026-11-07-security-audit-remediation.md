# Security Audit Findings — 2026-11-07 (Full-Project Re-scan)

Consolidated findings from the module-by-module audit required by
docs/requirements/2026-11-07-security-audit-remediation.md.
Method: parallel read-only audit subagents per module, Lead cross-checks, then
remediation with regression tests. Severity and category follow
docs/specs/2026-11-07-security-audit-remediation.md.

Status legend: [OPEN] not yet fixed · [FIXED] fixed with tests/evidence ·
[ACCEPTED] documented risk, no action (with reason).

## Lead findings (module: harmony config, scripts, supply chain)

### F-L1 [Medium][Secrets] Signing material tracked in git — CLOSED: false positive
- Location: harmony/build-profile.json5; .gitignore:9
- Verification: git ls-files does NOT list the file; git check-ignore confirms it is
  ignored; git log -- harmony/build-profile.json5 shows no commits. The DevEco signing
  material (encrypted password blobs, local certificate paths) is local-only by
  design: .gitignore:9 excludes it, scripts/build-harmony.ps1:35-37 restores it from
  harmony/build-profile.example.json5 when absent, and the template carries no
  secrets. No action required.
### F-L2 [Low][SupplyChain] http-proxy is unmaintained — ACCEPTED (documented)
- Location: gateway/package.json:22 (http-proxy 1.18.1)
- Description: http-proxy's last release is from 2020 and the project is unmaintained.
  No known CVE applies to the pinned version for this usage (loopback upstream,
  header sanitization in gateway/src/app.mjs prepareProxy).
- Impact: Future CVEs would not receive upstream patches.
- Fix: Replacing the proxy is a redesign (out of scope per the remediation rules);
  recorded as accepted risk with a re-review trigger.

### F-L3 [Info] Module permission surface is minimal — no action
- Location: harmony/entry/src/main/module.json5:36-51
- INTERNET, ACCESS_FIDO2_ONLINEAUTH (passkey login) and KEEP_BACKGROUND_RUNNING
  (background monitor, with reason) are each justified; the store variant drops
  FIDO2. Exported EntryAbility is the home entry; the form extension is the widget.
  No cleartext-traffic allowance was found in any profile.

### F-L4 [Info] No committed secrets outside the signing profile — no action
- Repo-wide grep for private keys, AWS-style key ids, long `sk-` secrets and
  hardcoded password/token/secret assignments found no real secrets (the only hit is
  a URL construction in plugins/dsh-harmony/index.mjs:93). Device E2E scripts take
  their secret fixture from DSH_STORE_REVIEW_ACCESS_KEY env and clean it up
  (scripts/device-ui-store-review-e2e.ps1:28-31,464-468).

## Subagent findings

### Module B — gateway native harness (gateway/src/native-harness.mjs)

#### F-B1 [Medium][DoS] Unbounded JSON body allocation on the native API — OPEN
- Location: gateway/src/app.mjs:120 (parser; consuming handlers in
  gateway/src/native-harness.mjs:486-501, 742-744, 833-835, 844-848, 357-361)
- Description: Every /pocket/api/native endpoint except /upload parses request bodies
  with express.json({ limit: Infinity }). The native-harness handlers validate types
  and patterns but never total magnitude: prompt accepts unbounded text, an
  unbounded-count attachments array and unbounded base64 images[].data; rename title,
  updateQueue text, answer custom strings, directoryList path and create cwd/agentPreset
  also lack length caps. express buffers the entire body in memory before any handler
  validation runs.
- Impact: An authenticated client — or any unauthenticated client when
  AUTH_MODE=none (ALLOW_NO_AUTH=true) — can POST an arbitrarily large JSON body and
  OOM/crash the single-process loopback gateway, killing the owner's only remote
  access path.
- Fix: finite body limit (e.g. '64mb') for /pocket/api/native plus per-field caps in
  native-harness.mjs (max text length, max base64 image data length, max
  attachments/images array count).

#### F-B2 [Low][DoS] Upload pass-through has no size cap and forwards unsanitized name/mediaType — OPEN
- Location: gateway/src/native-harness.mjs:459-485
- Description: /pocket/api/native/upload validates Content-Length only for numeric
  well-formedness, then streams the raw body to upstream /api/session/uploadFileBinary
  with the privileged cookie for up to 120s. No maximum size is enforced at the
  gateway; name (<=512 chars, any content) and mediaType (any string) are forwarded
  verbatim as query params. Contrast directoryCreate which blocks '/', '\\', '.' and
  '..' in names (line 746).
- Impact: An authenticated client can push an unbounded byte stream into the Harness
  host's upload pipeline for as long as the 120s timeout allows; upstream mishandling
  of '../' or control characters in name is reachable unfiltered.
- Fix: configurable maximum Content-Length rejected before streaming; restrict name
  to a safe filename charset mirroring line 746; optionally allowlist mediaType.

#### F-B3 [Low][AuthZ] Native session routes are not owner-scoped; only the answer route binds to the connection owner — OPEN
- Location: gateway/src/native-harness.mjs:526 (only owner check; unscoped routes at
  357-522, 555-853, 854-870; owner identity from gateway/src/app.mjs:50)
- Description: All native routes act on caller-supplied sessionId values using the
  single shared upstream credential. The only ownership check in the module is in the
  answer route; prompt, cancel, page/history, file/stat/list/bytes, upload, export and
  the operation switch never compare the acting owner. ownerOf is session(req) ||
  'anonymous', and in AUTH_MODE=proxy the loopback OIDC adapter can attest arbitrary
  owner strings (gateway/src/proxy-auth.mjs:14-18).
- Impact: In any deployment where the proxy attests more than one owner, each owner
  can read, steer, upload into, cancel and reorder every other owner's sessions — a
  full cross-owner IDOR. Currently unreachable in the single-owner passkey deployment
  and in AUTH_MODE=none every caller is 'anonymous' by explicit opt-in.
- Fix: enforce a single-owner invariant in proxy mode (reject a second distinct
  x-dsh-session owner for the gateway's lifetime) or scope native session access per
  owner.

#### F-B4 [Info][InfoDisclosure] rpcWithBytes relays arbitrary upstream error codes — OPEN
- Location: gateway/src/native-harness.mjs:248-252 (allowlist contrasted at 154-169;
  codes reach clients via 287)
- Description: rpcArgs preserves error.code only for an explicit list of stable
  decision codes, but rpcWithBytes (workspaceFiles/readBytes) copies any string
  envelope.result.error.code onto the thrown error, which the guarded error handler
  then returns to the client with a 409 status.
- Impact: An unexpected upstream error code string is passed verbatim to the client
  instead of being collapsed to a stable code; minimal practical impact (trusted local
  Harness, short code strings only) — a consistency gap in the module's own
  disclosure policy.
- Fix: apply the same stable-code allowlist before assigning error.code in
  rpcWithBytes.


### Module C — gateway native protocols (gateway/src/native-protocol.mjs, native-admin-protocol.mjs)

#### F-C1 [Medium][DoS] Unbounded JSON body buffering on all native protocol routes — OPEN (dup of F-B1)
- Location: gateway/src/app.mjs:120
- Same root cause and fix as F-B1: express.json({ limit: Infinity }) buffers any size body
  after auth; normalizers assume already-bounded input; /prompt forwards unbounded
  images[].data and rename/updateQueue forward uncapped strings.

#### F-C2 [Low][DoS] No size cap on the streamed upload route — OPEN (dup of F-B2)
- Location: gateway/src/native-harness.mjs:465
- Same as F-B2.

#### F-C3 [Low][InputValidation] settingsSet allowlist bypassed via inherited object properties — OPEN
- Location: gateway/src/native-harness.mjs:733
- Description: settingsSet validates with dictionary lookups on plain object literals
  (enums[ns]?.[field]?.includes(value)); inherited Object.prototype members
  (e.g. ns='constructor', field='name', value='Obj') pass the check and are forwarded
  to the Host settings/mutate — an ns/field pair not on the intended allowlist.
- Impact: The gateway's settings-mutation allowlist is not a real allowlist; contained
  today because the Host rejects unknown namespaces (settings/rejected is allowlisted).
- Fix: Object.hasOwn(enums, ns) && Object.hasOwn(enums[ns], field) before the includes
  check (or Set/Map allowlists).

#### F-C4 [Low][InputValidation] fullText() ignores its length argument; intended label/language caps not applied — OPEN
- Location: gateway/src/native-protocol.mjs:368 (labels, intended 100), :341 (code-fence
  language, intended 30)
- Description: fullText is single-parameter but is called with a second maxLength
  argument in two places, so the intended caps silently do not exist; Host/plugin
  strings of unbounded length reach normalized message rows.
- Impact: A plugin/tool can emit arbitrarily large tool-call labels or code-fence
  languages, inflating transcript contracts beyond the module's bounding discipline.
- Fix: make fullText(value, maxLength) truncate, or slice explicitly at call sites.

#### F-C5 [Low][InputValidation] Queue/message projections forward sourceKind/sourceForm without bounds — OPEN
- Location: gateway/src/native-protocol.mjs:286, 308-310, 354-355, 421
- Description: normalizeQueuedState bounds queue text to 64KB and ids to 160 chars but
  forwards item.sourceKind/sourceForm verbatim; queueFromInbox and normalizeRecord copy
  message.source.kind/.form uncapped into queue rows and every message row.
- Impact: Host-side content can attach multi-megabyte source.kind/source.form strings,
  inflating gateway-to-client frames beyond the queue contract's 64KB text budget.
- Fix: cap sourceKind/sourceForm (e.g. slice(0, 64)) like sibling bounded fields.

#### F-C6 [Info][InfoDisclosure] rpcWithBytes relays arbitrary Host error codes — OPEN (dup of F-B4)
- Location: gateway/src/native-harness.mjs:250
- Same as F-B4.

### Module D — deploy pocket-id-gateway

#### F-D1 [Low][DoS] Global login rate limit lets a remote attacker lock out new logins — OPEN
- Location: deploy/pocket-id-gateway/src/server.mjs:20
- Description: loginLimit() is one process-global counter (30 /_gateway/login per
  rolling 60s) shared by all clients; /_gateway/login is the only unauthenticated
  endpoint that performs work and is publicly reachable through the reverse proxy.
- Impact: ~30 requests/minute from an attacker permanently exhausts the budget; the
  owner's own re-login gets 429 for as long as the attack continues. Existing sessions
  keep working; the limiter protects nothing an attacker needs while being weaponizable
  against the owner.
- Fix: per-peer allowance for the trusted proxy (config.trustedProxy), or per-source
  rate limiting, keeping only a global flow-table bound.

#### F-D2 [Low][Config] systemd unit misses capability bounding and syscall/address-family sandboxing — OPEN
- Location: deploy/pocket-id.service:6
- Description: The unit already runs non-root with NoNewPrivileges, ProtectSystem=strict,
  ProtectHome, ProtectProc=invisible, PrivateTmp, RestrictSUIDSGID, StateDirectoryMode=0700,
  UMask=0077, but lacks CapabilityBoundingSet/AmbientCapabilities, RestrictAddressFamilies,
  RestrictNamespaces, LockPersonality, RestrictRealtime, MemoryDenyWriteExecute,
  SystemCallArchitectures/SystemCallFilter, and the ProtectKernel*/ProtectControlGroups/
  ProtectClock/ProtectHostname directives.
- Impact: The internet-exposed identity provider has weaker containment than its other
  hardening intends if the binary is ever exploited.
- Fix: add the listed systemd sandboxing directives.

#### F-D3 [Low][Secrets] Pocket ID secret env file has no enforced or documented permission — OPEN
- Location: deploy/pocket-id.service:11; deploy/pocket-id.env.example
- Description: ENCRYPTION_KEY (and STATIC_API_KEY during provisioning) load from
  /etc/pocket-id/pocket-id.env via EnvironmentFile=; neither the unit nor the example
  documents restrictive permissions.
- Impact: A default-umask copy (0644) lets any local account read the IdP encryption key.
- Fix: document install -m 600 -o root -g root, or move to systemd LoadCredential=.

### Module E — gateway web frontend (gateway/public)

#### F-E1 [Low][InputValidation] Prototype-chain keys bypass the ?section= allowlist and crash settings-page init — OPEN
- Location: gateway/public/pocket.js:135 (titles map :5, param :54/:131-132, catch :189);
  byte-identical copy under .artifacts/plugin-package/gateway/public/pocket.js
- Description: initialize() gates the ?section= param with titles[section] on a plain
  object literal, so inherited properties (constructor, valueOf, ...) pass the guard;
  querySelector returns null and .click() throws, aborting the rest of initialize()
  (state fetch, login/logout/notification UI never initialize).
- Impact: A crafted link /pocket/?section=constructor leaves the settings/login page
  non-functional until the param is removed; client-side DoS only, no script execution.
- Fix: Object.hasOwn(titles, section) (or validate against a Set of the four names).

#### F-E2 [Low][Bug] Host-mode login button posts to auth/none (403) on fresh page load — loginMode never initialized — OPEN
- Location: gateway/public/pocket.js:104 (declared :55, only assigned :110; #none shown
  for host mode :175-182); identical in the plugin-package copy
- Description: In host mode the settings page shows the token login button whose handler
  chooses the endpoint via loginMode === 'host' ? 'auth/native' : 'auth/none', but
  loginMode is only assigned inside the notifications enable action (hidden until
  authenticated). On a fresh load the button POSTs /pocket/api/auth/none, which the
  gateway rejects with 403 in host mode; the intended auth/native token exchange is
  never reached.
- Impact: The browser-only host-mode login fallback always fails until the user has
  clicked 开启通知 earlier in the same page lifetime — effectively unreachable.
  Fail-closed availability defect in an auth entry point (no bypass, no exposure).
- Fix: set loginMode = state.mode after the state fetch in initialize() (or derive the
  endpoint from state.mode at click time).

#### F-E3 [Info][Config] Strict CSP covers only /pocket while the upstream Harness web app shares the same origin — ACCEPTED (documented)
- Location: gateway/src/app.mjs:265-267 (CSP scoped to /pocket), :279-287 (catch-all proxy)
- Description: The gateway serves the hardened /pocket page and the full upstream Harness
  web UI on the same origin; no gateway CSP applies to proxied responses.
- Impact: Harness/plugin-controlled content rendered by the upstream UI already executes
  in the gateway origin and can call /pocket/api/* with the owner's session. Acceptable
  for a single-owner compatibility proxy; the trust boundary is recorded here.
- Fix: none now (single-owner design); if isolation is ever required, serve the Harness
  UI on a separate origin.

### Module H — HarmonyOS client files, caches, transfers, storage

#### F-H1 [Medium][XSS] Workspace HTML preview executes scripts with unrestricted network egress — OPEN
- Location: harmony/entry/src/main/ets/components/NativeHtmlPreview.ets:218-231,
  harmony/entry/src/main/ets/services/NativeHtmlDocument.ets:132-141,
  harmony/entry/src/main/ets/components/NativeFilePreview.ets:312-315,464-497,736-740
- Description: NativeFilePreview routes .html/.htm files to NativeHtmlPreview, which
  renders them in an ArkWeb Web component with javaScriptAccess(true).
  onInterceptRequest returns the prepared response only for the synthetic preview
  origin and returns null for every other URL, so subresource requests proceed to the
  real network; onLoadIntercept only blocks navigations. The injected CSP explicitly
  allows script-src 'unsafe-inline' data: http: https:, connect-src http: https:,
  img/media/frame-src http: https:. Before rendering, the client fetches every
  workspace file the HTML references (up to 32MB total) and inlines them as data:
  URLs; nativeHtmlResolveReference resolves any workspace-relative reference.
- Impact: A malicious .html file in the workspace (e.g. placed by the agent from a
  cloned/prompt-injected repo) executes attacker JavaScript when previewed. The script
  can reference arbitrary workspace files (config/.env, secrets.json), get them
  inlined as data: URLs, read them from the DOM, and exfiltrate them plus page
  content from the phone to any external http(s) server, bypassing the gateway.
  ArkWeb shares one cookie jar with the app, so credentialed cross-site requests
  toward the gateway origin are also possible.
- Fix: deny-by-default CSP (default-src 'none'; style-src 'unsafe-inline' data:;
  img-src data:; script-src 'none'; connect-src 'none'; frame-src 'none') or
  javaScriptAccess(false), and make onInterceptRequest return an empty response
  instead of null for non-preview URLs.

#### F-H2 [Low][DoS] Host responses buffered in memory without size caps before transfer limits are checked — OPEN
- Location: harmony/entry/src/main/ets/services/NativeHarnessClient.ets:490-508,251-264,553-575,
  harmony/entry/src/main/ets/services/NativeFileTransfer.ets:29-44
- Description: readFileBytes accumulates the entire response body with no byte cap
  before returning it; readComplete's maxBytes guard runs only after the full window
  is already in memory. The same unbounded accumulation exists for all
  /pocket/api/native/ responses in request() and uploadAttachment's response;
  NativeImageView/NativeImageLightbox base64-decode whole payloads before
  NativeAttachmentCache.save's 32MB check.
- Impact: A misbehaving or compromised Host/gateway that ignores the requested window
  length can make the phone buffer hundreds of MB in RAM, freezing or OOM-killing the
  app; documented limits never trigger because they are evaluated too late.
- Fix: abort and discard in the dataReceive handlers once received bytes exceed the
  requested window length plus slack (and a fixed cap for request()/upload responses).

#### F-H3 [Low][DoS] User-picked attachments are read fully into memory with no size limit — OPEN
- Location: harmony/entry/src/main/ets/components/NativeWorkspace.ets:3045-3066,3077-3092,3111
- Description: readAttachment loops reading the picked document until EOF with no
  byte cap, concatenates it into one Uint8Array kept in draft.data; up to 8 files per
  batch are read and each is uploaded in full. No client-side size check exists on
  this path.
- Impact: Selecting multi-gigabyte local files buffers them entirely in RAM and then
  attempts a giant upload, freezing or crashing the client.
- Fix: stop reading at a fixed cap (e.g. the 32MB NativeAttachmentCache.maxBytes
  budget or the documented upload limit) and surface a clear error.

#### F-H4 [Low][DoS] Directory-listing cache entries have no entry-count or payload cap — OPEN
- Location: harmony/entry/src/main/ets/services/NativeWorkspaceCache.ets:269-290,253,82-107
- Description: saveDirectory JSON.stringify's the entire server-provided listing and
  inserts it as one TEXT row; loadDirectory parses it back. Contrast saveText's 2MB
  and saveBinary's 64MB per-entry caps. validDirectoryEntry limits each name to 255
  chars but not the entry count; only the 512MB per-scope quota reacts after the fact.
- Impact: A crafted or buggy Host listing with hundreds of thousands of entries causes
  a large stringify/parse and RDB insert plus a full ForEach render — memory/CPU spike
  and UI hang; up to 512MB of metadata can accumulate per scope before trimming.
- Fix: cap the persisted entry count (rely on listing.truncated) and the serialized
  payload size before insert, mirroring the text/binary caps.

#### F-H5 [Info][PathTraversal] Preview paths are sent to the Host unnormalized; confinement relies entirely on server checks — OPEN
- Location: harmony/entry/src/main/ets/services/NativeLinkResolver.ets:35-38,
  harmony/entry/src/main/ets/components/NativeInlineText.ets:105-107,146-162,
  harmony/entry/src/main/ets/components/NativeFileBrowser.ets:235-247,
  harmony/entry/src/main/ets/components/NativeFilePreview.ets:384-385,501-502,583-584
- Description: Browser navigation normalizes paths with workspaceRelativePath, but
  preview paths bypass it: chat-link targets keep absolute paths verbatim and
  NativeFileBrowser builds preview paths from raw listing.path plus entry.name. These
  go directly into stat/read requests and cache keys.
- Impact: Model-emitted links like file:///etc/shadow are probed verbatim; the
  gateway/Host rejects outside-workspace paths today, so no exploitable traversal
  end-to-end — a client-side defense-in-depth gap that turns into arbitrary Host-file
  display if any Host build lacks the server-side guard.
- Fix: apply workspaceRelativePath (normalize plus workspace-root confinement) to
  every path before it reaches the file APIs, including chat-link targets and
  listing-derived preview paths.

#### F-H6 [Info][InfoDisclosure] Conversation-derived metadata and workspace bytes stored unencrypted next to encrypted caches — OPEN
- Location: harmony/entry/src/main/ets/services/NativeMetadataCache.ets:42-44,59-84,
  harmony/entry/src/main/ets/services/NativeAttachmentCache.ets:28-32,
  harmony/entry/src/main/ets/services/NativeWorkspaceCache.ets:221-225
- Description: Transcript and workspace-cache RDBs are created with encrypt: true,
  but NativeMetadataCache persists up to 200 session titles, workspace paths and the
  last session id in plaintext preferences, and NativeAttachmentCache/NativeWorkspaceCache
  write cached images and workspace file bytes as plaintext .bin files under filesDir.
- Impact: Device backup or forensic extraction recovers conversation titles, workspace
  paths and cached content without the RDB key, undermining the at-rest encryption goal.
- Fix: store navigation metadata inside the encrypted RDB (or hash titles), and either
  keep binary caches in an encrypted container or document the accepted tradeoff.

#### F-H7 [Info][InputValidation] DB-derived binary file_name used for deletion without the validation applied on read — OPEN
- Location: harmony/entry/src/main/ets/services/NativeWorkspaceCache.ets:504-531,624-632,657-661,717-747
- Description: loadBinary validates the stored file_name equals the expected
  hash-derived name before opening, but clearSession, evictStorageCandidate and
  trimBinary read file_name from binary_cache and pass it straight into
  fileIo.unlinkSync(binaryDirectory + '/' + fileName) with no such check.
- Impact: Not exploitable through app paths (file_name is only written by saveBinary;
  the RDB is app-private and encrypted), but a tampered/restored inconsistent database
  would make the app delete arbitrary paths under a prefix-relative join.
- Fix: validate fileName against the expected binaryKey-derived name in the delete
  paths, mirroring loadBinary.

### Module I — HarmonyOS client rendering (markdown/HTML/code)

#### F-I1 [High][XSS] HTML preview CSP permitted remote scripts and full network egress — FIXED
- Location: harmony/entry/src/main/ets/services/NativeHtmlDocument.ets:132-141,
  harmony/entry/src/main/ets/components/NativeHtmlPreview.ets:218-231 (confirmed
  independently by modules H and I)
- Same root as F-H1, plus one extra vector found by this module: data:text/html
  navigations ran inside the component with no CSP at all.
- Fix (user directive: script references are a required feature, so scripts KEEP
  running): the injected CSP now denies programmatic network (connect-src 'none'),
  remote frames (frame-src 'none'), remote objects (object-src data:) and form
  posts (form-action 'none', base-uri 'none'); NativeHtmlPreview collects the
  absolute HTTP(S) URLs the document author declared statically
  (nativeHtmlRemoteReferences/nativeHtmlRemoteCssReferences) and its
  onInterceptRequest serves the preview document, passes ONLY those authored URLs
  to the network and answers every other request (script-built beacons included)
  with an empty response; data: navigations are blocked in onLoadIntercept.
  Scripts still execute and authored remote assets still load; nothing a script
  computes can leave the component.

#### F-I2 [Medium][InfoDisclosure] Secret mask bypass inside inline code spans — FIXED
- Location: harmony/entry/src/main/ets/services/NativeInlineMarkdown.ets:96-106
  (consumed with maskSecrets by NativeInlineText/NativeMessageView/NativeTable)
- Description: scan() emitted code-span content verbatim without consulting the
  secret spans, so any credential wrapped in backticks displayed in clear even
  with the mask active, defeating the display-hardening feature.
- Fix: code spans render through plainSecretRuns with the correct base offset, so
  secrets inside backticks are masked exactly like prose; code styling survives on
  the unmasked parts.

#### F-I3 [Medium][UIBug] Full-document reader rendered the whole table once per 4 KiB chunk — FIXED
- Location: harmony/entry/src/main/ets/components/NativeTextContent.ets:184-190
- Description: openReader() parsed this.table from the entire value, then the
  reader's LazyForEach passed that whole-document table into body() for every
  4 KiB chunk, duplicating the complete table per chunk.
- Fix: each reader chunk parses its own table (this.tableFor(part)); a chunk that
  is not itself a table renders inline.

#### F-I4 [Low][Bug] GFM tables with one- or two-hyphen delimiter cells never rendered — FIXED
- Location: harmony/entry/src/main/ets/services/NativeMarkdownTable.ets:32,
  NativeDocumentModel.ets:222, NativeStreamMarkdown.ets:212
- Description: all three parsers required at least three hyphens per delimiter
  cell; GFM permits any positive count.
- Fix: -{3,} relaxed to -+ in all three places (test fixtures updated: a
  one-hyphen streaming delimiter is still cut as unfinished, a two-hyphen one is
  a complete table).

#### F-I5 [Low][Bug] Markdown fence parsing: spaced info strings broke fences; short closers accepted — FIXED
- Location: harmony/entry/src/main/ets/services/NativeDocumentModel.ets:236-247
- Description: the opening fence required a single-word info string, and the
  closer accepted any 3+ run, so a three-backtick line closed a four-backtick
  fence early.
- Fix: info strings may contain anything but a backtick; the closing run must be
  at least as long as the opening run.

#### F-I6 [Low][Bug] Diff memo cache keyed by field lengths, not content — FIXED
- Location: harmony/entry/src/main/ets/services/NativeDiff.ets:203-208,214-223
- Description: two states whose strings change content but keep identical lengths
  shared a memo key, so the transcript kept showing the old diff after a
  same-length rewrite.
- Fix: the signature now carries an FNV-1a content fingerprint plus length for
  args/metaRaw/output/error.

#### F-I7 [Low][UIBug] "此消息暂不支持原生显示。" fallback shown for supported empty tool rows — FIXED
- Location: harmony/entry/src/main/ets/components/NativeMessageView.ets:213-216
- Fix: the fallback excludes tool-role rows and rows with structured blocks.

#### F-I8 [Low][Bug] Dead ternary capped every HTML-preview asset at 8 MiB — FIXED
- Location: harmony/entry/src/main/ets/components/NativeHtmlPreview.ets:123
- Fix: binary assets now draw from the shared 32 MiB workspace-asset budget
  (text/css assets keep the 8 MiB per-asset cap), matching the preview spec.

### Module J — HarmonyOS client session/state services

#### F-J1 [Medium][Bug] NativeListSource.set silently dropped mid-list row changes — FIXED
- Location: harmony/entry/src/main/ets/services/NativeListSource.ets:51
- Description: with stable keys, only the last 16 rows were compared; if 1-4 tail
  rows changed, indices before the window were never compared and their content
  changes never reached onDataChange (stale rows in process groups and the
  transcript).
- Fix: stable-key updates compare every row and notify the few changed indices
  directly.

#### F-J2 [Medium][Bug] Empty plugin-block cleanup popped an unrelated rendered block at the 30-block cap — FIXED
- Location: harmony/entry/src/main/ets/services/NativeToolStructured.ets:507-513
  (pop sites at 557, 628, 656, 674, 688, 700, 715, 739)
- Description: addPluginBlock returned a block without pushing it at the cap;
  every empty-node cleanup then popped the last VALID block.
- Fix: addPluginBlock returns null when nothing was pushed; all 15 call sites
  guard the null, and cleanup pop only ever removes the block that was pushed.

#### F-J3 [Low][UIBug] Process group closed state taken from the interrupting row's turn — FIXED
- Location: harmony/entry/src/main/ets/services/NativeTranscript.ets:447
- Fix: the group's own turnKey decides its closed state.

#### F-J4 [Low][Bug] Automation draft rounding silently rescheduled non-minute intervals — FIXED
- Location: harmony/entry/src/main/ets/services/NativeAdminModels.ets:294
  (save path NativeAdminClient.ets:359)
- Description: opening and saving a 90-second task rewrote it to 120 seconds via
  Math.round to minutes.
- Fix: the draft keeps the task's exact seconds plus the rounded initial value;
  saving without re-timing preserves the original schedule.

#### F-J5 [Low][InputValidation] Model catalog JSON applied to shared state without shape validation — FIXED
- Location: harmony/entry/src/main/ets/services/NativeModelDirectory.ets:49
- Fix: the catalog and selection are validated (groups/models/ids/efforts
  arrays and string fields) before assignment; a malformed response keeps the
  previous catalog and rejects the load.

### Module K — HarmonyOS client UI components and docks

#### F-K1 [Medium][UIBug] Plugin enable/disable switch kept the flipped visual after a failed request — FIXED
- Location: harmony/entry/src/main/ets/components/NativePluginsSurface.ets:445,623,659
- Description: the uncontrolled ArkUI Toggle only re-syncs its visual when
  re-created; on failure nothing re-applied isOn, so the switch showed the
  inverted state until an unrelated refresh.
- Fix: every failed toggle bumps a toggleGeneration counter; the three Toggle
  sites alternate between two identical branches, which re-creates the switch
  with the authoritative state after each failure.

#### F-K2 [Low][Bug] Plugin search never filtered the 运行组件 section — FIXED
- Location: harmony/entry/src/main/ets/components/NativePluginsSurface.ets:93
- Fix: filteredEntries() applies the same query match (title/moduleName/entryId).

#### F-K3 [Low][Bug] Stale build-approval banner survived install-spec edits — FIXED
- Location: harmony/entry/src/main/ets/components/NativePluginsSurface.ets:758
- Fix: editing or reopening the install spec clears the previous package's
  pending-build notice, so 批准并重试 can never pre-approve builds from a
  different package.

#### F-K4 [Info][Config] NativeCompatibilitySurface was unreferenced dead code with a drifted, weaker Web policy — FIXED (deleted)
- Location: harmony/entry/src/main/ets/components/NativeCompatibilitySurface.ets
- Description: the live Web surface is inlined in Index.ets; the dead copy had
  already drifted (no authOrigin allowance, no dshPocket proxy, no notification
  hooks) and duplicated the security-sensitive origin allowlist.
- Fix: the component is deleted and the two tests that referenced it
  (design-system.test.mjs, control-alignment.test.mjs) updated.

### Module GB — gateway backend functional bug hunt

#### F-GB1 [Medium][Bug] Proxied host WebSockets counted against the native live-stream limit — FIXED
- Location: gateway/src/app.mjs:300-307
- Fix: live streams are tracked in their own per-owner set; the 4-connection cap
  counts only /pocket/native/live sockets while logout teardown still destroys
  every owner socket.

#### F-GB2 [Medium][Bug] Upstream abort mid-stream left the proxied client response half-open — FIXED
- Location: gateway/src/app.mjs:57-60
- Fix: proxyRes attaches response 'aborted' handling that destroys the client
  response when the upstream dies after headers/body started.

#### F-GB3 [Medium][UIBug] Overview aggregate and task list disagreed for stale waiting sessions — FIXED
- Location: gateway/src/overview.mjs:37-40 vs :50
- Fix: staleness wins in both the aggregate and the task rows (regression test
  added: stale+pending yields unknown in both).

#### F-GB4 [Low][Bug] projectEvent applied the title upsert before the monotonic sequence guard — FIXED
- Location: gateway/src/overview.mjs:9-14
- Fix: the title upsert moved below the seq check; a late titled event can no
  longer regress the stored title (regression test added).

#### F-GB5 [Low][InputValidation] normalizedHistory applied unvalidated surfaceOp replace operations — FIXED
- Location: gateway/src/native-protocol.mjs:436
- Fix: replace ops are validated with the snapshot-path contract; a malformed
  op skips its record instead of silently dropping transcript rows
  (regression test added).

#### F-GB6 [Low][InputValidation] normalizeFollow event frames skipped seq validation — FIXED
- Location: gateway/src/native-protocol.mjs:621-625
- Fix: a missing/invalid event seq or malformed op returns null, so the existing
  malformed-frame policy closes the generation (regression test added).

#### F-GB7 [Low][Bug] automationEditRequest forwarded expectedUpdatedAt: null verbatim — FIXED
- Location: gateway/src/native-admin-protocol.mjs:442-448
- Fix: null is dropped exactly like undefined, matching the Host contract
  (regression test added).

#### F-GB8 [Low][Bug] export and capabilities upstream fetches had no timeout — FIXED
- Location: gateway/src/native-harness.mjs:349 and :711
- Fix: both fetches carry server-side deadlines (60s export, 20s capability HEAD).

#### F-GB9 [Low][DoS] changes/summary buffered an unbounded chunked upstream body — FIXED
- Location: gateway/src/native-harness.mjs:329-336
- Fix: the summary body is read with a 2 MiB byte cap that aborts the upstream
  once exceeded, keeping the post-hoc check as a backstop.

### Module QA — host-side QA and verification pipeline

#### F-QA1 [High][Bug] Mock suite never forwarded ReduceMotion; "reduced-motion" evidence was a normal-motion capture — FIXED
- Location: scripts/device-ui-mock-suite.ps1:361
- Fix: the per-scenario splat forwards ReduceMotion, so reduced-motion scenes
  are actually captured with reduced motion. NOTE: existing reduced-motion
  evidence captured before this fix (including the iteration-notice scene) was
  mislabeled; a device re-capture is required and is listed as a device gap.

#### F-QA2 [High][Bug] Final hdc file recv exit codes never checked — FIXED
- Location: scripts/device-ui-mock.ps1:352
- Fix: both recv results are verified (exit code + file presence) and a missing
  capture fails the scenario instead of producing a manifest that claims files
  that were never received.

#### F-QA3 [Medium][Bug] image-region-diff cropped out-of-bounds regions as black on both sides — FIXED
- Location: scripts/image-region-diff.py:6
- Fix: the region is intersected with both images; a non-overlapping region or a
  size mismatch exits 2 with an error instead of silently reporting no change.

#### F-QA4 [Medium][Bug] --require-composer-visible never checked node visibility — FIXED
- Location: scripts/device-ui-layout-assert.py:108
- Fix: the matched TextArea must be effectively visible (visible/opacity/bounds)
  and multiple visible TextAreas fail the assertion.

#### F-QA5 [Medium][InfoDisclosure] Publication scanner missed /home/<user> after ':' or '/' — FIXED
- Location: scripts/check-publication.mjs:188
- Fix: ':' and '/' join the allowed prefix set, so scp remotes, file:// URLs and
  http(s) URLs containing personal paths are flagged.

#### F-QA6 [Low][Bug] Move-ShowcaseToTail reported atTail=true when the scroll container was missing — FIXED
- Location: scripts/showcase-scroll-to-tail.ps1:68
- Fix: a missing transcript-scroll returns atTail=false so the capture fails
  instead of silently passing tail verification.

#### F-QA7 [Low][Bug] buildSteps('release') without evidencePath silently degraded to pr — FIXED
- Location: scripts/qa.mjs:173
- Fix: the release profile requires an evidence manifest (QaUsageError).

#### F-QA8 [Low][Bug] Release evidence scope.featureIds never checked against the registered manifest — FIXED
- Location: scripts/verify-evidence.mjs:541
- Fix: validateEvidenceFile loads the registered feature ids from
  docs/testing/mock-feature-manifest.json and rejects unknown scope.featureIds.

#### F-QA9 [Low][Bug] --root without a value silently resolved to the process cwd — FIXED
- Location: scripts/verify-evidence.mjs:701
- Fix: a missing --root value throws.

#### F-QA10 [Low][Bug] Get-ExpectedMarker default silently disabled the content assertion — FIXED
- Location: scripts/device-ui-mock-suite.ps1:312
- Fix: an unregistered scenario/state pair throws instead of skipping marker
  verification.

#### F-QA11 [Info][Bug] Feature "covered" count subtracted invalid features that were never added — FIXED
- Location: scripts/verify-mock-coverage.mjs:318
- Fix: covered counts only valid ids that are not in the invalid set.

(All 13 module reports received.) gateway core, native harness, native protocols, deploy
gateway, web frontend, plugins, client network/bridge, client files/caches,
client rendering, client state, client components)

## Fix log

All fixes below are applied in this working tree and verified by the gateway test
suite (320 passing, 1 pre-existing skip) plus targeted regression tests added per
fix; HarmonyOS product-variant builds and the device-evidence gap list are in
docs/testing/2026-11-07-security-audit-remediation-e2e.md.

### Backend (gateway, deploy, plugin)
- F-B1/F-C1: express.json limit Infinity → '64mb' (app.mjs) + per-field caps in
  native-harness.mjs (prompt text 256 KiB, 32 attachments, 16 images with 16 MiB
  base64 each, titles 160, queue text 256 KiB, custom answers 4 KiB, identifiers
  160, paths 4096, model fields 160/64). Regression test added.
- F-B2/F-C2: upload enforces a 128 MiB declared cap, a wire-side byte bound that
  destroys the stream mid-flight, a safe filename charset (no '/', '\\',
  control chars, '.'/'..') and a media-type shape check. Regression test added.
- F-B3: documented as contained by design for the bridge deployment (one shared
  Harness account) and mitigated for standalone proxy deployments by F-A3's
  per-owner cookie isolation.
- F-B4/F-C6: rpcWithBytes relays only stable decision codes (shared
  stableDecisionCode helper). Regression test added.
- F-C3: settingsSet validates with Object.hasOwn (prototype-chain bypass closed).
  Regression test added.
- F-C4: fullText(value, maxLength) truncates; the intended 100/30 caps now apply.
- F-C5: sourceKind/sourceForm capped at 64 in all three projection paths.
  Regression test added.
- F-A1: same as F-B1 (64mb limit).
- F-A2: the auth limiter exempts live ceremonies (challenge id bound to the
  browser's binder cookie) and existing sessions; blind floods still consume the
  budget. Residual: an attacker can still delay the FIRST options call of a
  fresh device; per-source throttling belongs at the reverse proxy (documented
  with the deploy examples, same guidance as F-D1).
- F-A3: upstream cookies are stored per attested owner (Map) and threaded through
  native-harness via AsyncLocalStorage; a request without owner context resolves
  to no cookie instead of the last one any owner sent; logout drops the owner's
  cookie.
- F-D1: per-source throttling guidance added to deploy/Caddyfile.example (the
  Node service only sees the trusted proxy by design); in-process limit kept as
  a resource backstop.
- F-D2: pocket-id.service gains CapabilityBoundingSet=, AmbientCapabilities=,
  RestrictAddressFamilies, RestrictNamespaces, LockPersonality, RestrictRealtime,
  SystemCallArchitectures, SystemCallFilter=@system-service and the
  ProtectKernel*/ProtectControlGroups/ProtectClock/ProtectHostname directives.
  MemoryDenyWriteExecute intentionally omitted (V8 JIT needs W^X pages).
- F-D3: pocket-id.env.example documents install -m 600 -o root -g root.
- F-F1: the plugin validates trust BEFORE creating gateway apps (hostIdentity
  403 fence; proxy-secret timing-safe compare + loopback peer) in both the
  /pocket route and the WS upgrade, and the 32-slot app cache evicts
  least-recently-used non-pinned apps instead of throwing; the event-recording
  owner app is pinned.
- F-GB1..F-GB9: see module GB above.

### Web frontend (gateway/public)
- F-E1: ?section= gated with Object.hasOwn (prototype-chain keys can no longer
  crash settings-page initialization).
- F-E2: loginMode is initialized from the state fetch, so host-mode login uses
  the auth/native token exchange on a fresh page load instead of failing with 403.

### HarmonyOS client
- F-H1/F-I1: HTML preview keeps script execution (user directive) but denies
  programmatic network/forms/remote frames and enforces an authored-URL
  allowlist in the request interceptor; data: navigations blocked.
- F-H2: streamed responses are bounded (NativeResponseBudget): JSON 64 MiB,
  file windows length+64 KiB, upload replies 64 KiB; oversize aborts the task.
- F-H3: picked attachments stop reading at the 32 MiB budget with a clear error.
- F-H4: file listings are validated and bounded (1000 entries, truncated flag)
  client-side; oversized directory cache payloads are not persisted.
- F-H7: cache deletions recompute the expected hash-derived file name before
  unlinking (clearSession, evictStorageCandidate, trimBinary).
- F-I2..F-I8, F-J1..F-J5, F-K1..F-K4: see modules I, J, K above.
- F-G1: cleartext http:// origins are restricted to loopback hosts
  (127.0.0.0/8, localhost, [::1]); any other http origin is rejected with
  'HTTP 仅限本机地址，远程服务请使用 HTTPS'.

### Device round additions (2026-11-07, device online)

#### F-DEV1 [Medium][UIBug] Plugin surface scrollbar covered content instead of hugging the edge — FIXED
- Location: harmony/entry/src/main/ets/components/NativePluginsSurface.ets (root list
  and detail scroll)
- Description: the plugin drawer lists were laid out inside the page inset
  (16 vp on both sides), so the ArkUI scrollbar sat 16 vp inside the content
  area and visually covered the trailing side of rows. The conversation
  transcript already solves this by widening its list past the inset
  (width 'calc(100% + 24vp)' plus a matching right padding).
- Impact: the plugin list and plugin detail pages showed a scrollbar that
  overlapped row content and did not match the conversation surface.
- Fix: both plugin lists now use 'calc(100% + 16vp)' with a matching right
  padding, so the bar renders on the physical edge exactly like the transcript
  while row content keeps its inset. Verified on the device (HBN-AL80, API 26)
  in dark and light; the plugin scenarios still pass their layout assertions.

#### F-DEV2 [High][Bug] Mock suite assertions aborted on expected stderr — FIXED
- Location: scripts/device-ui-mock-suite.ps1 (Assert-LayoutMarker,
  Assert-LayoutBottomSafe, Assert-LayoutNodeId)
- Description: every layout assertion merged the Python query's stderr into
  the pipeline (2>&1) while $ErrorActionPreference was 'Stop'. The query
  writes its "not found" diagnostic to stderr, so an EXPECTED absence
  (Assert-LayoutMarker -MustExist $false) and a genuine failure were both
  turned into terminating errors before the exit code was read.
- Impact: 13 plugin/automation scenarios failed with "visible node not found:
  Invalid URL format or missing URL" even though the captures were correct.
- Fix: a shared Invoke-LayoutQuery helper runs the query with
  $ErrorActionPreference = 'Continue' and returns the output plus exit code, so
  the exit code is the only signal the assertions read.

#### F-DEV3 [Medium][Bug] Sidebar assertions required a workspace below the first viewport — FIXED
- Location: scripts/device-ui-mock.ps1 (capture flow)
- Description: the drawer is a lazy list, so a workspace header below the first
  viewport is absent from the layout tree. The suite required
  sidebar-workspace-workspace-gateway on the first frame and failed.
- Fix: sidebar captures scroll the drawer once before the screenshot and dump,
  so every registered workspace header is rendered and asserted. Verified in
  dark and light.

#### F-DEV4 [Medium][Bug] Dark Dock material assertion failed on uniform content — FIXED
- Location: scripts/device-ui-material-assert.py
- Description: the vertical samples cross the Dock's content (edit hint, queue
  rows, composer), which is legitimately uniform in the dark theme, so a
  flat span was reported as a missing material even though the Dock separated
  from the page (entry delta 8.86).
- Fix: a flat dark span only fails when the Dock also fails to separate from
  the page (entry delta < 4.0); the entry edge delta is the authoritative
  dark-theme signal. The dark capture now passes.

#### F-DEV5 [Low][Bug] PowerShell scripts were read as ANSI by Windows PowerShell 5.1 — FIXED
- Location: scripts/*.ps1 (7 files)
- Description: the suite scripts contain Chinese fixture markers but had no
  UTF-8 BOM, so Windows PowerShell 5.1 decoded them as ANSI and the scripts
  failed to parse.
- Fix: the affected scripts now carry a UTF-8 BOM.

#### F-DEV9 [Medium][UIBug] Full-permission confirmation used a pale text token as a button fill — FIXED
- Location: harmony/entry/src/main/ets/components/NativeWorkspace.ets (permissionConfirmCard),
  harmony/entry/src/main/ets/components/NativePluginCard.ets, harmony/entry/src/main/ets/services/NativeDesign.ets
- Description: the primary destructive action painted its background with
  dangerText()/warningText() — the semantic TEXT tokens (#FF9C9C / #F0B84A in
  dark mode) — while its label used textInverse (#17181B). A pale pink fill
  with dark type read as a light surface floating in the dark dialog, and the
  disabled state dimmed that pale fill further into a muddy tone. The plugin
  card's confirm button had the same shape with accent() + white type.
- Impact: the risk acknowledgement dialog — the one surface where the user
  confirms full permission — looked washed out and its primary action was hard
  to read in both themes.
- Fix: NativeDesign gains dangerSolid()/warningSolid() (saturated fills meant to
  pair with white type). The confirm action now uses a solid danger/warning fill
  with #FFFFFF text when acknowledged, and a neutral field() fill with tertiary
  text while unchecked, so the disabled state no longer dims a saturated fill.
  The plugin card confirm button uses accentStrong(). Verified on device in dark
  and light: acknowledged fill is #FFB3261E with white type, unchecked is
  neutral.

#### F-DEV10 [Medium][Bug] Showcase scenes acted on a fixed 700 ms delay — FIXED
- Location: harmony/entry/src/main/ets/components/NativeWorkspace.ets (aboutToAppear)
- Description: every showcase surface (sidebar, plugins, automation, more,
  browser, preview) opened on a fixed 700 ms timer started before the first
  reload settled. On a cold start with cleared app data the timer could fire
  before the fixture sessions existed, so the scene captured the conversation
  surface instead of the requested one.
- Impact: model-menu, plugins-restart, showcase-subagent, approval-workspace-once
  and the disclosure sidebar scenes failed intermittently inside a full suite
  run while passing when rerun alone.
- Fix: a whenFixtureReady() helper polls until the first reload finishes (with a
  6 s deadline) and then runs the scene action. All six fixed delays are gone;
  the affected scenes now pass individually with -ResetData.

#### F-DEV11 [Info] HTML preview now has deterministic device coverage — CLOSED gap
- Location: harmony/entry/src/main/ets/services/StoreShowcaseClient.ets,
  harmony/entry/src/main/ets/components/NativeWorkspace.ets,
  harmony/entry/src/main/ets/services/NativeUiFixture.ets,
  scripts/device-ui-mock.ps1, scripts/device-ui-mock-suite.ps1,
  docs/testing/mock-feature-manifest.json
- Description: the earlier round could only prove F-H1/F-I1 by source tests
  because no Mock fixture rendered an HTML document.
- Fix: a `docs/preview.html` fixture (inline script + one authored remote image)
  and an `html-preview` scene in dark and light, registered as
  `surface.file-preview-html`. The capture asserts the inline script ran
  (`DSH_SCRIPT_RAN`), proving scripts still execute while the authored-URL
  allowlist and the tightened CSP keep script-composed egress off the network.

#### F-DEV7 [Medium][Bug] Consecutive suite scenes inherited the previous scene's surface — FIXED
- Location: scripts/device-ui-mock-suite.ps1 (per-scenario splat)
- Description: the driver supports -ResetData but the suite never passed it, so
  NativeMetadataCache restored the previous scene's drawer/page state. A scene
  that opens the drawer or an admin page could therefore capture the previous
  surface; standalone reruns passed, which made the failure look intermittent.
- Impact: 6 of 152 scenes failed inside a full run (sidebar "置顶"/group markers,
  plugin restart, subagent filter, approval copy) while passing when rerun alone.
- Fix: every suite scenario now resets app data before launch, so each scene
  starts from a clean fixture state.

#### F-DEV8 [Low][Bug] QA step-count and layout-query contracts pinned the old shape — FIXED
- Location: gateway/test/qa-runner.test.mjs, gateway/test/control-alignment.test.mjs
- Description: adding the PowerShell encoding gate and routing layout assertions
  through Invoke-LayoutQuery changed the fast-profile step list and the
  bottom-safe invocation shape, which the contract tests pinned literally.
- Fix: the contracts now assert the new step id/args and the argument-array form.

#### F-DEV6 [Medium][Bug] Composer assertion rejected legitimate secondary TextAreas — FIXED
- Location: scripts/device-ui-layout-assert.py
- Description: the earlier hardening rejected any layout with more than one
  visible TextArea, but the question card legitimately renders its own custom
  answer field beside the composer.
- Fix: the composer is identified by its stable composer-input id; other
  TextAreas are ignored, and a later identified composer supersedes an earlier
  unidentified one. interaction-question passes in dark and light.

### Accepted risks (documented, no code change)
- F-H5 [Info][PathTraversal]: preview paths reach the Host unnormalized; the
  authoritative containment is the Host workspace-file contract
  (workspace-file/outside-workspace is in the gateway's stable-code allowlist
  and verified by tests). Client-side normalization of absolute chat-link paths
  would silently remap them to unrelated workspace files, which is worse than
  the current clean rejection.
- F-H6 [Info][InfoDisclosure]: session titles, workspace paths and cached
  workspace/attachment bytes live in plaintext preferences and .bin files next
  to the encrypted transcript RDB. HarmonyOS file-based device encryption covers
  app data at rest; moving metadata into the encrypted RDB or a container is a
  design change deferred with a revisit trigger (backup extraction remains the
  documented residual).
- F-E3 [Info][Config]: the upstream Harness web UI shares the gateway origin by
  design (single-owner compatibility proxy); the /pocket CSP cannot isolate it.
- F-L2/F-A5 [Low][SupplyChain]: http-proxy 1.18.1 is unmaintained but has no
  applicable advisory; kept pinned with a re-review trigger.
- F-A4 [Info][InfoDisclosure]: /pocket/api/state exposes mode/registered/
  pushConfigured/pluginVersion pre-login by design for the login UI.