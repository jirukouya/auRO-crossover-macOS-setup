#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

ACTION="${1:-status}"
if (( $# )); then
  shift
fi
BOTTLE_NAME="uaro-crossover"
CONFIRM=0

if [[ "$ACTION" == "-h" || "$ACTION" == "--help" || "$ACTION" == "help" ]]; then
  print "Usage: bottle.zsh {create|status|delete} --bottle NAME [--confirm]"
  exit 0
fi

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --confirm) CONFIRM=1; shift ;;
    -h|--help) print "Usage: bottle.zsh {create|status|delete} --bottle NAME [--confirm]"; exit 0 ;;
    *) print -u2 "unknown option: $1"; exit 2 ;;
  esac
done

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
BOTTLE_DIR="$(uo_bottle_dir)"

case "$ACTION" in
  create)
    if [[ -d "$BOTTLE_DIR/drive_c" ]]; then
      uo_info "PASS: bottle already exists: $BOTTLE_NAME"
    else
      "$CX_BOTTLE" --bottle "$BOTTLE_NAME" --create --template win10_64
      [[ -d "$BOTTLE_DIR/drive_c" ]] || uo_die "cxbottle reported success but drive_c is missing"
      uo_info "PASS: created bottle $BOTTLE_NAME"
    fi
    uo_write_state bottle created
    ;;
  status)
    if [[ -d "$BOTTLE_DIR/drive_c" ]]; then
      "$CX_BOTTLE" --bottle "$BOTTLE_NAME" --status || true
      uo_info "PASS: bottle exists: $BOTTLE_DIR"
    else
      uo_info "INFO: bottle does not exist: $BOTTLE_NAME"
      exit 1
    fi
    ;;
  delete)
    (( CONFIRM )) || uo_die "delete requires --confirm"
    [[ -d "$BOTTLE_DIR" ]] || uo_die "bottle does not exist: $BOTTLE_NAME"
    "$CX_BOTTLE" --bottle "$BOTTLE_NAME" --delete --force
    [[ ! -d "$BOTTLE_DIR" ]] || uo_die "bottle still exists after delete"
    uo_info "PASS: deleted bottle $BOTTLE_NAME"
    uo_write_state bottle deleted
    ;;
  *)
    print -u2 "unknown action: $ACTION"
    exit 2
    ;;
esac
