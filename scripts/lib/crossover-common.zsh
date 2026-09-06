#!/bin/zsh

setopt NO_NOMATCH

uo_die() {
  print -u2 -- "ERROR: $*"
  return 1
}

uo_warn() {
  print -u2 -- "WARN: $*"
}

uo_info() {
  print -- "$*"
}

uo_hash() {
  /usr/bin/shasum -a 256 -- "$1" | /usr/bin/awk '{print $1}'
}

uo_realpath() {
  local path="$1"
  [[ -e "$path" ]] || return 1
  (cd "$path" 2>/dev/null && pwd -P)
}

uo_validate_bottle_name() {
  local value="$1"
  [[ -n "$value" && "$value" != *'/'* && "$value" != '..'* && "$value" != *'..'* ]] || \
    uo_die "invalid bottle name: $value"
}

uo_resolve_crossover() {
  local requested="${CROSSOVER_APP:-}"
  local -a candidates=()
  local candidate canonical version build

  if [[ -n "$requested" ]]; then
    candidates+=("$requested")
  else
    candidates+=("/Applications/CrossOver.app" "$HOME/Applications/CrossOver.app")
  fi

  typeset -a found=()
  for candidate in "${candidates[@]}"; do
    [[ -d "$candidate/Contents/SharedSupport/CrossOver" ]] || continue
    canonical="$(uo_realpath "$candidate")" || continue
    if (( ${found[(I)$canonical]} == 0 )); then
      found+=("$canonical")
    fi
  done

  (( ${#found[@]} > 0 )) || uo_die "CrossOver.app was not found"

  typeset -a builds=()
  for candidate in "${found[@]}"; do
    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$candidate/Contents/Info.plist" 2>/dev/null || true)"
    build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$candidate/Contents/Info.plist" 2>/dev/null || true)"
    [[ -n "$version" && -n "$build" ]] || uo_die "CrossOver bundle has no readable version: $candidate"
    builds+=("$version/$build")
  done

  if (( ${#found[@]} > 1 )); then
    local first="${builds[1]}"
    for build in "${builds[@]}"; do
      [[ "$build" == "$first" ]] || uo_die "multiple CrossOver installations have different builds: ${builds[*]}"
    done
    if [[ -d "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver" ]]; then
      CX_APP="$(uo_realpath /Applications/CrossOver.app)"
    else
      CX_APP="${found[1]}"
    fi
  else
    CX_APP="${found[1]}"
  fi

  CX_ROOT="$CX_APP/Contents/SharedSupport/CrossOver"
  CX_WINE="$CX_ROOT/bin/wine"
  CX_BOTTLE="$CX_ROOT/CrossOver-Hosted Application/cxbottle"
  CX_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$CX_APP/Contents/Info.plist")"
  CX_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$CX_APP/Contents/Info.plist")"

  [[ -x "$CX_WINE" ]] || uo_die "CrossOver wine wrapper is missing: $CX_WINE"
  [[ -x "$CX_BOTTLE" ]] || uo_die "CrossOver bottle CLI is missing: $CX_BOTTLE"
  [[ "$($CX_WINE --version 2>/dev/null)" == *"$CX_VERSION"* ]] || \
    uo_die "CrossOver wine wrapper version does not match app version"
}

uo_require_supported_build() {
  local expected="${UA_SUPPORTED_CX_BUILD:-26.3.0.39832}"
  [[ "$CX_BUILD" == "$expected" ]] || \
    uo_die "unsupported CrossOver build $CX_BUILD; expected $expected"
}

uo_require_arm64_rosetta() {
  local arch="$(uname -m)"
  [[ "$arch" == "arm64" ]] || uo_die "this draft supports Apple Silicon only; host is $arch"
  /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1 || \
    uo_die "Rosetta translation is unavailable; install it interactively before continuing"
}

uo_bottle_dir() {
  print -- "$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE_NAME"
}

uo_require_bottle() {
  uo_validate_bottle_name "$BOTTLE_NAME" || return
  local dir="$(uo_bottle_dir)"
  [[ -d "$dir/drive_c" ]] || uo_die "CrossOver bottle not found or has no drive_c: $BOTTLE_NAME"
  BOTTLE_DIR="$dir"
}

uo_find_game_dir() {
  local root="${BOTTLE_DIR:-$(uo_bottle_dir)/drive_c}"
  local exe
  exe="$(find "$root" -type f -iname 'uaRO.exe' -print -quit 2>/dev/null)"
  [[ -n "$exe" ]] || return 1
  print -- "${exe:h}"
}

uo_state_file() {
  print -- "$HOME/Library/Application Support/uaRO-CrossOver/state.json"
}

uo_write_state() {
  local state_phase="$1"
  local state_status="$2"
  local file="$(uo_state_file)"
  mkdir -p "${file:h}"
  python3 - "$file" "$state_phase" "$state_status" "${CX_APP:-}" "${CX_VERSION:-}" "${CX_BUILD:-}" "${BOTTLE_NAME:-}" "${GAME_DIR:-}" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, phase, status, cx_app, cx_version, cx_build, bottle, game_dir = sys.argv[1:]
try:
    with open(path, encoding="utf-8") as handle:
        state = json.load(handle)
except (FileNotFoundError, json.JSONDecodeError):
    state = {}
state.update({
    "updated_at": datetime.now(timezone.utc).isoformat(),
    "phase": phase,
    "status": status,
    "crossover_app": cx_app,
    "crossover_version": cx_version,
    "crossover_build": cx_build,
    "bottle": bottle,
    "game_dir": game_dir,
})
with open(path, "w", encoding="utf-8") as handle:
    json.dump(state, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

uo_state_set() {
  local key="$1"
  local value="$2"
  local file="$(uo_state_file)"
  mkdir -p "${file:h}"
  python3 - "$file" "$key" "$value" <<'PY'
import json
import sys

path, key, value = sys.argv[1:]
try:
    with open(path, encoding="utf-8") as handle:
        state = json.load(handle)
except (FileNotFoundError, json.JSONDecodeError):
    state = {}
state[key] = value
with open(path, "w", encoding="utf-8") as handle:
    json.dump(state, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

uo_state_get() {
  local key="$1"
  local file="$(uo_state_file)"
  [[ -f "$file" ]] || return 1
  python3 - "$file" "$key" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        value = json.load(handle).get(sys.argv[2])
except (FileNotFoundError, json.JSONDecodeError):
    raise SystemExit(1)
if value is None:
    raise SystemExit(1)
print(value)
PY
}
