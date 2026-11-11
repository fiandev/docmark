import 'dart:io';

import '../security/secure_file_vault.dart';
import 'db/app_database.dart';
import 'db/dao/asset_dao.dart';
import 'db/dao/document_dao.dart';
import 'db/dao/history_dao.dart';
import 'db/dao/preset_dao.dart';

/// The "delete all app data" operation.
///
/// An interface (rather than the implementation alone) so the destructive
/// settings action can be overridden in widget tests without a real
/// database or vault.
abstract interface class AppDataWipe {
  /// Removes every document, preset, history row, asset reference, vault
  /// blob, and scratch file. Throws when the database or vault step fails;
  /// scratch cleanup is best-effort.
  Future<void> wipeAll();
}

/// Empties the encrypted database, the vault, and the scratch directories.
///
/// Order matters and is not the same as a single-item delete: the rows go
/// first, inside one transaction, so a failure cannot leave a half-wiped
/// metadata set. Vault blobs follow — an orphan blob is garbage-collectable,
/// while a row whose blob is gone is a dangling reference the UI must
/// explain. Scratch directories come last and never fail the operation:
/// after the data is gone, a locked temp file is noise, not data loss.
final class AppDataWipeImpl implements AppDataWipe {
  AppDataWipeImpl({
    required AppDatabase database,
    required SecureFileVault vault,
    List<Future<Directory> Function()> directories = const [],
  }) : _database = database,
       _assets = AssetDao(database),
       _documents = DocumentDao(database),
       _presets = PresetDao(database),
       _history = HistoryDao(database),
       _vault = vault,
       _directories = directories;

  final AppDatabase _database;
  final AssetDao _assets;
  final DocumentDao _documents;
  final PresetDao _presets;
  final HistoryDao _history;
  final SecureFileVault _vault;
  final List<Future<Directory> Function()> _directories;

  @override
  Future<void> wipeAll() async {
    await _database.transaction(() async {
      await _assets.deleteAllLinks();
      await _documents.deleteAll();
      await _presets.deleteAll();
      await _assets.deleteAllAssets();
      await _history.deleteAll();
    });

    await _vault.deleteAll();

    for (final resolve in _directories) {
      try {
        final directory = await resolve();
        if (await directory.exists()) await directory.delete(recursive: true);
      } catch (_) {
        // Scratch space is disposable. A locked file must not turn a
        // completed wipe into a failure the user has to retry.
      }
    }
  }
}
