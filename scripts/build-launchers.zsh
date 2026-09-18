#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
GAME_DIR=""
OVERLAY_DIR=""
APPLICATIONS_DIR="/Applications"
REPLACE=0
OVERLAY_REQUESTED=0

usage() {
  print "Usage: build-launchers.zsh --bottle NAME --game-dir DIR [--overlay-dir DIR] [--applications-dir DIR] [--replace]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --game-dir) GAME_DIR="$2"; shift 2 ;;
    --overlay-dir) OVERLAY_DIR="$2"; OVERLAY_REQUESTED=1; shift 2 ;;
    --applications-dir) APPLICATIONS_DIR="$2"; shift 2 ;;
    --replace) REPLACE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -n "$GAME_DIR" ]] || uo_die "--game-dir is required"
uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta
uo_require_bottle
GAME_DIR="$(uo_realpath "$GAME_DIR")" || uo_die "game directory does not exist: $GAME_DIR"
[[ -d "$GAME_DIR" ]] || uo_die "game directory is not a directory: $GAME_DIR"

if (( ! OVERLAY_REQUESTED )); then
  state_overlay_dir="$(uo_state_get overlay_dir 2>/dev/null || true)"
  if [[ -n "$state_overlay_dir" && "$(uo_state_get overlay_probe_after 2>/dev/null || true)" == "pass" ]]; then
    OVERLAY_DIR="$state_overlay_dir"
  fi
fi
RUNTIME_MODE=""
WINE_CMD=""
if [[ -n "$OVERLAY_DIR" ]]; then
  OVERLAY_DIR="$(uo_realpath "$OVERLAY_DIR")" || uo_die "overlay directory does not exist: $OVERLAY_DIR"
  [[ "$(uo_state_get overlay_probe_after 2>/dev/null || true)" == "pass" ]] || \
    uo_die "overlay has not passed the after-probe; refusing to create launchers"
  [[ -f "$OVERLAY_DIR/overlay-manifest.json" ]] || uo_die "overlay manifest is missing: $OVERLAY_DIR/overlay-manifest.json"
  [[ -x "$OVERLAY_DIR/bin/wine" ]] || uo_die "overlay wine wrapper is missing: $OVERLAY_DIR/bin/wine"
  WINE_CMD="$OVERLAY_DIR/bin/wine"
  RUNTIME_MODE="overlay"
else
  [[ "$(uo_state_get overlay_probe_before 2>/dev/null || true)" == "pass" ]] || \
    uo_die "run the stock raw-input probe before creating a stock-runtime launcher"
  [[ "$(uo_state_get overlay_probe_before_affected 2>/dev/null || true)" == "no" ]] || \
    uo_die "stock probe is affected; build and verify the per-bottle overlay before creating launchers"
  [[ "$(uo_state_get overlay_probe_before_clobbered 2>/dev/null || true)" == "0" ]] || \
    uo_die "stock probe reported clobbered entries; build and verify the per-bottle overlay before creating launchers"
  WINE_CMD="$CX_WINE"
  RUNTIME_MODE="stock"
fi

PATCHER_PATH="$(find "$GAME_DIR" -type f \( -iname 'UaRO Patcher.exe' -o -iname 'UaRo Patcher.exe' \) -print -quit 2>/dev/null)"
SETUP_PATH="$(find "$GAME_DIR" -type f -iname 'setup.exe' -print -quit 2>/dev/null)"
[[ -n "$PATCHER_PATH" ]] || uo_die "UaRO Patcher.exe was not found below $GAME_DIR"
[[ -n "$SETUP_PATH" ]] || uo_die "setup.exe was not found below $GAME_DIR"

win_path() {
  python3 - "$BOTTLE_DIR/drive_c" "$1" <<'PY'
import sys
from pathlib import Path

drive_c = Path(sys.argv[1]).resolve()
path = Path(sys.argv[2]).resolve()
try:
    relative = path.relative_to(drive_c)
except ValueError:
    raise SystemExit(f"ERROR: game path is outside bottle drive_c: {path}")
print("C:\\" + str(relative).replace("/", "\\"))
PY
}

PATCHER_WIN="$(win_path "$PATCHER_PATH")"
SETUP_WIN="$(win_path "$SETUP_PATH")"
mkdir -p "$APPLICATIONS_DIR"

