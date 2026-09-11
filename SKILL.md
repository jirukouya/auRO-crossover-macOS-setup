---
name: auro-crossover-macos-setup
version: 0.2.0-experimental
description: >-
  Install, repair, verify, or uninstall uaRO on Apple Silicon macOS using
  CrossOver's bundled CLI and private bottles. Trigger when the user mentions
  uaRO with CrossOver, CrossOver bottles or Wine, Gepard T Code 3::110::12 on
  CrossOver, wow64win.dll, or a fully automated CrossOver setup. Do not use
  this skill for Whisky-only installations. When this file is handed to a
  fresh AI session, read it once, route the task, and execute the numbered
  steps in order.
compatibility: Apple Silicon macOS; initial tested target CrossOver 26.3.0.39832; requires zsh, Python 3, CrossOver, and a user-supplied uaRO installer.
---

# uaRO on macOS via CrossOver — Full Install Skill

This skill is the executable runbook for installing, repairing, verifying, and uninstalling uaRO through CrossOver on Apple Silicon macOS.

It is written for a fresh AI session. Read the whole file once, then follow the routing table and numbered steps. Do not invent paths, build numbers, hashes, bottle names, installer members, or artifact provenance.

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
10. Phase E — launchers and live verification
11. Troubleshooting
12. Repair, rollback, and uninstall
13. Completion report

## 1. Quick routing — where do I start?

| User situation | Route |
|---|---|
| Fresh CrossOver installation | Run Pre-flight, then Steps 1–12 in order. |
| Existing or partial installation | Run Pre-flight and existing-state detection first; resume only from a verified checkpoint. |
| Gepard T Code 3::110::12, raw-input, wow64win.dll, or map-time crash | Inspect the live route; separate installer/setup issues from runtime overlay issues. |
| Settings or setup.exe problem | Work in Phase C; do not rebuild the raw-input overlay unless the probe requires it. |
| Uninstall request | Confirm the exact game directory or bottle, then use the scoped uninstall route. |
| Whisky-only request | Stop and route to auro-whisky-macos-setup. Do not mix Whisky and CrossOver instructions. |

### Fresh-session opening

At the beginning of a new task:

1. Identify whether the user wants CrossOver, Whisky, or both. If it is Whisky-only, stop this skill.
2. State the current route: fresh install, existing state, repair, verify, or uninstall.
3. Run Pre-flight before making any bottle, game, artifact, or launcher change.
4. Re-derive every path from actual command output. Never reuse a path from memory or from an old report.
5. Use the progress table below. After each phase, report what passed, what is unconfirmed, and the next action; stop and ask before continuing to the next phase. Always stop at a human GUI, credential, permission, destructive, or live-game gate.

## 2. Operating principles

1. Check first, change second. Discovery and verification commands come before create, copy, patch, or launch commands.
2. Use one logical operation per shell command. Do not chain unrelated commands with semicolons or hidden fallbacks.
3. Resolve actual CrossOver app path, CLI path, version, bottle path, game path, installer path, and artifact identity from the host.
4. Treat local files, state JSON, manifests, hashes, build labels, and command output as evidence. Draft history or README claims are not proof of a live result.
5. Do not collect game credentials. Stop at the account-login, map/login, macOS permission, or administrator prompt and ask the user to act.
6. After the raw-input overlay is deployed, launch only the generated Patcher and Settings launchers. Do not create or use a direct Game.app launcher.
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
| Step 5 | Installer GUI completed | User confirmation and setup path |
| Step 6 | Setup patch verified | patch-setup output and byte/hash evidence |
| Step 7 | Gecko and game configuration checked | check-gecko, configure, and optional keyboard output |
| Step 8 | Stock runtime probe completed | AFFECTED, CLOBBERED, and artifact verification |
| Step 9 | Runtime branch selected | Clean stock or overlay branch recorded |
| Step 10 | Overlay built, if required | Overlay manifest and post-probe evidence |
| Step 11 | Launchers built | Patcher and Settings launchers only |
| Step 12 | Live runtime verified | verify-live-runtime returns status=pass |

