# Store showcase refresh

Date: 2026-11-04

## Goal

Refresh the generated store artwork and README so the product reads like a
finished, calm development tool rather than an internal QA fixture. The
showcase must continue to come from deterministic Mock data and a connected
HarmonyOS device.

## Product requirements

- Use several credible work scenarios instead of repeating one release
  checklist across every image.
- Keep conversation, process, plan/subagent, file preview, permission, settings,
  automation, plugins, cards and open-source surfaces represented.
- Populate every list used in the artwork with enough realistic rows to show
  density and scanning behavior. Empty or one-row lists are not acceptable as
  marketing states.
- Portrait artwork must use comfortably readable type, keep the device clear of
  the footer, and preserve a dedicated bottom text band.
- Landscape and portrait artwork must remain exactly 1920x1080 and 1080x1920,
  respectively.
- Keep the screenshot path automated: capture on device, compose with the
  checked-in Python script, validate dimensions/size, and write a manifest.
- README copy must describe the shipped product in release voice. Do not frame
  the change as a changelog, beta note or incremental update.

## Out of scope

- New production UI surfaces.
- Remote content, real accounts, private origins or real transcript data.
- Manual image editing as the normal release path.
