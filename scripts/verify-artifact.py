#!/usr/bin/env python3
"""Verify the provenance manifest and hashes for a CrossOver raw-input artifact."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact-dir", required=True, type=Path)
    parser.add_argument("--crossover-build", required=True)
    parser.add_argument("--mode", choices=("probe", "overlay"), default="overlay")
    args = parser.parse_args()

    root = args.artifact_dir.expanduser().resolve()
    manifest_path = root / "manifest.json"
    if not manifest_path.is_file():
        raise SystemExit(f"ERROR: artifact manifest missing: {manifest_path}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ERROR: invalid artifact manifest: {exc}") from exc

    if manifest.get("crossover_build") != args.crossover_build:
        raise SystemExit(
            f"ERROR: artifact build {manifest.get('crossover_build')!r} does not match {args.crossover_build!r}"
        )
    for field in ("source_revision", "license"):
        if not manifest.get(field):
            raise SystemExit(f"ERROR: manifest field is required: {field}")
    files = manifest.get("files")
    if not isinstance(files, dict):
        raise SystemExit("ERROR: manifest.files must be an object")
    required = ("rawinput_overflow_probe.exe",)
    if args.mode == "overlay":
        required = ("wow64win.dll", "ntdll.so", "rawinput_overflow_probe.exe")
    for name in required:
        entry = files.get(name)
        if not isinstance(entry, dict) or not entry.get("path") or not entry.get("sha256"):
            raise SystemExit(f"ERROR: manifest.files.{name} must declare path and sha256")
        path = (root / entry["path"]).resolve()
        if root not in path.parents and path != root:
            raise SystemExit(f"ERROR: artifact path escapes artifact directory: {path}")
        if not path.is_file():
            raise SystemExit(f"ERROR: artifact file missing: {path}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest.lower() != str(entry["sha256"]).lower():
            raise SystemExit(f"ERROR: SHA-256 mismatch for {name}: got {digest}, expected {entry['sha256']}")
        print(f"PASS: {name} sha256={digest}")
    print(f"PASS: artifact matches CrossOver build {args.crossover_build}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
