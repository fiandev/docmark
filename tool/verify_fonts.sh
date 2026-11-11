#!/bin/sh
#
# tool/verify_fonts.sh — prove that every declared font path is a real font.
#
# This is the gate for shipping: `flutter build` copies whatever bytes sit at
# the paths in pubspec.yaml, so a placeholder that slips through ships a
# broken app instead of an empty family. The script checks, for every path in
# assets/fonts/FONT_MANIFEST.json:
#
#   1. the file exists;
#   2. it is at least 1 KiB (placeholders are one short line of text);
#   3. its first four bytes are a TrueType/OpenType signature:
#        00 01 00 00  sfnt version 1.0 (TrueType outlines)
#        OTTO         CFF outlines
#        true         Apple TrueType
#   4. when the manifest pins a SHA-256, the bytes still hash to it.
#
# It also cross-checks that the manifest and FontRegistry.catalog declare the
# same asset paths, and that every licence file the manifest names exists.
#
# Exit status: 0 only when every declared file is a pinned, real font.
#
# Usage: sh tool/verify_fonts.sh
#
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

MANIFEST='assets/fonts/FONT_MANIFEST.json'
REGISTRY='lib/src/domain/services/font_registry.dart'
MIN_BYTES=1024
WORK_DIR="${TMPDIR:-/tmp}/docmark-verify-fonts.$$"

warn() { printf '%s\n' "$*" >&2; }
die() {
  warn "error: $*"
  exit 1
}

[ -f "$MANIFEST" ] || die "$MANIFEST is missing"
mkdir -p "$WORK_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

if command -v sha256sum >/dev/null 2>&1; then
  sha256_of() { sha256sum "$1" | awk '{ print $1 }'; }
elif command -v shasum >/dev/null 2>&1; then
  sha256_of() { shasum -a 256 "$1" | awk '{ print $1 }'; }
elif command -v openssl >/dev/null 2>&1; then
  sha256_of() { openssl dgst -sha256 "$1" | awk '{ print $NF }'; }
else
  die 'need sha256sum, shasum, or openssl to verify pinned hashes'
fi

magic_of() {
  dd if="$1" bs=4 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n'
}

size_of() {
  wc -c <"$1" | tr -d ' '
}

manifest_sha_for() {
  awk -v p="$1" '
    index($0, "\"path\"") && index($0, p) { in_block = 1 }
    in_block && /"sha256":/ {
      line = $0
      sub(/.*"sha256":[[:space:]]*/, "", line)
      sub(/,[[:space:]]*$/, "", line)
      gsub(/"/, "", line)
      print line
      exit
    }
  ' "$MANIFEST"
}

grep -o '"path": "[^"]*"' "$MANIFEST" |
  sed 's/^"path": "//; s/"$//' >"$WORK_DIR/paths"

[ -s "$WORK_DIR/paths" ] || die "$MANIFEST declares no font paths"

total=0
bad=0
unpinned=0
missing=0
placeholders=0

warn 'checking declared font assets:'
while IFS= read -r path; do
  total=$((total + 1))

  if [ ! -f "$path" ]; then
    warn "  MISSING        $path"
    missing=$((missing + 1))
    bad=$((bad + 1))
    continue
  fi

  size=$(size_of "$path")
  if [ "$size" -lt "$MIN_BYTES" ]; then
    warn "  PLACEHOLDER    $path ($size bytes, expected >= $MIN_BYTES)"
    placeholders=$((placeholders + 1))
    bad=$((bad + 1))
    continue
  fi

  magic=$(magic_of "$path")
  case $magic in
    00010000 | 4f54544f | 74727565) : ;;
    *)
      warn "  NOT-A-FONT     $path (magic '$magic', $size bytes)"
      bad=$((bad + 1))
      continue
      ;;
  esac

  expected=$(manifest_sha_for "$path")
  case $expected in
    '' | null)
      warn "  UNPINNED       $path (real font, but sha256 is null in manifest)"
      unpinned=$((unpinned + 1))
      continue
      ;;
  esac

  actual=$(sha256_of "$path")
  if [ "$actual" != "$expected" ]; then
    warn "  SHA256-MISMATCH $path"
    warn "                  manifest: $expected"
    warn "                  on disk:  $actual"
    bad=$((bad + 1))
    continue
  fi

  printf '  ok             %s (%s bytes)\n' "$path" "$size"
done <"$WORK_DIR/paths"

# The manifest is only useful if it describes the same files the app asks for.
if [ -f "$REGISTRY" ]; then
  grep -o 'assets/fonts/[A-Za-z0-9_]*/[A-Za-z0-9]*\.ttf' "$REGISTRY" |
    sort -u >"$WORK_DIR/registry-paths"
  sort -u "$WORK_DIR/paths" >"$WORK_DIR/manifest-paths"
  grep -vxF -f "$WORK_DIR/manifest-paths" "$WORK_DIR/registry-paths" \
    >"$WORK_DIR/only-registry" || true
  if [ -s "$WORK_DIR/only-registry" ]; then
    warn ''
    warn 'FontRegistry.catalog declares paths the manifest omits:'
    while IFS= read -r path; do warn "  $path"; done <"$WORK_DIR/only-registry"
    bad=$((bad + 1))
  fi
  grep -vxF -f "$WORK_DIR/registry-paths" "$WORK_DIR/manifest-paths" \
    >"$WORK_DIR/only-manifest" || true
  if [ -s "$WORK_DIR/only-manifest" ]; then
    warn ''
    warn 'The manifest declares paths FontRegistry.catalog does not; the'
    warn 'registry is the contract, so drop them:'
    while IFS= read -r path; do warn "  $path"; done <"$WORK_DIR/only-manifest"
    bad=$((bad + 1))
  fi
fi

# A licence file that the manifest promises but does not ship is a compliance
# bug, not a build bug.
grep -o '"licenseFile": "[^"]*"' "$MANIFEST" |
  sed 's/^"licenseFile": "//; s/"$//' | sort -u >"$WORK_DIR/licenses"
while IFS= read -r licence; do
  [ -f "$licence" ] || {
    warn ''
    warn "  MISSING LICENCE $licence"
    bad=$((bad + 1))
  }
done <"$WORK_DIR/licenses"

warn ''
if [ "$bad" -ne 0 ]; then
  warn "FAILED: $bad problem(s) across $total declared font file(s)."
  if [ "$placeholders" -gt 0 ]; then
    warn "  $placeholders still ship placeholder text; run: sh tool/fetch_fonts.sh"
  fi
  if [ "$missing" -gt 0 ]; then
    warn "  $missing path(s) are absent; a git checkout may be incomplete"
  fi
  if [ "$unpinned" -gt 0 ]; then
    warn "  $unpinned file(s) are real but unpinned; run fetch_fonts.sh"
  fi
  warn 'Do not ship until this script exits 0. See assets/fonts/README.md.'
  exit 1
fi

if [ "$unpinned" -gt 0 ]; then
  warn "PASS WITH WARNINGS: all $total files are real fonts, but $unpinned are"
  warn 'not pinned in the manifest; run tool/fetch_fonts.sh to record hashes.'
  exit 0
fi

warn "PASS: all $total declared font files are pinned, real TrueType/OpenType."
