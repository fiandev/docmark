# DocMark

Local-first document watermarking for Android and iOS. Import an image or a
PDF, place text or image watermarks over it, and export a flattened copy
without the document ever leaving the device.

## What it does

- **Documents**: import images and multi-page PDFs, pick pages, and keep the
  source encrypted on disk.
- **Watermarks**: text and image layers with position, rotation, opacity,
  colour, and per-page placement.
- **Presets**: save, rename, duplicate, and re-apply watermark setups.
- **Processing history**: every export is recorded with an encrypted preview,
  and the history can be cleared independently of documents.
- **App Lock**: optional six-digit PIN plus biometrics, with persisted
  failed-attempt backoff.
- **Export**: PNG, JPEG, or PDF. Results can be shared or saved to the device.

## Privacy model

DocMark stores everything in private application storage:

- Document bytes and watermark images live in an envelope-encrypted vault:
  AES-256-GCM with a per-asset data key, and a KEK held by
  `flutter_secure_storage`.
- Metadata (names, page sizes, presets, history) lives in a SQLCipher
  database, keyed by a random 256-bit key.
- Nothing is uploaded. There is no network layer, account, or analytics call.
- Exports and share copies are necessarily plaintext. A share copy is deleted
  as soon as the share sheet returns, and the startup sweep removes leftovers
  from a crash.

Details and caveats (backups, screenshots, volume encryption) are in
[docs/security.md](docs/security.md).

## Requirements

- Flutter with Dart `^3.13.0`
- Android SDK 23+ (SQLCipher and `local_auth` both need it)
- Xcode with an iOS deployment target of 15.0+
- The local linter plugin in `packages/flutter_guardian`, wired through
  `analysis_options.yaml`

## Run it

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

`build_runner` generates the Riverpod providers, Drift database, mappers, and
the localization bindings; a fresh checkout does not build until it has run.

The seven bundled font families use real font binaries. They are not
committed as upstream downloads, so run the fetch script before shipping:

```bash
sh tool/fetch_fonts.sh
```

### Continuous code generation

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Release builds

Commit `pubspec.lock`. It cannot be generated in this environment, and a
shipped app should resolve the exact dependency set that was tested.

Android release signing reads `android/key.properties`:

```properties
storeFile=/absolute/path/to/release.jks
storePassword=…
keyAlias=…
keyPassword=…
```

The file is git-ignored. When it is absent, debug builds still use the debug
key, but a release build fails with an explanatory error instead of silently
shipping a debug-signed artifact. Release signing material is **not** included
in this repository.

iOS builds use the `com.dinurymomshad.docmark` bundle identifier. Provide your
own signing team and certificates in Xcode before archiving.

## Project layout

```
lib/
├── main.dart
└── src/
    ├── core/          # DI, storage, security, logging, theme primitives
    ├── domain/        # entities, repositories, services (no Flutter imports)
    ├── data/          # repository implementations, mappers, device services
    └── presentation/  # features, router, theme, shared widgets
test/                  # mirrors lib/src, plus fakes under test/support
docs/                  # architecture, DI, routing, security
tool/                  # asset preparation scripts
```

Feature slices are `home`, `document_import`, `watermark_editor`, `presets`,
`history`, `export`, `app_lock`, and `settings`. Cross-feature state is shared
only through `lib/src/core/di/features/*`, never by importing another feature.

## Documentation

- [Architecture](docs/architecture.md)
- [Dependency injection](docs/dependency_injection.md)
- [Routing and the gate model](docs/router.md)
- [Security](docs/security.md)

## Tests

```bash
flutter test                    # unit, repository, and widget tests
flutter test --coverage         # writes coverage/lcov.info
flutter analyze
```

Repository tests run against an in-memory Drift database and a real encrypted
vault under a temporary directory, so delete ordering and encryption are
exercised rather than mocked.

## License

MIT. See [LICENSE](LICENSE).