Status values:

- PASS: direct command output proves the checkpoint.
- UNCONFIRMED: the command or user action did not provide enough evidence.
- BLOCKED: a safety gate, missing input, failed verification, or unsupported state prevents continuation.
- N/A: the checkpoint does not apply, such as overlay build when the stock baseline is clean.

Do not report the whole installation as complete while Step 5, Step 8, or Step 12 is unconfirmed.

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
| ARTIFACT_DIR | Imported raw-input artifact cache | Required by the current stock probe contract |
| WIDTH, HEIGHT | User choice or current configuration | Explicitly confirm before writing game settings |
| OVERLAY_DIR | Build output and state | Required only when the baseline is affected |
| ERROR_TEXT | Exact user-reported symptom | Required when calling diagnose |

When a command prints a path, copy that exact path into the next command. Do not reconstruct macOS paths from a report.

## 5. Pre-flight and existing-state detection

Run from the repository root:

~~~zsh
scripts/uaro-crossover.zsh preflight --json
~~~

If the installer ZIP or extracted installer directory is already known, include one of:

~~~zsh
scripts/uaro-crossover.zsh preflight --installer-zip "$INSTALLER_ZIP" --json
scripts/uaro-crossover.zsh preflight --installer-dir "$INSTALLER_DIR" --json
~~~

When the raw-input source directory is already available, include it in the same pre-flight run:

~~~zsh
scripts/uaro-crossover.zsh preflight --installer-zip "$INSTALLER_ZIP" --rawinput-source-dir "$RAWINPUT_SOURCE_DIR" --json
~~~

Use --allow-missing-installer only for host-only diagnosis or when the user has explicitly chosen to complete installer staging later. It does not make installation ready.

Pre-flight must resolve or clearly report:

- Apple Silicon architecture and Rosetta availability.
- CrossOver app, version, bundled CLI, and bundled Wine.
- Bottle root and repository state directory.
- Required tools: zsh, Python 3, CrossOver CLI, file, shasum, and vmmap when live verification is requested.
- Whether the installer input exists and passes the expected member-name checks.
- Whether an artifact package is present and can be verified.

After pre-flight, inspect existing state:

~~~zsh
scripts/uaro-crossover.zsh bottle status --bottle "$BOTTLE_NAME"
~~~

If the bottle name is not known, list actual bottles first and ask the user to choose when more than one plausible bottle exists.

## 6. Phase A — host and artifact readiness

### Step 1 — Resolve CrossOver and Rosetta

Use the pre-flight output as the source of truth. Confirm the actual app build, CLI, Wine binary, bottle root, and architecture. If Rosetta is missing on Apple Silicon, stop and report the exact installation requirement.

Do not continue on a guessed CrossOver version or a CLI that belongs to another app installation.

### Step 2 — Import and verify the candidate artifact and installer

The current probe contract requires a candidate gepard-crossover-fix package before the stock probe can run. Import it before Step 8:

~~~zsh
scripts/uaro-crossover.zsh artifact import --source-dir "$RAWINPUT_SOURCE_DIR" --cache-dir "$ARTIFACT_DIR" --crossover-build "$CX_BUILD" --crossover-public-version "$CX_VERSION"
~~~

The candidate package must contain, at minimum:

- wow64win.dll
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

The user must complete the installer GUI, choose the intended game directory, and handle any CrossOver/macOS permission prompt. The AI must not enter or request game credentials.

After the GUI finishes, resolve the actual installed directory:

~~~zsh
scripts/uaro-crossover.zsh bottle status --bottle "$BOTTLE_NAME"
~~~

Record GAME_DIR and verify that both setup.exe and the expected uaRO files exist before Phase C.

## 8. Phase C — setup patch and game configuration

### Step 6 — Patch and verify setup.exe

The official client update and the setup.exe compatibility patch are separate operations. Confirm that SETUP_PATH is the installed file, not the staged UaRO_Setup.exe.

Run the hash-locked patch command:

