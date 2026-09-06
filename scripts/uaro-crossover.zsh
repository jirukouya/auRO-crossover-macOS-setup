#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"

usage() {
  print "Usage: uaro-crossover.zsh <preflight|bottle|install|patch-setup|configure|overlay|build-launchers|repair|uninstall> [options]"
  print ""
  print "CrossOver is the only supported runtime. Use --help on each command for details."
}

command="${1:-help}"
if (( $# )); then
  shift
fi

case "$command" in
  preflight)
    exec "$SCRIPT_DIR/preflight.zsh" "$@"
    ;;
  bottle)
    exec "$SCRIPT_DIR/bottle.zsh" "$@"
    ;;
  install)
    exec "$SCRIPT_DIR/stage-installer.zsh" --run "$@"
    ;;
  patch-setup)
    exec python3 "$SCRIPT_DIR/patch-setup.py" "$@"
    ;;
  configure)
    exec python3 "$SCRIPT_DIR/configure-game.py" "$@"
    ;;
  overlay)
    exec "$SCRIPT_DIR/overlay.zsh" "$@"
    ;;
  build-launchers)
    exec "$SCRIPT_DIR/build-launchers.zsh" "$@"
    ;;
  repair)
    exec "$SCRIPT_DIR/repair.zsh" "$@"
    ;;
  uninstall)
    exec "$SCRIPT_DIR/uninstall.zsh" "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
