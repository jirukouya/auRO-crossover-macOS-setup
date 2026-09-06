---
name: auro-crossover-macos-setup
version: 0.2.0-experimental
description: Install, repair, verify, or uninstall uaRO on Apple Silicon macOS using CodeWeavers CrossOver's bundled CLI and private bottles. Use this skill whenever the user mentions uaRO with CrossOver, CrossOver bottles, CrossOver Wine, Gepard T Code 3::110::12 on CrossOver, wow64win.dll, or asks for a fully automated CrossOver setup. Do not use it for Whisky-only installations.
compatibility: Apple Silicon macOS; initial tested target CrossOver 26.3.0.39832; requires zsh, Python 3, CrossOver, and a user-supplied uaRO installer.
---

# uaRO on macOS via CrossOver

This is a CrossOver-only workflow. Read the repository README and relevant reference before changing state. CrossOver's bundled `bin/wine` and `cxbottle` are the runtime interfaces; do not substitute another Wine manager's commands.

## Fast routing and problem separation

- A Whisky-only request belongs to `auro-whisky-macos-setup`; do not trigger this Skill.
- A CrossOver request, `Gepard`, `T Code 3::110::12`, or `wow64win.dll` request belongs here.
- If uaRO is already running, inspect the live runtime route before changing files. A game window alone does not prove that the overlay was loaded.
- Keep these chains separate: installer (`UaRO_Setup.exe` and `.bin` files), Settings (`setup.exe` and OpenSetup/FCOM), and map-time Gepard errors (raw-input Wine bug, DLL overlay, and launch route).

## Operating rules

1. Run `scripts/uaro-crossover.zsh preflight` first on every machine.
2. Resolve the actual CrossOver app, complete build, bottle, game directory, and artifact hashes. Never use a path copied from another machine.
3. Treat the prefilled history in any draft document as evidence from another environment, not as the current machine's state.
4. Stop on unknown bytes, missing files, build mismatches, failed probes, or incomplete verification.
5. Keep uaRO credentials and user data outside this repository.
6. Post the current phase, command result, and next single action after each state-changing phase. Pause before the next phase when a human choice or GUI interaction is required.
7. After an overlay exists, only `UaRO CrossOver Patcher.app` is a supported game launch route. The CrossOver UI shortcut may bypass the overlay.

## What is and is not automated

Automated: CrossOver discovery, version/build checks, Rosetta preflight, bottle creation, installer staging, context-checked OpenSetup patches, game configuration, raw-input probe/overlay validation, launcher generation, diagnostics, state recording, and scoped rollback.

Human-controlled: uaRO account authentication and download, installer GUI choices if the build requires them, first game login, map-load confirmation, and any macOS admin/password prompt. The skill must never capture or store these credentials.

## Phase A — Preflight

Run one of these, with exactly one installer input:

```zsh
scripts/uaro-crossover.zsh preflight --bottle uaro-crossover \
  --installer-zip "/path/to/UaRO_Setup.zip" \
  --rawinput-source-dir "/path/to/gepard-crossover-fix"
# or: --installer-dir "$HOME/Games/UaRO-Installer"
```

Require:

- `arm64` host and an executable Rosetta translation path;
- one unambiguous CrossOver installation;
- supported public version and exact build (`26.3.0.39832` for this draft);
- the CrossOver `bin/wine` wrapper and `cxbottle` CLI;
- enough free space;
- the exact three installer siblings; for a ZIP, validate its member list and compressed data before use;
- a bottle name and game directory that do not overlap another installation.

If two CrossOver app bundles exist with different builds, stop and ask the user to choose. If the build is unsupported, do not use a prebuilt DLL. `--rawinput-source-dir` validates the candidate package but does not install it.

The package can then be imported into a non-iCloud cache:

```zsh
scripts/uaro-crossover.zsh artifact import \
  --source-dir "/path/to/gepard-crossover-fix" \
  --cache-dir "$HOME/Games/UaRO-CrossOver-artifacts" \
  --crossover-build 26.3.0.39832
```

The importer validates x86-64 PE32+ `wow64win.dll`, x86 PE32 probe, the exact `*count` to `ret` source patch, hashes, and known package members. The community prebuilt's source revision, signature, and redistribution license remain `unconfirmed`.

## Phase B — Bottle and installer

Create or inspect the private bottle:

```zsh
scripts/uaro-crossover.zsh bottle create --bottle uaro-crossover
scripts/uaro-crossover.zsh bottle status --bottle uaro-crossover
```

Stage and launch the installer through CrossOver's `wine --bottle ... --cx-app` wrapper. The installer is a split Inno Setup bundle and must contain, with exact names, `UaRO_Setup.exe`, `UaRO_Setup-1.bin`, and `UaRO_Setup-2.bin`. ZIP input is copied, never moved, to `~/Games/UaRO-Installer/` and streamed into the bottle with temporary `.part` files; do not use `ditto` for this multi-gigabyte archive. Confirm the resulting `uaRO.exe`, `UaRo Patcher.exe`, and `setup.exe` paths inside the selected bottle before continuing.

## Phase C — Game patch and configuration

`UaRO_Setup.exe` is the installer. The `setup.exe` below the installed game directory is OpenSetup. Never pass the installer to the patcher.