~~~zsh
scripts/uaro-crossover.zsh patch-setup --setup "$SETUP_PATH"
~~~

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

If Gecko is missing, let CrossOver install it through its own supported path and re-run the check. Do not copy a random Gecko bundle.

Write the requested game resolution explicitly:

~~~zsh
scripts/uaro-crossover.zsh configure --game-dir "$GAME_DIR" --width "$WIDTH" --height "$HEIGHT" --state-file "$HOME/Library/Application Support/uaRO-CrossOver/state.json"
~~~

If the user requests keyboard compatibility settings:

~~~zsh
scripts/uaro-crossover.zsh configure-keyboard --bottle "$BOTTLE_NAME"
~~~

Re-run the relevant verification after each change. Resolution values are user configuration, not facts to infer from an old report.

## 9. Phase D — raw-input probe and runtime choice

### Step 8 — Run the stock probe

Run the probe against the unmodified CrossOver/Wine runtime, using the already verified candidate package:

~~~zsh
scripts/uaro-crossover.zsh overlay probe --bottle "$BOTTLE_NAME" --artifact-dir "$ARTIFACT_DIR"
~~~

The probe records at least:

- AFFECTED=yes|no
- CLOBBERED=0|1
- runtime=stock
- artifact and CrossOver build evidence

Interpretation:

| Probe result | Runtime route |
|---|---|
| AFFECTED=no and CLOBBERED=0 | Keep CrossOver stock Wine. Do not deploy an overlay. |
| AFFECTED=yes and CLOBBERED=0 | Build and verify the per-bottle overlay in Step 10. |
| CLOBBERED=1 | Stop. The baseline was modified or contaminated; do not infer a clean result. |
| Missing/invalid artifact or incomplete output | Stop as BLOCKED or UNCONFIRMED. |

The candidate DLL is not automatically deployed. It is only eligible for deployment if the stock probe reports AFFECTED=yes and all build, source, and hash gates pass.

### Step 9 — Select the runtime branch

If the baseline is clean, keep the recorded stock probe as the evidence that no overlay is required. The current overlay verify command is for an existing overlay, so do not invoke it on the clean branch. Step 10 is N/A.

If the baseline is affected, continue to Step 10. Never silently fall back to stock Wine after an affected baseline; live verification must block a stock or mixed route in that case.

## 10. Phase E — overlay, launchers, and live verification

### Step 10 — Build and verify the overlay only when required

For AFFECTED=yes, build the overlay from the exact verified candidate:

~~~zsh
scripts/uaro-crossover.zsh overlay build --bottle "$BOTTLE_NAME" --artifact-dir "$ARTIFACT_DIR"
~~~

Verify the resulting manifest and post-overlay probe:

~~~zsh
scripts/uaro-crossover.zsh artifact verify --artifact-dir "$ARTIFACT_DIR" --crossover-build "$CX_BUILD" --mode overlay
scripts/uaro-crossover.zsh overlay verify --bottle "$BOTTLE_NAME" --artifact-dir "$ARTIFACT_DIR"
~~~

The post-overlay probe must pass. A failed post-overlay probe blocks launcher creation.

### Step 11 — Build the safe launchers

Affected baseline, verified overlay:

~~~zsh
scripts/uaro-crossover.zsh build-launchers --bottle "$BOTTLE_NAME" --game-dir "$GAME_DIR" --overlay-dir "$OVERLAY_DIR"
~~~

Clean baseline, no overlay:

~~~zsh
scripts/uaro-crossover.zsh build-launchers --bottle "$BOTTLE_NAME" --game-dir "$GAME_DIR"
~~~

The clean-baseline command uses CrossOver's stock Wine only when the recorded baseline is clean. The affected-baseline command uses the verified per-bottle overlay.

Only these launchers are supported:

- UaRO CrossOver Patcher.app
- UaRO CrossOver Settings.app

The Patcher launcher applies setup.exe patch verification as needed before the game starts. It is the only supported game-launch route after an overlay has been deployed. No direct Game.app launcher is generated.

### Step 12 — Verify the live runtime

