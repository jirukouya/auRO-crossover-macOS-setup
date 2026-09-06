#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

BOTTLE_NAME="uaro-crossover"
JSON=0
uo_validate_bottle_name "$BOTTLE_NAME"

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help)
      print "Usage: check-gecko.zsh --bottle NAME [--json]"
      exit 0
      ;;
    *) print -u2 "unknown option: $1"; exit 2 ;;
  esac
done

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta
uo_require_bottle

GECKO_ROOT="$CX_ROOT/share/wine/gecko"
[[ -d "$GECKO_ROOT" ]] || {
  uo_state_merge_json '{"gecko":{"payload":"missing","bottle_marker":"unconfirmed"}}'
  uo_write_state gecko blocked
  uo_die "CrossOver Gecko payload directory is missing: $GECKO_ROOT"
}

typeset -a payloads=()
for arch in x86 x86_64; do
  payload="$(find "$GECKO_ROOT" -maxdepth 1 -type d -name "wine-gecko-*-$arch" -print -quit 2>/dev/null)"
  [[ -n "$payload" ]] || uo_die "CrossOver Gecko payload for $arch is missing: $GECKO_ROOT"
  [[ -n "$(find "$payload" -mindepth 1 -print -quit 2>/dev/null)" ]] || uo_die "CrossOver Gecko payload is empty: $payload"
  payloads+=("$payload")
done

typeset -a prefix_markers=()
while IFS= read -r marker; do
  prefix_markers+=("$marker")
done < <(find "$BOTTLE_DIR/drive_c/windows" -type f \( -iname 'mshtml.dll' -o -iname 'wine-gecko*' \) -print 2>/dev/null)

if (( ! JSON )); then
  uo_info "PASS: CrossOver Gecko payloads detected:"
  for payload in "${payloads[@]}"; do
    uo_info "INFO: $payload"
  done
fi

if (( ${#prefix_markers[@]} == 0 )); then
  uo_state_merge_json '{"gecko":{"payload":"pass","bottle_marker":"missing"}}'
  uo_write_state gecko blocked
  uo_die "CrossOver payload exists, but this bottle has no Gecko prefix marker yet; launch the Patcher once and install Gecko interactively, then rerun check-gecko"
fi

uo_state_set gecko_status installed
uo_state_set gecko_payloads "${(j:,:)payloads}"
uo_state_set gecko_prefix_markers "${(j:,:)prefix_markers}"
uo_state_merge_json "$(python3 - "${(j:,:)payloads}" "${(j:,:)prefix_markers}" <<'PY'
import json
import sys
payloads, markers = sys.argv[1:]
print(json.dumps({"gecko": {
    "payload": "pass",
    "bottle_marker": "pass",
    "payloads": payloads.split(","),
    "markers": markers.split(","),
}}))
PY
)"
uo_write_state gecko pass
if (( JSON )); then
  print -- "$(python3 - "${(j:,:)payloads}" "${(j:,:)prefix_markers}" <<'PY'
import json, sys
print(json.dumps({"payloads":sys.argv[1].split(","),"markers":sys.argv[2].split(","),"status":"pass"}))
PY
)"
else
  uo_info "PASS: bottle Gecko marker detected:"
  for marker in "${prefix_markers[@]}"; do
    uo_info "INFO: $marker"
  done
fi
