#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
INSTALLER_DIR=""
INSTALLER_ZIP=""
RAWINPUT_SOURCE_DIR=""
INSTALLER_CACHE_DIR="$HOME/Games/UaRO-Installer"
MIN_FREE_GIB=15
JSON_OUTPUT=0
ALLOW_MISSING_INSTALLER=0

usage() {
  print "Usage: preflight.zsh --bottle NAME (--installer-dir DIR | --installer-zip ZIP) [--rawinput-source-dir DIR] [--installer-cache-dir DIR] [--json]"
  print "       preflight.zsh --bottle NAME --allow-missing-installer [--rawinput-source-dir DIR] [--json]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --installer-dir) INSTALLER_DIR="$2"; shift 2 ;;
    --installer-zip) INSTALLER_ZIP="$2"; shift 2 ;;
    --rawinput-source-dir) RAWINPUT_SOURCE_DIR="$2"; shift 2 ;;
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
RAWINPUT_SOURCE_DIR="${RAWINPUT_SOURCE_DIR:-}"

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
STATE_FILE_PATH="$(uo_state_file)"
# Prepare the user-local state directory before checking writability. A clean
# install may have no prior state directory at all; creating this narrow
# directory avoids turning that normal first-run condition into UNCONFIRMED.
if [[ ! -d "${STATE_FILE_PATH:h}" ]]; then
  mkdir -p "${STATE_FILE_PATH:h}" 2>/dev/null || true
fi
STATE_STATUS="unconfirmed"
if uo_state_writable; then
  STATE_STATUS="pass"
fi
CROSSOVER_SIGNATURE_STATUS="unconfirmed"
if codesign --verify --deep --strict "$CX_APP" >/dev/null 2>&1; then
  CROSSOVER_SIGNATURE_STATUS="pass"
fi

INSTALLER_STATUS="missing"
INSTALLER_TYPE="none"
INSTALLER_SOURCE=""
INSTALLER_REPORT="{}"
RAWINPUT_STATUS="not-supplied"
RAWINPUT_REPORT="{}"

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

if [[ -n "$RAWINPUT_SOURCE_DIR" ]]; then
  RAWINPUT_SOURCE_DIR="$(uo_realpath "$RAWINPUT_SOURCE_DIR")" || uo_die "raw-input artifact source directory does not exist: $RAWINPUT_SOURCE_DIR"
  if RAWINPUT_REPORT="$(python3 "$SCRIPT_DIR/artifact.py" inspect --source-dir "$RAWINPUT_SOURCE_DIR" --crossover-build "$CX_BUILD" --crossover-public-version "$CX_VERSION")"; then
    RAWINPUT_STATUS="candidate"
  else
    RAWINPUT_STATUS="invalid"
    RAWINPUT_REPORT="{}"
    uo_warn "raw-input artifact source failed validation; preflight will remain blocked"
  fi
fi

if [[ "$INSTALLER_STATUS" != "complete" && ! $ALLOW_MISSING_INSTALLER ]]; then
  uo_warn "installer preflight is not complete; supply the exact three installer members or use --allow-missing-installer for host-only inspection"
fi

if (( JSON_OUTPUT )); then
  python3 - "$BOTTLE_NAME" "$BOTTLE_DIR" "$INSTALLER_SOURCE" "$INSTALLER_TYPE" "$INSTALLER_STATUS" \
    "$INSTALLER_CACHE_DIR" "$CX_APP" "$CX_VERSION" "$CX_BUILD" "$HOST_ARCH" "$FREE_GIB" "$INSTALLER_REPORT" "$RAWINPUT_SOURCE_DIR" "$RAWINPUT_STATUS" "$RAWINPUT_REPORT" "$STATE_FILE_PATH" "$STATE_STATUS" "$CROSSOVER_SIGNATURE_STATUS" <<'PY'
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
    rawinput_source,
    rawinput_status,
    rawinput_report,
    state_file,
    state_status,
    crossover_signature_status,
) = sys.argv[1:]
try:
    report = json.loads(installer_report)
except json.JSONDecodeError:
    report = None
try:
    rawinput = json.loads(rawinput_report)
except json.JSONDecodeError:
    rawinput = None
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
    "rawinput_source_dir": rawinput_source or None,
    "rawinput_status": rawinput_status,
    "rawinput": rawinput,
    "state_file": state_file,
    "state_status": state_status,
    "crossover_signature_status": crossover_signature_status,
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
  uo_info "INFO: raw-input artifact=${RAWINPUT_STATUS} source=${RAWINPUT_SOURCE_DIR:-not supplied}"
  if [[ "$STATE_STATUS" == "pass" ]]; then
    uo_info "PASS: state file is writable: $STATE_FILE_PATH"
  else
    uo_warn "state file is not writable; command output remains authoritative: $STATE_FILE_PATH"
  fi
  if [[ "$CROSSOVER_SIGNATURE_STATUS" == "pass" ]]; then
    uo_info "PASS: CrossOver.app code signature verifies"
  else
    uo_warn "CrossOver.app code signature is unconfirmed; do not re-sign automatically"
  fi
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

PREFLIGHT_OK=1
if [[ "$INSTALLER_STATUS" != "complete" && ! $ALLOW_MISSING_INSTALLER ]]; then
  PREFLIGHT_OK=0
fi
if [[ "$RAWINPUT_STATUS" == "invalid" ]]; then
  PREFLIGHT_OK=0
fi
if (( PREFLIGHT_OK )); then
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
    "installer": {
        "zip": zip_path or None,
        "sha256": (report_value or {}).get("archive_sha256") if isinstance(report_value, dict) else None,
        "members": (report_value or {}).get("members", []) if isinstance(report_value, dict) else [],
        "stage": "pending" if status == "complete" else "blocked",
    },
}))
PY
)"
uo_state_merge_json "$PATCH_JSON"

RAWINPUT_STATE_JSON="$(python3 - "$RAWINPUT_SOURCE_DIR" "$RAWINPUT_STATUS" "$RAWINPUT_REPORT" <<'PY'
import json
import sys

source, status, report = sys.argv[1:]
try:
    report_value = json.loads(report)
except json.JSONDecodeError:
    report_value = None
print(json.dumps({
    "raw_input": {
        "artifact_dir": source or None,
        "status": status,
        "source_report": report_value,
    }
}))
PY
)"
uo_state_merge_json "$RAWINPUT_STATE_JSON"

(( PREFLIGHT_OK )) || exit 1
