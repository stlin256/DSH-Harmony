# Store showcase refresh implementation

Date: 2026-11-04

## Fixture scenarios

Add deterministic `showcase-*` states to `NativeUiFixture` and
`StoreShowcaseClient`:

| State | Surface | Scenario |
| --- | --- | --- |
| `showcase-plan` | conversation | Make offline/sync settings reusable |
| `showcase-process` | process | Diagnose a search first-paint flicker |
| `showcase-lineage` | lineage | Split a filter refactor across subagents |
| `showcase-dark` | conversation | Group unread notifications |
| `showcase-dark-process` | process | Investigate repeated cache requests |
| `showcase-subagent` | subagent | Review cache expiry and fallback |
| `showcase-approval` | conversation | Approve one narrow-screen layout write |

The fixture must keep Host-owned projections and use only synthetic copy. The
automation and plugin inventories must carry enough rows to make the list
surfaces feel populated during capture. Marketing conversations must include at
least two completed context turns before the featured turn, keep a non-empty
final assistant response, and expose the answer inside the first device
viewport. File fixtures must contain enough structured source to fill the
preview surface: configuration near one hundred lines, tabular data with more
than fifteen rows, and a multi-level workspace listing. These rows must remain
credible synthetic product data rather than repeated placeholder text.
Marketing turn-change cards must exercise the product's real collapsed summary
by containing at least four changed files, while showing at most three rows and
the `再显示 1 个文件` disclosure affordance.

## Capture matrix

Capture these deterministic scenes:

| Raw file | Screen | Fixture | Theme |
| --- | --- | --- | --- |
| `01-conversation-light.png` | conversation | `showcase-plan` | Light |
| `02-process-light.png` | process | `showcase-process` | Light |
| `03-lineage-light.png` | lineage | `showcase-lineage` | Light |
| `04-preview-light.png` | preview | `text-config-preview` | Light |
| `05-approval-light.png` | conversation | `showcase-approval` | Light |
| `06-conversation-dark.png` | conversation | `showcase-dark` | Dark |
| `07-process-dark.png` | process | `showcase-dark-process` | Dark |
| `08-subagent-dark.png` | subagent | `showcase-subagent` | Dark |
| `09-automation-dark.png` | automation | `automation-list` | Dark |
| `10-plugins-dark.png` | plugins | `plugins-list` | Dark |
| `11-settings-light.png` | settings | `completed` | Light |

The curated ten-image store export uses conversation, process, lineage, preview,
approval, appearance, automation, plugins, desktop cards and open source.

## Composition

The portrait canvas reserves a separate footer band and uses larger semantic
type. The phone target height and vertical position are constants with a source
layout assertion, so the footer cannot overlap the device. The landscape layout
keeps the established left-copy/right-device hierarchy while receiving the same
readability improvements.

## Automation

`scripts/capture-store-screenshots.ps1` remains the one-command path. It builds
the Mock Release, installs it, captures all scenes, invokes
`scripts/compose-store-screenshots.py`, validates dimensions and file sizes,
and writes `manifest.json`. The manifest records the expanded scene list and
curated output counts.
