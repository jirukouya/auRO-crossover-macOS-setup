#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
ARTIFACT_DIR=""

usage() {
  print "Usage: deploy-app.zsh --artifact-dir DIR [--bottle NAME]"
  print "Option A: backup then replace CrossOver.app wow64win.dll from a verified artifact."
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --artifact-dir) ARTIFACT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -n "$ARTIFACT_DIR" ]] || uo_die "--artifact-dir is required"
ARTIFACT_DIR="$(uo_realpath "$ARTIFACT_DIR")" || uo_die "artifact directory does not exist: $ARTIFACT_DIR"

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta

python3 "$SCRIPT_DIR/verify-artifact.py" --artifact-dir "$ARTIFACT_DIR" --crossover-build "$CX_BUILD" --mode probe

SRC="$ARTIFACT_DIR/wow64win.dll"
[[ -f "$SRC" ]] || uo_die "artifact wow64win.dll is missing: $SRC"
TARGET="$CX_ROOT/lib/wine/x86_64-windows/wow64win.dll"
[[ -f "$TARGET" ]] || uo_die "CrossOver wow64win.dll is missing: $TARGET"
ORIG="$TARGET.orig"

SRC_HASH="$(uo_hash "$SRC")"
CURRENT_HASH="$(uo_hash "$TARGET")"

if [[ ! -f "$ORIG" ]]; then
  cp -p "$TARGET" "$ORIG"
  uo_info "PASS: backed up stock wow64win.dll to $ORIG"
else
  uo_info "INFO: existing backup left in place: $ORIG"
fi
ORIG_HASH="$(uo_hash "$ORIG")"

if [[ "$CURRENT_HASH" == "$SRC_HASH" ]]; then
  uo_info "INFO: CrossOver.app wow64win.dll already matches the artifact"
else
  cp -p "$SRC" "$TARGET"
  [[ "$(uo_hash "$TARGET")" == "$SRC_HASH" ]] || uo_die "deployed wow64win.dll hash mismatch: $TARGET"
  uo_info "PASS: deployed artifact wow64win.dll into CrossOver.app"
fi

uo_state_set app_dll_status pass
uo_state_set app_dll_sha256 "$SRC_HASH"
uo_state_set app_dll_orig_sha256 "$ORIG_HASH"
uo_state_set app_dll_path "$TARGET"
uo_write_state deploy-app pass
uo_info "PASS: Option A app DLL sha256=$SRC_HASH"
uo_info "INFO: CrossOver updates can restore the stock DLL; re-run deploy-app after an update"
