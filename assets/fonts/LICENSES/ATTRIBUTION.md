# Font attribution and licence map

Every family DocMark bundles, where it came from, and which licence governs it.
The machine-readable version of this table is `../FONT_MANIFEST.json`; the
paths and faces there are frozen by `FontRegistry.catalog` in
`lib/src/domain/services/font_registry.dart`.

## Families

| Token          | Flutter family | Faces                              | Directory                 | Upstream project                              | Ref     | Licence    | Notice                                   |
| -------------- | -------------- | ---------------------------------- | ------------------------- | --------------------------------------------- | ------- | ---------- | ---------------------------------------- |
| `inter`        | Inter          | Regular, Bold, Italic, BoldItalic  | `assets/fonts/inter/`     | <https://github.com/rsms/inter>               | `v4.1`  | OFL-1.1    | `Inter-OFL-1.1.txt`                      |
| `roboto`       | Roboto         | Regular, Bold, Italic, BoldItalic  | `assets/fonts/roboto/`    | <https://github.com/googlefonts/roboto>       | `v2.138`| Apache-2.0 | `Roboto-Apache-2.0.txt`                  |
| `robotoMono`   | Roboto Mono    | Regular, Bold, Italic, BoldItalic  | `assets/fonts/roboto_mono/` | <https://github.com/googlefonts/RobotoMono> | `main`  | OFL-1.1    | `RobotoMono-OFL-1.1.txt`                 |
| `montserrat`   | Montserrat     | Regular, Bold, Italic, BoldItalic  | `assets/fonts/montserrat/` | <https://github.com/JulietaUlanovsky/Montserrat> | `master` | OFL-1.1 | `Montserrat-OFL-1.1.txt`                 |
| `lora`         | Lora           | Regular, Bold, Italic, BoldItalic  | `assets/fonts/lora/`      | <https://github.com/cyrealtype/Lora-Cyrillic> | `master` | OFL-1.1    | `Lora-OFL-1.1.txt` (Reserved Font Name)  |
| `merriweather` | Merriweather   | Regular, Bold, Italic              | `assets/fonts/merriweather/` | <https://github.com/SorkinType/Merriweather> | `master` | OFL-1.1 | `Merriweather-OFL-1.1.txt`               |
| `caveat`       | Caveat         | Regular                            | `assets/fonts/caveat/`    | <https://github.com/googlefonts/caveat>       | `master` | OFL-1.1    | `Caveat-OFL-1.1.txt`                     |

`FontToken.system` is the platform default: no family, no asset, no licence.

## Licence texts

| File             | Applies to                                               |
| ---------------- | -------------------------------------------------------- |
| `OFL-1.1.txt`    | Inter, Roboto Mono, Montserrat, Lora, Merriweather, Caveat |
| `Apache-2.0.txt`  | Roboto                                                   |

The per-family notices repeat the upstream copyright line because OFL-1.1
condition 2 requires the copyright notice and the licence to travel with the
fonts, and Apache-2.0 section 4(a) requires a copy of the licence.

## Destination mapping

The contract is one path per `(family, face)` and it lives in two places that
must agree:

- `lib/src/domain/services/font_registry.dart` — `FontRegistry.catalog`, the
  single source of truth the app reads;
- `FONT_MANIFEST.json` — the same paths plus licence, upstream URL and pin.

`test/fonts/font_asset_manifest_test.dart` fails if the two disagree;
`tool/verify_fonts.sh` fails if the manifest drifts from the registry or a
declared path is not a real font. `pubspec.yaml` carries the same paths under
`flutter: fonts:`.

## Provenance and honesty about the hashes

The repository deliberately ships **placeholder** `.ttf` files and a manifest
whose `sha256` fields are `null`. A hash is a claim about bytes we do not yet
have, so nothing here invents one. `tool/fetch_fonts.sh` downloads each file,
validates its signature, and writes the real SHA-256 into the manifest; from
then on a re-run verifies instead of trusting.

Two things to check the first time the fetch runs on a networked machine,
because they could not be verified here:

1. **URLs.** The download table lives in `tool/fetch_fonts.sh`. Upstream repos
   reorganise; each family has a second candidate, and the script fails loudly
   with the URLs it tried rather than installing something wrong.
2. **Copyright lines.** The lines above are the upstream project attributions
   as published. Diff each project's `LICENSE`/`METADATA.pb` against its notice
   after fetching and correct any drift.

SIL OFL 1.1 condition 3 applies to Lora's Reserved Font Name. DocMark ships the
unmodified upstream files, which is why the name may stay; a subsetted or
otherwise modified build must not keep it.
