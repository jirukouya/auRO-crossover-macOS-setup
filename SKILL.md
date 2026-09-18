---
name: auro-crossover-macos-setup
version: 0.2.4-experimental
description: >-
  Install, repair, verify, or uninstall uaRO on Apple Silicon macOS using
  CrossOver. Trigger when this GitHub repo or SKILL.md is handed to a fresh
  AI session with “install uaRO”, “uaRO CrossOver”, Gepard T Code 3::110::12,
  or wow64win.dll, even if the user does not say “use a Skill.” Read this file
  once and start executing; do not wait for extra docs. Do not use this skill
  for Whisky-only installs.
compatibility: Apple Silicon macOS; CrossOver 26.3.0 line (public 26.3 / 26.3.0, build 26.3.0.*); requires zsh, Python 3, CrossOver, the repository scripts/references, and a user-supplied uaRO installer.
---

# uaRO on macOS via CrossOver — Full Install Skill

This file is meant to be handed to a fresh AI session (Claude Code, Codex, ChatGPT, Copilot, Grok) on a player's Mac, with no other context. Read it once, then execute. Commands live in `scripts/uaro-crossover.zsh`; do not invent hashes, bottle names, or installer downloads.

This is not a theory rewrite. It is the procedure after a real Apple Silicon + CrossOver 26.3.0 run: overlay-only probe can pass while Play still dies; first launch may require OpenSetup, so the skill shows the user the Settings SOP; Option A into CrossOver.app is the deploy that actually started the game. The maintainer confirmation used build 26.3.0.39832; any 26.3.0.* is allowed if probes pass.

## If this repo was just handed to you — start here

Do these in order. Do **not** first read every file under `references/`.

1. If the working directory is not this repository, clone it and `cd` into it:
   `https://github.com/jirukouya/auRO-crossover-macOS-setup`
2. Tell the user, in one short message, what this Mac must already have:
   - Apple Silicon Mac
   - CrossOver **26.3.0** (About CrossOver shows 26.3 or 26.3.0; build 26.3.0.*). Other major/minor versions stop.
   - uaRO installer: `UaRO_Setup.exe` + `UaRO_Setup-1.bin` + `UaRO_Setup-2.bin` (zip or folder)
   - `gepard-crossover-fix` folder from uaRO Discord (keep `wow64win.dll.crossover-26.3.0`; do not rename)
   - Option A will backup then replace `wow64win.dll` **inside CrossOver.app**
3. Search this Mac for the installer and gepard folder (`~/Downloads`, `~/Documents`, `~/Games`, Desktop). If found, use those paths. If not, ask **once** for both paths. Do not invent downloads.
4. Defaults unless a matching bottle already exists: `BOTTLE_NAME=uaro-crossover`, `ARTIFACT_DIR=$HOME/Games/UaRO-CrossOver-artifacts`. Do not stall on renaming them.
5. If the user says “继续安装” or this is an existing/partial install, run the read-only resume planner first:
   `scripts/uaro-crossover.zsh continue --bottle uaro-crossover --json`
   Use its `next_step` as a routing hint, then re-run the owning command and its verification. It never installs, patches, launches, or deletes anything by itself. For a fresh install, run host preflight from the repo root, then the internal Steps 1–12. Keep the technical progress table internally; for a beginner, show only the four-stage summary below. Stop only for: missing files, installer/OpenSetup GUI, macOS permission, login, or the user refusing Option A.
6. If the user only pasted this SKILL.md without the repo, clone the repo first. The skill cannot run from this file alone.

## Beginner-facing flow

Present the workflow as four simple stages. The AI performs the technical checks silently and only exposes a blocker or a user action:

1. **Install the game** — prepare CrossOver, create the private bottle, and complete the uaRO installer.
2. **Create the two launch buttons** — generate Patcher and Settings under `~/Applications`; these are on-demand launchers, not resident apps.
3. **Do first-time Settings** — show the three Settings values, let the user click OK, and close Settings. Do not inspect or guess the user's selections.
4. **Start and test the game** — open Patcher, log in, enter the map, and run the final runtime check.

Do not lead with hashes, plist paths, registry keys, or CrossOver internals. Keep those in the technical appendix and use them only when a stage is blocked.

## 0. Fresh-session execution contract

After the block above:

1. Open a reference only when blocked: `references/crossover-cli.md`, `raw-input-fix.md`, `runtime-routing.md`, `troubleshooting.md`, or `state-schema.md`. Do not load them all up front.
2. Run the relevant command with `--help` before first use. Do not add undocumented flags.
3. Keep a variable ledger from command output (`PASS` / `UNCONFIRMED` / `BLOCKED`). Do not paste placeholders.
4. Re-derive paths from this machine. Never reuse `/Users/derekho` or another report.
5. Missing installer or gepard package is a stop-and-ask, not a guess.

For a JSON pre-flight result, use these exact keys to populate the ledger:

| Ledger value | Pre-flight JSON key | Status rule |
|---|---|---|
| CROSSOVER_APP | `crossover_app` | PASS only when the path exists and belongs to the resolved build |
| CX_VERSION | `crossover_version` | PASS when read from the current app |
| CX_BUILD | `crossover_build` | PASS only when it matches the supported build or a matching artifact is verified |
| BOTTLE_NAME | `bottle` | PASS after user choice or an unambiguous existing-state match; for fresh install, confirm the proposed `uaro-crossover` name before using it |
| BOTTLE_PATH | `bottle_dir` | PASS when the returned path exists; absent is expected before a fresh bottle is created |
| INSTALLER_SOURCE | `installer_source` | PASS only when installer status is complete |
| INSTALLER_TYPE | `installer_type` | `zip` maps to `INSTALLER_ZIP`; `directory` maps to `INSTALLER_DIR`; never set both |
| RAWINPUT_SOURCE_DIR | `rawinput_source_dir` | PASS only when the source report is candidate/valid |

