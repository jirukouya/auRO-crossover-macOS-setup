#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
INSTALLER_DIR=""
INSTALLER_ZIP=""
INSTALLER_CACHE_DIR="$HOME/Games/UaRO-Installer"
RUN_INSTALLER=0

usage() {
  print "Usage: stage-installer.zsh --bottle NAME (--installer-dir DIR | --installer-zip ZIP) [--installer-cache-dir DIR] [--run]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --installer-dir) INSTALLER_DIR="$2"; shift 2 ;;
    --installer-zip) INSTALLER_ZIP="$2"; shift 2 ;;
    --installer-cache-dir) INSTALLER_CACHE_DIR="$2"; shift 2 ;;
    --run) RUN_INSTALLER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -z "$INSTALLER_DIR" || -z "$INSTALLER_ZIP" ]] || uo_die "--installer-dir and --installer-zip are mutually exclusive"
[[ -n "$INSTALLER_DIR" || -n "$INSTALLER_ZIP" ]] || uo_die "one of --installer-dir or --installer-zip is required"
INSTALLER_CACHE_DIR="${INSTALLER_CACHE_DIR:A}"

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta
uo_require_bottle

INSTALLER_TYPE="directory"
SOURCE_DIR=""
SOURCE_ZIP=""
ARCHIVE_SHA256=""
INSTALLER_REPORT="{}"

if [[ -n "$INSTALLER_ZIP" ]]; then
  INSTALLER_ZIP="$(uo_realpath "$INSTALLER_ZIP")" || uo_die "installer ZIP does not exist: $INSTALLER_ZIP"
  mkdir -p "$INSTALLER_CACHE_DIR"
  CACHE_ZIP="$INSTALLER_CACHE_DIR/UaRO_Setup.zip"
  SOURCE_HASH="$(uo_hash "$INSTALLER_ZIP")"
  if [[ -e "$CACHE_ZIP" ]]; then
    if [[ "$(uo_hash "$CACHE_ZIP")" != "$SOURCE_HASH" ]]; then
      uo_die "installer cache exists with a different SHA-256; inspect it before replacing: $CACHE_ZIP"
    fi
  elif [[ "$INSTALLER_ZIP" != "$CACHE_ZIP" ]]; then
    cp -p "$INSTALLER_ZIP" "$CACHE_ZIP"
  fi
  [[ "$(uo_hash "$CACHE_ZIP")" == "$SOURCE_HASH" ]] || uo_die "installer cache hash verification failed: $CACHE_ZIP"
  SOURCE_ZIP="$CACHE_ZIP"
  ARCHIVE_SHA256="$SOURCE_HASH"
  INSTALLER_TYPE="zip"
  INSTALLER_REPORT="$(python3 "$SCRIPT_DIR/verify-installer.py" --zip "$SOURCE_ZIP")"
else
  INSTALLER_DIR="$(uo_realpath "$INSTALLER_DIR")" || uo_die "installer directory does not exist: $INSTALLER_DIR"
  SOURCE_DIR="$INSTALLER_DIR"
  INSTALLER_REPORT="$(python3 "$SCRIPT_DIR/verify-installer.py" --dir "$SOURCE_DIR")"
fi

typeset -a names=(UaRO_Setup.exe UaRO_Setup-1.bin UaRO_Setup-2.bin)
STAGE_DIR="$BOTTLE_DIR/drive_c/UaROInstaller"
mkdir -p "$STAGE_DIR"
trap 'for part in "$STAGE_DIR"/*.part.*; do [[ -e "$part" ]] && /bin/rm -f -- "$part"; done' EXIT INT TERM

typeset -a staged_members=()
for name in "${names[@]}"; do
  target_path="$STAGE_DIR/$name"
  part_path="$STAGE_DIR/$name.part.$$"
  if [[ "$INSTALLER_TYPE" == "zip" ]]; then
    /usr/bin/unzip -p "$SOURCE_ZIP" "$name" > "$part_path"
  else
    cp -p "$SOURCE_DIR/$name" "$part_path"
  fi
  [[ -s "$part_path" ]] || uo_die "staged member is empty: $name"
  if [[ -e "$target_path" ]]; then
    cmp -s "$part_path" "$target_path" || uo_die "staged file differs; inspect it before restaging: $target_path"
    /bin/rm -f -- "$part_path"
  else
    /bin/mv "$part_path" "$target_path"
  fi
  member_size="$(stat -f '%z' "$target_path")"
  member_hash="$(uo_hash "$target_path")"
  staged_members+=("$name|$member_size|$member_hash")
  uo_info "PASS: staged $name size=$member_size sha256=$member_hash"
done

STAGE_JSON="$(python3 - "$INSTALLER_TYPE" "$INSTALLER_ZIP" "$SOURCE_DIR" "$SOURCE_ZIP" "$ARCHIVE_SHA256" "$STAGE_DIR" "${staged_members[@]}" <<'PY'
import json
import sys

source_type, source_zip, source_dir, cache_zip, archive_sha256, stage_dir, *members = sys.argv[1:]
encoded = []
for item in members:
    name, size, digest = item.split("|", 2)
    encoded.append({"name": name, "size": int(size), "sha256": digest})
print(json.dumps({
    "installer_type": source_type,
    "installer_zip": source_zip or None,
    "installer_dir": source_dir or None,
    "installer_cache": cache_zip or None,
    "installer_archive_sha256": archive_sha256 or None,
    "installer_stage_dir": stage_dir,
    "installer_members": encoded,
    "installer_stage": "staged",
    "installer": {
        "zip": source_zip or None,
        "sha256": archive_sha256 or None,
        "members": encoded,
        "cache": cache_zip or None,
        "stage": "staged",
    },
}))
PY
)"
uo_state_merge_json "$STAGE_JSON"
uo_write_state installer staged

if (( RUN_INSTALLER )); then
  uo_info "Opening the interactive uaRO installer in CrossOver. Complete only the user-level/default installation choices."
  uo_info "Human gate: choose current-user installation, keep the default destination, and uncheck automatic game launch on the final page."
  caffeinate -i "$CX_WINE" --wait --bottle "$BOTTLE_NAME" --workdir "$STAGE_DIR" --cx-app 'C:\UaROInstaller\UaRO_Setup.exe'
  GAME_DIR="$(uo_find_game_dir)" || uo_die "installer exited but uaRO.exe was not found in the bottle"
  uo_info "PASS: uaRO game directory: $GAME_DIR"
  uo_write_state installer complete
  COMPLETION_JSON="$(python3 - "$GAME_DIR" <<'PY'
import json
import sys
print(json.dumps({"installer_stage": "complete", "game_dir": sys.argv[1], "installer": {"stage": "complete"}}))
PY
)"
  uo_state_merge_json "$COMPLETION_JSON"
  zsh "$SCRIPT_DIR/verify-registration.zsh" --bottle "$BOTTLE_NAME" --game-dir "$GAME_DIR" --repair || \
    uo_die "CrossOver uaRO registration could not be proven; installation is blocked"
else
  uo_info "PASS: installer siblings staged at $STAGE_DIR"
  uo_info "Next action: rerun with --run to open the interactive installer."
fi
