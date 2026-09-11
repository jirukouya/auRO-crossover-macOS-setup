#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"

has_text() {
  local pattern="$1"
  shift
  if command -v rg >/dev/null 2>&1; then
    rg -q -- "$pattern" "$@"
  else
    grep -RqiE -- "$pattern" "$@"
  fi
}

for script in "$ROOT"/scripts/*.zsh "$ROOT"/scripts/lib/*.zsh \
  "$ROOT"/scripts/preflight "$ROOT"/scripts/install "$ROOT"/scripts/patch-setup \
  "$ROOT"/scripts/configure-game "$ROOT"/scripts/build-overlay "$ROOT"/scripts/verify-overlay \
  "$ROOT"/scripts/build-launchers "$ROOT"/scripts/repair "$ROOT"/scripts/uninstall \
  "$ROOT"/scripts/check-gecko "$ROOT"/scripts/verify-installer "$ROOT"/scripts/artifact \
  "$ROOT"/scripts/build-rawinput-artifact.zsh "$ROOT"/scripts/configure-keyboard.zsh \
  "$ROOT"/scripts/verify-live-runtime.zsh "$ROOT"/scripts/diagnose.zsh; do
  zsh -n "$script"
done

if has_text 'whisky|whiskyc?md|shellenv|wine64' "$ROOT/scripts"; then
  print -u2 -- "ERROR: CrossOver scripts contain a Whisky-specific dependency"
  exit 1
fi

if has_text '/Users/jax|/Users/[A-Za-z0-9._-]+/Downloads/gepard' "$ROOT/scripts"; then
  print -u2 -- "ERROR: scripts contain another computer's absolute path"
  exit 1
fi

if ! has_text 'lib/perl|CXLog\.pm|lib64|mktemp|ret' "$ROOT/scripts/overlay.zsh" "$ROOT/scripts/artifact.py"; then
  print -u2 -- "ERROR: overlay/artifact safeguards are missing"
  exit 1
fi

if ! has_text '--json|launch_path|vmmap|runtime_anchor' \
  "$ROOT/scripts/verify-live-runtime.zsh" "$ROOT/scripts/build-launchers.zsh"; then
  print -u2 -- "ERROR: live runtime route verification is missing"
  exit 1
fi

for marker in RUNTIME_MODE STOCK_BASELINE_CLEAN overlay_probe_before_clobbered; do
  if ! has_text "$marker" "$ROOT/scripts/verify-live-runtime.zsh" "$ROOT/scripts/build-launchers.zsh"; then
    print -u2 -- "ERROR: clean-stock runtime branch safeguard is missing: $marker"
    exit 1
  fi
done

if ! has_text 'runtime_mode' "$ROOT/scripts/build-launchers.zsh"; then
  print -u2 -- "ERROR: launcher runtime state propagation is missing"
  exit 1
fi

if has_text 'Game\.app' "$ROOT/scripts/build-launchers.zsh"; then
  print -u2 -- "ERROR: the first launcher release must not generate Game.app"
  exit 1
fi

print "PASS: shell syntax and CrossOver-only static checks"
