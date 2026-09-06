#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/configure-game.py"

with tempfile.TemporaryDirectory() as temporary:
    game = Path(temporary) / "UaRO"
    (game / "savedata").mkdir(parents=True)
    (game / "dinput.ini").write_text("[Input]\nWindowLock = 0\n", encoding="utf-8")
    (game / "savedata" / "OptionInfo.lua").write_text(
        "\n".join(
            [
                'OptionInfoList["RENDERSYSTEM"] = 0',
                'OptionInfoList["ISFULLSCREENMODE"] = 1',
                'OptionInfoList["MouseExclusive"] = 1',
                'OptionInfoList["WIDTH"] = 1280',
                'OptionInfoList["HEIGHT"] = 720',
                'OptionInfoList["DX9DEVICEID"] = "{OLD}"',
                'OptionInfoList["DX9DEVICENAME"] = "old"',
                "",
            ]
        ),
        encoding="utf-8",
    )
    result = subprocess.run(
        [
            "python3",
            str(SCRIPT),
            "--game-dir",
            str(game),
            "--width",
            "1920",
            "--height",
            "1200",
            "--device-id",
            "{TEST-DEVICE}",
        ],
        text=True,
        capture_output=True,
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    dinput = (game / "dinput.ini").read_text(encoding="utf-8")
    options = (game / "savedata" / "OptionInfo.lua").read_text(encoding="utf-8")
    assert "WindowLock = 1" in dinput
    assert 'OptionInfoList["RENDERSYSTEM"] = 2' in options
    assert 'OptionInfoList["ISFULLSCREENMODE"] = 0' in options
    assert 'OptionInfoList["MouseExclusive"] = 0' in options
    assert 'OptionInfoList["WIDTH"] = 1920' in options
    assert 'OptionInfoList["HEIGHT"] = 1200' in options
    assert 'OptionInfoList["OLD_WIDTH"] = 1920' in options
    assert 'OptionInfoList["OLD_HEIGHT"] = 1200' in options
    assert 'OptionInfoList["DX9DEVICEID"] = "{TEST-DEVICE}"' in options
    assert 'OptionInfoList["DX9DEVICENAME"] = "\\\\\\\\.\\\\DISPLAY1"' in options
    assert (game / "dinput.ini.orig-backup").is_file()
    assert (game / "savedata" / "OptionInfo.lua.orig-backup").is_file()

print("PASS: configure-game fixture tests")
