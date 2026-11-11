import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/features/security_providers.dart';
import '../../../../core/di/features/storage_providers.dart';
import '../../../../core/storage/db/dao/document_dao.dart';
import '../../../../core/storage/db/dao/history_dao.dart';

part 'storage_overview.g.dart';

/// What Settings can report about local storage without decrypting bytes.
final class StorageUsage {
  const StorageUsage({
    required this.bytes,
    required this.documentCount,
    required this.historyCount,
  });

  static const StorageUsage empty = StorageUsage(
    bytes: 0,
    documentCount: 0,
    historyCount: 0,
  );

  /// Total size of the encrypted blobs on disk, not their plaintext size.
  final int bytes;

  final int documentCount;
  final int historyCount;
}

/// Reads the encrypted vault and the two row counts Settings displays.
///
/// The vault size is measured from the encrypted files themselves, so the
/// number matches what the device actually holds; rows are counted through
/// the DAOs rather than materializing documents.
@riverpod
Future<StorageUsage> storageUsage(Ref ref) async {
  final database = ref.watch(appDatabaseProvider);
  final vault = await vaultDirectory();

  return StorageUsage(
    bytes: await _vaultBytes(vault),
    documentCount: (await DocumentDao(database).all()).length,
    historyCount: (await HistoryDao(database).all()).length,
  );
}

Future<int> _vaultBytes(Directory vault) async {
  if (!await vault.exists()) return 0;

  var total = 0;
  await for (final entity in vault.list(recursive: true, followLinks: false)) {
    if (entity is File) total += await entity.length();
  }

  return total;
}
