---
name: auro-crossover-macos-setup
version: 0.1.0-draft
description: Install, repair, verify, or uninstall uaRO on Apple Silicon macOS using CodeWeavers CrossOver's bundled CLI and private bottles. Use this skill whenever the user mentions uaRO with CrossOver, CrossOver bottles, CrossOver Wine, Gepard T Code 3::110::12 on CrossOver, wow64win.dll, or asks for a fully automated CrossOver setup. Do not use it for Whisky-only installations.
compatibility: Apple Silicon macOS; initial tested target CrossOver 26.3.0.39832; requires zsh, Python 3, CrossOver, and a user-supplied uaRO installer.
---

# uaRO on macOS via CrossOver

This is a CrossOver-only workflow. Read the repository README and relevant reference before changing state. CrossOver's bundled `bin/wine` and `cxbottle` are the runtime interfaces; do not substitute another Wine manager's commands.

## Operating rules

1. Run `scripts/uaro-crossover.zsh preflight` first on every machine.
2. Resolve the actual CrossOver app, complete build, bottle, game directory, and artifact hashes. Never use a path copied from another machine.
3. Treat the prefilled history in any draft document as evidence from another environment, not as the current machine's state.
4. Stop on unknown bytes, missing files, build mismatches, failed probes, or incomplete verification.
5. Keep uaRO credentials and user data outside this repository.
6. Post the current phase, command result, and next single action after each state-changing phase. Pause before the next phase when a human choice or GUI interaction is required.

## What is and is not automated

Automated: CrossOver discovery, version/build checks, Rosetta preflight, bottle creation, installer staging, context-checked OpenSetup patches, game configuration, raw-input probe/overlay validation, launcher generation, diagnostics, state recording, and scoped rollback.

Human-controlled: uaRO account authentication and download, installer GUI choices if the build requires them, first game login, map-load confirmation, and any macOS admin/password prompt. The skill must never capture or store these credentials.

## Phase A — Preflight

Run:

```zsh
scripts/uaro-crossover.zsh preflight --bottle uaro-crossover --installer-dir "$HOME/Games/UaRO-Installer"
```

Require:

- `arm64` host and an executable Rosetta translation path;
- one unambiguous CrossOver installation;
- supported public version and exact build (`26.3.0.39832` for this draft);
- the CrossOver `bin/wine` wrapper and `cxbottle` CLI;
- enough free space;
- three installer siblings with stable sizes and recorded SHA-256 values;
- a bottle name and game directory that do not overlap another installation.

If two CrossOver app bundles exist with different builds, stop and ask the user to choose. If the build is unsupported, do not use a prebuilt DLL.

## Phase B — Bottle and installer

Create or inspect the private bottle:

```zsh
scripts/uaro-crossover.zsh bottle create --bottle uaro-crossover
scripts/uaro-crossover.zsh bottle status --bottle uaro-crossover
```

Stage and launch the installer through CrossOver's `wine --bottle ... --cx-app` wrapper. The installer is a split Inno Setup bundle and must contain, with exact names, `UaRO_Setup.exe`, `UaRO_Setup-1.bin`, and `UaRO_Setup-2.bin`. Confirm the resulting `uaRO.exe`, `UaRo Patcher.exe`, and `setup.exe` paths inside the selected bottle before continuing.

## Phase C — Game patch and configuration

Use `scripts/patch-setup.py` for the three known OpenSetup sites. It backs up first, checks original or already-patched bytes, changes only the expected bytes, and verifies a byte-for-byte diff. Site C is the string patch at `0x43C08`, `mss32.dll` to `mss32.off`; if its original bytes are not present, stop.

Use `scripts/configure-game.py` for `dinput.ini` and `savedata/OptionInfo.lua`. It preserves backups, writes explicit windowed settings, and verifies the raw device-name bytes. Resolution remains provisional until the CrossOver settings path and a real on-screen result are confirmed.

## Phase D — Raw-input overlay

The `Gepard::T Code: 3::110::12` fix is a Wine compatibility fix, not an anti-cheat bypass. Run the stock probe first. A prebuilt artifact is valid only when its manifest matches the exact CrossOver build and the source/runtime hashes.

```zsh
scripts/uaro-crossover.zsh overlay probe --bottle uaro-crossover --artifact-dir "$HOME/Games/UaRO-CrossOver-artifacts"
scripts/uaro-crossover.zsh overlay build --bottle uaro-crossover --artifact-dir "$HOME/Games/UaRO-CrossOver-artifacts"
scripts/uaro-crossover.zsh overlay verify --bottle uaro-crossover --artifact-dir "$HOME/Games/UaRO-CrossOver-artifacts"
```

The overlay is per-bottle and must not replace files inside the CrossOver app. It must contain a matching patched `wow64win.dll`, the matching `ntdll.so` when required by the artifact, and the runtime support files declared by its manifest. Success requires `AFFECTED=no` and zero clobbered entries; `238` is not a universal expected count. Use probe output and `WINEDEBUG=+loaddll` evidence rather than relying on `lsof` to display a mapped PE DLL.

If the artifact directory is missing, incomplete, unsigned where signing is required, or built for another CrossOver build, stop without creating a launcher.

## Phase E — Launchers and verification

Generate only:

- `UaRO CrossOver Patcher.app`
- `UaRO CrossOver Settings.app`

The optional direct `Game.app` is intentionally excluded from the draft because it skips update checks. Launchers must use CrossOver paths, set the selected bottle and working directory, pass syntax/plist/signature checks, and be tested with the real Patcher. Do not claim completion until patcher startup, user login, and map load all pass.

## Repair and uninstall

```zsh
scripts/uaro-crossover.zsh repair --bottle uaro-crossover
scripts/uaro-crossover.zsh uninstall --bottle uaro-crossover --level game --confirm
```

Repair is diagnostic first and only fixes scoped launcher mechanics. Uninstall requires an explicit level, backs up `savedata`, and never removes CrossOver itself by default.

## Evidence labels

Use `已确认` for direct local output, `根据证据推导` for a reasoned conclusion, `未确认` for a claim not tested on this machine, `来源冲突` when documents disagree, and `被阻断` when a required artifact or human action is missing.
