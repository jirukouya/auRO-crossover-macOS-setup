from __future__ import annotations

import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "find-uaro-process.py"
SPEC = importlib.util.spec_from_file_location("find_uaro_process", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def test_ignores_diagnostic_shell_containing_uaro_text() -> None:
    text = "43394 /bin/zsh /bin/zsh -lc echo uaRO.exe\n"
    assert MODULE.candidate_pids(text) == []


def test_accepts_real_wine_game_process() -> None:
    text = r"99609 C:\users\crossover C:\users\crossover\AppData\Local\Programs\UaRO World of Your Dream\uaRO.exe 1rag1\n"
    assert MODULE.candidate_pids(text) == [99609]


def test_explicit_pid_validation_is_exact() -> None:
    text = r"99609 C:\users\crossover C:\users\crossover\AppData\Local\Programs\UaRO World of Your Dream\uaRO.exe 1rag1\n"
    assert 99609 in MODULE.candidate_pids(text)
    assert 43394 not in MODULE.candidate_pids(text)


if __name__ == "__main__":
    test_ignores_diagnostic_shell_containing_uaro_text()
    test_accepts_real_wine_game_process()
    test_explicit_pid_validation_is_exact()
    print("PASS: uaRO process discovery fixture tests")
