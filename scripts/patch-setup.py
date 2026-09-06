#!/usr/bin/env python3
"""Apply the three known uaRO OpenSetup compatibility patches safely."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


SITES = (
    ("site_a", 0x2C0CD, b"\xdc", b"\xd8"),
    ("site_b", 0x21E39, bytes.fromhex("dcd8dfe0"), bytes.fromhex("ddd8b440")),
    ("site_c", 0x43C08, b"mss32.dll", b"mss32.off"),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--setup", required=True, type=Path)
    parser.add_argument("--backup", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--report-json", type=Path)
    return parser.parse_args()


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def main() -> int:
    args = parse_args()
    setup = args.setup.expanduser().resolve()
    backup = (args.backup or setup.with_name(setup.name + ".orig-backup")).expanduser().resolve()
    if not setup.is_file():
        fail(f"setup executable not found: {setup}")

    original = setup.read_bytes()
    pending: list[tuple[str, int, bytes, bytes]] = []
    states: dict[str, str] = {}
    for name, offset, before, after in SITES:
        current = original[offset : offset + len(before)]
        if current == before:
            states[name] = "pending"
            pending.append((name, offset, before, after))
        elif current == after:
            states[name] = "already_patched"
        else:
            fail(
                f"{name} has unknown bytes at 0x{offset:X}: "
                f"{current.hex()} (expected {before.hex()} or {after.hex()})"
            )

    if args.dry_run:
        print(json.dumps({"setup": str(setup), "states": states, "would_patch": [x[0] for x in pending]}, indent=2))
        return 0

    if pending and not backup.exists():
        shutil.copy2(setup, backup)
    elif pending and backup.read_bytes() != original:
        fail(f"existing backup does not match current pre-patch file: {backup}")

    updated = bytearray(original)
    for name, offset, before, after in pending:
        updated[offset : offset + len(before)] = after
    setup.write_bytes(updated)

    final = setup.read_bytes()
    changed = [index for index, (left, right) in enumerate(zip(original, final)) if left != right]
    expected = sorted(index for _, offset, before, after in pending for index in range(offset, offset + len(before)) if before[index - offset] != after[index - offset])
    if changed != expected:
        fail(f"unexpected byte diff: got {[hex(x) for x in changed]}, expected {[hex(x) for x in expected]}")
    for name, offset, before, after in SITES:
        if final[offset : offset + len(after)] != after:
            fail(f"{name} did not verify after patch")

    report = {
        "setup": str(setup),
        "backup": str(backup) if backup.exists() else None,
        "states": states,
        "patched": [name for name, *_ in pending],
        "changed_offsets": [hex(value) for value in changed],
    }
    if args.report_json:
        args.report_json.expanduser().write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
