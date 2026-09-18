#!/usr/bin/env python3
from __future__ import annotations

import json
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "scripts/artifact.py"
VERIFY = ROOT / "scripts/verify-artifact.py"
BUILD = "26.3.0.39832"


def pe(machine: int, magic: int) -> bytes:
    data = bytearray(b"\0" * 512)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 0x80)
    data[0x80:0x84] = b"PE\0\0"
    struct.pack_into("<H", data, 0x84, machine)
    struct.pack_into("<H", data, 0x98, magic)
    return bytes(data)


def run(command: list[str], expect: int = 0) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, text=True, capture_output=True)
    assert result.returncode == expect, (result.returncode, result.stdout, result.stderr)
    return result


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    source = root / "source"
    source.mkdir()
    (source / "wow64win.dll.crossover-26.3.0").write_bytes(pe(0x8664, 0x20B))
    (source / "rawinput_overflow_probe.exe").write_bytes(pe(0x14C, 0x10B))
    (source / "rawinput_overflow_probe.c").write_text(
        "for (i = 0; i < *count; ++i)\nfor (i = 0; i < ret; ++i)\n", encoding="utf-8"
    )
    (source / "wow64win-rawinput-devicelist.patch").write_text(
        "-        for (i = 0; i < *count; ++i)\n+        for (i = 0; i < ret; ++i)\n",
        encoding="utf-8",
    )
    cache = root / "cache"
    run([
        "python3", str(ARTIFACT), "import", "--source-dir", str(source),
        "--cache-dir", str(cache), "--crossover-build", BUILD,
    ])
    manifest = json.loads((cache / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["schema"] == 2
    assert manifest["artifact_kind"] == "community_prebuilt"
    assert manifest["provenance"]["source_revision"] == "unconfirmed"
    run(["python3", str(VERIFY), "--artifact-dir", str(cache), "--crossover-build", BUILD])
    run(["python3", str(VERIFY), "--artifact-dir", str(cache), "--crossover-build", "26.3.0.39999"])
    run(["python3", str(VERIFY), "--artifact-dir", str(cache), "--crossover-build", "26.4.0.1"], expect=1)
    run(["python3", str(VERIFY), "--artifact-dir", str(cache), "--crossover-build", "other"], expect=1)

    # A second import is idempotent; a changed cache is not silently replaced.
    run([
        "python3", str(ARTIFACT), "import", "--source-dir", str(source),
        "--cache-dir", str(cache), "--crossover-build", BUILD,
    ])
    (cache / "wow64win.dll").write_bytes(b"changed")
    result = subprocess.run(
        ["python3", str(VERIFY), "--artifact-dir", str(cache), "--crossover-build", BUILD],
        text=True, capture_output=True,
    )
    assert result.returncode != 0 and "SHA-256 mismatch" in result.stderr

    reproducible = root / "reproducible-cache"
    run([
        "python3", str(ARTIFACT), "import", "--source-dir", str(source),
        "--cache-dir", str(reproducible), "--crossover-build", BUILD,
        "--artifact-kind", "reproducible_source", "--source-revision", "fixture-revision",
        "--redistribution-license", "fixture-license",
    ])
    reproducible_manifest = json.loads((reproducible / "manifest.json").read_text(encoding="utf-8"))
    assert reproducible_manifest["provenance"]["status"] == "reproducible_source"
    run(["python3", str(VERIFY), "--artifact-dir", str(reproducible), "--crossover-build", BUILD])

    wrong_arch = root / "wrong-arch"
    source.rename(wrong_arch)
    (wrong_arch / "wow64win.dll.crossover-26.3.0").write_bytes(pe(0x14C, 0x10B))
    result = subprocess.run(
        ["python3", str(ARTIFACT), "inspect", "--source-dir", str(wrong_arch), "--crossover-build", BUILD],
        text=True, capture_output=True,
    )
    assert result.returncode != 0 and "x86-64 PE32+" in result.stderr
    source = wrong_arch

    bad_patch = root / "bad-patch"
    # Make a clean copy of the valid members, then invalidate only the source patch.
    bad_patch.mkdir()
    for child in source.iterdir():
        child.replace(bad_patch / child.name)
    (bad_patch / "wow64win.dll.crossover-26.3.0").write_bytes((reproducible / "wow64win.dll").read_bytes())
    (bad_patch / "wow64win-rawinput-devicelist.patch").write_text("no replacement here\n", encoding="utf-8")
    result = subprocess.run(
        ["python3", str(ARTIFACT), "inspect", "--source-dir", str(bad_patch), "--crossover-build", BUILD],
        text=True, capture_output=True,
    )
    assert result.returncode != 0 and "*count -> ret" in result.stderr

    extra = root / "extra"
    bad_patch.rename(extra)
    (extra / "unexpected.bin").write_bytes(b"not allowed")
    result = subprocess.run(
        ["python3", str(ARTIFACT), "inspect", "--source-dir", str(extra), "--crossover-build", BUILD],
        text=True, capture_output=True,
    )
    assert result.returncode != 0 and "unknown files" in result.stderr

print("PASS: schema-2 artifact import and provenance fixture tests")
