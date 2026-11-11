# Dependency Injection

DocMark uses **Riverpod 3** with `riverpod_annotation` code generation. There
is no service locator: providers are the only container, and feature code
receives its dependencies through `ref`.

## Layout

```
lib/src/core/di/
├── dependency_injection.dart   # library: imports, parts, shared providers
├── parts/
│   ├── externals.dart          # platform/service singletons
│   ├── repository.dart         # locale repository
│   ├── services.dart           # cache service
│   └── use_cases.dart          # locale use cases
└── features/
    ├── storage_providers.dart  # AppDatabase, vault, asset store, wipe, sweep
    ├── security_providers.dart # KeyManager, EncryptionService, SecureFileVault
    ├── app_lock_providers.dart # LockStateStore, biometrics, AppLockService
    ├── history_providers.dart  # history repository, list, previews
    ├── presets_providers.dart  # preset repository/list, pending preset
    ├── editor_providers.dart
    ├── import_providers.dart
    ├── render_providers.dart
    └── home_providers.dart
```

`*.g.dart` files are generated and git-ignored. Regenerate after changing any
annotated provider:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Rules

1. **Cross-feature access goes through `core/di/features/`.** A feature must
   not import another feature's files. Settings, for example, invalidates
   `historyListProvider` and `presetListProvider` but never imports the
   history or presets screens.
2. **`keepAlive` is for expensive, process-wide objects.** The database,
   vault, repositories, App Lock service, and key managers are keep-alive.
   Screen reads are auto-dispose.
3. **Providers construct synchronously where possible.** `AppDatabase` opens
   lazily on first query so the provider can be synchronous while the
   SQLCipher key round-trip happens off the build path.
4. **No provider performs I/O at construction beyond starting a fire-and-forget
   task** (`tempFileCleanupServiceProvider`, `appLockServiceProvider`). Startup
   must never block on disk.
5. **Provider retry is disabled** in `bootstrap()` (`retry: (_, __) => null`).
   The router gate shows a retryable failure instead of an infinite retry
   loop.

## Typical provider

```dart
@Riverpod(keepAlive: true)
HistoryRepository historyRepository(Ref ref) => HistoryRepositoryImpl(
  crashReporter: ref.watch(crashReporterProvider),
  database: ref.watch(appDatabaseProvider),
  images: ref.watch(watermarkAssetStoreProvider),
);
```

Use `ref.watch` when the dependency changing should rebuild the provider, and
`ref.read` inside callbacks for one-off access.

## State notifiers

List state is a `Notifier` so mutations and invalidation live in one place:

```dart
@Riverpod(keepAlive: true)
class PresetList extends _$PresetList {
  @override
  Future<List<PresetEntity>> build() async { /* repository.list() */ }

  Future<Result<Unit, BusinessFailure>> delete(String presetId) async {
    final result = await ref.read(presetRepositoryProvider).delete(presetId);
    if (result is Success<Unit, BusinessFailure>) ref.invalidateSelf();
    return result;
  }
}
```

## Testing

Override the seam the widget touches, not the whole container:

```dart
ProviderScope(
  overrides: [
    historyRepositoryProvider.overrideWith((ref) => FakeHistoryRepository()),
    secureFileVaultProvider.overrideWith((ref) => FakeSecureFileVault()),
    appDataWipeProvider.overrideWith((ref) => FakeAppDataWipe()),
  ],
  child: const SettingsPage(),
);
```

Repository tests do the opposite: they build the real implementations over
an in-memory database and a temp-rooted vault (see
`test/data/repositories/docmark/harness.dart`).

Useful defaults to override:

| Provider | Fake |
| --- | --- |
| `crashReporterProvider` | `FakeCrashReporter` |
| `lockStateStoreProvider` | `MemoryLockStateStore` |
| `biometricAuthenticatorProvider` | `FakeBiometricAuthenticator` |
| `secureFileVaultProvider` | `FakeSecureFileVault` |
| `appDataWipeProvider` | `FakeAppDataWipe` |
