#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("parse_vmmap_paths", ROOT / "scripts/parse-vmmap-paths.py")
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

cx_root = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
overlay = "/Users/tester/Library/Application Support/CrossOver/Bottles/uaro-crossover/uaRO-CrossOver-overlay"
text = "\n".join(
    [
        f"__TEXT  rwx SM=COW  {cx_root}/lib/wine/x86_64-windows/wow64win.dll",
        f"__TEXT  rwx SM=COW  {cx_root}/lib/wine/x86_64-unix/ntdll.so",
        f"__TEXT  rwx SM=COW  {overlay}/lib/wine/x86_64-windows/wow64win.dll",
    ]
)
assert MODULE.extract_paths(text, [cx_root, overlay]) == [
    f"{cx_root}/lib/wine/x86_64-windows/wow64win.dll",
    f"{cx_root}/lib/wine/x86_64-unix/ntdll.so",
    f"{overlay}/lib/wine/x86_64-windows/wow64win.dll",
]
print("PASS: vmmap CrossOver path parsing fixture tests")
