#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/verify-artifact.py"
BUILD = "26.3.0.39832"

with tempfile.TemporaryDirectory() as temporary:
    artifact = Path(temporary)
    files = {
        "wow64win.dll": b"fixture-wow64",
        "ntdll.so": b"fixture-ntdll",
        "rawinput_overflow_probe.exe": b"fixture-probe",
    }
    entries = {}
    for name, contents in files.items():
        path = artifact / name
        path.write_bytes(contents)
        entries[name] = {
            "path": name,
            "sha256": hashlib.sha256(contents).hexdigest(),
        }
    (artifact / "manifest.json").write_text(
        json.dumps(
            {
                "crossover_build": BUILD,
                "source_revision": "fixture-revision",
                "license": "fixture-license",
                "files": entries,
            }
        ),
        encoding="utf-8",
    )
    good = subprocess.run(
        ["python3", str(SCRIPT), "--artifact-dir", str(artifact), "--crossover-build", BUILD],
        text=True,
        capture_output=True,
    )
    assert good.returncode == 0, (good.stdout, good.stderr)

    bad = subprocess.run(
        ["python3", str(SCRIPT), "--artifact-dir", str(artifact), "--crossover-build", "other-build"],
        text=True,
        capture_output=True,
    )
    assert bad.returncode != 0
    assert "does not match" in bad.stderr

print("PASS: artifact provenance fixture tests")
