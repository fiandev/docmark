#!/bin/sh
#
# tool/fetch_fonts.sh — replace the font placeholders with the real binaries.
#
# WHY THIS EXISTS
#   The repository commits a one-line placeholder at every .ttf path that
#   pubspec.yaml and FontRegistry.catalog declare, so the app builds and the
#   tests resolve without a network. Those placeholders are not fonts. This
#   script downloads the exact upstream file for each declared path, refuses
#   anything that is not a TrueType/OpenType binary, and pins the SHA-256 in
#   assets/fonts/FONT_MANIFEST.json.
#
# USAGE
#   sh tool/fetch_fonts.sh            # every family that is not current
#   sh tool/fetch_fonts.sh inter      # one family (usage shown below)
#   sh tool/fetch_fonts.sh roboto_mono
#
# REQUIREMENTS
#   curl (or wget), unzip (only for release-archive sources), and one of
#   `sha256sum`, `shasum -a 256`, or `openssl dgst -sha256`.
#
# RE-RUNNING IS SAFE
#   * A destination whose bytes already match the recorded SHA-256 is skipped.
#   * A download is staged in a temp directory and installed only after its
#     magic bytes and size look like a font.
#   * If the manifest records a SHA-256 and the download differs, this script
#     fails and installs nothing: upstream silently re-released the font, or
#     the download was corrupted. Investigate, then update the manifest
#     deliberately.
#   * When the manifest records null, the freshly computed hash is written
#     back into the manifest, which is how a null column becomes a pin.
#
# SOURCES
#   Upstream projects and licence per family are in assets/fonts/LICENSES/
#   ATTRIBUTION.md and in the manifest itself. The table below is the only
#   place download URLs live; the `upstreamUrl` field in the manifest
#   documents the same source for humans. If an upstream moves a file, add
#   the new URL as an extra candidate line instead of deleting the old one,
#   so the failure stays visible in the diff.
#
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

MANIFEST='assets/fonts/FONT_MANIFEST.json'
WORK_DIR="${TMPDIR:-/tmp}/docmark-fonts.$$"
MIN_BYTES=1024

log() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die() {
  warn "error: $*"
  exit 1
}

[ -f "$MANIFEST" ] || die "$MANIFEST is missing; run this from a checkout"
mkdir -p "$WORK_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM
mkdir -p "$WORK_DIR/cache" "$WORK_DIR/unpack"

# ---------------------------------------------------------------- primitives

if command -v sha256sum >/dev/null 2>&1; then
  sha256_of() { sha256sum "$1" | awk '{ print $1 }'; }
elif command -v shasum >/dev/null 2>&1; then
  sha256_of() { shasum -a 256 "$1" | awk '{ print $1 }'; }
elif command -v openssl >/dev/null 2>&1; then
  sha256_of() { openssl dgst -sha256 "$1" | awk '{ print $NF }'; }
else
  die 'need sha256sum, shasum, or openssl to hash downloads'
fi

if command -v curl >/dev/null 2>&1; then
  download() { # url out
    log "  GET $1"
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 \
      --silent --show-error -o "$2.part" "$1" && mv "$2.part" "$2"
  }
elif command -v wget >/dev/null 2>&1; then
  download() { # url out
    log "  GET $1"
    wget -q -O "$2.part" "$1" && mv "$2.part" "$2"
  }
else
  die 'need curl or wget to download fonts'
fi

# Prints the raw 4-byte magic of a file as hex, no spaces: 00010000 (TrueType),
# 4f54544f (OTTO / CFF OpenType), or 74727565 (Apple 'true').
magic_of() {
  dd if="$1" bs=4 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n'
}

size_of() {
  wc -c <"$1" | tr -d ' '
}

is_font_binary() { # path
  [ -f "$1" ] || return 1
  [ "$(size_of "$1")" -ge "$MIN_BYTES" ] || return 1
  case $(magic_of "$1") in
    00010000 | 4f54544f | 74727565) return 0 ;;
    *) return 1 ;;
  esac
}

# Prints the recorded sha256 for one manifest path, or the word "null".
#
# The path is matched with index(), not as a regex, and the needle carries no
# JSON quotes of its own: an asset path appears verbatim only on its own
# "path" line, and the extra "path" test keeps us off any other key.
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

