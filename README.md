# uaRO on Apple Silicon, via CrossOver

**This repo is for an AI coding agent: you hand it the GitHub link, say install uaRO with CrossOver, and the AI reads `SKILL.md` and runs the scripts on your Mac.**

[`SKILL.md`](./SKILL.md) is the execution playbook for Claude Code, OpenAI Codex, or GitHub Copilot. Hand it to an AI agent, say “install uaRO with CrossOver,” and it will run the local checks and stop when you need to provide a file, complete a GUI action, enter a password, log in, or confirm the live game test. The scripts and [`references/`](./references/) directory provide the guarded operations and supporting evidence behind that playbook.

This repository is intentionally separate from the [Whisky workflow](https://github.com/jirukouya/auRO-whisky-macOS-setup). CrossOver bottles, Wine runtime paths, launchers, and overlays use different interfaces and must not be mixed with Whisky commands.

## AzzyAI is now supported

The CrossOver installation skill now includes optional support for **AzzyAI**, a third-party AI that lets your **mercenary** or **homunculus** automatically find and attack nearby monsters.

After a fresh uaRO installation passes the normal live-runtime check, the skill asks whether you also want to install AzzyAI. The normal uaRO installation remains unchanged if you choose **No**.

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
| Map-time raw-input / Gepard error | Run the stock probe first. If it is affected, deploy the matching `wow64win.dll` with Option A (replace the DLL inside CrossOver.app after backing up `.orig`). Option B overlay is only if you refuse to edit the app bundle. | Probe after deploy: `AFFECTED=no` and clobbered entries = 0. Live `lsof` on `uaRO.exe` must show the deployed DLL. |
| First launch / no game window | OpenSetup (`setup.exe`) must run once and write `HKCU\Software\Gravity\RagnarokOnline`. Lua resolution alone is not enough. | Registry key exists; `setup.exe` stayed alive for the GUI. |
| Safe launch route | After Option A, launch `UaRo Patcher.exe` with CrossOver `bin/wine --bottle --workdir --cx-app`. Generated Patcher.app is optional. No Game.app. | `uaRO.exe` alive ≥15s; `verify-live-runtime` `status=pass`; lsof path matches deploy-app. |

This is a Wine compatibility fix, not a Gepard bypass. Wine loads builtin `wow64win.dll` from the directory of the loaded `ntdll.so`. Option A therefore changes `/Applications/CrossOver.app` after a `.orig` backup. Overlay-only copies are ignored if the process still loads stock ntdll.

CrossOver's desktop app already bundles the interfaces used by this workflow, including its `bin/wine` wrapper and `cxbottle` bottle tool. The Skill discovers the actual app and build on the current Mac instead of assuming a path copied from another machine.

## What you must have before the AI starts

- Apple Silicon Mac
- [CrossOver](https://www.codeweavers.com/crossover) **26.3.0** (About can say 26.3 or 26.3.0; internal build `26.3.0.*` is fine)
- uaRO installer zip or folder with `UaRO_Setup.exe`, `UaRO_Setup-1.bin`, `UaRO_Setup-2.bin`
- `gepard-crossover-fix` from uaRO Discord (keep the file named `wow64win.dll.crossover-26.3.0`)

The AI will search Downloads/Documents/Games. If it cannot find those two packages, it will ask you for the paths once.

The raw-input fix **backs up then replaces** `wow64win.dll` inside CrossOver.app. This is a shared application-level change and therefore requires `--confirm-app-change`; review the impact before running it. A CrossOver update can undo that; ask the AI to re-run `deploy-app --confirm-app-change`.

## How to actually run this

Talk to an AI that can run commands on your Mac (Claude Code, ChatGPT/Codex, GitHub Copilot, Grok). **You do not follow the scripts by hand.**

### Desktop app

1. Download Claude, ChatGPT, Copilot, or Grok and sign in.
2. Open a coding session and pick a folder (Documents is fine).
3. Paste:

```text
Fetch SKILL.md from https://github.com/jirukouya/auRO-crossover-macOS-setup and follow it to install uaRO through CrossOver on this Mac. Clone the repo if you are not already in it. Search my Mac for the uaRO installer and gepard-crossover-fix. Start running; only stop when you need a file path, a GUI click, my login, or if CrossOver is the wrong build.
```

### Terminal

Clone the repo, `cd` into it, start `claude` / `codex` / `copilot` / `grok`, and paste the same prompt.

The AI will guide these phases:

| Phase | What it does | What may require you |
|---|---|---|
| 1. Preflight | Checks Apple Silicon, Rosetta, CrossOver, build, disk space, installer, and artifact inputs. | Provide the installer and the matching raw-input candidate package before the stock probe. |
| 2. Bottle and install | Creates or inspects the private bottle and stages the split uaRO installer safely. | Log in to uaRO and complete any installer GUI choices. |
| 3. Patch and configure | Patches the installed `setup.exe`, checks Gecko, and writes the game configuration. | Complete an interactive Gecko step or macOS prompt if requested. |
| 4. Raw-input route | Runs the stock probe. Affected baselines default to Option A (`deploy-app`) into CrossOver.app; overlay is optional. | Supply the gepard-crossover-fix package (keep `wow64win.dll.crossover-26.3.0` as the human name). |
| 5. OpenSetup + launch | Launch patched `setup.exe` until Gravity registry exists, then `launch-patcher`. | In Settings: **2560×1600**, **DirectX 9**, **uncheck Restrict mouse to window**, then OK. Then Patcher Play / login. |

`build-launchers` copies `references/icons/AppIcon.icns` into both `.app` bundles and signs them. Do not hand-edit the bundle to “add an icon”; that breaks codesign and can make Play look dead. The working pattern (confirmed on the maintainer Mac) is: Option A official CrossOver `bin/wine`, keep the `.app` alive while `UaRo Patcher.exe` / `uaRO.exe` run, then `codesign`. Do not `exec` Wine as the bundle executable (Dock bounce with no window) and do not `exit 0` immediately after starting Wine (looks like a crash). Do not use `/Applications/uaRO/` Whisky experiment launchers. No Game.app.

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

While uaRO is running, verify the loaded DLL:

```zsh
scripts/uaro-crossover.zsh verify-live-runtime \
  --bottle uaro-crossover --json
lsof -p "$(pgrep -f 'uaRO.exe' | head -1)" | grep wow64win.dll
```

Option A success: `status=pass` and lsof shows CrossOver.app `wow64win.dll` matching `deploy-app`. Clean baseline: `runtime=stock` and `status=pass`. Overlay-only probe PASS is not enough. Dock “Running in Background” on a generated `.app` is not proof the game is running.

## Installing or fixing AzzyAI

Already installed uaRO through this CrossOver Skill? Ask the AI to install AzzyAI with this prompt:

```text
Read SKILL.md and AZZYAI_FIXES.md in this repository. I already have uaRO installed through CrossOver. Please install and configure AzzyAI for my mercenary or homunculus. Use the verified CrossOver game directory, back up existing AI files before changing them, apply the uaRO targeting fixes, and stop only when I need to do something inside the game. Explain each step in simple language and do not claim success until the AI actually attacks a nearby monster.
```

If AzzyAI is already installed but follows without attacking, use:

```text
Read SKILL.md and AZZYAI_FIXES.md in this repository. AzzyAI is already installed in my CrossOver uaRO setup, but my mercenary or homunculus follows me without attacking. Inspect the verified game directory first, back up every file before editing it, apply all required uaRO targeting fixes, and stop when I need to relog, resummon, or test inside the game. Explain each step simply and do not claim success from file changes alone.
```

The full CrossOver-specific procedure is in [`AZZYAI_FIXES.md`](./AZZYAI_FIXES.md). It handles the `AI/USER_AI` location, backups, `/merai` or `/hoai` activation, and the targeting fixes. The AI cannot perform the in-game activation or the final attack test for you.

## What you’ll need

- An Apple Silicon Mac (`arm64`). The initial workflow is not validated for Intel Macs.
- CrossOver installed locally. This repository does not install or license CrossOver for you.
- CrossOver **26.3.0** (build `26.3.0.*`). The gepard prebuilt DLL is labeled `wow64win.dll.crossover-26.3.0`. Other families (26.2, 26.4, …) are blocked. A non-39832 26.3.0 patch is allowed only if stock and after probes pass; full in-game confirmation on those patch numbers is unconfirmed.
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

**Experimental, public-facing.** Local static/fixture checks pass. One user-confirmed CrossOver run on Apple Silicon used build `26.3.0.39832`. Other `26.3.0.*` builds are accepted by the scripts if probes pass; they are not separately end-to-end confirmed:

- The stock raw-input probe reported `AFFECTED=yes`.
- The overlay after-probe reported `AFFECTED=no` with zero clobbered entries.
- The Patcher opened, login succeeded, a map loaded, and the user did not observe `Gepard::T Code: 3::110::12` on the overlay route.

The observed stock count of `238` clobbered entries and the approximately `869 MB` overlay size belong to that machine and run; they are not universal requirements or expected values.

Still **unconfirmed** are long-duration stability, other CrossOver builds, every possible Gepard failure, and trusted provenance for the community prebuilt DLL. This result is not a universal compatibility guarantee.

The core CrossOver installation has one user-confirmed acceptance run. CrossOver AzzyAI installation and in-game auto-attack still require a separate acceptance run; the documented AzzyAI targeting fixes are based on the tested uaRO/Whisky workflow.

## Changelog

Full history lives in [`CHANGELOG.md`](./CHANGELOG.md). The current Skill version is kept in the front matter of [`SKILL.md`](./SKILL.md), so the README does not maintain a second version number that can go stale.

## Disclaimer

This is unofficial software and runs at your own risk:

- No guarantees are made for uaRO, CrossOver, Gepard, macOS, or future client updates.
- The workflow patches the installed `setup.exe` and may deploy a third-party prebuilt Wine DLL into a private bottle overlay. Backups and hashes are used, but the artifact's source revision, signature, and license are currently **unconfirmed**.
- A CrossOver build update can invalidate the artifact. The Skill intentionally stops rather than applying an old DLL to a new build.
- The overlay does not automatically follow future CrossOver runtime updates and consumes additional disk space.
- The workflow does not collect, transmit, or store uaRO credentials. Account login, installer download, macOS prompts, and final in-game verification remain directly under your control.

## Contributors & Thanks

This CrossOver workflow exists because of the time, testing, and technical work shared by two contributors in the uaRO Discord community:

- **Rhya** — tested the CrossOver setup in practice alongside a5mod3us's fix, confirmed that it could launch and run uaRO, and provided hands-on feedback about performance and macOS quality-of-life behavior. [Original Discord message](https://discord.com/channels/702960460168953946/1463912027461386424/1538344442103070761)
- **a5mod3us** — investigated the root cause of `Gepard::T Code: 3::110::12`, identified the Wine raw-input bug, and shared the patch, detector probe, and CrossOver 26.3.0 `wow64win.dll` artifact that made this workflow possible. [Original Discord message](https://discord.com/channels/702960460168953946/1463912027461386424/1538224136776589332)

Thank you both for sharing your research, fixes, and testing time with the uaRO community. This repository builds on that work and is intended to acknowledge it clearly.

## Acknowledgments

- The uaRO community members who investigated the CrossOver raw-input issue and shared the probe, source patch, OpenSetup patcher, and experimental build-specific artifact.
- CodeWeavers for the CrossOver bottle and bundled Wine interfaces.
- The [Whisky uaRO workflow](https://github.com/jirukouya/auRO-whisky-macOS-setup), which provides the structural reference for this AI-executable documentation. Its runtime commands and paths are not used here.

## License

[`MIT`](./LICENSE) — free to use, modify, and share; provided as-is, with no warranty. uaRO files, CrossOver files, and third-party Wine artifacts remain subject to their own licenses and are not included by default.
