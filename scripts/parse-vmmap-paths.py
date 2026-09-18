#!/usr/bin/env python3
"""Extract loaded CrossOver DLL paths from vmmap output."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def extract_paths(text: str, roots: list[str]) -> list[str]:
    normalized_roots = [root.rstrip("/") for root in roots if root]
    paths: list[str] = []
    for line in text.splitlines():
        candidates: list[str] = []
        for root in normalized_roots:
            marker = root + "/"
            start = line.find(marker)
            if start < 0:
                continue
            for suffix in ("wow64win.dll", "ntdll.so"):
                end = line.find(suffix, start)
                if end >= 0:
                    candidates.append(line[start : end + len(suffix)])
        if not candidates:
            candidates = [match.group(1) for match in re.finditer(
                r"(/[^\s]*?(?:wow64win\.dll|ntdll\.so))(?=\s*$)",
                line,
                re.IGNORECASE,
            )]
        if candidates:
            paths.append(candidates[-1])
    return paths


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("usage: parse-vmmap-paths.py VMAP_OUTPUT [ROOT ...]")
    print("\n".join(extract_paths(Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"), sys.argv[2:])))
