#!/usr/bin/env python3
"""Validate the uaRO split installer as a directory or exact three-member ZIP."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import zipfile
from pathlib import Path

EXPECTED = ("UaRO_Setup.exe", "UaRO_Setup-1.bin", "UaRO_Setup-2.bin")


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def directory_report(root: Path) -> dict:
    if not root.is_dir():
        fail(f"installer directory does not exist: {root}")
    members = []
    for name in EXPECTED:
        path = root / name
        if not path.is_file() or path.is_symlink():
            fail(f"required installer member is missing or is a symlink: {path}")
        members.append({
            "name": name,
            "size": path.stat().st_size,
            "sha256": sha256_path(path),
        })
    return {
        "source": str(root),
        "source_type": "directory",
        "members": members,
    }


def zip_report(path: Path) -> dict:
    if not path.is_file() or path.is_symlink():
        fail(f"installer ZIP does not exist or is a symlink: {path}")
    try:
        with zipfile.ZipFile(path) as archive:
            infos = archive.infolist()
            names = [info.filename for info in infos]
            if len(names) != len(set(names)):
                fail("installer ZIP contains duplicate member names")
            if set(names) != set(EXPECTED):
                missing = sorted(set(EXPECTED) - set(names))
                extra = sorted(set(names) - set(EXPECTED))
                fail(f"installer ZIP members differ; missing={missing}, extra={extra}")
            members = []
            for info in infos:
                if info.filename not in EXPECTED:
                    fail(f"unexpected ZIP member: {info.filename}")
                if info.is_dir() or (info.flag_bits & 0x1):
                    fail(f"ZIP member is a directory or encrypted: {info.filename}")
                members.append({
                    "name": info.filename,
                    "size": info.file_size,
                    "compressed_size": info.compress_size,
                    "crc32": f"{info.CRC:08x}",
                })
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile) as exc:
        fail(f"cannot read installer ZIP: {exc}")

    test = subprocess.run(
        ["/usr/bin/unzip", "-t", str(path)],
        text=True,
        capture_output=True,
    )
    if test.returncode != 0:
        detail = (test.stderr or test.stdout).strip().splitlines()[-1:]
        fail("ZIP compressed-data test failed" + (f": {' '.join(detail)}" if detail else ""))
    return {
        "source": str(path),
        "source_type": "zip",
        "archive_size": path.stat().st_size,
        "archive_sha256": sha256_path(path),
        "members": members,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--zip", type=Path)
    source.add_argument("--dir", type=Path)
    parser.add_argument("--report-json", type=Path)
    args = parser.parse_args()

    report = zip_report(args.zip.expanduser().resolve()) if args.zip else directory_report(args.dir.expanduser().resolve())
    report["expected_members"] = list(EXPECTED)
    encoded = json.dumps(report, indent=2, sort_keys=True)
    if args.report_json:
        args.report_json.expanduser().resolve().write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

