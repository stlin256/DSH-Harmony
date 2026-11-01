# Fenced DSH UI and Media Compatibility E2E

Device evidence is required. Parser tests and builds do not prove interaction,
layout or accessibility on a device.

| ID | Scenario | Expected | Status |
| --- | --- | --- | --- |
| DSHUI-01 | Open an assistant reply with a valid `dsh-ui` stack | Native compact card replaces the JSON code block | Pending |
| DSHUI-02 | Open an incomplete or invalid fence | Compact error state and the original JSON fallback remain readable | Pending |
| DSHUI-03 | Open metrics, charts, compare, steps and callout blocks | Values and labels fit the phone width in light and dark themes | Pending |
| DSHUI-04 | Open the latest idle options view and choose one item | One visible-label reply is sent and the card becomes read-only | Pending |
| DSHUI-05 | Open a multi-select view | Selection is visible and one submit action sends all selected labels | Pending |
| DSHUI-06 | Confirm and cancel a confirm component | The displayed reply chip matches the chosen visible label | Pending |
| DSHUI-07 | Tap a historical or answered view | No new message is sent | Pending |
| DSHUI-08 | Receive a reply while the turn is running | Native card stays disabled and the raw message remains intact | Pending |
| DSHUI-09 | Reopen the session after an answer | Reply chip and read-only card restore from durable messages | Pending |
| DSHUI-10 | Repeat the card matrix with reduced motion enabled | Essential state changes remain immediate and readable | Pending |
| PROTO-COMPAT-11 | Open a successful tool with an unknown plugin root | Raw fallback appears; no blank typed card is shown | Pending |
| PROTO-COMPAT-12 | Open a media record without `v` and without `kind` | Kind is inferred from MIME and the card remains read-only | Pending |
| PROTO-COMPAT-13 | Open media with invalid optional facts and valid items | Valid items and cost remain; malformed optional facts are omitted | Pending |
| PROTO-COMPAT-14 | Open done media with no valid items | Raw fallback appears and no completion card is claimed | Pending |
| BUILD-01 | Build default and store Release variants | Both compile, sign and contain the shared changes | Pending |

## Evidence to record

- Device model, HarmonyOS/API version, HAP variant and version.
- Light and dark screenshots for an interactive and a fallback card.
- A short recording showing choose, confirm, reply chip and read-only history.
- Media default/inference/cost and empty-done fallback screenshots.
- No private host, credential, real transcript, workspace path or notification
  content.

## Automated verification

Automated service and source-contract results will be appended after the
implementation is complete. Device rows remain Pending without real-device
evidence.