Launch the Patcher launcher manually and confirm that the user reaches the intended game/login screen. Then run:

~~~zsh
scripts/uaro-crossover.zsh verify-live-runtime --bottle "$BOTTLE_NAME" --game-dir "$GAME_DIR" --json
~~~

Accepted completion states:

- Overlay route: runtime=overlay and status=pass, with the expected overlay hashes.
- Clean stock route: runtime=stock and status=pass, with AFFECTED=no and CLOBBERED=0 recorded in state.

A running process with no readable runtime evidence is UNCONFIRMED. If the baseline was affected, runtime=stock or runtime=mixed is BLOCKED.

For diagnosis:

~~~zsh
scripts/uaro-crossover.zsh diagnose --bottle "$BOTTLE_NAME" --error "$ERROR_TEXT" --json
~~~

Never report fixed based only on launcher files or a generated manifest. The live runtime check is the completion gate.

## 11. Troubleshooting

### Gepard T Code 3::110::12

Separate the layers:

1. Confirm the correct CrossOver bottle and game directory.
2. Confirm setup.exe patch sites A/B/C.
3. Confirm the stock probe result.
4. If affected, confirm overlay post-probe pass.
5. Confirm the Patcher launcher was used.
6. Run live runtime verification.

If the process is stock or mixed after an affected baseline, relaunch through Patcher and stop treating the result as fixed. If the baseline was clean, a remaining code is not proof that the raw-input overlay is needed; inspect setup, account, server, and map-time causes separately.

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

Do not copy DLLs into the CrossOver app bundle or a shared system Wine prefix.

### Artifact or installer mismatch

Treat a missing file, unknown hash, wrong build, wrong installer member, or mixed directory as a hard stop. Ask the user for a matching source package or the exact missing evidence.

## 12. Repair, rollback, and uninstall

### Repair is diagnostic by default

This command checks state and reports repair candidates. It does not perform mechanical fixes:

~~~zsh
scripts/uaro-crossover.zsh repair --bottle "$BOTTLE_NAME"
~~~

Only use --fix when the user has explicitly asked to repair and the target scope is confirmed:

~~~zsh
scripts/uaro-crossover.zsh repair --bottle "$BOTTLE_NAME" --fix
~~~

Before --fix, record the current state and confirm the bottle, game directory, artifact, and intended repair scope. After --fix, rerun the relevant probe, artifact, launcher, and live-runtime checks. A repair report alone is not proof of a working installation.

### Rollback

For an overlay issue, remove or move only the named per-bottle overlay after preserving its manifest and state evidence. Never delete the CrossOver app, the entire bottle root, or unrelated bottles as a repair shortcut.

If the baseline was affected, do not claim that rollback to stock is safe; stock remains blocked until a new clean baseline probe is completed.

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

Report the result in this order:

1. Route used: CrossOver fresh install, existing state, repair, verify, or uninstall.
2. Actual CrossOver app/build, CLI, bottle, game directory, and runtime branch.
3. Progress table with PASS, N/A, UNCONFIRMED, and BLOCKED states.
4. Artifact identity and installer evidence.
5. Setup patch sites and configuration values.
6. Stock probe values: AFFECTED and CLOBBERED.
7. Overlay manifest and post-probe result, or why overlay was N/A.
8. Launcher paths; state explicitly that no direct Game launcher is supported.
9. Live verification result and remaining user action.
10. Evidence labels: 已确认, 根据证据推导, 未确认, 来源冲突, or 被阻断.

A complete installation requires Step 5 and Step 12 to be PASS. A clean stock result may mark Step 10 as N/A, but only when AFFECTED=no and CLOBBERED=0 are directly recorded.

## References

- README.md — user-facing overview, supported workflow, and evidence status.
- references/runtime-routing.md — stock, overlay, and mixed-runtime rules.
- references/raw-input-fix.md — artifact, probe, source, and hash gates.
- references/troubleshooting.md — symptom-oriented diagnosis.
- CHANGELOG.md — version history.
- LICENSE — repository license.
