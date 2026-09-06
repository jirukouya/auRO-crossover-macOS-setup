#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/patch-setup.py"
SITES = (
    (0x2C0CD, b"\xdc", b"\xd8"),
    (0x21E39, bytes.fromhex("dcd8dfe0"), bytes.fromhex("ddd8b440")),
    (0x43C08, b"mss32.dll", b"mss32.off"),
)


def run(*args: str, expect: int = 0) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["python3", str(SCRIPT), *args],
        text=True,
        capture_output=True,
    )
    assert result.returncode == expect, (result.returncode, result.stdout, result.stderr)
    return result


with tempfile.TemporaryDirectory() as temporary:
    setup = Path(temporary) / "setup.exe"
    data = bytearray(b"\0" * 0x50000)
    for offset, before, _ in SITES:
        data[offset : offset + len(before)] = before
    setup.write_bytes(data)

    dry = run("--setup", str(setup), "--dry-run")
    report = json.loads(dry.stdout)
    assert report["would_patch"] == ["site_a", "site_b", "site_c"]

    run("--setup", str(setup))
    patched = setup.read_bytes()
    for offset, _, after in SITES:
        assert patched[offset : offset + len(after)] == after
    assert setup.with_name("setup.exe.orig-backup").read_bytes() == bytes(data)

    second = run("--setup", str(setup))
    second_report = json.loads(second.stdout)
    assert second_report["patched"] == []
    assert setup.read_bytes() == patched

    unknown = Path(temporary) / "unknown.exe"
    unknown.write_bytes(data.replace(b"\xdc", b"\xff", 1))
    failure = subprocess.run(
        ["python3", str(SCRIPT), "--setup", str(unknown)],
        text=True,
        capture_output=True,
    )
    assert failure.returncode != 0
    assert "unknown bytes" in failure.stderr

print("PASS: patch-setup fixture tests")
