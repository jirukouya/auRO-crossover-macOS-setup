#!/usr/bin/env python3
"""Verify CrossOver's exported uaRO application registration without GUI access."""

from __future__ import annotations

import argparse
import json
import plistlib
import re
from pathlib import Path


APP_NAME = "UaRO World of Your Dream"
PATCHER_NAME = "UaRo Patcher.exe"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify CrossOver menu/association registration for uaRO.")
    parser.add_argument("--bottle", required=True)
    parser.add_argument("--bottle-dir", type=Path, required=True)
    parser.add_argument("--game-dir", type=Path, required=True)
    parser.add_argument("--crossover-build", default="")
    parser.add_argument("--applications-dir", type=Path, required=True)
    parser.add_argument("--export-root", type=Path)
    parser.add_argument("--cxmenu-query-file", type=Path, required=True)
    parser.add_argument("--cxmenu-query-rc", type=int, default=0)
    parser.add_argument("--json", action="store_true")
    return parser.parse_args()


def read_key(text: str, key: str) -> str:
    match = re.search(rf'^"{re.escape(key)}"\s*=\s*"([^"]*)"\s*$', text, re.MULTILINE)
    return match.group(1) if match else ""


def matching_block(text: str, needle: str) -> str:
    sections = re.split(r"(?=^\[[^\n]+\])", text, flags=re.MULTILINE)
    for section in sections:
        if needle in section:
            return section
    return ""


def plist_nodes(value: object, name: str):
    if isinstance(value, dict):
        for key, child in value.items():
            if key.rstrip("/") == name:
                yield child
            yield from plist_nodes(child, name)
    elif isinstance(value, list):
        for child in value:
            yield from plist_nodes(child, name)


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] == '"':
        return value[1:-1]
    return value


def query_sections(text: str) -> list[str]:
    return [section for section in re.split(r"(?=^\[[^\n]+\])", text, flags=re.MULTILINE) if section.lstrip().startswith("[")]


def cxmenu_query_matches(text: str) -> tuple[bool, int]:
    sections = query_sections(text)
    app_sections = [section for section in sections if APP_NAME in section]
    matching = [
        section for section in app_sections
        if re.search(r"^IDs=.*CXMenuMacOSX/", section, flags=re.MULTILINE)
    ]
    return bool(app_sections), len(matching)


def shortcut_text(path: Path) -> str:
    data = path.read_bytes()
    return "\n".join((data.decode("utf-8", "ignore"), data.decode("utf-16le", "ignore")))


