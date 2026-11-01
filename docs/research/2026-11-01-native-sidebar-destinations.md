# Native sidebar destinations research

Date: 2026-11-01

## Current application

`NativeWorkspace` renders the three global entries in the drawer, but all call
one placeholder method. The compatibility surface retains web routes for the
same names, which proves that the destinations exist but does not satisfy the
native requirement.

The application already has the components needed for a consistent
implementation: semantic theme tokens, tinted DSH glyphs, shared navigation,
row, disclosure and spring motion, safe-area handling, server-side operation
allowlists, and a mock product that drives ArkUI without a live Host.

## Upstream plugin manager semantics

The DSH plugin surface combines two sources:

- `pluginManager/listBundles` describes packages and the patch rows they
  declare;
- `pluginManager/listPlugins` describes the live Loader entries and fiber
  phases.

A bundle can be official, installed, enabled, removable, updatable, or missing.
Its rows can be enabled, failed, loading, active or unloaded. Management can be
unavailable for protected or unaddressable rows. Installation may return
`applied`, `restart-required`, `overridden`, `failed` or `cancelled`, and may
request approval for package build scripts.

The upstream desktop page joins these sources and exposes dense grouped cards.
A phone needs the same facts in a list-detail flow. The highest-value native
scope is inventory, detail, enablement, install, update and removal. Plugin
configuration forms are extension-defined and remain outside the first native
contract.

## Upstream automation semantics

The automation surface is owned by the Host-wide Schedule service. Its
catalog contains durable tasks independent of the active conversation. Task
records have:

- a lifecycle status: active, paused or ended;
- a timing rule: after, at, every, daily, weekly, cron or rrule;
- an instruction and title;
- an existing-session, reusable-new-session or fresh-session destination;
- next occurrence, execution state and last acknowledged delivery.

The catalog is sorted by next run and supports local search and lifecycle
filtering. Editing is guarded by `expectedUpdatedAt`; a mismatch must surface a
conflict rather than overwrite another client's change. Delivery history is a
separate bounded read.

On a phone, a single list and a native secondary detail preserve context and
avoid the desktop split-pane squeeze. Creation uses a focused native form with
the supported timing rules and destination choices.

## More semantics

The upstream sidebar does not treat More as a content page. It is an anchored
menu whose rows come from registered sidebar actions. Its key behavior is
spatial attachment to the launcher and dismissal back into the same sidebar
state. The native adaptation therefore keeps the drawer open and expands a
compact menu beneath More.

## Mobile interaction observations

A separate mobile implementation demonstrates three useful patterns without
being used as a protocol source:

- list-detail navigation keeps dense management data readable on narrow
  screens;
- operation state is explicit and survives failures;
- saved drafts and native Back order prevent loss during editing.

The native DSH surface should use the Host's canonical records and APIs
directly. It should borrow layout behavior only where it agrees with DSH's
compact visual language.

## Gateway constraints

The existing native gateway maps unknown methods to `session/*`. Plugin and
schedule endpoints use different namespaces and cannot safely use that helper.
They require a direct Remote caller and an explicit operation allowlist.

The gateway should normalize responses before handing them to ArkTS:

- cap list sizes and string lengths;
- accept only known status and timing discriminants;
- omit arbitrary diagnostics and unknown fields;
- convert optional values to a stable wire shape;
- never accept a caller-supplied endpoint;
- treat conflict and invalid-input outcomes as successful structured results,
  while transport failures remain bounded errors.

## Selected approach

- Plugins and Automation are full native pages.
- More is a drawer-anchored native menu.
- A shared admin client owns typed operations.
- Gateway operations call only fixed upstream Remotes.
- Lists use ArkUI `List` and stable keys.
- Nested pages use `NativeMotion.navigationTransition`.
- Mutations expose progress, error and retry without changing the visual
  system.