The state file is `STATE_FILE=$HOME/Library/Application Support/uaRO-CrossOver/state.json`. Read it before resuming an existing installation, but never treat a previous state entry as proof that the current bottle or files still exist.

## Contents

1. Quick routing
2. Operating principles
3. Progress table
4. Parameters and evidence
5. Pre-flight and existing-state detection
6. Phase A — host and artifact readiness
7. Phase B — bottle and installer
8. Phase C — setup patch and game configuration
9. Phase D — raw-input probe and runtime choice
10. Phase E — DLL deploy, launch, and live verification
11. Optional AzzyAI
12. Troubleshooting
13. Repair, rollback, and uninstall
14. Completion report

## 1. Quick routing — where do I start?

| User situation | Route |
|---|---|
| Fresh CrossOver installation | Run Pre-flight, then Steps 1–12 in order. |
| Existing or partial installation | Run Pre-flight and existing-state detection first; resume only from a verified checkpoint. |
| Verify-only request or “is it fixed?” | Read state, run live verification/diagnosis, and do not create or patch anything unless the user later requests repair. |
| Repair request | Audit launchers first; use `--fix` only for the launcher repair scope explicitly confirmed by the user. |
| Gepard T Code 3::110::12, raw-input, wow64win.dll, or map-time crash | Inspect the live route; separate installer/setup issues from runtime overlay issues. |
| Settings or setup.exe problem | Work in Phase C; do not rebuild the raw-input overlay unless the probe requires it. |
| Uninstall request | Confirm the exact game directory or bottle, then use the scoped uninstall route. |
| Whisky-only request | Stop and route to auro-whisky-macos-setup. Do not mix Whisky and CrossOver instructions. |

### Fresh-session opening

At the beginning of a new task:

1. Identify CrossOver vs Whisky. Whisky-only → stop this skill.
2. State the route: fresh install, existing, repair, verify, or uninstall.
3. Follow **If this repo was just handed to you**. Then preflight. Do not start by reading all references.
4. Re-derive every path from command output.
5. Post the progress table after each step. Stop for GUI, credentials, permissions, missing files, or Option A refusal — not for every internal script.

Route-specific first action:

| Route | First action | Next decision |
|---|---|---|
| Fresh install | Search for installer + gepard package; use defaults `uaro-crossover` and `$HOME/Games/UaRO-CrossOver-artifacts`; run Pre-flight. | If the bottle does not exist, create it in Step 3. |
| Existing/partial | Read state, run Pre-flight with `--allow-missing-installer` only when appropriate, then run bottle status. | Resume only after matching the state path to the current bottle and game files. |
| Verify-only | Run `verify-live-runtime`; add `diagnose --error` when the user supplied an exact symptom. | Report `PASS`, `UNCONFIRMED`, or `BLOCKED`; do not mutate state except the normal verification record. |
| Repair | Run diagnostic `repair` without `--fix`. | Use `--fix` only after confirming that the requested repair is limited to generated launchers. |
| Uninstall | Resolve the exact game directory or bottle and show the final target path. | Require explicit scope and `--confirm` immediately before moving/deleting. |

When the user says “继续安装”, do not restart the whole explanation. Read the state and run the planner:

~~~zsh
scripts/uaro-crossover.zsh continue --bottle uaro-crossover --json
~~~

The planner is read-only and only selects the next core uaRO checkpoint (`preflight`, `install`, `patch-setup`, `check-gecko`, `overlay-probe`, runtime choice, launcher creation, or live launch). It re-checks the recorded bottle/game paths and never treats an old `pass` entry as proof. If no state exists, it returns `preflight`. If core installation is complete, it returns `next_step=none`. AzzyAI is never selected by this planner; it remains a separate, explicit post-install request.

## 2. Operating principles

1. Check first, change second. Discovery and verification commands come before create, copy, patch, or launch commands.
2. Use one logical operation per shell command. Do not chain unrelated commands with semicolons or hidden fallbacks.
3. Resolve actual CrossOver app path, CLI path, version, bottle path, game path, installer path, and artifact identity from the host.
4. Treat local files, state JSON, manifests, hashes, build labels, and command output as evidence. Draft history or README claims are not proof of a live result.
5. Do not collect game credentials. Stop at the account-login, map/login, macOS permission, or administrator prompt and ask the user to act.
6. After the raw-input DLL is deployed (Option A into CrossOver.app by default), launch `UaRo Patcher.exe` through CrossOver's bundled `bin/wine --bottle --workdir --cx-app`. Do not create or use a direct Game.app launcher. Overlay launchers are Option B only.
7. If a required value is unknown, stop that sub-step and label it unconfirmed. Do not guess a fallback.

## 3. Progress table

Maintain this table in the final report and update it during execution.

