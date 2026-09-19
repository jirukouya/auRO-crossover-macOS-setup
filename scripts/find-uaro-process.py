#!/usr/bin/env python3
"""Find a real uaRO.exe process from ps output without matching diagnostic shells."""

from __future__ import annotations

import argparse
import re
import sys


SHELL_NAMES = {
    "sh", "bash", "zsh", "fish", "dash", "ksh", "tcsh", "csh",
    "python", "python3", "perl", "ruby", "ps", "rg", "grep", "awk",
}
UA_RO_RE = re.compile(r"(?i)(?:^|[\\/])uaro\.exe(?:\s|$)")


def candidate_pids(text: str) -> list[int]:
    result: list[int] = []
    for line in text.splitlines():
        fields = line.strip().split(None, 2)
        if len(fields) != 3 or not fields[0].isdigit():
            continue
        pid, comm, args = fields
        comm_name = comm.rsplit("/", 1)[-1].lower()
        if comm_name in SHELL_NAMES:
            continue
        if UA_RO_RE.search(args):
            result.append(int(pid))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, help="validate one explicit PID instead of listing candidates")
    args = parser.parse_args()
    matches = candidate_pids(sys.stdin.read())
    if args.pid is not None:
        return 0 if args.pid in matches else 1
    for pid in matches:
        print(pid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
