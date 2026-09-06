#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/patch-setup.py"
SITES = (
    ("site_a", 0x2C0CD, "DC D0", "D8 D0"),
    ("site_b", 0x21E39, "DC D8", "D8 D8"),
    ("site_c", 0x43C08, "mss32.dll", "mss32.off"),
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def run(*args: str, expect: int = 0) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(["python3", str(SCRIPT), *args], text=True, capture_output=True)
    assert result.returncode == expect, (result.returncode, result.stdout, result.stderr)
    return result


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    setup = root / "setup.exe"
    profile_path = root / "profiles.json"
    original = bytearray(b"\0" * 0x50000)
    for _, offset, before, _ in SITES:
        raw = bytes.fromhex(before) if all(c in "0123456789abcdefABCDEF " for c in before) else before.encode()
        original[offset : offset + len(raw)] = raw
    patched = bytearray(original)
    profile_sites = []
    for name, offset, before, after in SITES:
        before_bytes = bytes.fromhex(before) if all(c in "0123456789abcdefABCDEF " for c in before) else before.encode()
        after_bytes = bytes.fromhex(after) if all(c in "0123456789abcdefABCDEF " for c in after) else after.encode()
        patched[offset : offset + len(after_bytes)] = after_bytes
        profile_sites.append({"name": name, "offset": hex(offset), "before": before, "after": after})
    profile = {
        "fixture-profile": {
            "status": "fixture-only",
            "original_sha256": sha(bytes(original)),
            "input_sha256": [sha(bytes(original))],
            "patched_sha256": sha(bytes(patched)),
            "backup_suffix": "fixture.backup",
            "sites": profile_sites,
        }
    }
    profile_path.write_text(json.dumps(profile), encoding="utf-8")
    setup.write_bytes(original)

    dry = run("--setup", str(setup), "--profiles-file", str(profile_path), "--dry-run")
    report = json.loads(dry.stdout)
    assert report["profile"] == "fixture-profile"
    assert report["would_patch"] == ["site_a", "site_b", "site_c"]

    run("--setup", str(setup), "--profiles-file", str(profile_path))
    assert setup.read_bytes() == bytes(patched)
    assert setup.with_name("setup.exe.fixture.backup").read_bytes() == bytes(original)

    state_path = root / "state.json"
    state_path.write_text(json.dumps({"schema": 2, "setup": {"backup": "keep-this-backup"}}), encoding="utf-8")
    run("--setup", str(setup), "--profiles-file", str(profile_path), "--state-file", str(state_path), "--dry-run")
    assert json.loads(state_path.read_text(encoding="utf-8"))["setup"]["backup"] == "keep-this-backup"

    second = run("--setup", str(setup), "--profiles-file", str(profile_path))
    second_report = json.loads(second.stdout)
    assert second_report["patched"] == []
    assert second_report["status"] == "already_patched"

    unknown = root / "unknown.exe"
    unknown_data = bytearray(original)
    unknown_data[SITES[0][1]] = 0xFF
    unknown.write_bytes(unknown_data)
    failure = subprocess.run(
        ["python3", str(SCRIPT), "--setup", str(unknown), "--profiles-file", str(profile_path)],
        text=True,
        capture_output=True,
    )
    assert failure.returncode != 0
    assert "unrecognised OpenSetup build" in failure.stderr or "unknown bytes" in failure.stderr

print("PASS: hash-profile patch-setup fixture tests")
