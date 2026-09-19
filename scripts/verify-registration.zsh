#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
GAME_DIR=""
APPLICATIONS_DIR="/Applications"
REPAIR=0
JSON=0

usage() {
  print "Usage: verify-registration.zsh --bottle NAME [--game-dir DIR] [--applications-dir DIR] [--repair] [--json]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --game-dir) GAME_DIR="$2"; shift 2 ;;
    --applications-dir) APPLICATIONS_DIR="$2"; shift 2 ;;
    --repair) REPAIR=1; shift ;;
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
CXMENU_QUERY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/uaro-cxmenu-query.XXXXXX")"
CXMENU_QUERY_FILE="$CXMENU_QUERY_DIR/query.txt"
trap 'rm -rf -- "$CXMENU_QUERY_DIR"' EXIT INT TERM
capture_cxmenu_query() {
  CXMENU_QUERY_RC=0
  set +e
  "$CX_ROOT/bin/cxmenu" --bottle "$BOTTLE_NAME" --query >"$CXMENU_QUERY_FILE" 2>&1
  CXMENU_QUERY_RC=$?
  set -e
}
capture_cxmenu_query
BOTTLE_STATUS="$($CX_BOTTLE --bottle "$BOTTLE_NAME" --status 2>&1)" || \
  uo_die "CrossOver bottle status query failed: $BOTTLE_NAME"
[[ "$BOTTLE_STATUS" == *"Status="* ]] || \
  uo_die "CrossOver bottle status is unavailable: $BOTTLE_NAME"
GAME_DIR="${GAME_DIR:-$(uo_state_get game_dir 2>/dev/null || true)}"
GAME_DIR="${GAME_DIR:-$(uo_find_game_dir || true)}"
[[ -n "$GAME_DIR" ]] || uo_die "game directory is unknown; pass --game-dir"
GAME_DIR="$(uo_realpath "$GAME_DIR")" || uo_die "game directory does not exist: $GAME_DIR"
APPLICATIONS_DIR="${APPLICATIONS_DIR:A}"

run_check() {
  python3 "$SCRIPT_DIR/verify-registration.py" \
    --bottle "$BOTTLE_NAME" \
    --bottle-dir "$BOTTLE_DIR" \
    --game-dir "$GAME_DIR" \
    --crossover-build "$CX_BUILD" \
    --applications-dir "$APPLICATIONS_DIR" \
    --export-root "$HOME/Applications/CrossOver" \
    --cxmenu-query-file "$CXMENU_QUERY_FILE" \
    --cxmenu-query-rc "$CXMENU_QUERY_RC" \
    --json
}

CHECK_JSON=""
CHECK_RC=0
set +e
CHECK_JSON="$(run_check)"
CHECK_RC=$?
set -e

REPAIR_ATTEMPTED=0
REPAIR_LOG=""
if (( CHECK_RC != 0 && REPAIR )); then
  REPAIR_ATTEMPTED=1
  STATE_FILE="$(uo_state_file)"
  LOG_DIR="${STATE_FILE:h}/logs"
  mkdir -p "$LOG_DIR"
  REPAIR_LOG="$LOG_DIR/registration-$(date +%Y%m%d-%H%M%S).log"
  {
    print -- "command=$CX_BOTTLE --bottle $BOTTLE_NAME --install"
    "$CX_BOTTLE" --bottle "$BOTTLE_NAME" --install
    print -- "command=$CX_ROOT/bin/cxmenu --sync --bottle $BOTTLE_NAME --mode install"
    "$CX_ROOT/bin/cxmenu" --sync --bottle "$BOTTLE_NAME" --mode install
  } >"$REPAIR_LOG" 2>&1 || true
  capture_cxmenu_query
  set +e
  CHECK_JSON="$(run_check)"
  CHECK_RC=$?
  set -e
fi

PATCH_JSON="$(python3 - "$CHECK_JSON" "$REPAIR_ATTEMPTED" "$REPAIR_LOG" <<'PY'
import json
import sys
from datetime import datetime, timezone

report = json.loads(sys.argv[1])
report["repair_attempted"] = bool(int(sys.argv[2]))
report["repair_log"] = sys.argv[3] or None
report["checked_at"] = datetime.now(timezone.utc).isoformat()
print(json.dumps({"registration": report, "phase": "registration", "status": report["status"]}))
PY
)"
uo_state_merge_json "$PATCH_JSON"
uo_write_state registration "$(python3 - "$CHECK_JSON" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["status"])
PY
)"

if (( JSON )); then
  python3 - "$PATCH_JSON" <<'PY'
import json, sys
print(json.dumps(json.loads(sys.argv[1])["registration"], indent=2, sort_keys=True))
PY
else
  python3 - "$CHECK_JSON" "$REPAIR_ATTEMPTED" <<'PY'
import json, sys
report = json.loads(sys.argv[1])
print(f"{str(report['status']).upper()}: CrossOver uaRO registration")
if int(sys.argv[2]):
    print("INFO: attempted one non-destructive cxbottle --install repair")
for item in report.get("failures", []) + report.get("warnings", []):
    print(f"- {item['code']}: {item['message']}")
PY
fi

[[ "$CHECK_RC" -eq 0 ]] || exit 1
