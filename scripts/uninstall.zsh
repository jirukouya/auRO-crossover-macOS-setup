#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
LEVEL="game"
GAME_DIR=""
APPLICATIONS_DIR="/Applications"
CONFIRM=0

usage() {
  print "Usage: uninstall.zsh --level game|bottle --confirm [--bottle NAME] [--game-dir DIR] [--applications-dir DIR]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --level) LEVEL="$2"; shift 2 ;;
    --game-dir) GAME_DIR="$2"; shift 2 ;;
    --applications-dir) APPLICATIONS_DIR="$2"; shift 2 ;;
    --confirm) CONFIRM=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

(( CONFIRM )) || uo_die "uninstall requires explicit --confirm"
[[ "$LEVEL" == "game" || "$LEVEL" == "bottle" ]] || uo_die "level must be game or bottle"
uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta
uo_require_bottle

if [[ -z "$GAME_DIR" ]]; then
  GAME_DIR="$(uo_state_get game_dir 2>/dev/null || true)"
fi
if [[ -n "$GAME_DIR" ]]; then
  if [[ -e "$GAME_DIR" ]]; then
    GAME_DIR="$(uo_realpath "$GAME_DIR")"
    [[ "$GAME_DIR" == "$BOTTLE_DIR/drive_c/"* ]] || uo_die "game directory must be inside this bottle's drive_c: $GAME_DIR"
  elif [[ "$LEVEL" == "game" ]]; then
    uo_die "game directory does not exist: $GAME_DIR"
  else
    GAME_DIR=""
  fi
fi
[[ "$LEVEL" == "bottle" || -n "$GAME_DIR" ]] || uo_die "--game-dir is required for --level game"

STAMP="$(date +%Y%m%d-%H%M%S)"
TRASH_ROOT="$HOME/.Trash/uaRO-CrossOver-$STAMP"
BACKUP_ROOT="$HOME/uaRO-CrossOver-backups/$STAMP"
mkdir -p "$TRASH_ROOT"

backup_savedata() {
  [[ -n "$GAME_DIR" ]] || return 0
  savedata="$GAME_DIR/savedata"
  [[ -d "$savedata" ]] || return 0
  mkdir -p "$BACKUP_ROOT"
  cp -R "$savedata" "$BACKUP_ROOT/savedata"
  uo_info "PASS: backed up savedata to $BACKUP_ROOT/savedata"
}

move_launcher() {
  local app="$APPLICATIONS_DIR/$1.app"
  [[ -e "$app" ]] || return 0
  /bin/mv "$app" "$TRASH_ROOT/"
  uo_info "PASS: moved launcher to $TRASH_ROOT/"
}

backup_savedata
if [[ "$LEVEL" == "game" ]]; then
  [[ -d "$GAME_DIR" ]] || uo_die "game directory is not present: $GAME_DIR"
  target="$TRASH_ROOT/${GAME_DIR:t}"
  [[ ! -e "$target" ]] || uo_die "trash target already exists: $target"
  /bin/mv "$GAME_DIR" "$target"
  move_launcher "UaRO CrossOver Patcher"
  move_launcher "UaRO CrossOver Settings"
  uo_write_state uninstall game-removed
  uo_info "PASS: moved uaRO game directory to $target"
  uo_info "INFO: CrossOver bottle was retained"
else
  "$CX_BOTTLE" --bottle "$BOTTLE_NAME" --delete --force
  [[ ! -d "$BOTTLE_DIR" ]] || uo_die "CrossOver bottle still exists after deletion"
  move_launcher "UaRO CrossOver Patcher"
  move_launcher "UaRO CrossOver Settings"
  uo_write_state uninstall bottle-removed
  uo_info "PASS: deleted CrossOver bottle $BOTTLE_NAME"
  uo_info "INFO: CrossOver.app itself was not modified"
fi
