#!/usr/bin/env python3
"""Configure the portable uaRO settings with backups and byte-level checks."""

from __future__ import annotations

import argparse
import re
import shutil
import uuid
from pathlib import Path


def args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-dir", required=True, type=Path)
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    parser.add_argument("--device-id", default=None)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def replace_value(text: str, key: str, value: str | int) -> str:
    pattern = re.compile(
        r'(OptionInfoList\["' + re.escape(key) + r'"\]\s*=\s*)(?:"[^"]*"|-?\d+)'
    )
    replacement = f'"{value}"' if isinstance(value, str) else str(value)
    text, count = pattern.subn(lambda match: match.group(1) + replacement, text)
    if count != 1:
        raise SystemExit(f"ERROR: expected exactly one OptionInfoList entry for {key}, found {count}")
    return text


def backup_once(path: Path) -> Path:
    backup = path.with_name(path.name + ".orig-backup")
    if not backup.exists():
        shutil.copy2(path, backup)
    return backup


def main() -> int:
    parsed = args()
    game_dir = parsed.game_dir.expanduser().resolve()
    if parsed.width <= 0 or parsed.height <= 0:
        raise SystemExit("ERROR: width and height must be positive")

    dinput = game_dir / "dinput.ini"
    option_info = game_dir / "savedata" / "OptionInfo.lua"
    for path in (dinput, option_info):
        if not path.is_file():
            raise SystemExit(f"ERROR: required file not found: {path}")

    dinput_text = dinput.read_text(encoding="utf-8")
    dinput_new, count = re.subn(r"(?m)^(\s*WindowLock\s*=\s*)\d+", r"\g<1>1", dinput_text)
    if count != 1:
        raise SystemExit(f"ERROR: expected exactly one WindowLock entry, found {count}")

    option_text = option_info.read_text(encoding="utf-8")
    device_id = parsed.device_id or "{" + str(uuid.uuid4()).upper() + "}"
    for key, value in (
        ("RENDERSYSTEM", 2),
        ("ISFULLSCREENMODE", 0),
        ("MouseExclusive", 0),
        ("WIDTH", parsed.width),
        ("HEIGHT", parsed.height),
        ("DX9DEVICEID", device_id),
        ("DX9DEVICENAME", r"\\\\.\\DISPLAY1"),
    ):
        option_text = replace_value(option_text, key, value)

    if 'OptionInfoList["OLD_WIDTH"]' in option_text:
        option_text = replace_value(option_text, "OLD_WIDTH", parsed.width)
    else:
        option_text = option_text.replace(
            f'OptionInfoList["WIDTH"] = {parsed.width}\n',
            f'OptionInfoList["WIDTH"] = {parsed.width}\nOptionInfoList["OLD_WIDTH"] = {parsed.width}\n',
            1,
        )
    if 'OptionInfoList["OLD_HEIGHT"]' in option_text:
        option_text = replace_value(option_text, "OLD_HEIGHT", parsed.height)
    else:
        option_text = option_text.replace(
            f'OptionInfoList["HEIGHT"] = {parsed.height}\n',
            f'OptionInfoList["HEIGHT"] = {parsed.height}\nOptionInfoList["OLD_HEIGHT"] = {parsed.height}\n',
            1,
        )

    if parsed.dry_run:
        print(f"DRY-RUN: would configure {game_dir} to {parsed.width}x{parsed.height}")
        return 0

    dinput_backup = backup_once(dinput)
    option_backup = backup_once(option_info)
    dinput.write_text(dinput_new, encoding="utf-8")
    option_info.write_text(option_text, encoding="utf-8")

    raw = option_info.read_bytes()
    expected_device_line = b'OptionInfoList["DX9DEVICENAME"] = "\\\\\\\\.\\\\DISPLAY1"'
    if expected_device_line not in raw:
        raise SystemExit("ERROR: DX9DEVICENAME raw bytes failed verification")
    if b"WindowLock=1" not in dinput.read_bytes().replace(b" ", b""):
        raise SystemExit("ERROR: WindowLock failed verification")
    print(f"PASS: configured {game_dir}")
    print(f"PASS: backups {dinput_backup} and {option_backup}")
    print(f"PASS: resolution={parsed.width}x{parsed.height} windowed=true")
    print("PASS: DX9DEVICENAME raw bytes verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