| Checkpoint | Meaning | Completion evidence |
|---|---|---|
| Pre-flight | Host and repository contract understood | preflight output passes, or the exact blocker is recorded |
| Step 1 | CrossOver and Rosetta resolved | Actual app/build/CLI output |
| Step 2 | Artifact and installer inputs resolved | Artifact verification and installer path/member evidence |
| Step 3 | Bottle resolved | Bottle status/create output |
| Step 4 | Installer staged | Staged files and exact member names |
| Step 5 | Installer GUI completed and CrossOver registration verified | User confirmation, setup path, and `verify-registration --repair` PASS |
| Step 6 | Setup patch verified | patch-setup output and byte/hash evidence |
| Step 7 | Gecko and game configuration checked | check-gecko, configure, and optional keyboard output |
| Step 8 | Stock runtime probe completed | AFFECTED and clobbered *entry count* from probe output |
| Step 9 | Runtime branch selected | Option A (default), Option B overlay, or clean stock |
| Step 10 | DLL deployed | Option A: CrossOver.app wow64win.dll hash; Option B: overlay after-probe |
| Step 11 | CrossOver registration + launchers + Settings SOP | Registration PASS; both user-level launchers signed; Settings instructions shown to the user |
| Step 12 | Live runtime verified | uaRO.exe alive ≥15s; lsof wow64win.dll path/hash; verify-live-runtime status=pass |

Status values:

- PASS: direct command output proves the checkpoint.
- UNCONFIRMED: the command or user action did not provide enough evidence.
- BLOCKED: a safety gate, missing input, failed verification, or unsupported state prevents continuation.
- N/A: the checkpoint does not apply, such as overlay build when the stock baseline is clean.

Do not report the whole installation as complete while Step 5, Step 8, Step 11 registration/launcher checks, or Step 12 is unconfirmed.

## 4. Parameters and evidence

Use these variables only after resolving them from the current machine:

| Variable | Source | Rule |
|---|---|---|
| CROSSOVER_APP | CrossOver discovery | Must be the actual installed app |
| CX_CLI | CrossOver bundled CLI | Must be executable and match the app |
| CX_WINE | CrossOver bundled Wine | Must be the Wine binary used by the bottle |
| BOTTLE_NAME | User choice or existing state | Do not silently reuse a different bottle |
| BOTTLE_PATH | bottle status or state | Must be the actual private bottle path |
| GAME_DIR | Installer output or existing state | Must contain the installed uaRO files |
| SETUP_PATH | Game directory | Usually GAME_DIR/setup.exe; verify before patching |
| INSTALLER_ZIP or INSTALLER_DIR | User-supplied input | Never download or invent an installer source |
| RAWINPUT_SOURCE_DIR | User-supplied raw-input candidate package | Source directory imported into the private cache |
| ARTIFACT_DIR | User-selected non-iCloud cache path, or `raw_input.artifact_dir` after a prior import | Required by the current stock probe contract; default proposal is `$HOME/Games/UaRO-CrossOver-artifacts` and must be checked before use |
| WIDTH, HEIGHT | OpenSetup / Settings; default 2560×1600 | Use 2560 and 1600 unless the user names another size. Do not stall asking. |
| OVERLAY_DIR | Build output and state | Required only when the baseline is affected |
| ERROR_TEXT | Exact user-reported symptom | Required when calling diagnose |
| PREFLIGHT_JSON | Temporary capture of JSON pre-flight output | Read-only ledger input; delete or leave in `/tmp` after the run |
| STATE_FILE | User-local state path | Never commit or upload this file |

When a command prints a path, copy that exact path into the next command. Do not reconstruct macOS paths from a report.

## 5. Pre-flight and existing-state detection

Run from the repository root. Do not run a command until every variable on that line has a ledger value. For a public first run, use `BOTTLE_NAME=uaro-crossover` and `ARTIFACT_DIR=$HOME/Games/UaRO-CrossOver-artifacts` unless a different bottle already exists. If the installer or gepard folder is not known yet, search common folders, then host-only discovery:

~~~zsh
PREFLIGHT_JSON="/tmp/uaro-crossover-preflight.json"
scripts/uaro-crossover.zsh preflight --bottle "$BOTTLE_NAME" --allow-missing-installer --json | tee "$PREFLIGHT_JSON"
~~~

For a fresh installation with a known installer and raw-input source, prefer a single JSON pre-flight so the AI can build its ledger from one result:

~~~zsh
PREFLIGHT_JSON="/tmp/uaro-crossover-preflight.json"
scripts/uaro-crossover.zsh preflight --bottle "$BOTTLE_NAME" --installer-zip "$INSTALLER_ZIP" --rawinput-source-dir "$RAWINPUT_SOURCE_DIR" --json | tee "$PREFLIGHT_JSON"
~~~

If only one installer input is known, use the matching form. Set it from the pre-flight `installer_type` and `installer_source` values: `zip` means `INSTALLER_ZIP="$INSTALLER_SOURCE"`; `directory` means `INSTALLER_DIR="$INSTALLER_SOURCE"`. Keep the other variable unset:

~~~zsh
scripts/uaro-crossover.zsh preflight --installer-zip "$INSTALLER_ZIP" --json
scripts/uaro-crossover.zsh preflight --installer-dir "$INSTALLER_DIR" --json
~~~

When the raw-input source directory is already available, include it in the same pre-flight run:

~~~zsh
scripts/uaro-crossover.zsh preflight --installer-zip "$INSTALLER_ZIP" --rawinput-source-dir "$RAWINPUT_SOURCE_DIR" --json
~~~

