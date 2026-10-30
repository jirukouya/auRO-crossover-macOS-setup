#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/verify-installer.py"
NAMES = {
    "UaRO_Setup.exe": b"exe-fixture",
    "UaRO_Setup-1.bin": b"bin-one-fixture",
    "UaRO_Setup-2.bin": b"bin-two-fixture",
}


def run(path: Path, expect: int = 0) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["python3", str(SCRIPT), "--zip", str(path)],
        text=True,
        capture_output=True,
    )
    assert result.returncode == expect, (result.returncode, result.stdout, result.stderr)
    return result


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    valid = root / "valid.zip"
    with zipfile.ZipFile(valid, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, content in NAMES.items():
            archive.writestr(name, content)
    report = json.loads(run(valid).stdout)
    assert report["source_type"] == "zip"
    assert [member["name"] for member in report["members"]] == list(NAMES)
    assert all("crc32" in member for member in report["members"])

    extra = root / "extra.zip"
    with zipfile.ZipFile(extra, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, content in NAMES.items():
            archive.writestr(name, content)
        archive.writestr("unexpected.txt", b"no")
    failure = run(extra, expect=1)
    assert "members differ" in failure.stderr

    traversal = root / "traversal.zip"
    with zipfile.ZipFile(traversal, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, content in NAMES.items():
            archive.writestr(name, content)
        archive.writestr("../unexpected.txt", b"no")
    failure = run(traversal, expect=1)
    assert "members differ" in failure.stderr

    corrupt = root / "corrupt.zip"
    corrupt.write_bytes(valid.read_bytes())
    with zipfile.ZipFile(valid) as archive:
        info = archive.getinfo("UaRO_Setup-1.bin")
        data_offset = info.header_offset + 30 + len(info.filename.encode()) + len(info.extra)
    damaged = bytearray(corrupt.read_bytes())
    damaged[data_offset + 1] ^= 0xFF
    corrupt.write_bytes(damaged)
    failure = run(corrupt, expect=1)
    assert "compressed-data test failed" in failure.stderr

    # iCloud cloud-only files must fail fast without being read.
    import importlib.util

    spec = importlib.util.spec_from_file_location("verify_installer", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    assert module.is_dataless(valid) is False
    real_stat = module.os.stat

    class Cloudy:
        def __init__(self, inner):
            self._inner = inner
            self.st_flags = inner.st_flags | module.SF_DATALESS

        def __getattr__(self, name):
            return getattr(self._inner, name)

    module.os.stat = lambda path, *a, **k: Cloudy(real_stat(path, *a, **k))
    try:
        assert module.is_dataless(valid) is True
        try:
            module.zip_report(valid)
        except SystemExit as exc:
            assert "iCloud cloud-only" in str(exc), exc
        else:
            raise AssertionError("dataless ZIP was accepted")
    finally:
        module.os.stat = real_stat

print("PASS: installer ZIP fixture tests")

