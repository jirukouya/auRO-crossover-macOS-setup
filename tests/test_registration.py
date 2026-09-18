from __future__ import annotations

import importlib.util
import plistlib
import tempfile
from pathlib import Path
from types import SimpleNamespace


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify-registration.py"
SPEC = importlib.util.spec_from_file_location("verify_registration", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def fixture() -> tuple[tempfile.TemporaryDirectory, SimpleNamespace, dict[str, Path]]:
    temp = tempfile.TemporaryDirectory()
    root = Path(temp.name)
    bottle = root / "bottle"
    drive_c = bottle / "drive_c"
    game = drive_c / "users/crossover/AppData/Local/Programs/UaRO World of Your Dream"
    game.mkdir(parents=True)
    (game / "uaRO.exe").write_bytes(b"game")
    (game / "UaRo Patcher.exe").write_bytes(b"patcher")
    conf = bottle / "cxbottle.conf"
    conf.write_text('"Version" = "26.3.0.39832"\n"MenuMode" = "install"\n"AssocMode" = "install"\n', encoding="utf-8")
    programs = drive_c / "users/crossover/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/UaRO World of Your Dream"
    programs.mkdir(parents=True)
    shortcut = programs / "UaRO World of Your Dream.lnk"
    shortcut.write_bytes(("C:\\users\\crossover\\AppData\\Local\\Programs\\UaRO World of Your Dream\\UaRo Patcher.exe\0").encode("utf-16le"))
    (bottle / "cxmenu.conf").write_text(
        '[StartMenu/UaRO World of Your Dream/UaRO World of Your Dream.lnk]\n'
        '"Shortcut" = "uaropatcher"\n"Mode" = "install"\n',
        encoding="utf-8",
    )
    command_dir = bottle / "desktopdata/cxmenu"
    command_dir.mkdir(parents=True)
    command = command_dir / "UaRO.lnk"
    command.write_text('#!/bin/sh\nexec wine --bottle "uaro-crossover" --start "UaRO World of Your Dream.lnk"\n', encoding="utf-8")
    icon = command_dir / "icon.png"
    icon.write_bytes(b"icon")
    plist = {
        "CrossOver-TEST/": {
            "Children": {
                "StartMenu/": {
                    "Children": {
                        "Windows Applications/": {
                            "Children": {
                                "UaRO World of Your Dream/": {
                                    "Children": {
                                        "UaRO World of Your Dream": {
                                            "Command": f'"{command}"',
                                            "Icon": str(icon),
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    plist_path = command_dir / "cxmenu_macosx.plist"
    plist_path.write_bytes(plistlib.dumps(plist))
    applications = root / "Applications"
    (applications / "CrossOver").mkdir(parents=True)
    args = SimpleNamespace(
        bottle="uaro-crossover",
        bottle_dir=bottle,
        game_dir=game,
        crossover_build="26.3.0.39832",
        applications_dir=applications,
        export_root=applications / "CrossOver",
    )
    return temp, args, {"bottle": bottle, "game": game, "conf": conf, "plist": plist_path, "command": command, "shortcut": shortcut}


def test_registration_passes_with_complete_export():
    temp, args, _ = fixture()
    try:
        assert MODULE.result(args)["status"] == "pass"
    finally:
        temp.cleanup()


def test_missing_plist_is_blocked():
    temp, args, paths = fixture()
    try:
        paths["plist"].unlink()
        report = MODULE.result(args)
        assert report["status"] == "blocked"
        assert report["failure_code"] == "CXMENU_PLIST_MISSING"
    finally:
        temp.cleanup()


def test_wrong_bottle_wrapper_is_blocked():
    temp, args, paths = fixture()
    try:
        paths["command"].write_text('#!/bin/sh\nexec wine --bottle "other-bottle" --start "UaRO World of Your Dream.lnk"\n', encoding="utf-8")
        report = MODULE.result(args)
        assert report["status"] == "blocked"
        assert report["failure_code"] == "EXPORTED_COMMAND_WRONG_BOTTLE"
    finally:
        temp.cleanup()


def test_missing_windows_shortcut_is_blocked():
    temp, args, paths = fixture()
    try:
        paths["shortcut"].unlink()
        report = MODULE.result(args)
        assert report["status"] == "blocked"
        assert report["failure_code"] == "WINDOWS_SHORTCUT_MISSING"
    finally:
        temp.cleanup()


def test_build_drift_is_unconfirmed():
    temp, args, _ = fixture()
    try:
        args.crossover_build = "26.3.0.40000"
        report = MODULE.result(args)
        assert report["status"] == "unconfirmed"
        assert report["failure_code"] == "CROSSOVER_BUILD_DRIFT"
    finally:
        temp.cleanup()


if __name__ == "__main__":
    test_registration_passes_with_complete_export()
    test_missing_plist_is_blocked()
    test_wrong_bottle_wrapper_is_blocked()
    test_missing_windows_shortcut_is_blocked()
    test_build_drift_is_unconfirmed()
    print("PASS: CrossOver registration fixture tests")
