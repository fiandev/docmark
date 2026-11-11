# Bundled fonts

Seven families, 24 files. `pubspec.yaml` declares every family and face; the
app resolves them through `FontRegistry.catalog`
(`lib/src/domain/services/font_registry.dart`); this directory holds the bytes,
their licences and the manifest that ties the two together.

## The committed `.ttf` files are placeholders

Each one contains a single line of text, not font data. They are committed on
purpose: pubspec, the registry and the tests all reference these exact paths, so
a checkout without network still builds, and the failing tests name the missing
licence work instead of a missing file.

A placeholder is not a valid font: Flutter's font loader rejects those bytes and
logs a font-loading error, so any screen that selects a bundled family renders
with the platform fallback at best.

## Fetch the real files

On a machine with network access:

```sh
sh tool/fetch_fonts.sh     # download, validate, pin SHA-256
sh tool/verify_fonts.sh    # gate: every path is a real, pinned font
```

`fetch_fonts.sh` accepts one family as an argument (`inter`, `roboto`,
`roboto_mono`, `montserrat`, `lora`, `merriweather`, `caveat`) and is safe to
re-run: files whose bytes already match the manifest pin are skipped, and a
file that does not match a recorded hash is never installed.

`verify_fonts.sh` exits non-zero and lists what is still wrong — missing file,
placeholder-sized file, wrong magic bytes, hash mismatch, unpinned hash, or a
manifest that drifted from `FontRegistry.catalog`. Do not ship while it fails.

Requirements: `curl` (or `wget`), `unzip` for the Inter and Roboto release
archives, and `sha256sum`, `shasum` or `openssl`.

## FONT_MANIFEST.json

One entry per family: the token, the Flutter family name, the licence and its
text, the upstream project and ref, and one entry per face with its asset path,
the upstream URL and a `sha256`.

`sha256` is `null` until the fetch runs, on purpose: a hash is a claim about
bytes, and inventing one would either block the correct download or bless the
wrong one. `fetch_fonts.sh` writes the value it measured. Once pinned, the hash
is a tripwire — an upstream re-release with different bytes fails loudly instead
of silently changing what the app renders.

## Licences

`LICENSES/` holds the full OFL-1.1 and Apache-2.0 texts, a per-family notice
with the upstream copyright line, and `ATTRIBUTION.md` with the family-to-licence
map. All OFL families ship unmodified upstream files; the Lora reserved name
therefore stays.

## Adding a family

1. Add the token to `FontToken` and a spec to `FontRegistry.catalog`.
2. Mirror it in `pubspec.yaml` under `flutter: fonts:` and `assets:`.
3. Add a `families[]` entry and one `files[]` entry per face to
   `FONT_MANIFEST.json`, with `sha256: null`.
4. Add the download rows to `tool/fetch_fonts.sh` and the licence notice here.
5. Run both scripts, then `flutter test test/fonts/`.