# Writes a freshly computed hash into the manifest, in place. The manifest is
# pretty-printed with one "path" and one "sha256" per line, so a two-line
# window is enough; no jq dependency and no JSON re-serialisation that would
# reformat the file.
record_sha() { # path sha256
  tmp="$WORK_DIR/manifest.json"
  awk -v p="$1" -v hash="$2" '
    index($0, "\"path\"") && index($0, p) { in_block = 1 }
    in_block && /"sha256":/ {
      sub(/"sha256":[[:space:]]*(null|"[0-9a-fA-F]*")/,
          "\"sha256\": \"" hash "\"")
      in_block = 0
    }
    { print }
  ' "$MANIFEST" >"$tmp"
  grep -q "\"sha256\": \"$2\"" "$tmp" ||
    die "could not record sha256 for $1 in $MANIFEST"
  mv "$tmp" "$MANIFEST"
}

# A destination is current when it is a font-shaped file whose bytes match the
# hash the manifest already pins. Null hashes are never "current": the point of
# a first fetch is to create the pin.
is_current() { # path
  is_font_binary "$1" || return 1
  expected=$(manifest_sha_for "$1")
  case $expected in
    '' | null) return 1 ;;
  esac
  [ "$(sha256_of "$1")" = "$expected" ]
}

# Validates a staged download, then installs it at the declared path.
install_face() { # staged-file dest
  staged=$1
  dest=$2
  is_font_binary "$staged" ||
    die "download for $dest is not a TrueType/OpenType font \
($(size_of "$staged") bytes, magic '$(magic_of "$staged")')"
  actual=$(sha256_of "$staged")
  expected=$(manifest_sha_for "$dest")
  case $expected in
    '' | null)
      record_sha "$dest" "$actual"
      log "  pinned $dest sha256=$actual"
      ;;
    *)
      [ "$actual" = "$expected" ] ||
        die "sha256 mismatch for $dest: manifest=$expected downloaded=$actual \
-- the upstream file changed; check it by hand, then update \
assets/fonts/FONT_MANIFEST.json"
      ;;
  esac
  mkdir -p "$(dirname "$dest")"
  cp "$staged" "$dest"
  log "  wrote $dest ($(size_of "$dest") bytes)"
}

# Pulls one named member out of a release archive. The archive is downloaded
# and unpacked once per URL; `find` locates the member so the script does not
# depend on how deep the upstream zip nests its static/ or hinted/ folder.
extract_member() { # url member-name dest
  url=$1
  member_name=$2
  dest=$3
  archive="$WORK_DIR/cache/$(basename "$url")"
  if [ ! -s "$archive" ]; then
    download "$url" "$archive" || return 1
  fi
  command -v unzip >/dev/null 2>&1 ||
    die "unzip is required to read $url"
  unpack="$WORK_DIR/unpack/$(basename "$url")"
  if [ ! -d "$unpack" ]; then
    mkdir -p "$unpack"
    unzip -q -o "$archive" -d "$unpack" >/dev/null || return 1
  fi
  member=$(find "$unpack" -type f -name "$member_name" | head -n 1)
  [ -n "$member" ] || {
    warn "  ! $member_name is not inside $(basename "$url")"
    return 1
  }
  install_face "$member" "$dest"
}

# One "<source>|<destination>" line: source is raw:<url> for a direct file or
# zip:<url> for a release archive that contains the face.
fetch_spec() { # source|dest
  spec=$1
  source=${spec%%|*}
  dest=${spec#*|}
  kind=${source%%:*}
  url=${source#*:}
  if is_current "$dest"; then
    log "= $dest (already pinned and matching)"
    return 0
  fi
  case $kind in
    raw)
      staged="$WORK_DIR/$(basename "$dest")"
      download "$url" "$staged" || return 1
      install_face "$staged" "$dest"
      ;;
    zip) extract_member "$url" "${dest##*/}" "$dest" ;;
    *) die "unknown source kind '$kind' in $spec" ;;
  esac
}

selected() { # dest
  if [ -z "$ONLY" ]; then
    return 0
  fi
  case $dest in
    "assets/fonts/$ONLY/"*) return 0 ;;
    *) return 1 ;;
  esac
}

