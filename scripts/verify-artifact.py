#!/usr/bin/env python3
"""Compatibility wrapper for the schema-2 CrossOver artifact verifier."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from artifact import verify_manifest


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
        verify_manifest(root, manifest, args.crossover_build, args.mode)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        raise SystemExit(f"ERROR: {exc}") from exc
    print(f"PASS: artifact matches CrossOver build {args.crossover_build}")
    if manifest.get("provenance", {}).get("status") == "community_prebuilt":
        print("WARN: community prebuilt artifact is experimental; source/signature/license are unconfirmed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