Use --allow-missing-installer only for host-only diagnosis or when the user has explicitly chosen to complete installer staging later. It does not make installation ready.

Read the JSON result and populate the ledger from the exact keys in Section 0. In particular, set `CX_VERSION` from `crossover_version`, `CX_BUILD` from `crossover_build`, `BOTTLE_PATH` from `bottle_dir`, and keep `INSTALLER_SOURCE`/`RAWINPUT_SOURCE_DIR` tied to the paths that actually passed. If you did not save JSON, use the human-readable output and do not pretend that shell variables were automatically assigned.

After `artifact import`, set `ARTIFACT_DIR` to the exact cache path printed by the command and confirmed by `raw_input.artifact_dir` in `STATE_FILE`. When resuming, prefer that state path only if it still exists and its manifest verifies against the current `CX_BUILD`. A path used only as a proposed default is not evidence that an artifact was imported.

When JSON was saved, print the ledger candidates without evaluating them as shell code:

~~~zsh
python3 - "$PREFLIGHT_JSON" <<'PY'
import json
import sys

data = json.loads(open(sys.argv[1], encoding="utf-8").read())
for ledger, key in {
    "CROSSOVER_APP": "crossover_app",
    "CX_VERSION": "crossover_version",
    "CX_BUILD": "crossover_build",
    "BOTTLE_NAME": "bottle",
    "BOTTLE_PATH": "bottle_dir",
    "INSTALLER_SOURCE": "installer_source",
    "INSTALLER_TYPE": "installer_type",
    "RAWINPUT_SOURCE_DIR": "rawinput_source_dir",
}.items():
    value = data.get(key)
    print(f"{ledger}={value if value is not None else '<missing>'}")
PY
~~~

Pre-flight must resolve or clearly report:

- Apple Silicon architecture and Rosetta availability.
- CrossOver app, version, bundled CLI, and bundled Wine.
- Bottle root and repository state directory.
- Required tools: zsh, Python 3, CrossOver CLI, file, shasum, and vmmap when live verification is requested.
- Whether the installer input exists and passes the expected member-name checks.
- Whether an artifact package is present and can be verified.

After pre-flight, inspect existing state only when the user says an installation or bottle already exists, or when the pre-flight result says the bottle is present:

~~~zsh
scripts/uaro-crossover.zsh bottle status --bottle "$BOTTLE_NAME"
~~~

For a fresh installation with no existing bottle, skip this status command and continue to Step 3's `bottle create`. If the bottle name is not known, list the actual directories first:

~~~zsh
find "$HOME/Library/Application Support/CrossOver/Bottles" -mindepth 1 -maxdepth 1 -type d -print
~~~

Ask the user to choose when more than one plausible bottle exists. Never choose a bottle only because it has the default name.

For an existing installation, use state only as a resume hint. If the state says the installer is complete and the recorded `GAME_DIR` still contains the game, skip Steps 3–5. Re-run Step 6 when the recorded setup path or hash no longer matches; re-run Step 7 when Gecko/configuration evidence is absent; re-run Step 8 when the recorded bottle, CrossOver build, artifact, or probe log no longer matches the current machine. Never skip a checkpoint solely because an old state entry says `pass`.

## 6. Phase A — host and artifact readiness

### Step 1 — Resolve CrossOver and Rosetta

Use the pre-flight output as the source of truth. Confirm the actual app build, CLI, Wine binary, bottle root, and architecture. If Rosetta is missing on Apple Silicon, stop and report the exact installation requirement.

Do not continue on a guessed CrossOver version or a CLI that belongs to another app installation.

### Step 2 — Import and verify the candidate artifact and installer

The current probe contract requires a candidate gepard-crossover-fix package before the stock probe can run. Import it before Step 8:

~~~zsh
scripts/uaro-crossover.zsh artifact import --source-dir "$RAWINPUT_SOURCE_DIR" --cache-dir "$ARTIFACT_DIR" --crossover-build "$CX_BUILD" --crossover-public-version "$CX_VERSION"
~~~

The candidate package is the Discord `gepard-crossover-fix` folder (or an import cache). Keep the human filename `wow64win.dll.crossover-<version>`; `artifact import` copies it to cache as `wow64win.dll`. Do not rename the user's package. Source directory is that folder; `--rawinput-source-dir` must not be the cache that already contains `manifest.json`.

Minimum members:

- `wow64win.dll` or `wow64win.dll.crossover-26.3.0`
- rawinput_overflow_probe.exe
- rawinput_overflow_probe.c
- wow64win-rawinput-devicelist.patch

Verify the probe artifact:

~~~zsh
scripts/uaro-crossover.zsh artifact verify --artifact-dir "$ARTIFACT_DIR" --crossover-build "$CX_BUILD" --mode probe
~~~

The probe must be build- and hash-locked. A package that is merely named correctly is not sufficient.

The installer ZIP or directory is verified by pre-flight and again by the staging command. Keep the exact input that passed those checks.

Required installer members are exactly:

- UaRO_Setup.exe — client installer.
- UaRO_Setup-1.bin — installer data part one.
- UaRO_Setup-2.bin — installer data part two.

If the candidate package or installer is missing, stop and report the blocker. Do not substitute a web download, an unverified DLL, or a same-name artifact from another build.

## 7. Phase B — bottle and installer

### Step 3 — Create or resolve the private bottle

For a fresh install:

