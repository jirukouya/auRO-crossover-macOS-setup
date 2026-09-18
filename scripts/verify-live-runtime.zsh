#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
GAME_DIR=""
OVERLAY_DIR=""
PID=""
JSON=0

usage() {
  print "Usage: verify-live-runtime.zsh --bottle NAME [--game-dir DIR] [--overlay-dir DIR] [--pid PID] [--json]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --game-dir) GAME_DIR="$2"; shift 2 ;;
    --overlay-dir) OVERLAY_DIR="$2"; shift 2 ;;
    --pid) PID="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta
uo_require_bottle
GAME_DIR="${GAME_DIR:-$(uo_state_get game_dir 2>/dev/null || true)}"
OVERLAY_DIR="${OVERLAY_DIR:-$(uo_state_get overlay_dir 2>/dev/null || true)}"
if [[ -n "$OVERLAY_DIR" ]]; then
  OVERLAY_DIR="${OVERLAY_DIR:A}"
fi
STOCK_BASELINE_CLEAN=0
if [[ "$(uo_state_get overlay_probe_before 2>/dev/null || true)" == "pass" \
    && "$(uo_state_get overlay_probe_before_affected 2>/dev/null || true)" == "no" \
    && "$(uo_state_get overlay_probe_before_clobbered 2>/dev/null || true)" == "0" ]]; then
  STOCK_BASELINE_CLEAN=1
fi

if [[ -z "$PID" ]]; then
  while IFS=$' \t' read -r candidate command; do
    [[ "$candidate" == <-> ]] || continue
    [[ "$command" == *uaRO.exe* ]] || continue
    PID="$candidate"
    break
  done < <(ps -axo pid=,command=)
fi

if [[ -z "$PID" ]]; then
  result='{"process":"not_running","launch_path":"unknown","runtime":"unknown","status":"unconfirmed"}'
  uo_state_merge_json "$(python3 - "$result" <<'PY'
import json, sys
print(json.dumps({"launch": {"runtime_check": json.loads(sys.argv[1])}}))
PY
)"
  (( JSON )) && print -- "$result" || uo_info "INFO: uaRO is not currently running; runtime route is unconfirmed"
  exit 0
fi

[[ "$PID" == <-> ]] || uo_die "invalid PID: $PID"
vmmap_output="$(mktemp "${TMPDIR:-/tmp}/uaro-vmmap.XXXXXX")"
trap 'rm -f -- "$vmmap_output"' EXIT INT TERM
if ! vmmap "$PID" >"$vmmap_output" 2>&1; then
  uo_warn "vmmap could not inspect PID $PID"
fi

typeset -a mapped=()
while IFS= read -r line; do
  [[ -n "$line" ]] && mapped+=("$line")
done < <(python3 - "$vmmap_output" <<'PY'
import re
import sys
from pathlib import Path

for line in Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines():
    match = re.search(r"(/.*(?:wow64win\.dll|ntdll\.so))\s*$", line, re.IGNORECASE)
    if match:
        print(match.group(1))
PY
)

launch_path="unknown"
runtime="unknown"
if (( ${#mapped[@]} > 0 )); then
  has_overlay=0
  has_stock=0
  for line in "${mapped[@]}"; do
    [[ -n "$OVERLAY_DIR" && "$line" == *"$OVERLAY_DIR"* ]] && has_overlay=1
    [[ "$line" == *"$CX_APP/"* || "$line" == *"$CX_ROOT/"* ]] && has_stock=1
  done
  if (( has_overlay && !has_stock )); then
    launch_path="patcher_launcher"
    runtime="overlay"
  elif (( has_stock && !has_overlay )); then
    launch_path="crossover_shortcut"
    runtime="stock"
  elif (( has_overlay && has_stock )); then
    launch_path="unknown"
    runtime="mixed"
  fi
fi

wow64_path="$(printf '%s\n' "${mapped[@]}" | grep -i 'wow64win\.dll' | head -1 || true)"
ntdll_path="$(printf '%s\n' "${mapped[@]}" | grep -i 'ntdll\.so' | head -1 || true)"
if [[ -z "$wow64_path" ]]; then
  wow64_path="$(lsof -p "$PID" 2>/dev/null | awk 'tolower($0) ~ /wow64win\.dll/ {print $NF; exit}' || true)"
fi
if [[ -z "$ntdll_path" ]]; then
  ntdll_path="$(lsof -p "$PID" 2>/dev/null | awk 'tolower($0) ~ /ntdll\.so/ {print $NF; exit}' || true)"
fi
wow64_hash=""
ntdll_hash=""
[[ -n "$wow64_path" && -f "$wow64_path" ]] && wow64_hash="$(uo_hash "$wow64_path")"
[[ -n "$ntdll_path" && -f "$ntdll_path" ]] && ntdll_hash="$(uo_hash "$ntdll_path")"
expected_hash=""
APP_DLL_HASH="$(uo_state_get app_dll_sha256 2>/dev/null || true)"
[[ -n "$OVERLAY_DIR" && -f "$OVERLAY_DIR/overlay-manifest.json" ]] && expected_hash="$(python3 - "$OVERLAY_DIR/overlay-manifest.json" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8"))["overlay_files"]["lib/wine/x86_64-windows/wow64win.dll"])
except (KeyError, OSError, json.JSONDecodeError):
    print("")
