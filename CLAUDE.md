# Project knowledge map

This repository is CrossOver-first and must not inherit executable Whisky commands.

## Sources of truth

1. `git log` and `git notes` for implementation history.
2. `CHANGELOG.md` for release-level changes.
3. `SKILL.md`, `references/`, and test fixtures for current behavior and verification.
4. External Discord or local draft material is evidence only until reproduced here.

## Safety constraints

- Do not commit uaRO installers, savedata, credentials, or source-uncertain binaries.
- Do not modify the existing `auRO-whisky-macOS-setup` repository from this project.
- Option A may patch `/Applications/CrossOver.app` only after the user explicitly confirms the shared-app change; `deploy-app` must verify the matching artifact/build, preserve `wow64win.dll.orig`, and require `--confirm-app-change`.
- Option B is the no-shared-app-change fallback: the current repository uses a complete per-bottle overlay and its generated launchers' overlay `bin/wine`; do not describe this route as a `cxbottle.conf` BinPath/LibPath mutation unless the implementation and tests are changed first.
- Any unsupported CrossOver build must stop before raw-input artifact deployment.
- Any binary mutation must have an expected-byte precondition, a backup, a narrow diff, and an idempotence test.

## Verification status

The scripts and fixtures are locally testable. The repository records separate runtime evidence: a 2026-09-06 overlay route reached the map without an observed T-code, while a later 2026-09-18 Option A run confirmed uaRO startup with the patched CrossOver.app DLL loaded; map-time T-code absence was not separately reconfirmed on the later run. CrossOver AzzyAI installation, activation, and in-game auto-attack remain unconfirmed until a separate acceptance run records them.