~~~zsh
scripts/uaro-crossover.zsh bottle create --bottle "$BOTTLE_NAME"
~~~

For an existing bottle:

~~~zsh
scripts/uaro-crossover.zsh bottle status --bottle "$BOTTLE_NAME"
~~~

Confirm that the bottle is private to this uaRO installation and that the returned path is the one used by later commands.

### Step 4 — Stage the split installer

Stage the verified installer into the bottle or staging directory without opening the GUI:

~~~zsh
scripts/stage-installer.zsh --bottle "$BOTTLE_NAME" --installer-zip "$INSTALLER_ZIP"
~~~

Or, for an extracted source:

~~~zsh
scripts/stage-installer.zsh --bottle "$BOTTLE_NAME" --installer-dir "$INSTALLER_DIR"
~~~

Preserve the exact split-installer member names. Do not flatten the package with ditto or use a mixed installer directory.

### Step 5 — Run the installer GUI

Launch and stage the client installer through CrossOver. Use the same input that passed pre-flight:

~~~zsh
scripts/uaro-crossover.zsh install --bottle "$BOTTLE_NAME" --installer-zip "$INSTALLER_ZIP"
~~~

For an extracted installer directory, use:

~~~zsh
scripts/uaro-crossover.zsh install --bottle "$BOTTLE_NAME" --installer-dir "$INSTALLER_DIR"
~~~

The user must complete the installer GUI, choose the intended game directory, and handle any CrossOver/macOS permission prompt. The AI must not enter or request game credentials. The Patcher launcher is the later client-update entry point; there is no separate client-update shell command in this repository. If a client update replaces the installed `setup.exe`, rerun Step 6 before live verification.

After the GUI finishes, resolve the actual installed directory:

~~~zsh
scripts/uaro-crossover.zsh bottle status --bottle "$BOTTLE_NAME"
~~~

Record GAME_DIR and verify that both setup.exe and the expected uaRO files exist before Phase C.

Before continuing, verify that CrossOver can recognize the installed application without opening its desktop UI. The command performs a read-only check first and, when needed, runs one non-destructive `cxbottle --install` export before checking again:

~~~zsh
scripts/uaro-crossover.zsh verify-registration \
  --bottle "$BOTTLE_NAME" \
  --game-dir "$GAME_DIR" \
  --applications-dir "$HOME/Applications" \
  --repair --json
~~~

This is a hard gate. A missing `cxmenu.conf` entry, missing CrossOver menu plist, stale bottle/build path, missing Windows shortcut, or missing exported command is `BLOCKED`; do not call the installation complete or proceed by guessing a different bottle. The repair only updates CrossOver menu/association exports and records a log under the uaRO state log directory.

## 8. Phase C — setup patch and game configuration

### Step 6 — Patch and verify setup.exe

The official client update and the setup.exe compatibility patch are separate operations. Confirm that SETUP_PATH is the installed file, not the staged UaRO_Setup.exe.

Run the hash-locked patch command (same bytes as `scripts/patch_opensetup_rosetta.py` from the gepard-crossover-fix package):

~~~zsh
scripts/uaro-crossover.zsh patch-setup --setup "$SETUP_PATH"
python3 scripts/patch_opensetup_rosetta.py "$SETUP_PATH"
~~~

Either command is acceptable if the SHA matches. Prefer reporting `Already patched` / after_sha256 rather than JSON `states=pending`.

The patch must verify these exact sites before changing bytes:

| Site | Expected bytes | Replacement |
|---|---|---|
| A | DC D8 | D8 D8 |
| B | DC D0 | D8 D0 |
| C | mss32.dll | mss32.off |

A mismatch is a hard stop. Do not force the patch or apply it to another executable.

### Step 7 — Check Gecko and configure the game

Check the bottle's Gecko state:

~~~zsh
scripts/uaro-crossover.zsh check-gecko --bottle "$BOTTLE_NAME" --json
~~~

If the CrossOver Gecko payload itself is missing, stop and ask the user to install the matching Gecko component through CrossOver, then rerun this check. Do not copy a random Gecko bundle. If the payload exists but the selected bottle has no Gecko marker, mark Step 7 pending and use the Patcher route to let CrossOver install Gecko interactively. Use an existing generated Patcher launcher when available; for a fresh install, it is safe to defer this one check until the launchers in Step 11 exist. Rerun `check-gecko` before Step 12.

Write the game resolution explicitly. Default is **2560×1600** unless the user named another size:

~~~zsh
WIDTH="${WIDTH:-2560}"
HEIGHT="${HEIGHT:-1600}"
scripts/uaro-crossover.zsh configure --game-dir "$GAME_DIR" --width "$WIDTH" --height "$HEIGHT" --state-file "$HOME/Library/Application Support/uaRO-CrossOver/state.json"
~~~

`configure` also sets DirectX 9 (`RENDERSYSTEM=2`) and leaves the mouse **not** locked to the window (`WindowLock=0`). Lua is still not a substitute for OpenSetup.

If the user requests keyboard compatibility settings:

~~~zsh
scripts/uaro-crossover.zsh configure-keyboard --bottle "$BOTTLE_NAME"
~~~

Re-run the relevant verification after each change.

Lua config is not enough for a first launch. The skill does not inspect or guess whether the user's Settings choices are correct. After Step 6, launch Settings through the supported user-level launcher or official wine:

~~~zsh
scripts/uaro-crossover.zsh launch-setup --bottle "$BOTTLE_NAME" --game-dir "$GAME_DIR"
~~~

