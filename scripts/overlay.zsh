#!/bin/zsh

set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib/crossover-common.zsh"

ACTION="${1:-}"
if (( $# )); then
  shift
fi
BOTTLE_NAME="uaro-crossover"
ARTIFACT_DIR=""
OVERLAY_DIR=""

usage() {
  print "Usage: overlay.zsh {probe|build|verify} --bottle NAME --artifact-dir DIR [--overlay-dir DIR]"
}

while (( $# )); do
  case "$1" in
    --bottle) BOTTLE_NAME="$2"; shift 2 ;;
    --artifact-dir) ARTIFACT_DIR="$2"; shift 2 ;;
    --overlay-dir) OVERLAY_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -n "$ACTION" ]] || { usage >&2; exit 2; }
[[ -n "$ARTIFACT_DIR" ]] || uo_die "--artifact-dir is required"
ARTIFACT_DIR="$(uo_realpath "$ARTIFACT_DIR")" || uo_die "artifact directory does not exist: $ARTIFACT_DIR"

uo_validate_bottle_name "$BOTTLE_NAME"
uo_resolve_crossover
uo_require_supported_build
uo_require_arm64_rosetta
uo_require_bottle

OVERLAY_DIR="${OVERLAY_DIR:-$BOTTLE_DIR/uaRO-CrossOver-overlay}"
OVERLAY_DIR="${OVERLAY_DIR:A}"
VERIFY_PROBE_ARTIFACT=(python3 "$SCRIPT_DIR/verify-artifact.py" --artifact-dir "$ARTIFACT_DIR" --crossover-build "$CX_BUILD" --mode probe)
VERIFY_OVERLAY_ARTIFACT=(python3 "$SCRIPT_DIR/verify-artifact.py" --artifact-dir "$ARTIFACT_DIR" --crossover-build "$CX_BUILD" --mode overlay)

artifact_path() {
  python3 - "$ARTIFACT_DIR" "$1" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
print((root / manifest["files"][sys.argv[2]]["path"]).resolve())
PY
}

assert_probe_clean() {
  local log="$1"
  grep -Eiq 'AFFECTED[[:space:]]*=[[:space:]]*no' "$log" || \
    uo_die "raw-input probe did not report AFFECTED=no: $log"
  grep -Eiq 'entries[[:space:]]+clobbered.*(=|:)[[:space:]]*0|clobbered.*past.*(=|:)[[:space:]]*0' "$log" || \
    uo_die "raw-input probe did not report zero clobbered entries: $log"
}

record_probe_state() {
  local scope="$1"
  local probe_status="$2"
  local patch_json
  patch_json="$(python3 - "$ARTIFACT_DIR" "$scope" "$probe_status" "$PROBE_LOG" "$PROBE_AFFECTED" "$PROBE_CLOBBERED" <<'PY'
import json
import sys

artifact_dir, scope, status, log, affected, clobbered = sys.argv[1:]
print(json.dumps({"raw_input": {
    "artifact_dir": artifact_dir,
    scope: {"status": status, "log": log, "affected": affected, "clobbered": int(clobbered)},
    "status": status,
}}))
PY
  )"
  uo_state_merge_json "$patch_json"
}
probe_summary() {
  python3 - "$1" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
affected = re.findall(r"AFFECTED\s*=\s*(yes|no)", text, re.IGNORECASE)
clobbered = re.findall(r"entries\s+clobbered.*?(?:=|:)\s*(\d+)|clobbered.*?past.*?(?:=|:)\s*(\d+)", text, re.IGNORECASE)
if not affected:
    raise SystemExit("ERROR: raw-input probe did not report AFFECTED=yes or AFFECTED=no")
values = [left or right for left, right in clobbered if left or right]
if not values:
    raise SystemExit("ERROR: raw-input probe did not report a numeric clobbered count")
print(affected[-1].lower())
print(values[-1])
PY
}


run_probe() {
  local wine_cmd="$1"
  local tag="$2"
  local require_clean="${3:-0}"
  local probe_dir="$BOTTLE_DIR/drive_c/UaRO-CrossOver-Probe"
  local probe_source="$(artifact_path rawinput_overflow_probe.exe)"
  local probe_target="$probe_dir/rawinput_overflow_probe.exe"
  local state_path="$(uo_state_file)"
  local log_dir="${state_path:h}/logs"
  local log="$log_dir/rawinput-${tag}-$(date +%Y%m%d-%H%M%S).log"
  mkdir -p "$probe_dir" "$log_dir"
  if [[ -e "$probe_target" ]]; then
    cmp -s "$probe_source" "$probe_target" || uo_die "probe already staged but differs: $probe_target"
  else
    cp -p "$probe_source" "$probe_target"
  fi

  uo_info "INFO: running raw-input probe ($tag); log=$log"
  local output rc
  if output="$(WINEDEBUG=+loaddll caffeinate -i "$wine_cmd" --bottle "$BOTTLE_NAME" --workdir "$probe_dir" --cx-app 'C:\UaRO-CrossOver-Probe\rawinput_overflow_probe.exe' 2>&1)"; then
    rc=0
  else
    rc=$?
  fi
  print -- "$output" | tee "$log"
  typeset -a summary=("${(@f)$(probe_summary "$log")}")
  PROBE_AFFECTED="${summary[1]}"
  PROBE_CLOBBERED="${summary[2]}"
  if (( require_clean )); then
    assert_probe_clean "$log"
    (( rc == 0 )) || uo_warn "clean probe returned non-zero guest exit ($rc); semantic output passed"
    uo_info "PASS: raw-input probe is clean ($tag)"
  elif [[ "$PROBE_AFFECTED" == "yes" ]]; then
    (( rc == 0 )) && uo_warn "affected probe returned zero; using semantic output as the gate"
    uo_info "PASS: raw-input probe recorded affected=$PROBE_AFFECTED clobbered=$PROBE_CLOBBERED ($tag; guest rc=$rc)"
  else
    (( rc == 0 )) || uo_warn "stock probe returned non-zero but semantic output is clean"
    uo_info "PASS: raw-input probe recorded affected=$PROBE_AFFECTED clobbered=$PROBE_CLOBBERED ($tag)"
  fi
  PROBE_LOG="$log"
}