PY
)"
if [[ -z "$expected_hash" && -n "$APP_DLL_HASH" ]]; then
  expected_hash="$APP_DLL_HASH"
fi

runtime_status="unconfirmed"
APP_DLL_MATCH=0
[[ -n "$APP_DLL_HASH" && -n "$wow64_hash" && "$wow64_hash" == "$APP_DLL_HASH" && "$wow64_path" == *"$CX_APP/"* ]] && APP_DLL_MATCH=1
if [[ "$runtime" == "overlay" && -n "$wow64_hash" && "$wow64_hash" == "$expected_hash" && -n "$ntdll_path" ]]; then
  runtime_status="pass"
elif [[ "$runtime" == "stock" && "$STOCK_BASELINE_CLEAN" == "1" && -n "$wow64_path" && -n "$ntdll_path" ]]; then
  runtime_status="pass"
elif (( APP_DLL_MATCH )); then
  launch_path="crossover_wine"
  runtime="stock"
  runtime_status="pass"
elif [[ "$runtime" == "stock" || "$runtime" == "mixed" ]]; then
  runtime_status="blocked"
fi

python3 - "$PID" "$launch_path" "$runtime" "$runtime_status" "$wow64_path" "$wow64_hash" "$ntdll_path" "$ntdll_hash" "$expected_hash" "$vmmap_output" <<'PY'
import json
import sys
from pathlib import Path

pid, launch_path, runtime, status, wow64_path, wow64_hash, ntdll_path, ntdll_hash, expected_hash, vmmap_path = sys.argv[1:]
result = {
    "process": "running",
    "pid": int(pid),
    "launch_path": launch_path,
    "runtime": runtime,
    "status": status,
    "wow64win": {"path": wow64_path, "sha256": wow64_hash, "expected_sha256": expected_hash},
    "ntdll": {"path": ntdll_path, "sha256": ntdll_hash},
    "vmmap_log": vmmap_path,
}
print(json.dumps(result, indent=2, sort_keys=True))
PY

RESULT_JSON="$(python3 - "$PID" "$launch_path" "$runtime" "$runtime_status" "$wow64_path" "$wow64_hash" "$ntdll_path" "$ntdll_hash" "$expected_hash" <<'PY'
import json, sys
pid, launch_path, runtime, status, wow64_path, wow64_hash, ntdll_path, ntdll_hash, expected_hash = sys.argv[1:]
print(json.dumps({"process":"running","pid":int(pid),"launch_path":launch_path,"runtime":runtime,"status":status,
    "wow64win":{"path":wow64_path,"sha256":wow64_hash,"expected_sha256":expected_hash},
    "ntdll":{"path":ntdll_path,"sha256":ntdll_hash}}))
PY
)"
uo_state_merge_json "$(python3 - "$RESULT_JSON" <<'PY'
import json, sys
print(json.dumps({"launch": {"runtime_check": json.loads(sys.argv[1])}}))
PY
)"

if (( JSON )); then
  print -- "$RESULT_JSON"
elif [[ "$runtime_status" == "pass" ]]; then
  if [[ "$runtime" == "overlay" ]]; then
    uo_info "PASS: PID $PID is using the per-bottle overlay runtime"
  elif (( APP_DLL_MATCH )); then
    uo_info "PASS: PID $PID loaded the Option A CrossOver.app wow64win.dll"
  else
    uo_info "PASS: PID $PID is using the stock runtime and the recorded stock probe was clean"
  fi
elif [[ "$runtime_status" == "blocked" ]]; then
  uo_die "PID $PID is not using the deployed patched wow64win.dll; close it and relaunch via official CrossOver wine or deploy-app"
else
  uo_warn "PID $PID exists but runtime anchors are incomplete; status is unconfirmed"
fi
[[ "$runtime_status" != "blocked" ]] || exit 1
