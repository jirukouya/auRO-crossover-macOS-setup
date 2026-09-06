#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"

usage() {
  print "Usage: uaro-crossover.zsh <preflight|artifact|bottle|install|patch-setup|check-gecko|configure|configure-keyboard|overlay|build-launchers|verify-live-runtime|diagnose|repair|uninstall> [options]"
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
  artifact)
    exec "$SCRIPT_DIR/artifact" "$@"
    ;;
  bottle)
    exec "$SCRIPT_DIR/bottle.zsh" "$@"
    ;;
  install)
    exec "$SCRIPT_DIR/stage-installer.zsh" --run "$@"
    ;;
  patch-setup)
    exec "$SCRIPT_DIR/patch-setup" "$@"
    ;;
  check-gecko)
    exec "$SCRIPT_DIR/check-gecko.zsh" "$@"
    ;;
  configure)
    exec python3 "$SCRIPT_DIR/configure-game.py" "$@"
    ;;
  configure-keyboard)
    exec "$SCRIPT_DIR/configure-keyboard.zsh" "$@"
    ;;
  overlay)
    exec "$SCRIPT_DIR/overlay.zsh" "$@"
    ;;
  build-launchers)
    exec "$SCRIPT_DIR/build-launchers.zsh" "$@"
    ;;
  verify-live-runtime)
    exec "$SCRIPT_DIR/verify-live-runtime.zsh" "$@"
    ;;
  diagnose)
    exec "$SCRIPT_DIR/diagnose.zsh" "$@"
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
