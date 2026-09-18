#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
GAME_DIR=""
TARGET="patcher"

usage() {
  print "Usage: launch-patcher.zsh --bottle NAME [--game-dir DIR] [--setup]"
  print "Launch UaRo Patcher.exe or setup.exe through CrossOver's bundled wine wrapper."
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --game-dir) GAME_DIR="$2"; shift 2 ;;
    --setup) TARGET="setup"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta
uo_require_bottle
GAME_DIR="${GAME_DIR:-$(uo_state_get game_dir 2>/dev/null || true)}"
if [[ -z "$GAME_DIR" ]]; then
  GAME_DIR="$(uo_find_game_dir || true)"
fi
[[ -n "$GAME_DIR" ]] || uo_die "game directory is unknown; pass --game-dir"
GAME_DIR="$(uo_realpath "$GAME_DIR")" || uo_die "game directory does not exist: $GAME_DIR"

if [[ "$TARGET" == "setup" ]]; then
  EXE="$(find "$GAME_DIR" -type f -iname 'setup.exe' -print -quit)"
  [[ -n "$EXE" ]] || uo_die "setup.exe was not found in $GAME_DIR"
else
  EXE="$(find "$GAME_DIR" -type f \( -iname 'UaRO Patcher.exe' -o -iname 'UaRo Patcher.exe' \) -print -quit)"
  [[ -n "$EXE" ]] || uo_die "UaRo Patcher.exe was not found in $GAME_DIR"
fi

GAME_WIN="$(python3 - "$BOTTLE_DIR/drive_c" "$GAME_DIR" <<'PY'
import sys
from pathlib import Path
drive_c = Path(sys.argv[1]).resolve()
path = Path(sys.argv[2]).resolve()
relative = path.relative_to(drive_c)
print("C:\\" + str(relative).replace("/", "\\"))
PY
)"
EXE_WIN="$(python3 - "$BOTTLE_DIR/drive_c" "$EXE" <<'PY'
import sys
from pathlib import Path
drive_c = Path(sys.argv[1]).resolve()
path = Path(sys.argv[2]).resolve()
relative = path.relative_to(drive_c)
print("C:\\" + str(relative).replace("/", "\\"))
PY
)"

uo_info "INFO: launching $EXE_WIN via $CX_WINE (workdir=$GAME_WIN)"
exec "$CX_WINE" --bottle "$BOTTLE_NAME" --workdir "$GAME_WIN" --cx-app "$EXE_WIN"
