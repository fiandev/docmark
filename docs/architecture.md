# DocMark Architecture

DocMark is a local-first Flutter app. It has one job: import a document,
apply a watermark, and export a new copy without sending the document
anywhere. The architecture exists to keep that promise auditable — the
encrypted vault and the database are behind interfaces, and the UI can only
reach them through the domain layer.

## Layers

```
lib/src/
├── core/           # bootstrap, DI, storage, security, logging
├── domain/         # entities, repository interfaces, services
├── data/           # repository implementations, mappers, device services
└── presentation/   # features, router, theme, shared widgets
```

Dependencies point inward: `presentation → domain ← data`, with `core`
providing wiring that both sides read.

### Core

- **`core/bootstrap.dart`**: builds the one `ProviderContainer`, installs the
  global error handlers, starts the App Lock lifecycle observer, and kicks
  off the abandoned-temp-file sweep.
- **`core/di/`**: Riverpod providers. `parts/` holds the small shared
  providers (locale, cache, crash reporter); `features/` holds the per-feature
  contracts (`storage_providers.dart`, `security_providers.dart`,
  `history_providers.dart`, and so on). Features cross boundaries only
  through these files.
- **`core/storage/`**: the SQLCipher `AppDatabase` and its DAOs, the
  envelope-encrypted `SecureFileVault`, the watermark asset store, temp-file
  cleanup, and the `AppDataWipe` operation behind "delete all data".
- **`core/security/`**: AES-256-GCM envelope encryption, the KEK manager,
  secure key-value storage, and App Lock (`lock/`).
- **`core/logger/`**: a `kDebugMode`-gated log facade and a payload-free
  Riverpod observer.

### Domain

Pure Dart, no Flutter imports.

- `entities/`: `DocumentEntity`, `PresetEntity`, `HistoryEntryEntity`,
  `WatermarkElement`, geometry, and image formats.
- `repositories/`: `DocumentRepository`, `PresetRepository`,
  `HistoryRepository`, `LocaleRepository`. These are the frozen seams the
  presentation layer depends on.
- `services/`: `MediaNormalizerService`, `FormatProbe`, `RenderContract`, the
  font registry, and watermark geometry.
- `failures/`: the sealed `BusinessFailure` vocabulary the UI localizes.

### Data

- `repositories/*_impl.dart`: implement the domain interfaces over the
  database and the vault. `core/base/repository.dart` is the only place a
  `try`/`catch` becomes a typed `Result`; recoverable exceptions map to
  `BusinessFailure`, and Dart `Error`s are reported as bugs.
- `mappers/docmark_mappers.dart`: row ↔ entity conversion and JSON codecs.
- `services/render/`: PDF composition, rasterization, and watermark drawing.
- `services/media/`: format probing, image normalization, and platform pickers.

Delete order is a rule in this layer: database rows are committed first,
then blobs are erased. An orphan blob is recoverable garbage; a row whose
blob is gone is unrecoverable metadata.

### Presentation

- `presentation/core/`: router and gate, theme tokens and extensions, shared
  widgets, failure mapping, and the application-state providers.
- `presentation/features/`: one directory per feature —
  `home`, `document_import`, `watermark_editor`, `presets`, `history`,
  `export`, `app_lock`, `settings`, `splash`, `onboarding`.

A feature owns its controllers and widgets. It may import `presentation/core`
and `core/di`; it must not import another feature's files.

## State and DI

Riverpod 3 with code generation. Providers are `keepAlive` where an object is
expensive (database, vault, repositories) and auto-dispose for screen-scoped
reads. Generated files (`*.g.dart`, `*.mapper.dart`) are not committed; run
`dart run build_runner build --delete-conflicting-outputs`.

See [dependency_injection.md](dependency_injection.md) for the provider map.

## Storage model

- `Documents`, `DocumentPages`, `DocumentAssets`: metadata, page geometry,
  and the pointer to the encrypted source blob.
- `Presets`, `PresetAssets`: saved watermark configurations and their
  reference-counted image assets.
- `WatermarkAssets`: the vault registry for watermark images.
- `HistoryEntries`: exported runs with serialized asset references.
- `AssetLinks`: which owner (document or history entry) points at which
  asset, used for reference-counted deletion.
- `AppMeta`: internal bookkeeping.

The database has no foreign keys; cascades are explicit DAO transactions, and
their commit is the point of no return: vault files are erased only after the
rows that reference them are gone. SQLCipher provides at-rest encryption and
the vault uses per-asset envelope encryption, so compromising one key does not
expose the rest.

## Security

The threat model, envelope format, App Lock behaviour, and known limitations
are documented in [security.md](security.md).

## Routing

`routerStateProvider` folds startup, onboarding, and App Lock status into a
single destination, and `RedirectGate.redirect` is the whole policy. Pages
never navigate on a lock or onboarding change; they invalidate a status
provider and the gate follows. See [router.md](router.md).

## Testing

`test/` mirrors `lib/src`. Repository tests use an in-memory Drift database
and a real encrypted vault rooted in a temp directory. Widget tests override
the DI seams they touch (repositories, vault, wipe, App Lock service) rather
than reaching into platform channels. `test/support/` holds the shared fakes.
