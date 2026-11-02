# Store showcase screenshots

Updated: 2026-11-03

## User requirement

Refresh the AppGallery and README artwork from deterministic Mock content on a
real HarmonyOS device. The refreshed set must show the current product surface,
including the floating task plan, ordered work process, plan and subagent
lineage, file preview, settings, subagent conversation, automation and plugin
management. The copy is product presentation rather than a release changelog:
it describes what DSH Harmony is and does, not what was newly added.

## Acceptance criteria

- The normal application launch remains unchanged.
- The `mock` Release product can open the native shell with synthetic sessions,
  workspaces, tools, plans, subagents, files, plugins and automation.
- Every capture selects a screen, fixture state and light or dark appearance
  explicitly so the result is deterministic across runs.
- The ten listing scenes cover the floating task plan, ordered work process,
  plan and subagent lineage, text-file preview, settings, dark plan and
  subagent presentation, dark subagent conversation, automation and plugins.
- The mock model selection uses the upstream identity `DeepSeek-V4-Pro` with
  the supported `max` reasoning effort rather than a legacy reasoner label.
- Mock content contains no deployment address or user data.
- The capture helper produces real-device screenshots from the Mock product,
  framed by rounded device outlines.
- The promotional set also includes paired light/dark appearance artwork,
  desktop-card artwork and open-source project artwork.
- User-facing artwork and README copy describe the current product in the
  existing brand voice and do not enumerate release additions.
- The artwork is compact: the device frame and copy occupy the canvas as one
  dense visual block, with no large empty field around a small phone.
- Every promotional image is available at exactly 1920×1080 and 1080×1920,
  remains below AppGallery's 5 MB limit and contains no private data.
- Evidence records the device serial and model, API version, Mock HAP hash,
  every scene state and the capture result.
- README instructions and product descriptions refer only to the native
  HarmonyOS workspace.
