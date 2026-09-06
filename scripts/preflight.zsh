#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
INSTALLER_DIR=""
MIN_FREE_GIB=15
JSON_OUTPUT=0
ALLOW_MISSING_INSTALLER=0

usage() {
  print "Usage: preflight.zsh --bottle NAME --installer-dir DIR [--json] [--allow-missing-installer]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --installer-dir) INSTALLER_DIR="$2"; shift 2 ;;
    --min-free-gib) MIN_FREE_GIB="$2"; shift 2 ;;
    --json) JSON_OUTPUT=1; shift ;;
    --allow-missing-installer) ALLOW_MISSING_INSTALLER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta

FREE_KIB="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
FREE_GIB=$(( FREE_KIB / 1024 / 1024 ))
(( FREE_GIB >= MIN_FREE_GIB )) || uo_die "only ${FREE_GIB} GiB free; need at least ${MIN_FREE_GIB} GiB"

BOTTLE_DIR="$(uo_bottle_dir)"
BOTTLE_STATUS="missing"
if [[ -d "$BOTTLE_DIR/drive_c" ]]; then
  BOTTLE_STATUS="present"
fi

typeset -a installer_names=(UaRO_Setup.exe UaRO_Setup-1.bin UaRO_Setup-2.bin)
typeset -a installer_hashes=()
INSTALLER_STATUS="missing"
if [[ -n "$INSTALLER_DIR" && -d "$INSTALLER_DIR" ]]; then
  INSTALLER_STATUS="complete"
  for name in "${installer_names[@]}"; do
    path="$INSTALLER_DIR/$name"
    if [[ ! -f "$path" ]]; then
      INSTALLER_STATUS="incomplete"
      break
    fi
    installer_hashes+=("$(uo_hash "$path")")
  done
fi

if [[ "$INSTALLER_STATUS" != "complete" && ! $ALLOW_MISSING_INSTALLER ]]; then
  uo_warn "installer preflight is not complete; supply the three uaRO installer files or use --allow-missing-installer for host-only inspection"
fi

if (( JSON_OUTPUT )); then
  python3 - "$BOTTLE_NAME" "$BOTTLE_DIR" "$INSTALLER_DIR" "$INSTALLER_STATUS" "$CX_APP" "$CX_VERSION" "$CX_BUILD" "$FREE_GIB" "${installer_hashes[@]}" <<'PY'
import json
import sys

bottle, bottle_dir, installer_dir, installer_status, cx_app, cx_version, cx_build, free_gib, *hashes = sys.argv[1:]
print(json.dumps({
    "bottle": bottle,
    "bottle_dir": bottle_dir,
    "installer_dir": installer_dir or None,
    "installer_status": installer_status,
    "installer_sha256": hashes,
    "crossover_app": cx_app,
    "crossover_version": cx_version,
    "crossover_build": cx_build,
    "host_arch": "arm64",
    "free_gib": int(free_gib),
}, indent=2, sort_keys=True))
PY
else
  uo_info "PASS: host=arm64 CrossOver=$CX_VERSION build=$CX_BUILD"
  uo_info "PASS: CrossOver wine=$CX_WINE"
  uo_info "PASS: CrossOver bottle CLI=$CX_BOTTLE"
  uo_info "PASS: free space=${FREE_GIB}GiB"
  uo_info "INFO: bottle=$BOTTLE_NAME status=$BOTTLE_STATUS path=$BOTTLE_DIR"
  uo_info "INFO: installer=$INSTALLER_STATUS dir=${INSTALLER_DIR:-not supplied}"
  if [[ "$INSTALLER_STATUS" == "complete" ]]; then
    for i in {1..3}; do
      uo_info "INFO: ${installer_names[$i]} sha256=${installer_hashes[$i]}"
    done
  fi
fi

if [[ "$INSTALLER_STATUS" == "complete" || $ALLOW_MISSING_INSTALLER ]]; then
  uo_write_state preflight pass
else
  uo_write_state preflight blocked
  exit 1
fi
