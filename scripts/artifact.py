#!/usr/bin/env python3
"""Import and verify external CrossOver raw-input artifacts without trusting paths."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import sys
from pathlib import Path


CANONICAL = {
    "wow64win.dll": ("wow64win.dll", "wow64win.dll.crossover-26.3.0"),
    "rawinput_overflow_probe.exe": ("rawinput_overflow_probe.exe",),
    "rawinput_overflow_probe.c": ("rawinput_overflow_probe.c",),
    "rawinput_patch": ("wow64win-rawinput-devicelist.patch",),
}
ALLOWED_SOURCE_FILES = {
    "README.md",
    "SKILL.md",
    "SHARE-PROMPT.md",
    "patch_opensetup_rosetta.py",
    "rawinput_overflow_probe.c",
    "rawinput_overflow_probe.exe",
    "wow64win-rawinput-devicelist.patch",
    "wow64win.dll",
    "wow64win.dll.crossover-26.3.0",
}


def crossover_family(value: str | None) -> str:
    text = (value or "").strip()
    if text == "26.3" or text.startswith("26.3.0"):
        return "26.3.0"
    return text


def same_crossover_family(left: str | None, right: str | None) -> bool:
    family = crossover_family(left)
    return family == "26.3.0" and family == crossover_family(right)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def regular_file(root: Path, name: str) -> Path:
    candidate = root / name
    if candidate.is_symlink() or not candidate.is_file():
        raise ValueError(f"required artifact is not a regular file: {candidate}")
    if candidate.resolve().parent != root.resolve():
        raise ValueError(f"artifact path escapes source directory: {candidate}")
    return candidate


def pe_machine(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if len(data) < 0x40 or data[:2] != b"MZ":
        raise ValueError(f"not a PE file: {path}")
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    if pe_offset + 0x1A > len(data) or data[pe_offset : pe_offset + 4] != b"PE\0\0":
        raise ValueError(f"invalid PE header: {path}")
    machine = struct.unpack_from("<H", data, pe_offset + 4)[0]
    magic = struct.unpack_from("<H", data, pe_offset + 24)[0]
    return machine, magic


def validate_patch(path: Path) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if "for (i = 0; i < *count; ++i)" not in text or "for (i = 0; i < ret; ++i)" not in text:
        raise ValueError("raw-input source patch does not contain the exact *count -> ret change")


def source_files(source: Path) -> dict[str, Path]:
    source = source.expanduser().resolve()
    if not source.is_dir():
        raise ValueError(f"artifact source directory does not exist: {source}")
    unknown = sorted(
        entry.name for entry in source.iterdir() if entry.name not in ALLOWED_SOURCE_FILES
    )
    if unknown:
        raise ValueError(f"unknown files in artifact source directory: {', '.join(unknown)}")
    selected: dict[str, Path] = {}
    for key, candidates in CANONICAL.items():
        for candidate in candidates:
            path = source / candidate
            if path.exists():
                selected[key] = regular_file(source, candidate)
                break
        if key not in selected:
            raise ValueError(f"missing artifact member for {key}: {', '.join(candidates)}")
    dll_machine, dll_magic = pe_machine(selected["wow64win.dll"])
    if (dll_machine, dll_magic) != (0x8664, 0x20B):
        raise ValueError("wow64win.dll must be an x86-64 PE32+ DLL")
    probe_machine, probe_magic = pe_machine(selected["rawinput_overflow_probe.exe"])
    if (probe_machine, probe_magic) != (0x14C, 0x10B):
        raise ValueError("rawinput_overflow_probe.exe must be an x86 PE32 executable")
    validate_patch(selected["rawinput_patch"])
    return selected


def make_manifest(
    files: dict[str, Path],
    build: str,
    public_version: str,
    kind: str,
    source_revision: str,
    redistribution_license: str,
) -> dict:
    return {
        "schema": 2,
        "artifact_kind": kind,
        "crossover_public_version": public_version,
        "crossover_build": build,
        "files": {
            key: {"path": destination, "sha256": sha256(path)}
            for key, (path, destination) in (
                ("wow64win.dll", (files["wow64win.dll"], "wow64win.dll")),
                ("rawinput_overflow_probe.exe", (files["rawinput_overflow_probe.exe"], "rawinput_overflow_probe.exe")),
                ("rawinput_patch", (files["rawinput_patch"], "wow64win-rawinput-devicelist.patch")),
                ("rawinput_probe_source", (files["rawinput_overflow_probe.c"], "rawinput_overflow_probe.c")),
            )
        },
        "provenance": {
            "status": "community_prebuilt" if kind == "community_prebuilt" else "reproducible_source",
            "source_revision": source_revision,
            "binary_signature": "unconfirmed" if kind == "community_prebuilt" else "not-applicable",
            "redistribution_license": redistribution_license,
        },
    }


def inspect(args: argparse.Namespace) -> int:
    files = source_files(args.source_dir)
    report = {
        "source_dir": str(args.source_dir.expanduser().resolve()),
        "crossover_build": args.crossover_build,
        "status": "candidate",
        "files": {
            key: {"name": path.name, "size": path.stat().st_size, "sha256": sha256(path)}
            for key, path in files.items()
        },
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


def write_import_state(args: argparse.Namespace, cache: Path, manifest: dict) -> None:
    if not args.state_file:
        return
    state_path = args.state_file.expanduser().resolve()
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        state = {}
    state.setdefault("schema", 2)
    state["phase"] = "rawinput"
    state["status"] = "experimental"
    raw_input = state.get("raw_input") if isinstance(state.get("raw_input"), dict) else {}
    raw_input.update({
        "artifact_dir": str(cache),
        "wow64win_sha256": manifest["files"]["wow64win.dll"]["sha256"],
        "probe_sha256": manifest["files"]["rawinput_overflow_probe.exe"]["sha256"],
        "status": "pending",
        "provenance": manifest["provenance"],
    })
    state["raw_input"] = raw_input
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def import_artifact(args: argparse.Namespace) -> int:
    files = source_files(args.source_dir)
    cache = args.cache_dir.expanduser().resolve()
    cache.parent.mkdir(parents=True, exist_ok=True)
    if cache.exists():
        if not cache.is_dir():
            raise ValueError(f"artifact cache is not a directory: {cache}")
        existing = cache / "manifest.json"
        if existing.is_file():
            manifest = json.loads(existing.read_text(encoding="utf-8"))
            if not same_crossover_family(manifest.get("crossover_build"), args.crossover_build):
                raise ValueError("artifact cache exists for a different CrossOver version family")
            verify_manifest(cache, manifest, args.crossover_build, "overlay")
            write_import_state(args, cache, manifest)
            print(f"PASS: artifact cache already matches {cache}")
            return 0
        if any(cache.iterdir()):
            raise ValueError(f"artifact cache is non-empty without a manifest: {cache}")
    else:
        cache.mkdir()

    staging = cache.with_name(cache.name + ".staging")
    if staging.exists():
        raise ValueError(f"staging directory already exists; inspect before removing: {staging}")
    staging.mkdir()
    try:
        destinations = {
            "wow64win.dll": "wow64win.dll",
            "rawinput_overflow_probe.exe": "rawinput_overflow_probe.exe",
            "rawinput_overflow_probe.c": "rawinput_overflow_probe.c",
            "rawinput_patch": "wow64win-rawinput-devicelist.patch",
        }
        for key, destination in destinations.items():
            shutil.copy2(files[key], staging / destination)
        manifest = make_manifest(
            {
                "wow64win.dll": staging / "wow64win.dll",
                "rawinput_overflow_probe.exe": staging / "rawinput_overflow_probe.exe",
                "rawinput_overflow_probe.c": staging / "rawinput_overflow_probe.c",
                "rawinput_patch": staging / "wow64win-rawinput-devicelist.patch",
            },
            args.crossover_build,
            args.crossover_public_version,
            args.artifact_kind,
            args.source_revision,
            args.redistribution_license,
        )
        (staging / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        verify_manifest(staging, manifest, args.crossover_build, "overlay")
        staging.replace(cache)
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    print(f"PASS: imported {args.artifact_kind} artifact into {cache}")
    if args.artifact_kind == "community_prebuilt":
        print("INFO: DLL provenance remains unconfirmed; cache is experimental only")
    write_import_state(args, cache, manifest)
    return 0


def verify_manifest(root: Path, manifest: dict, build: str, mode: str) -> None:
    if manifest.get("schema") != 2:
        raise ValueError("artifact manifest schema must be 2")
    if not same_crossover_family(manifest.get("crossover_build"), build):
        raise ValueError(
            f"artifact build {manifest.get('crossover_build')!r} is not in the 26.3.0 family of {build!r}"
        )
    public = manifest.get("crossover_public_version")
    if not public:
        raise ValueError("manifest crossover_public_version is required")
    if not same_crossover_family(str(public), "26.3.0"):
        raise ValueError(f"manifest crossover_public_version {public!r} is not 26.3.0")
    provenance = manifest.get("provenance")
    if not isinstance(provenance, dict) or provenance.get("status") not in ("community_prebuilt", "reproducible_source"):
        raise ValueError("manifest provenance.status must be community_prebuilt or reproducible_source")
    for field in ("source_revision", "binary_signature", "redistribution_license"):
        if not provenance.get(field):
            raise ValueError(f"manifest provenance.{field} is required")
    if provenance["status"] == "reproducible_source" and "unconfirmed" in {
        provenance["source_revision"], provenance["redistribution_license"]
    }:
        raise ValueError("reproducible_source artifacts require confirmed source revision and redistribution license")
    required = ("wow64win.dll", "rawinput_overflow_probe.exe")
    if mode == "overlay":
        required += ("rawinput_patch", "rawinput_probe_source")
    entries = manifest.get("files")
    if not isinstance(entries, dict):
        raise ValueError("manifest.files must be an object")
    for name in required:
        entry = entries.get(name)
        if not isinstance(entry, dict) or not entry.get("path") or not entry.get("sha256"):
            raise ValueError(f"manifest.files.{name} must declare path and sha256")
        path = (root / str(entry["path"])).resolve()
        if root.resolve() not in path.parents or not path.is_file():
            raise ValueError(f"artifact path is missing or escapes artifact directory: {path}")
        actual = sha256(path)
        if actual.lower() != str(entry["sha256"]).lower():
            raise ValueError(f"SHA-256 mismatch for {name}: got {actual}, expected {entry['sha256']}")
    if mode == "overlay":
        dll_machine, dll_magic = pe_machine(root / str(entries["wow64win.dll"]["path"]))
        if (dll_machine, dll_magic) != (0x8664, 0x20B):
            raise ValueError("manifest wow64win.dll is not x86-64 PE32+")
        probe_machine, probe_magic = pe_machine(root / str(entries["rawinput_overflow_probe.exe"]["path"]))
        if (probe_machine, probe_magic) != (0x14C, 0x10B):
            raise ValueError("manifest probe is not x86 PE32")
        validate_patch(root / str(entries["rawinput_patch"]["path"]))


def verify(args: argparse.Namespace) -> int:
    root = args.artifact_dir.expanduser().resolve()
    manifest_path = root / "manifest.json"
    if not manifest_path.is_file():
        raise ValueError(f"artifact manifest missing: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    verify_manifest(root, manifest, args.crossover_build, args.mode)
    print(f"PASS: artifact matches CrossOver build {args.crossover_build}")
    if manifest.get("provenance", {}).get("status") == "community_prebuilt":
        print("WARN: community prebuilt artifact is experimental; source/signature/license are unconfirmed")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("inspect", "import"):
        child = sub.add_parser(command)
        child.add_argument("--source-dir", required=True, type=Path)
        if command == "import":
            child.add_argument("--cache-dir", required=True, type=Path)
            child.add_argument("--state-file", type=Path)
        child.add_argument("--crossover-build", required=True)
        child.add_argument("--crossover-public-version", default="26.3.0")
        if command == "import":
            child.add_argument("--artifact-kind", choices=("community_prebuilt", "reproducible_source"), default="community_prebuilt")
            child.add_argument("--source-revision", default="unconfirmed")
            child.add_argument("--redistribution-license", default="unconfirmed")
    child = sub.add_parser("verify")
    child.add_argument("--artifact-dir", required=True, type=Path)
    child.add_argument("--crossover-build", required=True)
    child.add_argument("--mode", choices=("probe", "overlay"), default="overlay")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "inspect":
            return inspect(args)
        if args.command == "import":
            return import_artifact(args)
        return verify(args)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
