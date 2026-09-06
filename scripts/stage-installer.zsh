#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
INSTALLER_DIR=""
RUN_INSTALLER=0

usage() {
  print "Usage: stage-installer.zsh --bottle NAME --installer-dir DIR [--run]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --installer-dir) INSTALLER_DIR="$2"; shift 2 ;;
    --run) RUN_INSTALLER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -n "$INSTALLER_DIR" ]] || uo_die "--installer-dir is required"
[[ -d "$INSTALLER_DIR" ]] || uo_die "installer directory does not exist: $INSTALLER_DIR"
uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_bottle

typeset -a names=(UaRO_Setup.exe UaRO_Setup-1.bin UaRO_Setup-2.bin)
STAGE_DIR="$BOTTLE_DIR/drive_c/UaROInstaller"
mkdir -p "$STAGE_DIR"

for name in "${names[@]}"; do
  source_path="$INSTALLER_DIR/$name"
  target_path="$STAGE_DIR/$name"
  [[ -f "$source_path" ]] || uo_die "missing installer sibling: $source_path"
  if [[ -e "$target_path" ]]; then
    cmp -s "$source_path" "$target_path" || uo_die "staged file differs; remove or inspect it before restaging: $target_path"
  else
    cp -p "$source_path" "$target_path"
  fi
  cmp -s "$source_path" "$target_path" || uo_die "byte comparison failed after staging: $name"
  uo_info "PASS: staged $name sha256=$(uo_hash "$target_path")"
done

uo_write_state installer staged

if (( RUN_INSTALLER )); then
  uo_info "Opening the interactive uaRO installer in CrossOver. Complete only the user-level/default installation choices."
  caffeinate -i "$CX_WINE" --bottle "$BOTTLE_NAME" --workdir "$STAGE_DIR" --cx-app 'C:\UaROInstaller\UaRO_Setup.exe'
  GAME_DIR="$(uo_find_game_dir)" || uo_die "installer exited but uaRO.exe was not found in the bottle"
  uo_info "PASS: uaRO game directory: $GAME_DIR"
  uo_write_state installer complete
else
  uo_info "PASS: installer siblings staged at $STAGE_DIR"
  uo_info "Next action: rerun with --run to open the interactive installer."
fi
