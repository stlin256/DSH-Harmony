# Store showcase screenshots implementation

Updated: 2026-11-03

## Product isolation

`EntryAbility` accepts launch-only string parameters:

- `storeShowcase=true`
- `showcaseScreen=conversation|disclosure|lineage|preview|settings|subagent|automation|plugins`
- `showcaseState=<state from NativeUiFixture>`
- `showcaseTheme=light|dark|system`

The `mock` product enables `ProductCapabilities.supportsMockFixtures`; the
explicit `storeShowcase=true` parameter remains available for capture commands.
The selected client is an in-memory `NativeHarnessClient` implementation and
never opens a network connection. It supplies synthetic sessions, workspaces,
host settings, model metadata, tools, plans, subagents, files and admin lists to
the existing `NativeWorkspace` and `NativeSettings` components.

The fixture stays in the installed binary so screenshots remain reproducible.
Normal launches do not read fixture data, write it to the transcript cache or
use it for widget state.

## Content contract

The fixture uses only generic product copy:

- workspaces: `DSH Harmony 移动端`, `Passkey Gateway`
- session: `发布准备与商店检查`
- response: release checklist and next steps
- file examples: configuration text, delimited tables, Markdown, code and SVG
- model: `DeepSeek-V4-Pro`, reasoning effort `max`

No origin, account, token, cookie, real path or real session title is present.

## Capture matrix

| Raw file | Screen | Fixture state | Theme |
| --- | --- | --- | --- |
| `01-conversation-light.png` | `conversation` | `showcase-plan` | Light |
| `02-process-light.png` | `process` | `showcase-process` | Light |
| `03-lineage-light.png` | `lineage` | `showcase-lineage` | Light |
| `04-preview-light.png` | `preview` | `text-config-preview` | Light |
| `05-approval-light.png` | `conversation` | `showcase-approval` | Light |
| `06-conversation-dark.png` | `conversation` | `showcase-dark` | Dark |
| `07-process-dark.png` | `process` | `showcase-dark-process` | Dark |
| `08-subagent-dark.png` | `subagent` | `showcase-subagent` | Dark |
| `09-automation-dark.png` | `automation` | `automation-list` | Dark |
| `10-plugins-dark.png` | `plugins` | `plugins-list` | Dark |
| `11-settings-light.png` | `settings` | `completed` | Light |

## Capture output

`scripts/capture-store-screenshots.ps1` builds and installs the Mock Release
HAP, launches the selected fixture states and captures raw device images through
`devecocli ui screenshot`.

The script is the one-command refresh path. By default it builds the `mock`
Release product, installs it, captures all scenes, composes both orientations,
validates dimensions and file size, and writes `manifest.json`. A contributor
that already has a current Mock HAP can pass `-SkipBuild`; a capture-only pass
can also pass `-SkipInstall`.

```powershell
.\scripts\capture-store-screenshots.ps1 -Device '<device-id>'
```

Pass `-RestoreCommunity` to rebuild and reinstall the community Push Kit variant
after capture. Without it, the device remains on the captured Mock build.

`scripts/compose-store-screenshots.py` places each real-device portrait capture
in a branded rounded device frame. The phone is enlarged to dominate the right
half of landscape art and the lower visual block of portrait art. Titles,
feature chips and the device are packed into a centered composition rather
than spread across distant corners.

The curated export order is:

1. Conversation and floating task plan, light
2. Expanded work process, light
3. Plan and subagent lineage, light
4. File preview, light
5. Settings, light
6. Paired light/dark appearance
7. Desktop cards
8. Open source
9. Expanded work process, dark
10. Subagent conversation, dark

The paired appearance art uses the actual light and dark conversation captures.
The card art follows the bundled `OverviewCard`/`QuickCard` colors, radius and
information hierarchy. The open-source art names the real repository and makes
no star or license claim.

`manifest.json` records the USB device serial and model, API version, Mock HAP
SHA-256, scene list, fixture model and output counts. The script does not claim
device evidence from a build-only run.

README and promotional copy keep the existing brand voice. The refresh may
change which product surfaces are shown, but it does not add phrases such as
"new", "updated" or "now available".

The process is read-only with respect to the remote service. Device completion
requires a connected, unlocked device whose HDC state is neither `Offline` nor
`Unauthorized`.
