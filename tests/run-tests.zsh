#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"

python3 "$ROOT/test_patch_setup.py"
python3 "$ROOT/test_configure_game.py"
python3 "$ROOT/test_artifact.py"
python3 "$ROOT/test_installer.py"
python3 -m py_compile "$ROOT"/../scripts/*.py
"$ROOT/test_shell_static.zsh"
