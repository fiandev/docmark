import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import '../../security/encryption_service.dart';
import '../../security/key_manager.dart';
import 'database_key_store.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The app database, always opened through SQLCipher.
///
/// No foreign keys are declared on purpose: cascades run in explicit DAO
/// transactions, because the delete order also has to remove vault files
/// and SQLite cannot express that. The schema still models the relations
/// with primary keys and link tables.
@DriftDatabase(
  tables: [
    Documents,
    DocumentPages,
    DocumentAssets,
    WatermarkAssets,
    Presets,
    PresetAssets,
    HistoryEntries,
    AssetLinks,
    AppMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Builds an [AppDatabase] that opens lazily on first query.
///
/// Lazy open keeps the DI provider synchronous while still letting the key
/// round-trip (`flutter_secure_storage` plus the wrapped-key file) happen
/// off the build path. Every query therefore happens after the PRAGMA key
/// statement has run; the database file itself is unreadable without it.
AppDatabase createAppDatabase({
  required Future<Directory> Function() directory,
  required KeyManager keyManager,
  required EncryptionService encryption,
}) {
  return AppDatabase(
    LazyDatabase(() async {
      if (Platform.isAndroid) {
        await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
      }

      final folder = await directory();
      await folder.create(recursive: true);
      final keyStore = DatabaseKeyStore(
        encryption: encryption,
        keyManager: keyManager,
        keyFile: File(p.join(folder.path, 'docmark.key')),
      );
      final key = await keyStore.loadOrCreate();
      final databaseFile = File(p.join(folder.path, 'docmark.sqlite'));

      return NativeDatabase(
        databaseFile,
        setup: (raw) {
          // SQLCipher accepts a raw 32-byte key in the `x'..'` form, which
          // skips its passphrase KDF. The key is already full-entropy
          // random bytes, so stretching it would add cost without strength.
          raw.execute('PRAGMA key = "x\'${_hex(key.bytes)}\'"');
        },
      );
    }),
  );
}

String _hex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }

  return buffer.toString();
}
