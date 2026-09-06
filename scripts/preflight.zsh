#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
INSTALLER_DIR=""
INSTALLER_ZIP=""
INSTALLER_CACHE_DIR="$HOME/Games/UaRO-Installer"
MIN_FREE_GIB=15
JSON_OUTPUT=0
ALLOW_MISSING_INSTALLER=0

usage() {
  print "Usage: preflight.zsh --bottle NAME (--installer-dir DIR | --installer-zip ZIP) [--installer-cache-dir DIR] [--json]"
  print "       preflight.zsh --bottle NAME --allow-missing-installer [--json]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --installer-dir) INSTALLER_DIR="$2"; shift 2 ;;
    --installer-zip) INSTALLER_ZIP="$2"; shift 2 ;;
    --installer-cache-dir) INSTALLER_CACHE_DIR="$2"; shift 2 ;;
    --min-free-gib) MIN_FREE_GIB="$2"; shift 2 ;;
    --json) JSON_OUTPUT=1; shift ;;
    --allow-missing-installer) ALLOW_MISSING_INSTALLER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -z "$INSTALLER_DIR" || -z "$INSTALLER_ZIP" ]] || uo_die "--installer-dir and --installer-zip are mutually exclusive"
INSTALLER_CACHE_DIR="${INSTALLER_CACHE_DIR:A}"

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta

HOST_ARCH="$(uname -m)"
FREE_KIB="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
FREE_GIB=$(( FREE_KIB / 1024 / 1024 ))
(( FREE_GIB >= MIN_FREE_GIB )) || uo_die "only ${FREE_GIB} GiB free; need at least ${MIN_FREE_GIB} GiB"

BOTTLE_DIR="$(uo_bottle_dir)"
BOTTLE_STATUS="missing"
if [[ -d "$BOTTLE_DIR/drive_c" ]]; then
  BOTTLE_STATUS="present"
fi

INSTALLER_STATUS="missing"
INSTALLER_TYPE="none"
INSTALLER_SOURCE=""
INSTALLER_REPORT="{}"

if [[ -n "$INSTALLER_ZIP" ]]; then
  INSTALLER_ZIP="$(uo_realpath "$INSTALLER_ZIP")" || uo_die "installer ZIP does not exist: $INSTALLER_ZIP"
  INSTALLER_TYPE="zip"
  INSTALLER_SOURCE="$INSTALLER_ZIP"
  if INSTALLER_REPORT="$(python3 "$SCRIPT_DIR/verify-installer.py" --zip "$INSTALLER_ZIP")"; then
    INSTALLER_STATUS="complete"
  else
    INSTALLER_STATUS="incomplete"
    INSTALLER_REPORT="{}"
  fi
elif [[ -n "$INSTALLER_DIR" ]]; then
  INSTALLER_DIR="$(uo_realpath "$INSTALLER_DIR")" || uo_die "installer directory does not exist: $INSTALLER_DIR"
  INSTALLER_TYPE="directory"
  INSTALLER_SOURCE="$INSTALLER_DIR"
  if INSTALLER_REPORT="$(python3 "$SCRIPT_DIR/verify-installer.py" --dir "$INSTALLER_DIR")"; then
    INSTALLER_STATUS="complete"
  else
    INSTALLER_STATUS="incomplete"
    INSTALLER_REPORT="{}"
  fi
fi

if [[ "$INSTALLER_STATUS" != "complete" && ! $ALLOW_MISSING_INSTALLER ]]; then
  uo_warn "installer preflight is not complete; supply the exact three installer members or use --allow-missing-installer for host-only inspection"
fi

if (( JSON_OUTPUT )); then
  python3 - "$BOTTLE_NAME" "$BOTTLE_DIR" "$INSTALLER_SOURCE" "$INSTALLER_TYPE" "$INSTALLER_STATUS" \
    "$INSTALLER_CACHE_DIR" "$CX_APP" "$CX_VERSION" "$CX_BUILD" "$HOST_ARCH" "$FREE_GIB" "$INSTALLER_REPORT" <<'PY'
import json
import sys

(
    bottle,
    bottle_dir,
    installer_source,
    installer_type,
    installer_status,
    installer_cache,
    cx_app,
    cx_version,
    cx_build,
    host_arch,
    free_gib,
    installer_report,
) = sys.argv[1:]
try:
    report = json.loads(installer_report)
except json.JSONDecodeError:
    report = None
print(json.dumps({
    "bottle": bottle,
    "bottle_dir": bottle_dir,
    "installer_source": installer_source or None,
    "installer_type": installer_type,
    "installer_status": installer_status,
    "installer_cache_dir": installer_cache,
    "installer": report,
    "crossover_app": cx_app,
    "crossover_version": cx_version,
    "crossover_build": cx_build,
    "host_arch": host_arch,
    "free_gib": int(free_gib),
}, indent=2, sort_keys=True))
PY
else
  uo_info "PASS: host=$HOST_ARCH CrossOver=$CX_VERSION build=$CX_BUILD"
  uo_info "PASS: Rosetta translation available"
  uo_info "PASS: CrossOver wine=$CX_WINE"
  uo_info "PASS: CrossOver bottle CLI=$CX_BOTTLE"
  uo_info "PASS: free space=${FREE_GIB}GiB"
  uo_info "INFO: bottle=$BOTTLE_NAME status=$BOTTLE_STATUS path=$BOTTLE_DIR"
  uo_info "INFO: installer=$INSTALLER_STATUS type=$INSTALLER_TYPE source=${INSTALLER_SOURCE:-not supplied}"
  if [[ "$INSTALLER_STATUS" == "complete" ]]; then
    python3 - "$INSTALLER_REPORT" <<'PY'
import json
import sys

report = json.loads(sys.argv[1])
print(f"PASS: installer source type={report['source_type']}")
if report["source_type"] == "zip":
    print(f"PASS: installer ZIP size={report['archive_size']} sha256={report['archive_sha256']}")
for member in report["members"]:
    detail = f"size={member['size']}"
    if "sha256" in member:
        detail += f" sha256={member['sha256']}"
    if "crc32" in member:
        detail += f" crc32={member['crc32']}"
    print(f"PASS: {member['name']} {detail}")
PY
  fi
fi

if [[ "$INSTALLER_STATUS" == "complete" || $ALLOW_MISSING_INSTALLER ]]; then
  uo_write_state preflight pass
else
  uo_write_state preflight blocked
fi

PATCH_JSON="$(python3 - "$INSTALLER_REPORT" "$INSTALLER_SOURCE" "$INSTALLER_ZIP" "$INSTALLER_DIR" "$INSTALLER_CACHE_DIR" "$INSTALLER_STATUS" "$INSTALLER_TYPE" <<'PY'
import json
import sys

report, source, zip_path, directory, cache_dir, status, source_type = sys.argv[1:]
try:
    report_value = json.loads(report)
except json.JSONDecodeError:
    report_value = None
print(json.dumps({
    "installer_source": source or None,
    "installer_zip": zip_path or None,
    "installer_dir": directory or None,
    "installer_cache_dir": cache_dir,
    "installer_type": source_type,
    "installer_status": status,
    "installer_report": report_value,
    "installer_stage": "pending" if status == "complete" else "blocked",
}))
PY
)"
uo_state_merge_json "$PATCH_JSON"

[[ "$INSTALLER_STATUS" == "complete" || $ALLOW_MISSING_INSTALLER ]] || exit 1
