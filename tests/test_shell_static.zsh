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
  "$ROOT"/scripts/verify-live-runtime.zsh "$ROOT"/scripts/diagnose.zsh \
  "$ROOT"/scripts/deploy-app.zsh "$ROOT"/scripts/launch-patcher.zsh \
  "$ROOT"/scripts/verify-registration.zsh; do
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

if has_text 'osascript|System Events|cua_repl|computer\.click' "$ROOT/scripts/verify-registration.zsh" "$ROOT/scripts/verify-registration.py"; then
  print -u2 -- "ERROR: registration verification must not depend on desktop control"
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

if ! has_text 'confirm-app-change' "$ROOT/scripts/deploy-app.zsh" "$ROOT/SKILL.md" "$ROOT/README.md"; then
  print -u2 -- "ERROR: Option A app-level confirmation gate is missing"
  exit 1
fi

if ! has_text 'artifact fetch|SHA256SUMS|github_release_api' "$ROOT/scripts/artifact.py" "$ROOT/SKILL.md" "$ROOT/README.md"; then
  print -u2 -- "ERROR: build-matched GitHub Release artifact fetch gate is missing"
  exit 1
fi

if ! has_text 'probe-scope|probe-after-pass|overlay_probe_after' "$ROOT/scripts/overlay.zsh" "$ROOT/SKILL.md"; then
  print -u2 -- "ERROR: before/after probe state separation is missing"
  exit 1
fi

if ! has_text 'parse-vmmap-paths|lsof -p.*-Fn' "$ROOT/scripts/verify-live-runtime.zsh"; then
  print -u2 -- "ERROR: vmmap path parsing safeguards are missing"
  exit 1
fi

if ! has_text 'runtime_mode' "$ROOT/scripts/build-launchers.zsh"; then
  print -u2 -- "ERROR: launcher runtime state propagation is missing"
  exit 1
fi

if ! has_text 'wait-children|LSUIElement' "$ROOT/scripts/build-launchers.zsh"; then
  print -u2 -- "ERROR: launchers must be on-demand and hidden from ordinary Dock app treatment"
  exit 1
fi

if ! has_text 'PYTHONDONTWRITEBYTECODE' "$ROOT/scripts/build-launchers.zsh"; then
  print -u2 -- "ERROR: launcher must not create unsigned Python __pycache__ resources"
  exit 1
fi

if has_text '&!|for \(\(i=0; i<180' "$ROOT/scripts/build-launchers.zsh"; then
  print -u2 -- "ERROR: launchers must not detach Wine or poll as a resident background process"
  exit 1
fi

for marker in 'Fresh-session execution contract' 'CX_BUILD' 'Verify-only existing installation' 'repair --bottle' 'Patcher.*client' 'allow-missing-installer' 'deploy-app'; do
  if ! has_text "$marker" "$ROOT/SKILL.md"; then
    print -u2 -- "ERROR: Skill execution contract marker is missing: $marker"
    exit 1
  fi
done

if ! has_text 'verify-registration|registration' "$ROOT/scripts/uaro-crossover.zsh" "$ROOT/SKILL.md"; then
  print -u2 -- "ERROR: CrossOver registration gate is missing"
  exit 1
fi

if ! has_text 'cxmenu --query|CXMenuMacOSX|cxmenu_macosx' "$ROOT/scripts/verify-registration.zsh" "$ROOT/scripts/verify-registration.py" "$ROOT/SKILL.md"; then
  print -u2 -- "ERROR: CrossOver native menu query hard gate is missing"
  exit 1
fi

if ! has_text 'comm=,args=|find-uaro-process' "$ROOT/scripts/verify-live-runtime.zsh"; then
  print -u2 -- "ERROR: live runtime PID discovery is too broad"
  exit 1
fi

if ! has_text 'print -r -- "\$PROCESS_INFO"' "$ROOT/scripts/verify-live-runtime.zsh"; then
  print -u2 -- "ERROR: live runtime must preserve Windows backslashes during PID validation"
  exit 1
fi

if ! has_text 'probe_state_status|record_probe_state stock.*probe_state_status' "$ROOT/scripts/overlay.zsh"; then
  print -u2 -- "ERROR: probe state must reflect semantic AFFECTED/clobbered results"
  exit 1
fi

if ! has_text 'cxmenu.*--sync.*--bottle.*--mode install' "$ROOT/scripts/build-launchers.zsh"; then
  print -u2 -- "ERROR: launcher creation must refresh CrossOver menu registration"
  exit 1
fi

if ! has_text 'STATE_FILE_PATH:h' "$ROOT/scripts/preflight.zsh" || ! has_text 'mkdir -p' "$ROOT/scripts/preflight.zsh"; then
  print -u2 -- "ERROR: preflight must prepare the user-local state directory"
  exit 1
fi

if ! has_text 'staging.*large installer parts' "$ROOT/scripts/stage-installer.zsh"; then
  print -u2 -- "ERROR: installer staging progress message is missing"
  exit 1
fi

if ! has_text 'APPLICATIONS_DIR="/Applications"|/Applications' "$ROOT/scripts/build-launchers.zsh" "$ROOT/scripts/repair.zsh" "$ROOT/SKILL.md"; then
  print -u2 -- "ERROR: system Applications launcher default is missing"
  exit 1
fi

if ! has_text 'CROSSOVER_SIGNATURE_STATUS|state_status|uo_state_writable' "$ROOT/scripts/preflight.zsh" "$ROOT/scripts/lib/crossover-common.zsh"; then
  print -u2 -- "ERROR: preflight environment evidence is missing"
  exit 1
fi

if has_text 'Game\.app' "$ROOT/scripts/build-launchers.zsh"; then
  print -u2 -- "ERROR: the first launcher release must not generate Game.app"
  exit 1
fi

print "PASS: shell syntax and CrossOver-only static checks"
