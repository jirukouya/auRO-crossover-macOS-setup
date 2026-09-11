# uaRO on Apple Silicon, via CrossOver

**This repo gives an AI coding agent a guarded workflow that installs, repairs, verifies, and uninstalls the uaRO Windows game on your Mac through CrossOver.**

[`SKILL.md`](./SKILL.md) is the execution playbook for Claude Code, OpenAI Codex, or GitHub Copilot. Hand it to an AI agent, say “install uaRO with CrossOver,” and it will run the local checks and stop when you need to provide a file, complete a GUI action, enter a password, log in, or confirm the live game test. The scripts and [`references/`](./references/) directory provide the guarded operations and supporting evidence behind that playbook.

This repository is intentionally separate from the [Whisky workflow](https://github.com/jirukouya/auRO-whisky-macOS-setup). CrossOver bottles, Wine runtime paths, launchers, and overlays use different interfaces and must not be mixed with Whisky commands.

## The problem this solves

[uaRO](https://uaro.net/) is a Windows-only Ragnarok Online private server protected by **Gepard Shield 3.0**. CrossOver can run the client on Apple Silicon, but the stock Wine runtime can mishandle the client's raw-input device list. After a map loads, that Wine-side problem can surface as:

```text
Gepard::T Code: 3::110::12
```

That message is not automatically proof of a uaRO server or account problem. It can be caused by the compatibility layer returning or copying raw-input data incorrectly.

Fresh installs have a separate issue: the installed game's Settings program may need a registered Rosetta/OpenSetup patch before it runs reliably. The names are easy to confuse:

- `UaRO_Setup.exe` is the installer.
- `setup.exe` inside the installed game directory is OpenSetup / Settings.

The patch targets the installed `setup.exe`, never the installer.

## The CrossOver fix

The workflow keeps the two problems separate and verifies each one independently:

| Problem | Workflow | Required proof |
|---|---|---|
| Installer or Settings crash | Apply the hash-locked three-site patch to the installed `setup.exe`, then check Gecko in the selected bottle. | The file hash matches a registered profile and the bottle passes the Gecko gate. |
| Map-time raw-input / Gepard error | Run the stock probe first. If it is affected, validate a matching artifact and build a private per-bottle overlay; if it is clean, keep the CrossOver stock runtime. | Clean branch: `AFFECTED=no` with `CLOBBERED=0`. Overlay branch: the after-probe reports the same clean result. |
| Safe launch route | Use the generated `UaRO CrossOver Patcher.app`; the clean branch may use stock Wine, while the affected branch must use the verified overlay. | Live runtime verification reports `status=pass` with `runtime=stock` for a clean baseline or `runtime=overlay` for an affected baseline. |

This is a Wine compatibility fix, not a Gepard bypass. The overlay uses the current CrossOver support files and local `ntdll.so` together with a matching patched `wow64win.dll`; it does not modify `/Applications/CrossOver.app` or install an external `ntdll.so`.

CrossOver's desktop app already bundles the interfaces used by this workflow, including its `bin/wine` wrapper and `cxbottle` bottle tool. The Skill discovers the actual app and build on the current Mac instead of assuming a path copied from another machine.

## How to actually run this

You drive this by talking to an AI. Open this repository as the working folder in a local coding session, then use one of the following paths.

For a fresh AI session, provide the repository rather than copying `SKILL.md` alone. The AI should read the Skill, this README, `references/crossover-cli.md`, and `references/state-schema.md`, then run the relevant script's `--help` and pre-flight before it creates or changes a bottle. The Skill maps pre-flight JSON into an explicit variable ledger, so missing installer, artifact, bottle, or CrossOver state is reported as a gate instead of being guessed.

### Option A — Desktop app (recommended)

Use Claude Code, ChatGPT/Codex, or GitHub Copilot and paste:

```text
Read SKILL.md in this repository and install uaRO through CrossOver on this Mac. Use the supplied installer and the matching gepard-crossover-fix candidate package required by the stock probe. Stop after each phase, show the progress table, and do not launch the game until I approve the live test.
```

The AI will guide the following phases:

| Phase | What it does | What may require you |
|---|---|---|
| 1. Preflight | Checks Apple Silicon, Rosetta, CrossOver, build, disk space, installer, and artifact inputs. | Provide the installer and the matching raw-input candidate package before the stock probe. |
| 2. Bottle and install | Creates or inspects the private bottle and stages the split uaRO installer safely. | Log in to uaRO and complete any installer GUI choices. |
| 3. Patch and configure | Patches the installed `setup.exe`, checks Gecko, and writes the game configuration. | Complete an interactive Gecko step or macOS prompt if requested. |
| 4. Raw-input route | Runs the stock probe with the candidate package. Affected baselines get a build-matched overlay and after-probe; clean baselines stay on stock Wine. | Supply or rebuild the artifact before probing if it is missing; deployment is still gated by `AFFECTED=yes`. |
| 5. Launch and verify | Builds the supported Patcher and Settings launchers and verifies the actual loaded runtime. | Log in and confirm that a character can enter a map. |

The default draft generates `UaRO CrossOver Patcher.app` and `UaRO CrossOver Settings.app`. It does not generate a direct Game launcher because that route can skip the patcher's update check.

### Option B — Terminal

From the repository root, start with preflight and provide exactly one installer input:

```zsh
scripts/uaro-crossover.zsh preflight \
  --bottle uaro-crossover \
  --installer-zip "/path/to/UaRO_Setup.zip"
```

The installer can also be an already staged directory containing exactly these three files:

```text
UaRO_Setup.exe
UaRO_Setup-1.bin
UaRO_Setup-2.bin
```

Import the matching candidate package into a non-iCloud cache before running the stock probe. The current probe validates the package even when the final result is clean; its patched DLL is deployed only when the probe reports `AFFECTED=yes`:

```zsh
scripts/uaro-crossover.zsh artifact import \
  --source-dir "/path/to/gepard-crossover-fix" \
  --cache-dir "$HOME/Games/UaRO-CrossOver-artifacts" \
  --crossover-build 26.3.0.39832 \
  --crossover-public-version 26.3.0
```

Do not skip the phase gates or substitute Whisky commands. The complete bottle, installer, patch, Gecko, configuration, overlay, launcher, and live-runtime sequence is defined in [`SKILL.md`](./SKILL.md).

The workflow preserves the original installer and streams its members into the bottle; it does not commit the installer, artifact, savedata, or credentials to GitHub.

## Updating an existing install

Already installed uaRO through CrossOver? Hand the AI this repository and ask:

```text
Read SKILL.md in this repository. I already have uaRO installed in CrossOver. Inspect the current bottle, setup.exe profile, Gecko, raw-input artifact, overlay, and launcher route. Apply only missing or outdated fixes, and do not reinstall the game unless verification proves it is necessary.
```

If the symptom is `Gepard::T Code: 3::110::12`, diagnose the live route first:

```zsh
scripts/uaro-crossover.zsh diagnose \
  --bottle uaro-crossover \
  --error "Gepard::T Code: 3::110::12"
```

While uaRO is running, verify that the process actually loaded the overlay:

```zsh
scripts/uaro-crossover.zsh verify-live-runtime \
  --bottle uaro-crossover --json
```

For an affected baseline, the required result is `runtime=overlay` and `status=pass`. For a clean baseline, the required result is `runtime=stock` and `status=pass`. A working game window alone is not enough. After an overlay has been built, do not use the uaRO shortcut inside the CrossOver UI; that route can load the stock runtime and reproduce the error.

## What you’ll need

- An Apple Silicon Mac (`arm64`). The initial workflow is not validated for Intel Macs.
- CrossOver installed locally. This repository does not install or license CrossOver for you.
- CrossOver build `26.3.0.39832` for the current prebuilt artifact path. Other builds are blocked unless a matching artifact is obtained or rebuilt and verified.
- A uaRO account and a locally downloaded installer ZIP or staged installer directory. The account login and download remain human-driven.
- A matching `gepard-crossover-fix` candidate package is required to run the current stock probe. Its patched DLL is deployed only if the probe reports `AFFECTED=yes`; its community prebuilt source revision, binary signature, and redistribution license are currently **unconfirmed**.
- Enough free space for the installer cache, bottle, backups, and per-bottle overlay. Exact future sizes vary by CrossOver build and installed files.
- Time to handle the human-controlled steps: account login, installer GUI, Gecko if requested, macOS prompts, first game login, and map-load confirmation.

If no candidate package is available, the current toolchain cannot run the baseline probe and stops before making a runtime choice. If a probe later reports `AFFECTED=yes`, deployment still stops unless the package passes the exact build, source, and hash gates. An advanced source-build fallback exists, but it still requires an official CrossOver source archive, a verified source hash, and the required build tools.

## Uninstalling

Ask the AI to use the scoped CrossOver uninstall flow:

```zsh
scripts/uaro-crossover.zsh uninstall \
  --bottle uaro-crossover \
  --level game \
  --game-dir "/path/to/installed/uaRO" \
  --confirm
```

The scoped game level keeps CrossOver and unrelated bottles. The workflow backs up savedata where applicable, moves the selected game directory and generated launchers to the macOS Trash, and avoids broad deletion by default. Removing the CrossOver application itself requires choosing a broader level explicitly.

## Status

**Private / experimental.** The current draft has passed local static and fixture checks, plus one user-confirmed CrossOver run on Apple Silicon with CrossOver `26.3.0.39832`:

- The stock raw-input probe reported `AFFECTED=yes`.
- The overlay after-probe reported `AFFECTED=no` with zero clobbered entries.
- The Patcher opened, login succeeded, a map loaded, and the user did not observe `Gepard::T Code: 3::110::12` on the overlay route.

The observed stock count of `238` clobbered entries and the approximately `869 MB` overlay size belong to that machine and run; they are not universal requirements or expected values.

Still **unconfirmed** are long-duration stability, other CrossOver builds, every possible Gepard failure, and trusted provenance for the community prebuilt DLL. This result is not a universal compatibility guarantee.

## Changelog

Full history lives in [`CHANGELOG.md`](./CHANGELOG.md). The current Skill version is kept in the front matter of [`SKILL.md`](./SKILL.md), so the README does not maintain a second version number that can go stale.

## Disclaimer

This is unofficial software and runs at your own risk:

- No guarantees are made for uaRO, CrossOver, Gepard, macOS, or future client updates.
- The workflow patches the installed `setup.exe` and may deploy a third-party prebuilt Wine DLL into a private bottle overlay. Backups and hashes are used, but the artifact's source revision, signature, and license are currently **unconfirmed**.
- A CrossOver build update can invalidate the artifact. The Skill intentionally stops rather than applying an old DLL to a new build.
- The overlay does not automatically follow future CrossOver runtime updates and consumes additional disk space.
- The workflow does not collect, transmit, or store uaRO credentials. Account login, installer download, macOS prompts, and final in-game verification remain directly under your control.

## Acknowledgments

- The uaRO community members who investigated the CrossOver raw-input issue and shared the probe, source patch, OpenSetup patcher, and experimental build-specific artifact.
- CodeWeavers for the CrossOver bottle and bundled Wine interfaces.
- The [Whisky uaRO workflow](https://github.com/jirukouya/auRO-whisky-macOS-setup), which provides the structural reference for this AI-executable documentation. Its runtime commands and paths are not used here.

## License

[`MIT`](./LICENSE) — free to use, modify, and share; provided as-is, with no warranty. uaRO files, CrossOver files, and third-party Wine artifacts remain subject to their own licenses and are not included by default.
