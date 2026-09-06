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
- Do not patch `/Applications/CrossOver.app`; use a per-bottle overlay.
- Any unsupported CrossOver build must stop before raw-input artifact deployment.
- Any binary mutation must have an expected-byte precondition, a backup, a narrow diff, and an idempotence test.

## Verification status

The scripts and fixtures are locally testable. Real CrossOver bottle creation, uaRO installer execution, raw-input overlay deployment, account login, and map load are not claimed until a dedicated acceptance run records them.
