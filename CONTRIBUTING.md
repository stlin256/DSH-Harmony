# Contributing

Thanks for helping improve DSH Harmony. This repository is a native HarmonyOS
client for DeepSeek Harness plus the companion `@dsh-harmony/plugin`.

## Before you start

- Read [`AGENTS.md`](AGENTS.md) — it defines the required workflow for UI and
  state changes (requirement, research, spec, tests, mock fixtures, device E2E,
  QA gates).
- Read [`docs/VALIDATION.md`](docs/VALIDATION.md) for the current verification
  status and what counts as evidence.
- Read [`docs/NATIVE-COVERAGE.md`](docs/NATIVE-COVERAGE.md) before claiming a
  surface is fully native.

## Issues

- Use the issue forms for bugs and feature requests.
- Questions, setups and "show your build" posts belong in
  [Discussions](https://github.com/stlin256/DSH-Harmony/discussions).
- Never paste tokens, cookies, private host names, signatures or real transcript
  content into issues, discussions, logs or screenshots.

## Pull requests

- Keep the change scoped, and describe the user-visible or behavioral outcome.
- Fill in the pull request template: requirement, spec, tests and evidence.
- Run `node scripts/qa.mjs fast` for documentation-only changes and
  `node scripts/qa.mjs pr` for code changes; keep the QA report path in the PR.
- Shared ArkUI changes must build the `community`, `store` and `mock` variants.
- Device-dependent behavior needs current device evidence or an explicit pending
  status — static tests and mock coverage alone are not device proof.
- Do not include private hosts, credentials, cookies, signatures or transcript
  content in source, tests, docs, logs or commits.

## Licensing

DSH Harmony is licensed under AGPL-3.0. By contributing you agree that your
contribution is provided under the same license.