# -------------------------------------------------------------------- sources
#
# Inter and Roboto publish static faces inside release archives (their repos
# only carry variable fonts), so their rows are zip: sources. The other
# families publish static TTFs directly. Two candidates per family where a
# mirror exists: the first that resolves wins, and the pinned hash keeps the
# winner honest.
#
read_sources() {
  cat <<'EOF'
zip:https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip|assets/fonts/inter/Inter-Regular.ttf
zip:https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip|assets/fonts/inter/Inter-Bold.ttf
zip:https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip|assets/fonts/inter/Inter-Italic.ttf
zip:https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip|assets/fonts/inter/Inter-BoldItalic.ttf
zip:https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip|assets/fonts/inter/Inter-Regular.ttf
zip:https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip|assets/fonts/inter/Inter-Bold.ttf
zip:https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip|assets/fonts/inter/Inter-Italic.ttf
zip:https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip|assets/fonts/inter/Inter-BoldItalic.ttf

zip:https://github.com/googlefonts/roboto/releases/download/v2.138/roboto-unhinted.zip|assets/fonts/roboto/Roboto-Regular.ttf
zip:https://github.com/googlefonts/roboto/releases/download/v2.138/roboto-unhinted.zip|assets/fonts/roboto/Roboto-Bold.ttf
zip:https://github.com/googlefonts/roboto/releases/download/v2.138/roboto-unhinted.zip|assets/fonts/roboto/Roboto-Italic.ttf
zip:https://github.com/googlefonts/roboto/releases/download/v2.138/roboto-unhinted.zip|assets/fonts/roboto/Roboto-BoldItalic.ttf
zip:https://github.com/googlefonts/roboto/releases/download/v2.138/roboto-hinted.zip|assets/fonts/roboto/Roboto-Regular.ttf
zip:https://github.com/googlefonts/roboto/releases/download/v2.138/roboto-hinted.zip|assets/fonts/roboto/Roboto-Bold.ttf
zip:https://github.com/googlefonts/roboto/releases/download/v2.138/roboto-hinted.zip|assets/fonts/roboto/Roboto-Italic.ttf
zip:https://github.com/googlefonts/roboto/releases/download/v2.138/roboto-hinted.zip|assets/fonts/roboto/Roboto-BoldItalic.ttf

raw:https://raw.githubusercontent.com/googlefonts/RobotoMono/main/fonts/ttf/RobotoMono-Regular.ttf|assets/fonts/roboto_mono/RobotoMono-Regular.ttf
raw:https://raw.githubusercontent.com/googlefonts/RobotoMono/main/fonts/ttf/RobotoMono-Bold.ttf|assets/fonts/roboto_mono/RobotoMono-Bold.ttf
raw:https://raw.githubusercontent.com/googlefonts/RobotoMono/main/fonts/ttf/RobotoMono-Italic.ttf|assets/fonts/roboto_mono/RobotoMono-Italic.ttf
raw:https://raw.githubusercontent.com/googlefonts/RobotoMono/main/fonts/ttf/RobotoMono-BoldItalic.ttf|assets/fonts/roboto_mono/RobotoMono-BoldItalic.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/robotomono/static/RobotoMono-Regular.ttf|assets/fonts/roboto_mono/RobotoMono-Regular.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/robotomono/static/RobotoMono-Bold.ttf|assets/fonts/roboto_mono/RobotoMono-Bold.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/robotomono/static/RobotoMono-Italic.ttf|assets/fonts/roboto_mono/RobotoMono-Italic.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/robotomono/static/RobotoMono-BoldItalic.ttf|assets/fonts/roboto_mono/RobotoMono-BoldItalic.ttf

raw:https://raw.githubusercontent.com/JulietaUlanovsky/Montserrat/master/fonts/ttf/Montserrat-Regular.ttf|assets/fonts/montserrat/Montserrat-Regular.ttf
raw:https://raw.githubusercontent.com/JulietaUlanovsky/Montserrat/master/fonts/ttf/Montserrat-Bold.ttf|assets/fonts/montserrat/Montserrat-Bold.ttf
raw:https://raw.githubusercontent.com/JulietaUlanovsky/Montserrat/master/fonts/ttf/Montserrat-Italic.ttf|assets/fonts/montserrat/Montserrat-Italic.ttf
raw:https://raw.githubusercontent.com/JulietaUlanovsky/Montserrat/master/fonts/ttf/Montserrat-BoldItalic.ttf|assets/fonts/montserrat/Montserrat-BoldItalic.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/static/Montserrat-Regular.ttf|assets/fonts/montserrat/Montserrat-Regular.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/static/Montserrat-Bold.ttf|assets/fonts/montserrat/Montserrat-Bold.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/static/Montserrat-Italic.ttf|assets/fonts/montserrat/Montserrat-Italic.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/static/Montserrat-BoldItalic.ttf|assets/fonts/montserrat/Montserrat-BoldItalic.ttf

raw:https://raw.githubusercontent.com/cyrealtype/Lora-Cyrillic/master/fonts/ttf/Lora-Regular.ttf|assets/fonts/lora/Lora-Regular.ttf
raw:https://raw.githubusercontent.com/cyrealtype/Lora-Cyrillic/master/fonts/ttf/Lora-Bold.ttf|assets/fonts/lora/Lora-Bold.ttf
raw:https://raw.githubusercontent.com/cyrealtype/Lora-Cyrillic/master/fonts/ttf/Lora-Italic.ttf|assets/fonts/lora/Lora-Italic.ttf
raw:https://raw.githubusercontent.com/cyrealtype/Lora-Cyrillic/master/fonts/ttf/Lora-BoldItalic.ttf|assets/fonts/lora/Lora-BoldItalic.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/lora/static/Lora-Regular.ttf|assets/fonts/lora/Lora-Regular.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/lora/static/Lora-Bold.ttf|assets/fonts/lora/Lora-Bold.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/lora/static/Lora-Italic.ttf|assets/fonts/lora/Lora-Italic.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/lora/static/Lora-BoldItalic.ttf|assets/fonts/lora/Lora-BoldItalic.ttf

raw:https://raw.githubusercontent.com/SorkinType/Merriweather/master/fonts/ttf/Merriweather-Regular.ttf|assets/fonts/merriweather/Merriweather-Regular.ttf
raw:https://raw.githubusercontent.com/SorkinType/Merriweather/master/fonts/ttf/Merriweather-Bold.ttf|assets/fonts/merriweather/Merriweather-Bold.ttf
raw:https://raw.githubusercontent.com/SorkinType/Merriweather/master/fonts/ttf/Merriweather-Italic.ttf|assets/fonts/merriweather/Merriweather-Italic.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/merriweather/static/Merriweather-Regular.ttf|assets/fonts/merriweather/Merriweather-Regular.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/merriweather/static/Merriweather-Bold.ttf|assets/fonts/merriweather/Merriweather-Bold.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/merriweather/static/Merriweather-Italic.ttf|assets/fonts/merriweather/Merriweather-Italic.ttf

raw:https://raw.githubusercontent.com/googlefonts/caveat/master/fonts/ttf/Caveat-Regular.ttf|assets/fonts/caveat/Caveat-Regular.ttf
raw:https://raw.githubusercontent.com/google/fonts/main/ofl/caveat/static/Caveat-Regular.ttf|assets/fonts/caveat/Caveat-Regular.ttf
EOF
}

