#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_ARCHIVE=""
SOURCE_SHA256=""
OUTPUT_DIR=""
CROSSOVER_BUILD="26.3.0.39832"
CROSSOVER_VERSION="26.3.0"
SOURCE_REVISION=""
LICENSE_TEXT="unconfirmed"

usage() {
  print "Usage: build-rawinput-artifact.zsh --source-archive TAR.GZ --source-sha256 HASH --output-dir DIR [options]"
  print "  [--crossover-build BUILD] [--source-revision REV] [--redistribution-license TEXT]"
}
while (( $# )); do
  case "$1" in
    --source-archive) SOURCE_ARCHIVE="$2"; shift 2 ;;
    --source-sha256) SOURCE_SHA256="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --crossover-build) CROSSOVER_BUILD="$2"; shift 2 ;;
    --source-revision) SOURCE_REVISION="$2"; shift 2 ;;
    --redistribution-license) LICENSE_TEXT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ -n "$SOURCE_ARCHIVE" && -n "$SOURCE_SHA256" && -n "$OUTPUT_DIR" ]] || { usage >&2; exit 2; }
SOURCE_ARCHIVE="$(realpath "$SOURCE_ARCHIVE")"
[[ -f "$SOURCE_ARCHIVE" ]] || { print -u2 "ERROR: source archive not found: $SOURCE_ARCHIVE"; exit 1; }
[[ "$SOURCE_SHA256" == "$(/usr/bin/shasum -a 256 "$SOURCE_ARCHIVE" | awk '{print $1}')" ]] || { print -u2 "ERROR: source archive SHA-256 mismatch"; exit 1; }
[[ ! -e "$OUTPUT_DIR" ]] || { print -u2 "ERROR: output directory exists; inspect it before rebuilding: $OUTPUT_DIR"; exit 1; }
for tool in arch patch make bison x86_64-w64-mingw32-gcc i686-w64-mingw32-gcc; do
  command -v "$tool" >/dev/null 2>&1 || { print -u2 "ERROR: required build tool is missing: $tool"; exit 1; }
done
if [[ -z "$SOURCE_REVISION" ]]; then SOURCE_REVISION="archive-sha256:$SOURCE_SHA256"; fi
TMP_DIR="$(mktemp -d /tmp/uaro-wine-build.XXXXXX)"
trap 'if [[ -d "$TMP_DIR" ]]; then /bin/rm -rf -- "$TMP_DIR"; fi' EXIT INT TERM
tar -xzf "$SOURCE_ARCHIVE" -C "$TMP_DIR"
SOURCE_ROOT="$(find "$TMP_DIR" -type d -path "*/dlls/wow64win" -print -quit)"
[[ -n "$SOURCE_ROOT" ]] || { print -u2 "ERROR: CrossOver source tree with dlls/wow64win was not found"; exit 1; }
SOURCE_ROOT="$(cd "$SOURCE_ROOT/../.." && pwd)"
patch -p1 --dry-run -d "$SOURCE_ROOT" < "$ROOT/references/wow64win-rawinput-devicelist.patch" >/dev/null
patch -p1 -d "$SOURCE_ROOT" < "$ROOT/references/wow64win-rawinput-devicelist.patch" >/dev/null
cd "$SOURCE_ROOT"
BUILD_TRIPLET="$(arch -x86_64 tools/config.guess)"
arch -x86_64 ./configure --build="$BUILD_TRIPLET" --host="$BUILD_TRIPLET" --enable-win64
arch -x86_64 make -C dlls/wow64win
mkdir -p "$OUTPUT_DIR"
DLL_PATH="$(find "$SOURCE_ROOT/dlls/wow64win" -type f -name 'wow64win.dll' -print -quit)"
[[ -f "$DLL_PATH" ]] || { print -u2 "ERROR: wow64win.dll was not produced"; exit 1; }
arch -x86_64 i686-w64-mingw32-gcc -O2 -Wall "$ROOT/references/rawinput_overflow_probe.c" -o "$OUTPUT_DIR/rawinput_overflow_probe.exe"
cp -p "$DLL_PATH" "$OUTPUT_DIR/wow64win.dll"
cp -p "$ROOT/references/rawinput_overflow_probe.c" "$OUTPUT_DIR/rawinput_overflow_probe.c"
cp -p "$ROOT/references/wow64win-rawinput-devicelist.patch" "$OUTPUT_DIR/wow64win-rawinput-devicelist.patch"
python3 "$ROOT/scripts/artifact.py" import --source-dir "$OUTPUT_DIR" --cache-dir "$OUTPUT_DIR.cache" --crossover-build "$CROSSOVER_BUILD" --crossover-public-version "$CROSSOVER_VERSION" --artifact-kind reproducible_source --source-revision "$SOURCE_REVISION" --redistribution-license "$LICENSE_TEXT"
print "PASS: reproducible raw-input artifact created; review license/source records before use"