create_launcher() {
  local display_name="$1"
  local bundle_id="$2"
  local executable_name="$3"
  local app_win="$4"
  local bundle="$APPLICATIONS_DIR/$display_name.app"
  local macos_dir="$bundle/Contents/MacOS"
  local resources_dir="$bundle/Contents/Resources"

  if [[ -e "$bundle" ]]; then
    (( REPLACE )) || uo_die "launcher already exists; pass --replace to rebuild: $bundle"
    /bin/rm -rf "$bundle"
  fi
  mkdir -p "$macos_dir" "$resources_dir"
  cp "$SCRIPT_DIR/patch-setup.py" "$resources_dir/patch-setup.py"
  cp "$SCRIPT_DIR/setup_profiles.py" "$resources_dir/setup_profiles.py"
  python3 - "$macos_dir/$executable_name" "$bundle/Contents/Info.plist" \
    "$display_name" "$bundle_id" "$executable_name" "$BOTTLE_NAME" "$GAME_DIR" \
    "$WINE_CMD" "$RUNTIME_MODE" "$app_win" "$SETUP_WIN" "$SETUP_PATH" <<'PY'
import plistlib
import sys
from pathlib import Path

launcher_path, plist_path, display, bundle_id, executable, bottle, game_dir, wine, runtime_mode, app_win, setup_win, setup_path = sys.argv[1:]
launcher = r'''#!/bin/zsh
set -euo pipefail
MACOS_DIR="${0:A:h}"
APP_ROOT="${MACOS_DIR:h:h}"
GAME_DIR="__GAME_DIR__"
BOTTLE_NAME="__BOTTLE_NAME__"
WINE_CMD="__WINE_CMD__"
RUNTIME_MODE="__RUNTIME_MODE__"
APP_WIN="__APP_WIN__"
SETUP_WIN="__SETUP_WIN__"
SETUP_PATH="__SETUP_PATH__"
PATCH_SCRIPT="$APP_ROOT/Contents/Resources/patch-setup.py"
STATE_FILE="$HOME/Library/Application Support/uaRO-CrossOver/state.json"
LOG_DIR="$HOME/Library/Application Support/uaRO-CrossOver/logs"
mkdir -p "$LOG_DIR"
LAUNCH_LOG="$LOG_DIR/launcher-$(date +%Y%m%d-%H%M%S).log"

[[ -d "$GAME_DIR" ]] || { print -u2 -- "uaRO game directory is missing: $GAME_DIR"; exit 1; }
[[ -x "$WINE_CMD" ]] || { print -u2 -- "CrossOver Wine runtime is missing: $WINE_CMD"; exit 1; }
cd "$GAME_DIR"
python3 "$PATCH_SCRIPT" --setup "$SETUP_PATH" --state-file "$STATE_FILE"
print -- "launcher=$0 bottle=$BOTTLE_NAME game_dir=$GAME_DIR wine=$WINE_CMD" | tee "$LAUNCH_LOG"
"$WINE_CMD" --bottle "$BOTTLE_NAME" --workdir "$GAME_DIR" --cx-app "$APP_WIN" >>"$LAUNCH_LOG" 2>&1 &
CHILD_PID=$!
python3 - "$STATE_FILE" "$0" "$CHILD_PID" "$LAUNCH_LOG" "$GAME_DIR" "$WINE_CMD" "$RUNTIME_MODE" <<'STATEPY'
import json, os, sys, tempfile
from datetime import datetime, timezone
from pathlib import Path
path, launcher, pid, log, game_dir, wine, runtime_mode = sys.argv[1:]
try: state = json.loads(Path(path).read_text(encoding="utf-8"))
except (FileNotFoundError, json.JSONDecodeError): state = {}
state.setdefault("schema", 2)
state["launch"] = {"launcher": launcher, "pid": int(pid), "launch_path": "patcher_launcher",
    "runtime": runtime_mode, "runtime_anchor": "pending", "started_at": datetime.now(timezone.utc).isoformat(),
    "log": log, "game_dir": game_dir, "wine": wine}
Path(path).parent.mkdir(parents=True, exist_ok=True)
fd, tmp = tempfile.mkstemp(prefix=".state.", suffix=".part", dir=Path(path).parent)
with os.fdopen(fd, "w", encoding="utf-8") as handle:
    json.dump(state, handle, indent=2, sort_keys=True); handle.write("\n"); handle.flush(); os.fsync(handle.fileno())
os.replace(tmp, path)
STATEPY
print -- "PID=$CHILD_PID; verify with: uaro-crossover.zsh verify-live-runtime --bottle $BOTTLE_NAME --json"
set +e
wait "$CHILD_PID"
RC=$?
set -e
python3 - "$STATE_FILE" "$RC" <<'EXITPY'
import json, sys
from pathlib import Path
path, rc = sys.argv[1:]
try: state = json.loads(Path(path).read_text(encoding="utf-8"))
except (FileNotFoundError, json.JSONDecodeError): state = {}
state.setdefault("launch", {})["last_exit_code"] = int(rc)
Path(path).write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
EXITPY
exit "$RC"
'''
for token, value in {
    "__GAME_DIR__": game_dir,
    "__BOTTLE_NAME__": bottle,
    "__WINE_CMD__": wine,
    "__RUNTIME_MODE__": runtime_mode,
    "__APP_WIN__": app_win,
    "__SETUP_WIN__": setup_win,
    "__SETUP_PATH__": setup_path,
}.items():
    launcher = launcher.replace(token, value)
Path(launcher_path).write_text(launcher, encoding="utf-8")
Path(launcher_path).chmod(0o755)
plist = {
    "CFBundleDisplayName": display,
    "CFBundleExecutable": executable,
    "CFBundleIdentifier": bundle_id,
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": display,
    "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": "0.2.1",
    "CFBundleVersion": "0.2.1",
    "LSMinimumSystemVersion": "13.0",
    "NSHighResolutionCapable": True,
}
with open(plist_path, "wb") as handle:
    plistlib.dump(plist, handle, sort_keys=False)
PY
  zsh -n "$macos_dir/$executable_name"
  plutil -lint "$bundle/Contents/Info.plist" >/dev/null
  codesign --force --deep --sign - "$bundle" >/dev/null
  codesign --verify --deep --strict "$bundle" >/dev/null
  uo_info "PASS: signed launcher $bundle"
}

create_launcher "UaRO CrossOver Patcher" "com.jirukouya.uaro.crossover.patcher" \
  "UaRO CrossOver Patcher" "$PATCHER_WIN"
create_launcher "UaRO CrossOver Settings" "com.jirukouya.uaro.crossover.settings" \
  "UaRO CrossOver Settings" "$SETUP_WIN"

GAME_DIR="$GAME_DIR"
uo_write_state launchers built
uo_info "INFO: launcher runtime=$RUNTIME_MODE"
uo_info "PASS: created the two supported launchers under $APPLICATIONS_DIR"
uo_info "INFO: no direct game launcher was created"