# ----------------------------------------------------------------------- main

case ${1:-} in
  '') ONLY='' ;;
  -h | --help)
    cat <<'USAGE'
tool/fetch_fonts.sh — download the real font binaries into assets/fonts/.

Usage:
  sh tool/fetch_fonts.sh                 # every family that is not current
  sh tool/fetch_fonts.sh <family>        # inter, roboto, roboto_mono,
                                         # montserrat, lora, merriweather,
                                         # caveat
  sh tool/fetch_fonts.sh --help

Rewrites the sha256 fields in assets/fonts/FONT_MANIFEST.json.
Read assets/fonts/README.md before running it.
USAGE
    exit 0
    ;;
  robotoMono | roboto-mono | robotomono | ROBOTO_MONO) ONLY=roboto_mono ;;
  *) ONLY=$1 ;;
esac

attempted="$WORK_DIR/dests"
: >"$attempted"

read_sources >"$WORK_DIR/sources"
while IFS= read -r spec; do
  [ -n "$spec" ] || continue
  dest=${spec#*|}
  selected "$dest" || continue
  printf '%s\n' "$dest" >>"$attempted"
  fetch_spec "$spec" || warn "  ! could not fetch $dest from ${spec%%|*}"
done <"$WORK_DIR/sources"

[ -s "$attempted" ] ||
  die "nothing matched family '${ONLY:-}' ; known: inter roboto \
roboto_mono montserrat lora merriweather caveat"

sort -u "$attempted" >"$WORK_DIR/dests.sorted"

# The point of the run: after it, every attempted path is a pinned, real font.
failed=0
count=0
while IFS= read -r dest; do
  if is_current "$dest"; then
    count=$((count + 1))
    log "ok $dest"
  else
    warn "FAIL $dest is still not a pinned font"
    failed=1
  fi
done <"$WORK_DIR/dests.sorted"

if [ "$failed" -ne 0 ]; then
  warn ''
  warn 'Some fonts could not be fetched. Either this machine has no network,'
  warn 'or an upstream URL above moved. Fix the URL table in this script and'
  warn 're-run; nothing was installed for the failed paths.'
  exit 1
fi

log ''
log "all $count font file(s) pinned and matching; $MANIFEST is up to date."
log 'Next: sh tool/verify_fonts.sh'
