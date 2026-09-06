# uaRO on Apple Silicon, via CrossOver

**This repo is one file that installs and repairs the uaRO Windows game on your Mac by talking to an AI, not by reading instructions yourself.**

[`SKILL.md`](./SKILL.md) is a self-contained playbook written *for an AI coding agent* (Claude Code, OpenAI Codex, or GitHub Copilot) to read and execute. Hand it the file, say “install uaRO with CrossOver,” and it drives the local setup while stopping at the steps that require you personally. This repository is intentionally separate from the Whisky workflow because CrossOver has its own bottle, runtime, and launcher interfaces.

## The problem this solves

[uaRO](https://uaro.net/) (a Ragnarok Online private server) is a Windows-only game protected by **Gepard Shield 3.0**. On Apple Silicon, CrossOver can run the client, but the stock Wine compatibility layer may mishandle the 32-bit raw-input device list:

- the client can ask for a buffer larger than the number of devices actually returned;
- an affected WoW64 thunk may copy entries past the returned count;
- the overwritten client state can later surface as `Gepard::T Code: 3::110::12` after a map loads;
- the error is therefore not necessarily a uaRO server or account problem.

This is a Wine-side compatibility issue. The repository does not bypass Gepard or modify the anti-cheat. It uses a user-supplied, build-matched `wow64win.dll` in a per-bottle overlay and proves the result with a stock probe and an after-probe.

Fresh installs have a separate Rosetta/OpenSetup issue: the installed `setup.exe` may need the registered three-site FCOM/Miles patch before the Settings program can run reliably. `UaRO_Setup.exe` is the installer and must never be confused with the installed game's `setup.exe`.

## What makes the CrossOver path different

CrossOver does not require a separate “CrossOver CLI edition.” The desktop app bundles the interfaces used by this workflow:

- `Contents/SharedSupport/CrossOver/bin/wine` runs Windows programs with `--bottle`, `--cx-app`, and `--workdir`.
- `Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/cxbottle` creates and manages bottles.

The workflow creates a per-bottle overlay containing the local CrossOver support files, the local `ntdll.so`, and the matching patched `wow64win.dll`. It does **not** modify `/Applications/CrossOver.app` and does **not** install an external `ntdll.so`.

The initial verified target is:

- Apple Silicon (`arm64`);
- CrossOver `26.3.0.39832`;
- a user-supplied uaRO installer ZIP or staged installer directory;
- a separately supplied schema-2 raw-input artifact when the stock probe reports the bug.

## How to actually run this

You drive this by talking to an AI — through its desktop app or command-line tool. The AI must have access to this repository and must read [`SKILL.md`](./SKILL.md) before changing the CrossOver bottle.

### Option A — Desktop app

Use Claude Code, ChatGPT/Codex, or GitHub Copilot in a local coding session. Open this repository as the working folder and paste:

```text
Read SKILL.md in this repository and install uaRO through CrossOver on this Mac. Use the supplied installer and the local gepard-crossover-fix artifact if available. Stop after each phase, show the progress table, and do not launch the game until I approve the live test.
```

The workflow can create bottles, stage the split installer, patch the installed `setup.exe`, check Gecko, configure the game, build the overlay, and create launchers. It pauses when you need to provide an installer, complete a CrossOver/Gecko GUI action, type a password, log in to uaRO, or confirm a map load.

### Option B — Terminal

From the repository root, use:

```zsh
scripts/uaro-crossover.zsh preflight \
  --bottle uaro-crossover \
  --installer-zip "/path/to/UaRO_Setup.zip"
```

If you have the community raw-input package, import it into a local non-iCloud cache:

```zsh
scripts/uaro-crossover.zsh artifact import \
  --source-dir "/path/to/gepard-crossover-fix" \
  --cache-dir "$HOME/Games/UaRO-CrossOver-artifacts" \
  --crossover-build 26.3.0.39832
```

Then follow the phase gates in `SKILL.md`:

```zsh
scripts/uaro-crossover.zsh bottle create --bottle uaro-crossover
scripts/uaro-crossover.zsh install \
  --bottle uaro-crossover \
  --installer-zip "/path/to/UaRO_Setup.zip"
scripts/uaro-crossover.zsh check-gecko --bottle uaro-crossover
scripts/uaro-crossover.zsh overlay probe \
  --bottle uaro-crossover \
  --artifact-dir "$HOME/Games/UaRO-CrossOver-artifacts"
scripts/uaro-crossover.zsh overlay build \
  --bottle uaro-crossover \
  --artifact-dir "$HOME/Games/UaRO-CrossOver-artifacts"
scripts/uaro-crossover.zsh overlay verify \
  --bottle uaro-crossover \
  --artifact-dir "$HOME/Games/UaRO-CrossOver-artifacts"
```

The installer ZIP is preserved and streamed into the bottle; it is not committed to GitHub. The workflow does not read or store uaRO passwords.

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

The required result is `runtime=overlay` and `status=pass`. A successful game window is not enough. Do not use the uaRO shortcut inside the CrossOver UI after an overlay has been built; that route can load the stock runtime and reproduce the error.

## What you’ll need

- An Apple Silicon Mac (`arm64`). The initial workflow is not validated for Intel Macs.
- CrossOver installed locally. This repository does not install or license CrossOver for you.
- CrossOver build `26.3.0.39832` for the current prebuilt artifact path. Other builds are blocked unless a matching artifact is rebuilt and verified.
- A uaRO account and a locally downloaded installer. The installer download is behind the uaRO account area, so the login and download remain human-driven.
- Enough free space for the installer cache, bottle, backups, and approximately 869 MB for the current overlay observed on the verified machine. Exact future sizes are not guaranteed.
- The optional `gepard-crossover-fix` package when the stock probe reports `AFFECTED=yes`. Its source revision, binary signature, and redistribution license are currently **unconfirmed**.

## Uninstalling

Ask the AI to use the scoped CrossOver uninstall flow:

```zsh
scripts/uaro-crossover.zsh uninstall \
  --bottle uaro-crossover \
  --level game \
  --confirm
```

The workflow keeps CrossOver and unrelated bottles unless you explicitly choose a broader level. It backs up savedata where applicable and does not use broad deletion by default. The per-bottle overlay and generated launchers are separate from the CrossOver application itself.

## Status

**Private / experimental.** `0.2.0-experimental` has passed local static and fixture checks, plus one user-confirmed CrossOver run on Apple Silicon with CrossOver `26.3.0.39832`: the stock probe reported `AFFECTED=yes` with 238 clobbered entries, the overlay after-probe reported `AFFECTED=no` with zero, and the user logged in and entered a map without observing `Gepard::T Code: 3::110::12`.

That result is not a universal compatibility guarantee. Long-duration stability, other CrossOver builds, every possible Gepard crash, and trusted provenance for the community prebuilt DLL remain **unconfirmed**. The repository does not upload the DLL, installer, savedata, or credentials.

## Changelog

Full version history lives in [`CHANGELOG.md`](./CHANGELOG.md). The current version is kept in `SKILL.md` front matter and the repository metadata.

## Disclaimer

This is unofficial software and runs at your own risk:

- No guarantees are made for uaRO, CrossOver, Gepard, macOS, or future client updates.
- The workflow patches the installed `setup.exe` and may deploy a third-party prebuilt Wine DLL into a private bottle overlay. Backups and hashes are used, but the artifact's source revision, signature, and license are currently **unconfirmed**.
- A CrossOver build update can invalidate the artifact. The Skill intentionally stops rather than applying an old DLL to a new build.
- The overlay consumes disk space and does not automatically follow future CrossOver runtime updates.
- The workflow does not collect, transmit, or store uaRO credentials. Account login, installer download, macOS prompts, and final in-game verification remain directly under your control.

## Acknowledgments

- The uaRO community members who investigated the CrossOver raw-input issue and shared the probe, source patch, OpenSetup patcher, and experimental build-specific artifact.
- CodeWeavers for the CrossOver bottle and bundled Wine interfaces.
- The Whisky uaRO workflow, which provides the structural reference for the AI-executable installation documentation; its runtime commands and paths are not used here.

## License

[`MIT`](./LICENSE) — free to use, modify, and share; provided as-is, with no warranty. uaRO files, CrossOver files, and third-party Wine artifacts remain subject to their own licenses and are not included by default.