**Show this short SOP to the user before they click OK.** OpenSetup defaults are wrong for this Mac skill. The player must:

1. **Resolution:** `2560 x 1600` (or the size they asked for).
2. **Graphics API:** **DirectX 9** (not DirectX 8 / OpenGL).
3. **Restrict mouse to window:** **unchecked**. The box is ticked by default — clear it.

Then click **OK** and close Settings. The skill records that the instructions were shown; it does not read `user.reg` or fail the installation because a setting cannot be inspected without desktop control. Do not open Settings and Patcher at the same time.

## 9. Phase D — raw-input probe and runtime choice

### Step 8 — Run the stock probe

Run the probe against the unmodified CrossOver/Wine runtime, using the already verified candidate package:

~~~zsh
scripts/uaro-crossover.zsh overlay probe --bottle "$BOTTLE_NAME" --artifact-dir "$ARTIFACT_DIR"
~~~

The probe records at least:

- AFFECTED=yes|no
- clobbered entry count (not a 0/1 contamination flag)
- runtime=stock
- artifact and CrossOver build evidence

Interpretation:

| Probe result | Runtime route |
|---|---|
| AFFECTED=no and clobbered entries = 0 | Keep CrossOver stock Wine. Do not deploy a DLL. |
| AFFECTED=yes and clobbered entries > 0 (often 238 on this Mac) | Deploy the matching DLL. Default is Option A (`deploy-app`). |
| Probe binary reports a contaminated/clobbered *baseline flag* of 1 with unreadable output | Stop. Do not infer a clean result. |
| Missing/invalid artifact or incomplete output | Stop as BLOCKED or UNCONFIRMED. |

Do not treat clobbered **entry count** 238 as the contamination flag. That count is the expected broken stock thunk.

The candidate DLL is not automatically deployed. It is only eligible when the stock probe reports AFFECTED=yes and all build/source/hash gates pass.

### Step 9 — Select the runtime branch

If the baseline is clean, keep the recorded stock probe as the evidence that no overlay is required. The current overlay verify command is for an existing overlay, so do not invoke it on the clean branch. Step 10 is N/A.

If the baseline is affected, continue to Step 10. Default deployment is Option A into CrossOver.app, but it requires explicit `--confirm-app-change` because it changes the shared CrossOver.app runtime. Option B overlay is only if the user refuses to change the app bundle.

## 10. Phase E — DLL deploy, launch, and live verification

### Step 10 — Deploy the DLL (Option A default)

Wine loads builtin `wow64win.dll` from the directory of the `ntdll.so` that was actually loaded. A folder that only contains the replacement DLL is ignored.

**Option A (default, gepard-crossover-fix SHARE-PROMPT):** backup then replace the DLL inside CrossOver.app:

~~~zsh
scripts/uaro-crossover.zsh deploy-app --artifact-dir "$ARTIFACT_DIR" --bottle "$BOTTLE_NAME" --confirm-app-change
~~~

Keep `wow64win.dll.orig`. CrossOver updates restore stock; after reviewing the shared-app impact, re-run `deploy-app --confirm-app-change`. Confirm with the official wrapper, not an overlay wine:

~~~zsh
# copy probe into the bottle first if needed; use the after scope after Option A
scripts/uaro-crossover.zsh overlay probe --bottle "$BOTTLE_NAME" --artifact-dir "$ARTIFACT_DIR" --probe-scope after
~~~

After Option A, a probe through `$CX_WINE --bottle --cx-app` must print AFFECTED=no and clobbered entries = 0. Use `overlay probe --probe-scope after` so the state file does not overwrite the stock before-probe result.

**Option B (only if the user refuses to edit CrossOver.app):** build the per-bottle overlay, then set `BinPath`/`LibPath` in `cxbottle.conf` as in the gepard-crossover-fix SKILL. Building overlay files without those bottle keys is not Option B.

~~~zsh
scripts/uaro-crossover.zsh overlay build --bottle "$BOTTLE_NAME" --artifact-dir "$ARTIFACT_DIR"
scripts/uaro-crossover.zsh artifact verify --artifact-dir "$ARTIFACT_DIR" --crossover-build "$CX_BUILD" --mode overlay
scripts/uaro-crossover.zsh overlay verify --bottle "$BOTTLE_NAME" --artifact-dir "$ARTIFACT_DIR"
~~~

A failed after-probe blocks launch.

### Step 11 — Launch Patcher through official CrossOver wine

Do not use `/Applications/uaRO/` Whisky experiment bundles. Build the supported user-level launchers as part of the completion path:

~~~zsh
scripts/uaro-crossover.zsh build-launchers --bottle "$BOTTLE_NAME" --game-dir "$GAME_DIR"
~~~

By default the bundles are created under `$HOME/Applications`, avoiding an administrator prompt. They are on-demand launchers, not resident apps: they use CrossOver `--wait-children`, exit when Settings/Patcher and their children exit, and set `LSUIElement` so macOS does not present them as ordinary Dock applications. Pass `--applications-dir /Applications` only when the user explicitly wants system-wide apps. `build-launchers` embeds `references/icons/AppIcon.icns` and signs both bundles. Do not add LaunchAgents, login items, daemons, or a polling loop. `repair` audits registration, launcher scripts, signatures, and on-demand lifecycle metadata; it does not prove the game starts.

Re-run the registration check after building launchers:

