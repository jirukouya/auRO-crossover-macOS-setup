#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
APPLICATIONS_DIR="/Applications"
FIX=0

usage() {
  print "Usage: repair.zsh --bottle NAME [--applications-dir DIR] [--fix]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --applications-dir) APPLICATIONS_DIR="$2"; shift 2 ;;
    --fix) FIX=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta
uo_require_bottle

failures=0
for display_name in "UaRO CrossOver Patcher" "UaRO CrossOver Settings"; do
  bundle="$APPLICATIONS_DIR/$display_name.app"
  executable="$bundle/Contents/MacOS/$display_name"
  plist="$bundle/Contents/Info.plist"
  helper="$bundle/Contents/Resources/patch-setup.py"
  profiles="$bundle/Contents/Resources/setup_profiles.py"
  if [[ ! -d "$bundle" || ! -f "$executable" || ! -f "$plist" || ! -f "$helper" ]]; then
    uo_warn "launcher is incomplete: $bundle"
    failures=$(( failures + 1 ))
    continue
  fi
  if [[ ! -f "$profiles" && ! $FIX ]]; then
    uo_warn "launcher is missing the hash-profile helper: $bundle"
    failures=$(( failures + 1 ))
    continue
  fi
  if (( FIX )); then
    chmod +x "$executable"
    cp "$SCRIPT_DIR/patch-setup.py" "$helper"
    cp "$SCRIPT_DIR/setup_profiles.py" "$profiles"
    codesign --force --deep --sign - "$bundle" >/dev/null
  fi
  if ! zsh -n "$executable"; then
    uo_warn "launcher shell syntax is invalid: $executable"
    failures=$(( failures + 1 ))
    continue
  fi
  if ! plutil -lint "$plist" >/dev/null; then
    uo_warn "launcher Info.plist is invalid: $plist"
    failures=$(( failures + 1 ))
    continue
  fi
  if ! codesign --verify --deep --strict "$bundle" >/dev/null 2>&1; then
    uo_warn "launcher signature verification failed: $bundle"
    failures=$(( failures + 1 ))
    continue
  fi
  expected_executable="$(plutil -extract CFBundleExecutable raw -o - "$plist")"
  [[ "$expected_executable" == "$display_name" ]] || {
    uo_warn "Info.plist executable name mismatch: $plist"
    failures=$(( failures + 1 ))
    continue
  }
  uo_info "PASS: verified launcher $bundle"
done

if (( failures )); then
  uo_write_state repair failed
  exit 1
fi
uo_write_state repair pass
uo_info "PASS: CrossOver launchers are healthy"