def result(args: argparse.Namespace) -> dict:
    bottle_dir = args.bottle_dir.expanduser().resolve()
    game_dir = args.game_dir.expanduser().resolve()
    applications_dir = args.applications_dir.expanduser().resolve()
    conf_path = bottle_dir / "cxbottle.conf"
    menu_conf_path = bottle_dir / "cxmenu.conf"
    plist_path = bottle_dir / "desktopdata/cxmenu/cxmenu_macosx.plist"
    checks: dict[str, object] = {}
    failures: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []

    def require(name: str, ok: bool, code: str, message: str, severity: str = "blocked") -> None:
        checks[name] = ok
        if not ok:
            item = {"code": code, "message": message}
            (failures if severity == "blocked" else warnings).append(item)

    require("bottle_dir", bottle_dir.is_dir(), "BOTTLE_MISSING", f"bottle directory is missing: {bottle_dir}")
    require("game_dir", game_dir.is_dir(), "GAME_DIR_MISSING", f"game directory is missing: {game_dir}")
    game_exe = game_dir / "uaRO.exe"
    patcher_exe = game_dir / PATCHER_NAME
    require("game_executable", game_exe.is_file(), "GAME_EXE_MISSING", f"uaRO.exe is missing: {game_exe}")
    require("patcher_executable", patcher_exe.is_file(), "PATCHER_EXE_MISSING", f"{PATCHER_NAME} is missing: {patcher_exe}")

    conf_text = conf_path.read_text(encoding="utf-8", errors="replace") if conf_path.is_file() else ""
    menu_mode = read_key(conf_text, "MenuMode")
    assoc_mode = read_key(conf_text, "AssocMode")
    recorded_build = read_key(conf_text, "Version")
    checks["menu_mode"] = menu_mode
    checks["assoc_mode"] = assoc_mode
    checks["recorded_build"] = recorded_build
    require("menu_mode_install", menu_mode == "install", "MENU_MODE_NOT_INSTALL", f"MenuMode is {menu_mode or 'missing'}, expected install")
    require("assoc_mode_install", assoc_mode == "install", "ASSOC_MODE_NOT_INSTALL", f"AssocMode is {assoc_mode or 'missing'}, expected install")
    if args.crossover_build and recorded_build and recorded_build != args.crossover_build:
        warnings.append({"code": "CROSSOVER_BUILD_DRIFT", "message": f"bottle metadata build {recorded_build} differs from current build {args.crossover_build}"})
    elif args.crossover_build and not recorded_build:
        warnings.append({"code": "CROSSOVER_BUILD_UNCONFIRMED", "message": "bottle metadata has no CrossOver build"})

    menu_text = menu_conf_path.read_text(encoding="utf-8", errors="replace") if menu_conf_path.is_file() else ""
    menu_block = matching_block(menu_text, APP_NAME)
    require("cxmenu_conf", bool(menu_text), "CXMENU_CONF_MISSING", f"cxmenu.conf is missing: {menu_conf_path}")
    require("ua_ro_menu_entry", bool(menu_block), "UA_RO_MENU_ENTRY_MISSING", "cxmenu.conf has no uaRO menu entry")
    if menu_block:
        require("ua_ro_shortcut_mode", '"Mode" = "install"' in menu_block, "UA_RO_SHORTCUT_NOT_INSTALLED", "uaRO menu entry is not marked install")

    shortcut_candidates = sorted((bottle_dir / "drive_c/users/crossover/AppData/Roaming/Microsoft/Windows/Start Menu/Programs").glob(f"**/{APP_NAME}.lnk"))
    shortcut_path = shortcut_candidates[0] if shortcut_candidates else Path()
    require("windows_shortcut", bool(shortcut_path and shortcut_path.is_file()), "WINDOWS_SHORTCUT_MISSING", "installer did not create the expected Windows Start Menu shortcut")
    shortcut_dump = shortcut_text(shortcut_path) if shortcut_path.is_file() else ""
    target_win = ""
    drive_c = bottle_dir / "drive_c"
    try:
        target_win = "C:\\" + str(game_dir.relative_to(drive_c)).replace("/", "\\")
    except ValueError:
        failures.append({"code": "GAME_DIR_OUTSIDE_BOTTLE", "message": "game directory is outside the selected bottle drive_c"})
    require("windows_shortcut_target", PATCHER_NAME.lower() in shortcut_dump.lower() and (not target_win or target_win.lower() in shortcut_dump.lower()), "WINDOWS_SHORTCUT_TARGET_MISMATCH", "Windows shortcut does not target the current bottle game directory")

    plist_data: object = {}
    if plist_path.is_file():
        try:
            plist_data = plistlib.loads(plist_path.read_bytes())
        except (OSError, plistlib.InvalidFileException):
            failures.append({"code": "CXMENU_PLIST_INVALID", "message": f"cannot parse CrossOver menu plist: {plist_path}"})
    require("cxmenu_plist", plist_path.is_file(), "CXMENU_PLIST_MISSING", f"CrossOver menu plist is missing: {plist_path}")
    app_nodes = list(plist_nodes(plist_data, APP_NAME)) if plist_data else []
    require("plist_app_entry", bool(app_nodes), "PLIST_APP_ENTRY_MISSING", "CrossOver menu plist has no uaRO application entry")
    command_paths: list[Path] = []
    icon_paths: list[Path] = []
    for node in app_nodes:
        if not isinstance(node, dict):
            continue
        command = unquote(str(node.get("Command", "")))
        icon = str(node.get("Icon", ""))
        command_match = re.search(r"(/[^\"]+\.lnk)", command)
        if command_match:
            command_paths.append(Path(command_match.group(1)))
        if icon:
            icon_paths.append(Path(icon))
    command_path = next((path for path in command_paths if path.is_file()), Path())
    require("exported_command", bool(command_path), "EXPORTED_COMMAND_MISSING", "CrossOver plist command does not point to an existing .lnk wrapper")
    if command_path.is_file():
        wrapper = command_path.read_text(encoding="utf-8", errors="replace")
        require("exported_command_bottle", f'--bottle "{args.bottle}"' in wrapper, "EXPORTED_COMMAND_WRONG_BOTTLE", "exported command points to a different bottle")
        require("exported_command_shortcut", APP_NAME in wrapper, "EXPORTED_COMMAND_WRONG_TARGET", "exported command does not target the uaRO shortcut")
    require("exported_icon", any(path.is_file() for path in icon_paths), "EXPORTED_ICON_MISSING", "CrossOver plist icon path is missing")
    query_path = args.cxmenu_query_file.expanduser().resolve()
    query_text = query_path.read_text(encoding="utf-8", errors="replace") if query_path.is_file() else ""
    query_has_app, query_matching = cxmenu_query_matches(query_text)
    require("cxmenu_query", args.cxmenu_query_rc == 0 and bool(query_text.strip()), "CXMENU_QUERY_FAILED", "CrossOver cxmenu query could not be completed")
    require("cxmenu_query_ua_ro", query_has_app, "CXMENU_QUERY_UA_RO_MISSING", "CrossOver cxmenu query has no uaRO menu entry")
    require("cxmenu_macosx", query_matching > 0, "CXMENU_MACOSX_NOT_REGISTERED", "uaRO menu entry is not registered with CrossOver's CXMenuMacOSX system")
    # CrossOver exports its menu helpers under the user's CrossOver folder,
    # independently of where our optional signed launchers are installed.
    exported_root = (args.export_root or (Path.home() / "Applications/CrossOver")).expanduser().resolve()
    checks["exported_applications_root"] = str(exported_root)
    require("exported_applications_root", exported_root.is_dir(), "EXPORTED_APPS_ROOT_MISSING", f"CrossOver exported application root is missing: {exported_root}")

    status = "blocked" if failures else ("unconfirmed" if warnings else "pass")
    failure_code = failures[0]["code"] if failures else (warnings[0]["code"] if warnings else None)
    return {
        "status": status,
        "bottle": args.bottle,
        "bottle_dir": str(bottle_dir),
        "game_dir": str(game_dir),
        "crossover_build": args.crossover_build,
        "menu_mode": menu_mode,
        "assoc_mode": assoc_mode,
        "cxmenu_conf": str(menu_conf_path),
        "cxmenu_plist": str(plist_path),
        "shortcut_path": str(shortcut_path) if shortcut_path else "",
        "command_path": str(command_path) if command_path else "",
        "cxmenu_query_rc": args.cxmenu_query_rc,
        "cxmenu_query_matches": query_matching,
        "applications_root": str(exported_root),
        "launcher_applications_dir": str(applications_dir),
        "checks": checks,
        "failures": failures,
        "warnings": warnings,
        "failure_code": failure_code,
    }


def main() -> int:
    args = parse_args()
    report = result(args)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    elif report["status"] == "pass":
        print("PASS: CrossOver uaRO registration is complete")
    else:
        print(f"{str(report['status']).upper()}: CrossOver uaRO registration is not complete")
        for item in report["failures"] + report["warnings"]:
            print(f"- {item['code']}: {item['message']}")
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
