from __future__ import annotations

import json
import subprocess
import os
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLANNER = ROOT / "scripts" / "continue.py"


def run_planner(tmp_path: Path, state: dict) -> dict:
    state_path = tmp_path / "state.json"
    state_path.write_text(json.dumps(state), encoding="utf-8")
    result = subprocess.run(
        ["python3", str(PLANNER), "--state-file", str(state_path), "--json"],
        check=True,
        capture_output=True,
        text=True,
        env={**os.environ, "HOME": str(tmp_path)},
    )
    return json.loads(result.stdout)


def base_state(tmp_path: Path) -> dict:
    game_dir = tmp_path / "game"
    game_dir.mkdir()
    (game_dir / "uaRO.exe").write_bytes(b"fixture")
    bottle = Path.home() / "Library/Application Support/CrossOver/Bottles" / "fixture-not-created"
    return {
        "bottle": "fixture-not-created",
        "game_dir": str(game_dir),
        "installer": {"stage": "complete"},
        "setup": {"status": "pass"},
        "config": {"status": "pass"},
        "gecko": {"payload": "pass", "bottle_marker": "pass"},
        "registration": {"status": "pass"},
        "raw_input": {},
        "launchers": {"status": "pass"},
        "overlay_probe_before": "pass",
        "overlay_probe_before_affected": "no",
        "overlay_probe_before_clobbered": "0",
        "live_runtime_status": "unconfirmed",
        "_fixture_bottle": str(bottle),
    }


def test_missing_state_starts_preflight(tmp_path: Path) -> None:
    state_path = tmp_path / "missing.json"
    result = subprocess.run(
        ["python3", str(PLANNER), "--state-file", str(state_path), "--json"],
        check=True,
        capture_output=True,
        text=True,
    )
    report = json.loads(result.stdout)
    assert report["route"] == "fresh"
    assert report["next_step"] == "preflight"


def test_resume_never_selects_azzyai(tmp_path: Path) -> None:
    state = base_state(tmp_path)
    result = run_planner(tmp_path, state)
    assert result["next_step"] == "bottle-create"
    assert result["optional_addons"] == ["azzyai"]
    assert "AzzyAI" not in (result["message"] or "")


def test_core_complete_marks_azzyai_separate(tmp_path: Path) -> None:
    state = base_state(tmp_path)
    state["bottle"] = "fixture"
    state["game_dir"] = str(tmp_path / "game")
    (tmp_path / "Library/Application Support/CrossOver/Bottles/fixture").mkdir(parents=True)
    state["live_runtime_status"] = "pass"
    result = run_planner(tmp_path, state)
    assert result["core_complete"] is True
    assert result["next_step"] == "none"
    assert "AzzyAI" in result["message"]


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="uaro-continue-test.") as directory:
        root = Path(directory)
        (root / "missing").mkdir()
        test_missing_state_starts_preflight(root / "missing")
        (root / "resume").mkdir()
        test_resume_never_selects_azzyai(root / "resume")
        (root / "complete").mkdir()
        test_core_complete_marks_azzyai_separate(root / "complete")
    print("PASS: continue planner fixture tests")
