# Changelog

## [Unreleased]

- Added a fresh-session execution contract with explicit repository-reference loading, variable-ledger rules, pre-flight JSON field mapping, bottle discovery, and fresh/existing/verify/repair route selection.
- Clarified that the Patcher is the client-update entry point, Gecko may require an interactive bottle marker step, and generic repair only audits or repairs generated launchers.
- Reorganized the CrossOver Skill around fresh-session routing, a numbered progress table, and explicit Phase A–E gates modeled on the mature Whisky workflow.
- Documented the candidate-artifact prerequisite for the stock probe, the clean-stock branch with no overlay, and the distinction between diagnostic repair and `repair --fix`.
- Allowed launcher creation and live verification to use stock CrossOver Wine when the recorded baseline is clean, while keeping stock/mixed routes blocked after an affected baseline.
- Implemented the 0.2.0 experimental artifact-import flow, schema-2 manifests, PE/source-patch validation, and a source-build fallback path.
- Replaced byte-only OpenSetup patching with the hash-locked `gepard-crossover-26.3.0` profile; the older four-byte Site B variant is no longer production code.
- Made raw-input probe exit status semantic, copied CrossOver `lib/perl`/optional `lib64`, anchored overlay `ntdll.so` to the local runtime, and made overlay creation atomic.
- Kept community prebuilt DLLs outside Git and marked their provenance unconfirmed; no CrossOver app files, installer, savedata, or credentials are included.
- Initial CrossOver-first repository and Skill skeleton.
- Added CrossOver path/build discovery, bottle operations, installer staging, fail-closed OpenSetup patching, game configuration, overlay contracts, launcher validation, repair, rollback, and fixture tests.
- Added exact three-member ZIP validation, non-iCloud installer caching, streaming staging, installer hash/member state, and a CrossOver Gecko check gate.
- Deliberately excluded uaRO installers, credentials, savedata, and unverified Wine binaries.
- Recorded the first local user-confirmed CrossOver end-to-end run and added a live runtime-route gate so a stock CrossOver shortcut cannot be mistaken for an overlay launch.

## [0.2.0-experimental] - 2026-09-06

- One local Patcher, login, and map-load run is user-confirmed; the release remains experimental because community DLL provenance and broader build compatibility are unconfirmed.

## [0.1.0-draft] - 2026-09-06

- Drafted the first implementation target for CrossOver `26.3.0.39832` on Apple Silicon.
- End-to-end uaRO installation and raw-input overlay remain unverified until tested on a disposable bottle with matching artifacts.
