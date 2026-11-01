# Fenced DSH UI and Media Compatibility Implementation Spec

Date: 2026-11-01

Status: implementation specification.

## 1. Shared structured view model

Extend `NativePluginBlock` with:

```text
id
multi
confirmLabel
cancelLabel
```

Extend `NativePluginItem` with the visible reply value.

Keep `NativePluginDocument` as the common bounded view model.

## 2. Assistant fence parser

Add a public parser:

```text
nativeDshUiDocument(source: string): NativePluginDocument
```

Behavior:

1. Measure UTF-8 source bytes. Reject above 16 KiB.
2. Parse valid JSON object/array.
3. If strict parsing fails, remove comments and trailing commas and retry once.
4. Wrap an array as `{type: "stack", children: value}`.
5. Require a known assistant root type:
   `stack`, `row`, `text`, `metric`, `chart`, `compare`, `steps`, `callout`,
   `options`, `confirm`.
6. Traverse in source order with the 40-node, depth-6 and child-16 budgets.
7. Unknown nested nodes become a safe unsupported placeholder.
8. Options retain visible labels, descriptions and read-only selected state.
9. Confirm components retain only their optional display labels.
10. Invalid source keeps `present=true`, `valid=false` and no invented blocks.

The existing tool-card parser remains capped at 8 KiB and stays read-only.
Tool cards must additionally require `phase=result`, no failure and a known
root component.

## 3. Assistant card UI

Add `NativeDshUiCard`:

- parse the fence source once on source change;
- render through `NativePluginCard` in interactive mode;
- show a compact error row and the original code block when invalid;
- send options/confirm replies through a callback.

`NativePluginCard` gains a read-only flag. In read-only mode no option or
confirm can execute. In interactive mode:

- single-select option taps send the selected visible label;
- multi-select accumulates visible labels and presents one compact submit
  action;
- confirm/cancel send their displayed labels when they differ from defaults;
- one successful reply locks the card;
- a failed send unlocks it and shows an error toast;
- reduced motion removes decorative transitions.

## 4. Reply protocol and state

Reply text:

```text
[dsh-ui reply] <optional title>
选择：Label A、Label B
```

or:

```text
[dsh-ui reply] <optional title>
确认：<non-default label>
```

The parser also accepts `确认`, `取消`, `Select`, `Confirm` and `Cancel`.

Expose:

- `nativeDshUiReplyText(...)`;
- `nativeDshUiReplyLabel(source)`;
- `nativeDshUiCanReply(rows, messageId, running, waiting)`.

Availability:

- false while the session is running or waiting;
- false when a later user or assistant message exists;
- true only for the latest idle assistant view.

The workspace submits the reply through the existing authenticated prompt path
without attachments. It never sends option values or component IDs.

## 5. Markdown integration

`NativeMessageView` intercepts code blocks whose normalized language is
`dsh-ui` and renders `NativeDshUiCard`.

For user messages beginning with `[dsh-ui reply]`, render a compact reply chip
instead of a full prose bubble. The original text remains in the message model.

## 6. Media compatibility

Extend `NativeMediaDocument` with cost estimate/currency.

Read `dsh-go/media` with the following rules:

- missing `v` => 1; non-integer or `<1` => invalid; larger positive versions
  remain readable;
- `items` not an array => no items;
- invalid individual items are skipped;
- invalid optional dimensions/bytes/duration become absent;
- explicit `image`/`video` wins; otherwise infer from the first valid MIME;
- unknown status becomes `done`;
- done with no valid items is invalid;
- status `failed` remains valid with no items;
- request fields are independently validated;
- cost is valid when `estimate` is finite and non-negative;
- all prior 8 KiB and read-only rules remain.

Display cost only when valid and avoid locale-specific currency conversion.

## 7. Tests

ArkTS service and source-contract tests:

- fence arrays, comments/trailing commas, metrics, options and confirm;
- invalid root and oversize fallback;
- depth and child budgets;
- option/confirm response text and reply chip parsing;
- latest-idle reply availability;
- successful-result-only tool cards and unknown-root rejection;
- media version defaults, kind inference, malformed optional facts, cost and
  empty-done rejection;
- native chat and reply-chip wiring.

## 8. Build gate

Shared ArkTS changes require both `default` and `store` Release builds. Device
rows remain Pending until real-device evidence exists.
