#!/usr/bin/env python3
"""Hash-locked OpenSetup patch profiles used by patch-setup.py."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


PROFILES: dict[str, dict[str, Any]] = {
    "gepard-crossover-26.3.0": {
        "status": "experimental",
        "description": "Community OpenSetup profile for the CrossOver 26.3 uaRO build.",
        "original_sha256": "81b8a080a87ce15ac9158cf2aaf127a8f9408d6d84787d99eb188bc009932cf0",
        "input_sha256": [
            "81b8a080a87ce15ac9158cf2aaf127a8f9408d6d84787d99eb188bc009932cf0",
            "a8d0fdb96f8618a46fde8460e5a97d881e3410377a9290af516e8c9b76b1c9c5",
            "06f8a32fb0219a46a4a7d75fbb2b54af9c57baba5bb5b00dee11549534eede2b",
        ],
        "patched_sha256": "427c3631fb52384902a8a994157c98d9c4399917e869c85d03d493e0ab83fb73",
        "backup_suffix": "original-81b8a080a87c.backup",
        "sites": [
            {
                "name": "site_a",
                "offset": "0x2C0CD",
                "before": "DC D0",
                "after": "D8 D0",
                "description": "Rosetta-safe FCOM ST(0) encoding",
            },
            {
                "name": "site_b",
                "offset": "0x21E39",
                "before": "DC D8",
                "after": "D8 D8",
                "description": "Rosetta-safe FCOMP ST(0) encoding",
            },
            {
                "name": "site_c",
                "offset": "0x43C08",
                "before": "mss32.dll",
                "after": "mss32.off",
                "description": "Keep Miles audio out of OpenSetup",
            },
        ],
    }
}


def load_profiles(path: Path | None = None) -> dict[str, dict[str, Any]]:
    """Load the production catalog or an explicit fixture catalog."""

    if path is None:
        return PROFILES
    data = json.loads(path.expanduser().read_text(encoding="utf-8"))
    if isinstance(data, dict) and "profiles" in data:
        data = data["profiles"]
    if not isinstance(data, dict) or not data:
        raise ValueError("profile catalog must be a non-empty object")
    return data


def parse_bytes(value: str) -> bytes:
    if all(character in "0123456789abcdefABCDEF " for character in value):
        return bytes.fromhex(value)
    return value.encode("ascii")


def normalized_profile(name: str, profile: dict[str, Any]) -> dict[str, Any]:
    required = ("original_sha256", "input_sha256", "patched_sha256", "sites")
    missing = [key for key in required if key not in profile]
    if missing:
        raise ValueError(f"profile {name!r} is missing: {', '.join(missing)}")
    sites = []
    for site in profile["sites"]:
        if not all(key in site for key in ("name", "offset", "before", "after")):
            raise ValueError(f"profile {name!r} contains an incomplete site")
        sites.append(
            {
                **site,
                "offset_int": int(str(site["offset"]), 0),
                "before_bytes": parse_bytes(str(site["before"])),
                "after_bytes": parse_bytes(str(site["after"])),
            }
        )
    normalized = {**profile, "name": name, "sites": sites}
    normalized["input_sha256"] = set(profile["input_sha256"])
    return normalized


def find_profile_for_hash(profiles: dict[str, dict[str, Any]], digest: str) -> tuple[str, dict[str, Any]] | None:
    for name, raw in profiles.items():
        profile = normalized_profile(name, raw)
        if digest in profile["input_sha256"] or digest == profile["patched_sha256"]:
            return name, profile
    return None