case "$ACTION" in
  probe)
    "${VERIFY_PROBE_ARTIFACT[@]}"
    run_probe "$CX_WINE" before 0
    record_probe_state stock affected
    uo_state_set overlay_probe_before pass
    uo_state_set overlay_probe_before_log "$PROBE_LOG"
    uo_state_set overlay_probe_before_affected "$PROBE_AFFECTED"
    uo_state_set overlay_probe_before_clobbered "$PROBE_CLOBBERED"
    uo_write_state overlay probe-before-pass
    ;;
  build)
    "${VERIFY_OVERLAY_ARTIFACT[@]}"
    [[ "$(uo_state_get overlay_probe_before 2>/dev/null || true)" == "pass" ]] || \
      uo_die "run overlay probe first; refusing to build an overlay without a clean stock baseline"
    [[ "$(uo_state_get overlay_probe_before_affected 2>/dev/null || true)" == "yes" ]] || \
      uo_die "stock probe did not report AFFECTED=yes; refusing to deploy an overlay that is not needed"
    [[ ! -e "$OVERLAY_DIR" ]] || uo_die "overlay already exists; inspect it or remove it explicitly before rebuilding: $OVERLAY_DIR"
    mkdir -p "${OVERLAY_DIR:h}"
    STAGING_DIR="$(mktemp -d "$OVERLAY_DIR.stage.XXXXXX")"
    trap '[[ -n "${STAGING_DIR:-}" && -d "$STAGING_DIR" ]] && /bin/rm -rf -- "$STAGING_DIR"' EXIT INT TERM
    for relative in bin lib/wine share; do
      [[ -d "$CX_ROOT/$relative" ]] || uo_die "CrossOver runtime directory is missing: $CX_ROOT/$relative"
      mkdir -p "$STAGING_DIR/$relative"
      cp -R "$CX_ROOT/$relative/." "$STAGING_DIR/$relative/"
    done
    [[ -d "$CX_ROOT/lib/perl" ]] || uo_die "CrossOver runtime support is missing: $CX_ROOT/lib/perl"
    mkdir -p "$STAGING_DIR/lib/perl"
    cp -R "$CX_ROOT/lib/perl/." "$STAGING_DIR/lib/perl/"
    if [[ -d "$CX_ROOT/lib64" ]]; then
      mkdir -p "$STAGING_DIR/lib64"
      cp -R "$CX_ROOT/lib64/." "$STAGING_DIR/lib64/"
    fi

    wow64_source="$(artifact_path wow64win.dll)"
    ntdll_source="$CX_ROOT/lib/wine/x86_64-unix/ntdll.so"
    [[ -f "$ntdll_source" ]] || uo_die "CrossOver ntdll.so is missing: $ntdll_source"
    mkdir -p "$STAGING_DIR/lib/wine/x86_64-windows" "$STAGING_DIR/lib/wine/x86_64-unix"
    cp -p "$wow64_source" "$STAGING_DIR/lib/wine/x86_64-windows/wow64win.dll"
    cp -p "$ntdll_source" "$STAGING_DIR/lib/wine/x86_64-unix/ntdll.so"
    codesign --force --sign - "$STAGING_DIR/lib/wine/x86_64-unix/ntdll.so" >/dev/null
    [[ -x "$STAGING_DIR/bin/wine" ]] || uo_die "overlay wine wrapper was not copied"
    [[ -f "$STAGING_DIR/lib/perl/CXLog.pm" ]] || uo_die "overlay is incomplete: lib/perl/CXLog.pm is missing"
    [[ -f "$STAGING_DIR/lib/wine/x86_64-windows/wow64win.dll" ]] || uo_die "overlay wow64win.dll is missing"
    [[ -f "$STAGING_DIR/lib/wine/x86_64-unix/ntdll.so" ]] || uo_die "overlay ntdll.so is missing"

    python3 - "$STAGING_DIR/overlay-manifest.json" "$CX_VERSION" "$CX_BUILD" "$OVERLAY_DIR" \
      "$STAGING_DIR" "$wow64_source" "$ntdll_source" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path, version, build, overlay, staging, wow64_source, ntdll_source = sys.argv[1:]