~~~zsh
scripts/uaro-crossover.zsh verify-registration \
  --bottle "$BOTTLE_NAME" \
  --game-dir "$GAME_DIR" \
  --applications-dir "$HOME/Applications" \
  --json
~~~

Supported launch after Option A:

~~~zsh
scripts/uaro-crossover.zsh launch-patcher --bottle "$BOTTLE_NAME" --game-dir "$GAME_DIR"
~~~

The executable name is `UaRo Patcher.exe` (not `Patcher.exe`). Working directory must be the game directory. No Game.app. If the client Patcher replaces `setup.exe`, rerun Step 6.

### Step 12 — Verify the live runtime

Confirm `uaRO.exe` stays up at least 15 seconds (broken thunk dies around 12s). Then:

~~~zsh
scripts/uaro-crossover.zsh verify-live-runtime --bottle "$BOTTLE_NAME" --game-dir "$GAME_DIR" --json
~~~

and Gate 1 from gepard-crossover-fix:

~~~zsh
P=$(pgrep -f 'uaRO.exe' | head -1)
lsof -p "$P" | grep -o '[^ ]*wow64win.dll' | sort -u
~~~

Accepted completion states:

- Option A: `uaRO.exe` running; lsof path is CrossOver.app `wow64win.dll`; hash matches `deploy-app`; verify-live-runtime `status=pass`.
- Option B overlay: runtime=overlay and status=pass, with overlay hashes.
- Clean stock (never affected): runtime=stock and status=pass, with AFFECTED=no and clobbered entries = 0.

A running process with no readable runtime evidence is UNCONFIRMED. Overlay-only probe PASS is not proof the game starts. After Option A, stock+matching app DLL is pass, not blocked.

For diagnosis, provide the exact user-reported symptom:

~~~zsh
scripts/uaro-crossover.zsh diagnose --bottle "$BOTTLE_NAME" --error "$ERROR_TEXT" --json
~~~

Never report fixed based only on launcher files or a generated manifest. The live runtime check is the completion gate.

## Optional post-install add-on: AzzyAI (mercenary/homunculus auto-attack)

AzzyAI is an optional third-party Lua AI that can make a uaRO mercenary or homunculus automatically find and attack nearby monsters. It is **not part of the core installation**, does not affect the core completion gate, and must not be installed unless the user starts a separate, explicit request after uaRO has passed the live-runtime check.

Do not ask about AzzyAI during the normal install. After the core completion report is delivered, the user may start a separate request such as:

> uaRO 已经可以玩了。现在另外帮我安装 AzzyAI。

The core installation report remains complete if the user never requests this add-on. If explicitly requested, read and follow [`AZZYAI_FIXES.md`](./AZZYAI_FIXES.md) from Step 1 through the verification steps.

For the AzzyAI flow:

1. Reuse the verified `GAME_DIR` from the CrossOver ledger. Do not guess a bottle path or use a Whisky command.
2. Resolve and verify exactly `$GAME_DIR/AI/USER_AI` before copying anything; do not search another bottle.
3. Back up the existing AI directory before replacing files, and ask before overwriting a user's existing AI.
4. Download and copy AzzyAI, then apply the uaRO targeting fixes from the guide.
5. Stop for the user to launch the supported Patcher, log in, and run `/merai` or `/hoai`. File installation alone does not activate AzzyAI.
6. Resume only after the user confirms the in-game activation, then verify a fresh matching startup log and ask the user to verify that the mercenary or homunculus attacks nearby monsters.

The full guide also covers the uaRO targeting cause, both independent Lua patches, `AAI_ACTORS.log`, engagement range, species-based tactics, `LiveMobID`, and reinstall recovery. Do not report AzzyAI as working from file presence alone. The in-game command and an actual attack test remain human-controlled gates.

## 11. Troubleshooting

### Gepard T Code 3::110::12

Separate the layers:

1. Confirm the correct CrossOver bottle and game directory.
2. Confirm setup.exe patch sites A/B/C.
3. Confirm the stock probe result.
4. If affected, confirm Option A app DLL hash or Option B overlay after-probe.
5. Confirm launch used official CrossOver wine (Option A) or BinPath overlay (Option B).
6. Run live verification: uaRO.exe ≥15s and lsof of wow64win.dll.

If Option A is deployed, stock CrossOver.app DLL with the matching hash is success. If lsof still shows the `.orig` stock file, `deploy-app` did not take. If the baseline was clean, a remaining T-code is not proof a DLL overlay is needed.

### setup.exe or Settings failure

Check the exact installed file, then run:

~~~zsh
scripts/uaro-crossover.zsh patch-setup --setup "$SETUP_PATH"
scripts/uaro-crossover.zsh check-gecko --bottle "$BOTTLE_NAME" --json
~~~

Do not use UaRO_Setup.exe as a substitute for the installed setup.exe.

### Overlay verification failure

Stop launcher creation. Re-check:

- artifact build and source files;
- CrossOver version and Wine binary;
- overlay manifest hashes;
- before/after probe state;
- bottle path and state JSON.

Option A *does* copy the verified DLL into CrossOver.app after `wow64win.dll.orig` exists. Do not copy an unverified DLL, and do not skip the backup. Option B must not leave CrossOver.app unchanged *and* still launch through stock ntdll.

### Artifact or installer mismatch

Treat a missing file, unknown hash, wrong build, wrong installer member, or mixed directory as a hard stop. Ask the user for a matching source package or the exact missing evidence.

