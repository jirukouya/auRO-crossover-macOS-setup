#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
ERROR_TEXT=""
JSON=0

usage() {
  print "Usage: diagnose.zsh --bottle NAME --error TEXT [--json]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --error) ERROR_TEXT="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -n "$ERROR_TEXT" ]] || uo_die "--error is required"
uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta
uo_require_bottle

if [[ "$ERROR_TEXT" == *"3::110::12"* || "$ERROR_TEXT" == *"Gepard"* ]]; then
  category="raw_input_or_launch_route"
  next_action="run stock probe, then verify the live process is using the per-bottle overlay"
elif [[ "$ERROR_TEXT" == *"setup.exe"* || "$ERROR_TEXT" == *"Program Error"* ]]; then
  category="opensetup_or_rosetta"
  next_action="inspect installed setup.exe hash and run the registered OpenSetup profile"
else
  category="unclassified"
  next_action="collect a live runtime report and preserve the exact error text; cause is unconfirmed"
fi

runtime_json="$($SCRIPT_DIR/verify-live-runtime.zsh --bottle "$BOTTLE_NAME" --json 2>/dev/null || true)"
python3 - "$ERROR_TEXT" "$category" "$next_action" "$runtime_json" <<'PY'
import json
import sys
error, category, next_action, runtime = sys.argv[1:]
try:
    runtime_data = json.loads(runtime)
except json.JSONDecodeError:
    runtime_data = {"status": "unconfirmed"}
print(json.dumps({"error": error, "category": category, "runtime": runtime_data, "next_action": next_action}, indent=2, sort_keys=True))
PY

DIAG_JSON="$(python3 - "$ERROR_TEXT" "$category" "$next_action" "$runtime_json" <<'PY'
import json, sys
error, category, next_action, runtime = sys.argv[1:]
try: data = json.loads(runtime)
except json.JSONDecodeError: data = {"status":"unconfirmed"}
print(json.dumps({"error":error,"category":category,"runtime":data,"next_action":next_action}))
PY
)"
uo_state_merge_json "$(python3 - "$DIAG_JSON" <<'PY'
import json, sys
print(json.dumps({"diagnostics": json.loads(sys.argv[1])}))
PY
)"

if (( ! JSON )); then
  uo_info "INFO: category=$category"
  uo_info "INFO: next action=$next_action"
fi
