#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
DRY_RUN=0

usage() {
  print "Usage: configure-keyboard.zsh --bottle NAME [--dry-run]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta
uo_require_bottle

KEY='HKCU\Software\Wine\Mac Driver'
typeset -a VALUES=(LeftCommandIsCtrl RightCommandIsCtrl LeftOptionIsAlt RightOptionIsAlt)

if (( DRY_RUN )); then
  uo_info "DRY-RUN: would set CrossOver bottle keyboard mappings in $KEY"
  exit 0
fi

uo_info "INFO: stopping Wine processes for bottle $BOTTLE_NAME before registry update"
CX_BOTTLE="$BOTTLE_NAME" "$CX_ROOT/bin/wineserver" -k >/dev/null 2>&1 || true
for name in "${VALUES[@]}"; do
  "$CX_WINE" --wait --bottle "$BOTTLE_NAME" --cx-app 'C:\windows\system32\reg.exe' \
    ADD "$KEY" /v "$name" /t REG_SZ /d y /f >/dev/null
done

for name in "${VALUES[@]}"; do
  query="$($CX_WINE --wait --bottle "$BOTTLE_NAME" --cx-app 'C:\windows\system32\reg.exe' QUERY "$KEY" /v "$name" 2>&1)"
  print -- "$query" | grep -Eiq "${name}[[:space:]]+REG_SZ[[:space:]]+y" || \
    uo_die "registry verification failed for $name"
done

uo_state_merge_json "$(python3 - "$BOTTLE_NAME" <<'PY'
import json
import sys
print(json.dumps({"keyboard": {
    "status": "pass",
    "bottle": sys.argv[1],
    "values": {
        "LeftCommandIsCtrl": "y",
        "RightCommandIsCtrl": "y",
        "LeftOptionIsAlt": "y",
        "RightOptionIsAlt": "y",
    },
}}))
PY
)"
uo_write_state config keyboard-pass
uo_info "PASS: CrossOver keyboard registry mappings verified"
