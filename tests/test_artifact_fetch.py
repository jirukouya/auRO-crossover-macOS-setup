#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import struct
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "scripts/artifact.py"
BUILD = "26.3.0.39832"
TAG = f"crossover-{BUILD}"
ASSET_NAME = f"gepard-crossover-fix-{BUILD}-discord.zip"


def pe(machine: int, magic: int) -> bytes:
    data = bytearray(b"\0" * 512)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 0x80)
    data[0x80:0x84] = b"PE\0\0"
    struct.pack_into("<H", data, 0x84, machine)
    struct.pack_into("<H", data, 0x98, magic)
    return bytes(data)


payload_dir = f"gepard-crossover-fix-{BUILD}-discord"
payload = {
    f"{payload_dir}/wow64win.dll.crossover-26.3.0": pe(0x8664, 0x20B),
    f"{payload_dir}/rawinput_overflow_probe.exe": pe(0x14C, 0x10B),
    f"{payload_dir}/rawinput_overflow_probe.c": (
        "for (i = 0; i < *count; ++i)\nfor (i = 0; i < ret; ++i)\n"
    ).encode(),
    f"{payload_dir}/wow64win-rawinput-devicelist.patch": (
        "- for (i = 0; i < *count; ++i)\n+ for (i = 0; i < ret; ++i)\n"
    ).encode(),
}
checksums = "".join(
    f"{hashlib.sha256(data).hexdigest()}  {name}\n" for name, data in payload.items()
)
with tempfile.TemporaryDirectory() as temporary:
    archive_path = Path(temporary) / ASSET_NAME
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("SHA256SUMS", checksums)
        for name, data in payload.items():
            archive.writestr(name, data)
    archive_bytes = archive_path.read_bytes()


spec = importlib.util.spec_from_file_location("uaro_artifact", ARTIFACT)
assert spec and spec.loader
artifact = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artifact)

metadata = {
    "draft": False,
    "tag_name": TAG,
    "html_url": "https://github.com/jirukouya/auRO-crossover-macOS-setup/releases/tag/" + TAG,
    "assets": [{
        "name": ASSET_NAME,
        "state": "uploaded",
        "size": len(archive_bytes),
        "digest": "sha256:" + hashlib.sha256(archive_bytes).hexdigest(),
        "browser_download_url": "https://download.test/asset.zip",
    }],
}


def fake_fetch(url: str, *, accept: str, timeout: int = 30) -> bytes:
    if url == "https://api.test/release":
        return json.dumps(metadata).encode()
    if url == "https://download.test/asset.zip":
        return archive_bytes
    raise AssertionError(f"unexpected fetch URL: {url}")


artifact.fetch_url = fake_fetch

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    cache = root / "cache"
    state = root / "state.json"
    args = argparse.Namespace(
        cache_dir=cache,
        crossover_build=BUILD,
        crossover_public_version="26.3.0",
        repo="jirukouya/auRO-crossover-macOS-setup",
        release_tag=None,
        release_api_url="https://api.test/release",
        state_file=state,
    )
    assert artifact.fetch_artifact(args) == 0
    manifest = json.loads((cache / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["crossover_build"] == BUILD
    saved_state = json.loads(state.read_text(encoding="utf-8"))
    release = saved_state["raw_input"]["release"]
    assert release["tag"] == TAG
    assert release["asset_name"] == ASSET_NAME
    assert release["payload_sha256sums_verified"] is True

    wrong_args = argparse.Namespace(**vars(args))
    wrong_args.crossover_build = "26.3.0.39999"
    try:
        artifact.fetch_artifact(wrong_args)
    except ValueError as exc:
        assert "tag mismatch" in str(exc)
    else:
        raise AssertionError("a different build must not reuse this Release asset")

print("PASS: build-matched Release download, ZIP safety, SHA256SUMS, and state tests")