## 12. Repair, rollback, and uninstall

### Verify-only existing installation

For a user who asks whether an existing installation is working, do not reinstall or rebuild first:

~~~zsh
scripts/uaro-crossover.zsh bottle status --bottle "$BOTTLE_NAME"
scripts/uaro-crossover.zsh verify-registration --bottle "$BOTTLE_NAME" --applications-dir "$HOME/Applications" --json
scripts/uaro-crossover.zsh verify-live-runtime --bottle "$BOTTLE_NAME" --game-dir "$GAME_DIR" --json
~~~

If the user supplied an exact error, add:

~~~zsh
scripts/uaro-crossover.zsh diagnose --bottle "$BOTTLE_NAME" --error "$ERROR_TEXT" --json
~~~

Use the state file and current filesystem paths to decide which completed checkpoint can be resumed. A verify-only route must not create a bottle, patch `setup.exe`, import an artifact, run `deploy-app`, build an overlay, or rebuild launchers.

### Repair is diagnostic by default

This command audits the two generated launcher bundles: shell syntax, Info.plist, bundled patch helper/profile, and code signature. It does not patch the game, rebuild an overlay, rerun the raw-input probe, or repair Gecko:

~~~zsh
scripts/uaro-crossover.zsh repair --bottle "$BOTTLE_NAME"
~~~

Only use --fix when the user has explicitly asked to repair and the target scope is confirmed:

~~~zsh
scripts/uaro-crossover.zsh repair --bottle "$BOTTLE_NAME" --fix
~~~

Before --fix, record the current state and confirm that the requested scope is limited to generated launchers. `--fix` refreshes the bundled patch helper/profile, restores executable permission, and re-signs the launcher. After --fix, rerun launcher verification and the relevant setup, artifact, probe, and live-runtime checks. A repair report alone is not proof of a working installation.

For other repair scopes, use the narrow command that owns that evidence: rerun `patch-setup` for `setup.exe`, `check-gecko` for Gecko, `configure` for game settings, and `overlay verify` plus the after-probe for an overlay. Do not assume the generic `repair` command handles those areas.

### Rollback

For an overlay issue, remove or move only the named per-bottle overlay after preserving its manifest and state evidence. Never delete the CrossOver app, the entire bottle root, or unrelated bottles as a repair shortcut.

Option A rollback: `mv "$CX_ROOT/lib/wine/x86_64-windows/wow64win.dll.orig" "$CX_ROOT/lib/wine/x86_64-windows/wow64win.dll"` after stopping wine. If the baseline was affected, do not claim unpatched stock is safe until a new clean probe.

### Uninstall

Uninstall only the exact scope the user confirmed:

~~~zsh
scripts/uaro-crossover.zsh uninstall --level game --bottle "$BOTTLE_NAME" --game-dir "$GAME_DIR" --confirm
~~~

For a full private bottle removal:

~~~zsh
scripts/uaro-crossover.zsh uninstall --level bottle --bottle "$BOTTLE_NAME" --confirm
~~~

The command must not touch other bottles, the CrossOver app, user credentials, or unrelated macOS files. Confirm the final path before executing an irreversible removal.

## 13. Completion report

Start the user-facing report with this plain-language block before technical evidence:

~~~text
现在能不能玩：PASS / 未完成 / 被阻断
CrossOver 是否能识别 uaRO：PASS / 未确认 / BLOCKED
Patcher/Settings 是否可用：PASS / 未生成 / 失败
~~~

Then show only three next-step categories: what the user can do now, what the user must do, and which automatic evidence could not be proven. Keep paths, hashes, plist details, and state fields in the technical appendix.

Report the result in this order:

1. Route used: CrossOver fresh install, existing state, repair, verify, or uninstall.
2. Actual CrossOver app/build, CLI, bottle, game directory, and runtime branch.
3. Progress table with PASS, N/A, UNCONFIRMED, and BLOCKED states.
4. Artifact identity and installer evidence.
5. Setup patch sites and the Settings SOP shown to the user (default: 2560×1600, DirectX 9, Restrict mouse to window off); do not claim the user's selections were machine-verified.
6. Stock probe values: AFFECTED and clobbered entry count.
7. Option A app DLL hash, or overlay manifest/after-probe, or why deploy was N/A.
8. Launch command; no Game.app; Settings instructions shown.
9. Live verification: process age, lsof path, verify-live-runtime status.
10. Evidence labels: 已确认, 根据证据推导, 未确认, 来源冲突, or 被阻断.

A complete installation requires Step 5, Step 11 registration/launcher checks, and Step 12 to be PASS. Option A may mark overlay Step 10 details as N/A when `deploy-app` hash matches. A clean stock result may mark Step 10 as N/A only when AFFECTED=no and clobbered entries = 0. A visual CrossOver screenshot is not required; registration PASS is based on CLI, plist, shortcut, path, and build evidence.

## References

- README.md — user-facing overview, supported workflow, and evidence status.
- AZZYAI_FIXES.md — optional CrossOver-specific AzzyAI installation, activation, and uaRO targeting fixes.
- references/runtime-routing.md — stock, overlay, and mixed-runtime rules.
- references/raw-input-fix.md — artifact, probe, source, and hash gates.
- references/troubleshooting.md — symptom-oriented diagnosis.
- CHANGELOG.md — version history.
- LICENSE — repository license.
