#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"

for script in "$ROOT"/scripts/*.zsh "$ROOT"/scripts/lib/*.zsh \
  "$ROOT"/scripts/preflight "$ROOT"/scripts/install "$ROOT"/scripts/patch-setup \
  "$ROOT"/scripts/configure-game "$ROOT"/scripts/build-overlay "$ROOT"/scripts/verify-overlay \
  "$ROOT"/scripts/build-launchers "$ROOT"/scripts/repair "$ROOT"/scripts/uninstall; do
  zsh -n "$script"
done

if rg -n -i 'whisky|whiskyc?md|shellenv|wine64' "$ROOT/scripts"; then
  print -u2 -- "ERROR: CrossOver scripts contain a Whisky-specific dependency"
  exit 1
fi

print "PASS: shell syntax and CrossOver-only static checks"
