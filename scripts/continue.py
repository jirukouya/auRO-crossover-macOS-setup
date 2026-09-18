#!/usr/bin/env python3
"""Read uaRO state and identify the next safe core-install action.

This command is deliberately read-only.  It does not install, patch, launch, or
delete anything; it gives an AI agent a small, user-facing resume plan.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


DEFAULT_STATE = Path.home() / "Library/Application Support/uaRO-CrossOver/state.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-file", type=Path, default=DEFAULT_STATE)
    parser.add_argument("--bottle", help="override the bottle name from state")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args()


def status(value: object) -> str:
    return str(value).lower() if value is not None else ""


def report_for(state_path: Path, state: dict, bottle_override: str | None) -> dict:
    bottle = bottle_override or state.get("bottle") or "uaro-crossover"
    game_dir = state.get("game_dir")
    game_path = Path(game_dir).expanduser() if game_dir else None
    bottle_path = Path.home() / "Library/Application Support/CrossOver/Bottles" / bottle
    installer = state.get("installer") if isinstance(state.get("installer"), dict) else {}
    setup = state.get("setup") if isinstance(state.get("setup"), dict) else {}
    config = state.get("config") if isinstance(state.get("config"), dict) else {}
    gecko = state.get("gecko") if isinstance(state.get("gecko"), dict) else {}
    registration = state.get("registration") if isinstance(state.get("registration"), dict) else {}
    launchers = state.get("launchers") if isinstance(state.get("launchers"), dict) else {}

    installer_complete = status(installer.get("stage")) == "complete"
    installer_staged = status(installer.get("stage")) == "staged"
    game_exists = bool(game_path and game_path.is_dir() and (game_path / "uaRO.exe").is_file())
    setup_pass = status(setup.get("status")) in {"pass", "already_patched", "patched"}
    config_pass = status(config.get("status")) == "pass"
    gecko_pass = status(gecko.get("payload")) == "pass" and status(gecko.get("bottle_marker")) == "pass"
    registration_pass = status(registration.get("status")) == "pass"
    launchers_pass = status(launchers.get("status")) == "pass"
    probe_before = status(state.get("overlay_probe_before")) == "pass"
    affected = status(state.get("overlay_probe_before_affected"))
    clobbered = status(state.get("overlay_probe_before_clobbered"))
    app_dll_pass = status(state.get("app_dll_status")) == "pass"
    probe_after = status(state.get("overlay_probe_after")) == "pass"
    live_pass = status(state.get("live_runtime_status")) == "pass"

    result = {
        "state_file": str(state_path.expanduser().resolve()),
        "route": "existing" if state else "fresh",
        "bottle": bottle,
        "bottle_dir": str(bottle_path),
        "game_dir": str(game_path.resolve()) if game_path else None,
        "status": "resume",
        "next_step": None,
        "user_action": None,
        "message": None,
        "core_complete": False,
        "optional_addons": ["azzyai"],
        "evidence": {
            "state_present": bool(state),
            "bottle_exists": bottle_path.is_dir(),
            "installer": status(installer.get("stage")) or "missing",
            "game_files": game_exists,
            "setup": status(setup.get("status")) or "missing",
            "config": status(config.get("status")) or "missing",
            "gecko": "pass" if gecko_pass else "pending",
            "registration": status(registration.get("status")) or "missing",
            "launchers": status(launchers.get("status")) or "missing",
            "stock_probe": "pass" if probe_before else "missing",
            "runtime": status(state.get("runtime")) or "unknown",
            "live_runtime": status(state.get("live_runtime_status")) or "missing",
        },
    }

    def choose(step: str, message: str, user_action: str | None = None) -> dict:
        result["next_step"] = step
        result["message"] = message
        result["user_action"] = user_action
        return result

    if not state:
        return choose("preflight", "没有现有安装记录，从环境检查开始。")
    if not result["evidence"]["bottle_exists"]:
        return choose("bottle-create", "state 记录的 bottle 不存在，需要先确认或创建目标 bottle。")
    if not installer_complete:
        if installer_staged:
            return choose("install", "安装文件已准备好，下一步是完成 uaRO 安装器界面。", "完成安装器界面并确认游戏目录。")
        return choose("preflight", "安装尚未完成，需要先验证安装器和 gepard 文件。")
    if not game_exists:
        return choose("install", "state 记录的游戏目录不存在或缺少 uaRO.exe，需要重新确认安装目录。", "确认实际游戏目录；不要自动选择另一个 bottle。")
    if not registration_pass:
        return choose("verify-registration", "游戏文件存在，但 CrossOver 登记尚未通过；先执行一次登记修复。")
    if not setup_pass:
        return choose("patch-setup", "已找到游戏，但 setup.exe 尚未通过兼容性 patch。")
    if not config_pass:
        return choose("configure", "setup.exe 已通过，下一步写入默认游戏配置。")
    if not gecko_pass:
        return choose("check-gecko", "Gecko 或 bottle 标记尚未确认；检查并按需要通过 Patcher 完成一次安装。", "如果 CrossOver 要求安装 Gecko，请完成该提示。")
    if not probe_before:
        return choose("overlay-probe", "还没有完成未修改 CrossOver runtime 的 raw-input 基线检查。")
    if affected == "yes" and clobbered != "0" and not (app_dll_pass or probe_after):
        return choose("runtime-choice", "基线受影响，需要选择 Option A 或 Option B 后再部署修复。", "默认是 Option A；只有拒绝修改 CrossOver.app 时才使用 Option B。")
    if not launchers_pass:
        return choose("build-launchers", "运行路线已确定，下一步生成 Patcher 和 Settings 启动按钮。")
    if not registration_pass:
        return choose("verify-registration", "启动按钮已生成，但 CrossOver 登记仍未通过。")
    if not live_pass:
        return choose("launch-patcher", "技术准备已完成，下一步由用户打开 Patcher、登录并进入地图。", "登录并进入地图后，再运行最终运行验证。")

    result["status"] = "complete"
    result["core_complete"] = True
    result["message"] = "核心 uaRO CrossOver 安装已完成；AzzyAI 是独立的可选加装，不会由 continue 自动安装。"
    result["next_step"] = "none"
    return result


def main() -> int:
    parsed = parse_args()
    state_path = parsed.state_file.expanduser().resolve()
    try:
        state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.is_file() else {}
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"ERROR: cannot read state file {state_path}: {exc}")
    if not isinstance(state, dict):
        raise SystemExit(f"ERROR: state file is not a JSON object: {state_path}")
    result = report_for(state_path, state, parsed.bottle)
    if parsed.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"{result['status'].upper()}: {result['message']}")
        print(f"Next step: {result['next_step']}")
        if result["user_action"]:
            print(f"User action: {result['user_action']}")
        print(f"Bottle: {result['bottle']}")
        if result["game_dir"]:
            print(f"Game directory: {result['game_dir']}")
        print("AzzyAI: separate optional add-on; not part of core resume")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
