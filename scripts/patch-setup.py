#!/usr/bin/env python3
"""Apply a hash-locked uaRO OpenSetup profile with an atomic, reversible write."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
from pathlib import Path

from setup_profiles import find_profile_for_hash, load_profiles, normalized_profile


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--setup", required=True, type=Path)
    parser.add_argument("--backup", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--report-json", type=Path)
    parser.add_argument("--profiles-file", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--state-file", type=Path, help=argparse.SUPPRESS)
    return parser.parse_args()


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def site_state(data: bytes, profile: dict) -> tuple[dict[str, str], list[dict]]:
    states: dict[str, str] = {}
    pending: list[dict] = []
    for site in profile["sites"]:
        offset = site["offset_int"]
        before = site["before_bytes"]
        after = site["after_bytes"]
        current = data[offset : offset + len(before)]
        if current == before:
            states[site["name"]] = "pending"
            pending.append(site)
        elif current == after:
            states[site["name"]] = "already_patched"
        else:
            fail(
                f"{site['name']} has unknown bytes at 0x{offset:X}: {current.hex()} "
                f"(expected {before.hex()} or {after.hex()})"
            )
    return states, pending


def atomic_write(path: Path, data: bytes) -> None:
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".part", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        shutil.copystat(path, temporary)
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def record_state(path: Path | None, report: dict) -> None:
    if path is None:
        return
    path = path.expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        state = {}
    state.setdefault("schema", 2)
    state["phase"] = "setup"
    state["status"] = "pass"
    previous = state.get("setup") if isinstance(state.get("setup"), dict) else {}
    update = {
        "path": report["setup"],
        "profile": report.get("profile"),
        "before_sha256": report.get("before_sha256"),
        "after_sha256": report.get("after_sha256"),
        "sites": report.get("states", {}),
        "status": report.get("status"),
    }
    # A dry-run or an already-patched check must not erase the backup from a prior real patch.
    if report.get("backup") is not None:
        update["backup"] = report["backup"]
    elif previous.get("backup") is not None:
        update["backup"] = previous["backup"]
    state["setup"] = {**previous, **update}
    path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    setup = args.setup.expanduser().resolve()
    if not setup.is_file():
        fail(f"setup executable not found: {setup}")

    try:
        profiles = load_profiles(args.profiles_file)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        fail(f"cannot load profile catalog: {exc}")

    original = setup.read_bytes()
    current_hash = digest(original)
    match = find_profile_for_hash(profiles, current_hash)
    if match is None:
        fail(f"unrecognised OpenSetup build SHA-256: {current_hash}; refusing to patch")

    profile_name, profile = match
    if current_hash == profile["patched_sha256"]:
        backup = args.backup or setup.with_name(f"{setup.name}.{profile['backup_suffix']}")
        backup = backup.expanduser().resolve()
        report = {
            "setup": str(setup),
            "profile": profile_name,
            "before_sha256": current_hash,
            "after_sha256": current_hash,
            "backup": str(backup) if backup.exists() else None,
            "states": {site["name"]: "already_patched" for site in profile["sites"]},
            "patched": [],
            "changed_offsets": [],
            "status": "already_patched",
        }
        print(json.dumps(report, indent=2))
        if not args.dry_run:
            record_state(args.state_file, report)
        if args.report_json:
            args.report_json.expanduser().write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        return 0
    states, pending = site_state(original, profile)
    if not pending:
        fail(
            f"OpenSetup bytes look patched but full SHA-256 {current_hash} is not the registered "
            f"profile output {profile['patched_sha256']}"
        )
    if current_hash not in profile["input_sha256"]:
        fail(f"profile {profile_name} does not allow input SHA-256 {current_hash}")

    if args.dry_run:
        print(
            json.dumps(
                {
                    "setup": str(setup),
                    "profile": profile_name,
                    "before_sha256": current_hash,
                    "states": states,
                    "would_patch": [site["name"] for site in pending],
                    "target_sha256": profile["patched_sha256"],
                },
                indent=2,
            )
        )
        return 0

    backup = args.backup or setup.with_name(f"{setup.name}.{profile['backup_suffix']}")
    backup = backup.expanduser().resolve()
    if not backup.exists():
        shutil.copy2(setup, backup)
    elif digest(backup.read_bytes()) != current_hash:
        fail(f"existing backup does not match current pre-patch file: {backup}")

    updated = bytearray(original)
    changed_offsets: list[int] = []
    for site in pending:
        offset = site["offset_int"]
        before = site["before_bytes"]
        after = site["after_bytes"]
        updated[offset : offset + len(before)] = after
        changed_offsets.extend(
            offset + index for index, (left, right) in enumerate(zip(before, after)) if left != right
        )

    updated_bytes = bytes(updated)
    actual_changed = [index for index, (left, right) in enumerate(zip(original, updated_bytes)) if left != right]
    if actual_changed != sorted(changed_offsets):
        fail(
            f"unexpected byte diff: got {[hex(value) for value in actual_changed]}, "
            f"expected {[hex(value) for value in sorted(changed_offsets)]}"
        )
    final_hash = digest(updated_bytes)
    if final_hash != profile["patched_sha256"]:
        fail(
            f"profile output hash mismatch: got {final_hash}, expected {profile['patched_sha256']}; "
            "the input may be a different or mixed patch state"
        )
    atomic_write(setup, updated_bytes)
    final = setup.read_bytes()
    if digest(final) != profile["patched_sha256"] or final != updated_bytes:
        fail("final OpenSetup verification failed after atomic replacement")

    report = {
        "setup": str(setup),
        "profile": profile_name,
        "backup": str(backup),
        "before_sha256": current_hash,
        "after_sha256": final_hash,
        "states": {site["name"]: "patched" for site in pending},
        "patched": [site["name"] for site in pending],
        "changed_offsets": [hex(value) for value in sorted(changed_offsets)],
        "status": "patched",
    }
    if args.report_json:
        args.report_json.expanduser().write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    record_state(args.state_file, report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