def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()
def tree_digest(path: Path) -> str:
    value = hashlib.sha256()
    for child in sorted(path.rglob("*")):
        if child.is_file():
            value.update(str(child.relative_to(path)).encode("utf-8"))
            value.update(b"\0")
            value.update(child.read_bytes())
    return value.hexdigest()
overlay_path = Path(staging)
support_paths = ["bin", "lib/wine", "lib/perl", "share"] + (["lib64"] if (overlay_path / "lib64").exists() else [])
data = {
    "schema": 2,
    "crossover_public_version": version,
    "crossover_build": build,
    "overlay_dir": overlay,
    "artifact_files": {
        "wow64win.dll": {"source": wow64_source, "sha256": digest(Path(wow64_source))},
        "ntdll.so": {"source": ntdll_source, "sha256": digest(Path(ntdll_source))},
    },
    "overlay_files": {
        "lib/wine/x86_64-windows/wow64win.dll": digest(overlay_path / "lib/wine/x86_64-windows/wow64win.dll"),
        "lib/wine/x86_64-unix/ntdll.so": digest(overlay_path / "lib/wine/x86_64-unix/ntdll.so"),
        "lib/perl/CXLog.pm": digest(overlay_path / "lib/perl/CXLog.pm"),
        "bin/wine": digest(overlay_path / "bin/wine"),
    },
    "support_paths": support_paths,
    "support_hashes": {relative: tree_digest(overlay_path / relative) for relative in support_paths},
    "probe_after": "pending",
}
Path(manifest_path).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
    mv "$STAGING_DIR" "$OVERLAY_DIR"
    STAGING_DIR=""
    uo_state_set overlay_dir "$OVERLAY_DIR"
    uo_state_set overlay_artifact_hash "$(uo_hash "$OVERLAY_DIR/lib/wine/x86_64-windows/wow64win.dll")"
    uo_write_state overlay built
    uo_info "PASS: built per-bottle overlay: $OVERLAY_DIR"
    ;;
  verify)
    "${VERIFY_OVERLAY_ARTIFACT[@]}"
    [[ -f "$OVERLAY_DIR/overlay-manifest.json" ]] || uo_die "overlay manifest missing: $OVERLAY_DIR/overlay-manifest.json"
    [[ -x "$OVERLAY_DIR/bin/wine" ]] || uo_die "overlay wine wrapper is missing: $OVERLAY_DIR/bin/wine"
    [[ -f "$OVERLAY_DIR/lib/wine/x86_64-windows/wow64win.dll" ]] || uo_die "overlay wow64win.dll is missing"
    [[ -f "$OVERLAY_DIR/lib/wine/x86_64-unix/ntdll.so" ]] || uo_die "overlay ntdll.so is missing"
    codesign --verify --strict "$OVERLAY_DIR/lib/wine/x86_64-unix/ntdll.so" >/dev/null
    python3 - "$OVERLAY_DIR/overlay-manifest.json" "$CX_VERSION" "$CX_BUILD" "$OVERLAY_DIR" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_text(encoding="utf-8"))
overlay = Path(sys.argv[4]).resolve()
if manifest.get("schema") != 2 or manifest.get("crossover_public_version") != sys.argv[2] or manifest.get("crossover_build") != sys.argv[3]:
    raise SystemExit("ERROR: overlay CrossOver version/build does not match the current CrossOver")
if Path(manifest.get("overlay_dir", "")).resolve() != overlay:
    raise SystemExit("ERROR: overlay manifest path does not match the requested overlay")
for relative, expected in manifest.get("overlay_files", {}).items():
    actual = hashlib.sha256((overlay / relative).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"ERROR: overlay SHA-256 mismatch for {relative}")
def tree_digest(path):
    import hashlib
    value = hashlib.sha256()
    for child in sorted(path.rglob("*")):
        if child.is_file():
            value.update(str(child.relative_to(path)).encode("utf-8"))
            value.update(b"\0")
            value.update(child.read_bytes())
    return value.hexdigest()
for relative, expected in manifest.get("support_hashes", {}).items():
    path = overlay / relative
    if not path.is_dir() or tree_digest(path) != expected:
        raise SystemExit(f"ERROR: overlay support tree SHA-256 mismatch for {relative}")
PY
    run_probe "$OVERLAY_DIR/bin/wine" after 1
    record_probe_state after clean
    uo_state_set overlay_probe_after pass
    uo_state_set overlay_probe_after_log "$PROBE_LOG"
    uo_state_set overlay_probe_after_affected "$PROBE_AFFECTED"
    uo_state_set overlay_probe_after_clobbered "$PROBE_CLOBBERED"
    python3 - "$OVERLAY_DIR/overlay-manifest.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["probe_after"] = "pass"
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
    uo_write_state overlay verified
    uo_info "PASS: overlay matches CrossOver $CX_BUILD and raw-input probe is clean"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
