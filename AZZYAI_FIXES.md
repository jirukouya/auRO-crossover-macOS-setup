# Installing and fixing AzzyAI on uaRO through CrossOver

AzzyAI is a third-party Lua AI for controlling a mercenary or homunculus. This guide uses the same uaRO-tested installation and targeting fixes as the Whisky workflow: **Phase A (Steps 1–5)** installs AzzyAI, then **Phase B (Steps 6–10)** fixes the private-server targeting problem where it follows but never attacks.

Only the path and launcher rules are CrossOver-specific. Use the `GAME_DIR` already verified by the main CrossOver Skill, and always start the game through the supported `UaRO CrossOver Patcher.app`. Do not substitute a Whisky path, guess a bottle, or copy files into `/Applications/CrossOver.app`.

## Phase A — Installing AzzyAI (Steps 1–5)

## Step 1 — Download AzzyAI

**Source: [github.com/SpenceKonde/AzzyAI](https://github.com/SpenceKonde/AzzyAI)** — the author's own repository remains the canonical source even though it is no longer actively maintained and has no packaged Releases. Download the repository archive, not a random forum re-upload:

~~~zsh
curl -fL --progress-bar -o "$HOME/Downloads/AzzyAI-master.zip" \
  https://github.com/SpenceKonde/AzzyAI/archive/refs/heads/master.zip
~~~

The user may instead use the repository's **Code → Download ZIP** button. Record the archive hash before extracting it so a later repair report can identify the exact downloaded file:

~~~zsh
shasum -a 256 "$HOME/Downloads/AzzyAI-master.zip"
~~~

## Step 2 — Locate the CrossOver game's `USER_AI` folder

Do not search the entire home directory. The main CrossOver Skill has already resolved the current bottle's real `GAME_DIR`; the AI directory must be inside it:

~~~zsh
USER_AI_DIR="$GAME_DIR/AI/USER_AI"
[[ -d "$USER_AI_DIR" ]] || { print -u2 -- "USER_AI is missing from the verified game directory: $USER_AI_DIR"; exit 1; }
~~~

Confirm this directory is inside `GAME_DIR` and contains the expected default AI files before changing anything. The game root (`GAME_DIR`), not `USER_AI`, holds `AAIStartM.txt`, `AAIStartH.txt`, and `AAI_ERROR.log` used later for verification.

## Step 3 — Extract, back up, and copy the right files

**Extract to a scratch folder first, then copy — never extract directly over `USER_AI`.** The GitHub zip has an extra directory level: it expands to `AzzyAI-master/USER_AI/<the actual .lua files, AzzyAIConfig.exe, Documentation.pdf>`. What must land in the real game folder is the *contents* of `AzzyAI-master/USER_AI/`, not `AzzyAI-master` itself and not a nested `USER_AI` directory.

~~~zsh
AZZY_EXTRACT_DIR="${TMPDIR:-/tmp}/azzyai-crossover-extract"
mkdir -p "$AZZY_EXTRACT_DIR"
ditto -xk "$HOME/Downloads/AzzyAI-master.zip" "$AZZY_EXTRACT_DIR"
[[ -d "$AZZY_EXTRACT_DIR/AzzyAI-master/USER_AI" ]] || { print -u2 -- "AzzyAI archive has an unexpected layout"; exit 1; }
~~~

Before copying, ask whether the player wants to replace the existing AI. A fresh uaRO `USER_AI` already contains default mercenary/homunculus AI files (`AI_M.lua` and `AI.lua`, among others). Most players choosing AzzyAI want to replace them, but do not assume.

After the user confirms, create a recoverable backup and copy the AzzyAI contents:

~~~zsh
AZZY_INSTALL_BACKUP_DIR="${USER_AI_DIR}.before-azzyai-$(date +%Y%m%d-%H%M%S)"
cp -R "$USER_AI_DIR" "$AZZY_INSTALL_BACKUP_DIR"
cp -R "$AZZY_EXTRACT_DIR/AzzyAI-master/USER_AI/." "$USER_AI_DIR/"
~~~

Report the backup path. Do not copy into another CrossOver bottle, a shared Wine prefix, or the CrossOver app bundle.

## Step 4 — Activate AzzyAI in-game

**This step is easy to skip.** Files in `USER_AI` do not mean AzzyAI is active. Record the activation time, then ask the user to:

1. Launch the game through `UaRO CrossOver Patcher.app` and log in to the character that should use AzzyAI.
2. Type `/merai` for a mercenary or `/hoai` for a homunculus, repeating if needed until the game confirms that the AI is customized.
3. Summon the mercenary/homunculus, or relog if a homunculus is already out, so it loads the new AI.

Set `ACTIVATION_STARTED_AT="$(date +%s)"` immediately before this user-controlled step and record whether the user activated a mercenary or homunculus.

## Step 5 — Verify the install

Do not trust Step 4 without evidence. Select the matching log after the user confirms activation:

~~~zsh
STARTUP_LOG="$GAME_DIR/AAIStartM.txt" # use AAIStartH.txt for a homunculus
[[ -f "$STARTUP_LOG" ]] || { print -u2 -- "AzzyAI startup log was not created: $STARTUP_LOG"; exit 1; }
[[ "$(stat -f %m "$STARTUP_LOG")" -ge "$ACTIVATION_STARTED_AT" ]] || { print -u2 -- "AzzyAI startup log predates this activation"; exit 1; }
~~~

The matching startup log must exist in the game root, not `USER_AI`, and must be newer than the activation. If it does not, AzzyAI is not confirmed as running; inspect the verified path and activation before continuing.

**What almost certainly happens next on uaRO:** the mercenary/homunculus may follow but not attack. This is expected on private servers, not an installation mistake. Continue directly into Phase B and check all five steps together.

The GitHub source is not guaranteed byte-identical to the historical `AzzyAI 1.551` package used during the original diagnosis, but the fixes below are located by code pattern, never a hard-coded line number.

## Phase B — Fixing “installs fine, but never attacks” (Steps 6–10)

AzzyAI was written for official Gravity server assumptions. uaRO is rAthena-class and can allocate actor IDs differently, so AzzyAI can classify real monsters as players. The same shared `AI_main.lua` and `AzzyUtil.lua` paths serve both the mercenary and homunculus AI, while `M_*.lua` and `H_*.lua` configuration files are separate.

Before editing, back up every Lua file that will change. Do not rely only on the Phase A directory backup because an existing AzzyAI repair may skip installation entirely:

~~~zsh
AZZY_REPAIR_BACKUP_DIR="${USER_AI_DIR}.before-uaro-targeting-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$AZZY_REPAIR_BACKUP_DIR"
for AZZY_FILE in AI_main.lua AzzyUtil.lua M_Config.lua H_Config.lua; do
  [[ -f "$USER_AI_DIR/$AZZY_FILE" ]] && cp -p "$USER_AI_DIR/$AZZY_FILE" "$AZZY_REPAIR_BACKUP_DIR/$AZZY_FILE"
done
~~~

Lua files are loaded when the mercenary/homunculus initializes. After edits, the user must relog or resummon before testing. Steps 9 and 10 are independent code paths: applying only one can still leave the AI unable to attack.

## Step 6 — `Const_.lua` version-check false positive

**File: `AI/USER_AI/Const_.lua`. No fix needed.** AzzyAI's `"1.552"` version can be logged as `"1.55"` by its own version-check regex, producing a cosmetic “wrong version” or “ranged pierce exploit” warning in `AAIStartM.txt` or `AAIStartH.txt`. It does not gate AI logic. Record it and continue.

## Step 7 — Fix `StickyStandby`

**File: `AI/USER_AI/M_Config.lua`** for a mercenary, or **`H_Config.lua`** for a homunculus. AzzyAI's stock `StickyStandby=1` can force an AI that is following its owner into non-aggressive standby.

Unless the user explicitly wants defend-only behavior, set:

~~~lua
StickyStandby = 0
~~~

## Step 8 — Fix `AutoDetectPlant` temporarily

In the same configuration file, AzzyAI's stock `AutoDetectPlant=1` can ignore a monster that appears to be stationary. This is a behavior filter, not actual species detection.

Set this while verifying Steps 9–10:

~~~lua
AutoDetectPlant = 0
~~~

Once the AI attacks correctly, this becomes a preference:

- Keep `0` for active farming, including stationary monsters.
- Restore `1` to skip monsters that remain stationary, understanding that ordinary monsters may also be skipped until they move.

## Step 9 — Patch `AI_main.lua` player/monster misclassification

**File: `AI/USER_AI/AI_main.lua`.** Search for the code pattern; do not trust a line number:

~~~lua
-- before:
if (v > MagicNumber2) then
    Players[v]=1
-- after:
if (v > MagicNumber2 and IsMonster(v)==0) then --uaRO monster IDs also exceed MagicNumber2
    Players[v]=1
~~~

The original condition treats every actor ID above `MagicNumber2` (100,000) as a player. uaRO monster GIDs can also exceed that threshold, so real monsters never enter `Targets[]`.

If the after-pattern is already present, record Step 9 as already applied. If neither pattern appears, stop and report an AzzyAI version mismatch instead of patching by line number.

## Step 10 — Patch `AzzyUtil.lua` `IsPlayer()`

**File: `AI/USER_AI/AzzyUtil.lua`.** Find the `IsPlayer()` function:

~~~lua
-- before:
function IsPlayer(id)
	if (id>MagicNumber2) then
		return 1
	else
		return 0
	end
end
-- after:
function IsPlayer(id)
	if (id>MagicNumber2 and IsMonster(id)==0) then --same fix as AI_main.lua's classification loop
		return 1
	else
		return 0
	end
end
~~~

`GetTact()` calls this independent function. Even if Step 9 allows a monster into `Targets[]`, this function can still reject it as a player. Apply or confirm both Step 9 and Step 10.

## Optional: engagement range for active farming

For aggressive auto-farming, keep the chase bound at least as large as the detection distance in `M_Config.lua` or `H_Config.lua`:

~~~lua
StationaryAggroDist  = 12
MobileAggroDist      = 12
StationaryMoveBounds = 14
MobileMoveBounds     = 14
~~~

AzzyAI's stock values are `12/7/14/9`, which are internally consistent but use a narrower range while moving. Do not change these preferences unless the user asks.

## How to verify and diagnose

AzzyAI provides a useful debug switch. In `M_Extra.lua` or `H_Extra.lua`, temporarily uncomment:

~~~lua
LogEnable["AAI_ACTORS"]=1
~~~

After the user relogs or resummons, `AAI_ACTORS.log` in `GAME_DIR` records newly seen actor IDs, type, position, and the engine's `IsMonster()` result. This can confirm whether the server's monster IDs exceed `MagicNumber2` while the engine still recognizes them as monsters.

Turn the logging line back off after testing. If the actor log proves monsters are recognized but the AI still does not attack, a temporary probe after `SelectEnemy(GetEnemyList(MyID,aggro))` in `AI_main.lua` can log `aggro`, `HPPercent(MyID)`, `ShouldStandby`, `StickyStandby`, and the returned target count. Remove all temporary probes after diagnosis. Do not use `GetV(V_HOMUNTYPE, v)` as a mercenary probe; that engine call is not safe in a mercenary AI context.

## Ignoring specific monsters by species

AzzyAI supports a per-species tactics entry in `M_Tactics.lua` or `H_Tactics.lua`:

~~~lua
MyTact[classID]={TACT_IGNORE,SKILL_ALWAYS,KITE_NEVER,CAST_REACT,PUSH_SELF,DEBUFF_NEVER,CLASS_BOTH,RESCUE_OWNER,-1,SNIPE_OK,KS_NEVER,1,CHASE_NORMAL} --monster name
~~~

`classID` is a monster species/database ID, not the changing actor GID. This works directly for a homunculus. A mercenary without a homunculus cannot reliably obtain a species ID: `GetV(V_HOMUNTYPE, v)` is only usable from a homunculus AI context, while mercenary fallback classification is too generic.

For a mercenary with a homunculus nearby, set `LiveMobID = 1` in both `H_Config.lua` and `M_Config.lua`. The homunculus can maintain `AI/USER_AI/MobID.lua` with GID-to-species data that the mercenary uses. This requires a homunculus-capable class such as Alchemist or Genetic; do not assume every mercenary player has this option.

In a pure mercenary setup, calling `GetV(V_HOMUNTYPE, v)` from the mercenary context can fail at the engine level instead of returning a usable value. Without `MobID[GID]` data, `GetClass()` only provides broad categories such as normal, summoned, or plant, not a real species ID. Do not silently enable a species tactic in that situation.

Without a homunculus-capable class, use `AutoDetectPlant=1` as the approximate fallback for ignoring monsters that remain stationary. It is behavior-based, not a true species ignore list: an ordinary monster that spawns still can also be skipped, and a monster that moves can become attackable.

## Reapplying after an AzzyAI reinstall

Copying a fresh AzzyAI archive over `USER_AI` restores stock `AI_main.lua`, `AzzyUtil.lua`, `M_Config.lua`, and `H_Config.lua`. If AzzyAI is reinstalled, repeat Steps 7–10 and the reload/attack verification. Step 6 still requires no change.

## Completion evidence

Report these four states separately:

1. AzzyAI archive downloaded and its SHA-256 recorded.
2. Existing `USER_AI` backed up and AzzyAI files copied to the verified CrossOver game directory.
3. User activated `/merai` or `/hoai`, reloaded the AI, and produced a fresh matching startup log.
4. User confirmed that the mercenary or homunculus selected and attacked a nearby valid monster.

Do not report AzzyAI as working until all applicable states are confirmed.