Use `scripts/patch-setup.py` for the hash-locked `gepard-crossover-26.3.0` profile. It records the full input hash, backs up first, checks all three sites, changes only the expected bytes, atomically replaces the file, and requires the registered patched hash. The profile uses `0x21E39: DC D8 -> D8 D8`, `0x2C0CD: DC D0 -> D8 D0`, and `0x43C08: mss32.dll -> mss32.off`. The older four-byte Site B variant is fixture-only and is not mixed with this profile.

Run `scripts/uaro-crossover.zsh check-gecko --bottle uaro-crossover` after installation. It checks the CrossOver-bundled Gecko payload and the selected bottle's actual prefix marker. If the payload exists but the bottle marker is absent, stop and launch the Patcher once for the user's interactive Gecko install; do not download an unknown runtime.

Use `scripts/configure-game.py` for `dinput.ini` and `savedata/OptionInfo.lua`. It preserves backups, writes explicit windowed settings, and verifies the raw device-name bytes. Resolution remains provisional until the CrossOver settings path and a real on-screen result are confirmed.

Keyboard mapping is optional and CrossOver-specific:

```zsh
scripts/uaro-crossover.zsh configure-keyboard --bottle uaro-crossover
```

The command stops the selected bottle's Wine server, writes and reads back `LeftCommandIsCtrl`, `RightCommandIsCtrl`, `LeftOptionIsAlt`, and `RightOptionIsAlt` under `HKCU\Software\Wine\Mac Driver`. Whether `Option` behaves as the game's Alt key remains unconfirmed until a real game interaction test.

## Phase D — Raw-input overlay

The `Gepard::T Code: 3::110::12` fix is a Wine compatibility fix, not an anti-cheat bypass. Run the stock probe first. A prebuilt artifact is valid only when its manifest matches the exact CrossOver build and the source/runtime hashes.

```zsh
scripts/uaro-crossover.zsh overlay probe --bottle uaro-crossover --artifact-dir "$HOME/Games/UaRO-CrossOver-artifacts"
scripts/uaro-crossover.zsh overlay build --bottle uaro-crossover --artifact-dir "$HOME/Games/UaRO-CrossOver-artifacts"
scripts/uaro-crossover.zsh overlay verify --bottle uaro-crossover --artifact-dir "$HOME/Games/UaRO-CrossOver-artifacts"
```

The stock probe is semantic: an affected probe may return a non-zero guest exit, and its output still records the baseline. Deployment is allowed only when stock says `AFFECTED=yes`, the artifact manifest exactly matches the CrossOver build, and the artifact hashes/source patch pass. The per-bottle overlay copies the current machine's `ntdll.so` plus `bin`, `lib/wine`, `lib/perl`, optional `lib64`, and `share`; it never trusts or installs an external `ntdll.so`. It is built in a temporary directory and atomically renamed. Success requires after-probe `AFFECTED=no` and zero clobbered entries; `238` is not a universal expected count. Use probe output, `WINEDEBUG=+loaddll`, the overlay anchor, and its manifest rather than relying on `lsof` to display a mapped PE DLL.

If the artifact directory is missing, incomplete, unsigned where signing is required, or built for another CrossOver build, stop without creating a launcher. If no trusted prebuilt exists, `scripts/build-rawinput-artifact.zsh` provides the source-build fallback, but it requires the user to supply and hash the official CrossOver source archive plus the needed x86 build tools; it does not install Homebrew packages automatically.

## Phase E — Launchers and verification

Generate only:

- `UaRO CrossOver Patcher.app`
- `UaRO CrossOver Settings.app`

The optional direct `Game.app` is intentionally excluded from the draft because it skips update checks. Launchers must use CrossOver paths, set the selected bottle and working directory, pass syntax/plist/signature checks, and be tested with the real Patcher. Do not claim completion until patcher startup, user login, and map load all pass.

While the game is running, verify the actual loaded runtime:

```zsh
scripts/uaro-crossover.zsh verify-live-runtime \
  --bottle uaro-crossover --json
```

The required result is `runtime=overlay` and `status=pass`, with both `ntdll.so` and `wow64win.dll` anchored under the per-bottle overlay. `runtime=stock` or `runtime=mixed` is a hard stop: close uaRO and relaunch through `UaRO CrossOver Patcher.app`. No running process is reported as `not_running`, not as a failed DLL test.

For a reported error, use the decision-oriented diagnostic command first:

```zsh
scripts/uaro-crossover.zsh diagnose \
  --bottle uaro-crossover --error "Gepard::T Code: 3::110::12"
```

It checks the process route, runtime anchor, last probe, overlay, and OpenSetup state before suggesting the next action. Do not immediately replace a game DLL for this T-code.

## Repair and uninstall

```zsh
scripts/uaro-crossover.zsh repair --bottle uaro-crossover
scripts/uaro-crossover.zsh uninstall --bottle uaro-crossover --level game --confirm
```

Repair is diagnostic first and only fixes scoped launcher mechanics. Uninstall requires an explicit level, backs up `savedata`, and never removes CrossOver itself by default.

## Evidence labels

Use `已确认` for direct local output, `根据证据推导` for a reasoned conclusion, `未确认` for a claim not tested on this machine, `来源冲突` when documents disagree, and `被阻断` when a required artifact or human action is missing.

The current local evidence is one user-confirmed end-to-end run on Apple Silicon with CrossOver `26.3.0.39832`: stock probe `AFFECTED=yes` with 238 clobbered entries; overlay after-probe `AFFECTED=no` with zero; Patcher login and map load succeeded without the T-code. This does not establish universal CrossOver compatibility, long-duration stability, or trusted community-artifact provenance.
