/// OWNER: T1 (storage + temp cleanup).
///
/// Frozen DI contract for startup storage maintenance and the SQLCipher
/// database. `bootstrap()` awaits nothing here, so `cleanupAbandoned` must
/// never throw synchronously.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../logger/log.dart';
import '../../storage/app_data_wipe.dart';
import '../../storage/db/app_database.dart';
import '../../storage/db/dao/asset_dao.dart';
import '../../storage/scratch_paths.dart';
import '../../storage/temp_cleanup.dart';
import '../../storage/vault/watermark_asset_store.dart';
import 'security_providers.dart';

part 'storage_providers.g.dart';

/// Removes abandoned temporary plaintext files at startup.
abstract interface class TempFileCleanupService {
  /// Deletes temp files older than the grace window. Safe to call on every
  /// launch; a second call is a no-op.
  Future<void> cleanupAbandoned();
}

@Riverpod(keepAlive: true)
TempFileCleanupService tempFileCleanupService(Ref ref) =>
    TempFileCleanupServiceImpl(
      directories: [
        temporaryDirectory,
        shareDirectory,
        vaultStagingDirectory,
      ],
      onError: (error) =>
          Log.warning('Temp cleanup skipped: ${error.runtimeType}'),
    );

/// The encrypted application database.
///
/// Construction is synchronous; the SQLCipher key round-trip and the file
/// open happen on the first query. Repositories can therefore be built
/// from synchronous providers while the database still opens encrypted.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) => createAppDatabase(
  directory: databaseDirectory,
  keyManager: ref.watch(keyManagerProvider),
  encryption: ref.watch(encryptionServiceProvider),
);

/// Encrypted watermark images plus their reference-counted deletion.
///
/// The editor imports a watermark image through this store, not through
/// the bare vault, so the asset gets a database row and a preset can
/// resolve it later.
@Riverpod(keepAlive: true)
WatermarkAssetStore watermarkAssetStore(Ref ref) => WatermarkAssetStore(
  vault: ref.watch(secureFileVaultProvider),
  assets: AssetDao(ref.watch(appDatabaseProvider)),
);

/// Private root for the database file and its wrapped key.
Future<Directory> databaseDirectory() async {
  final support = await getApplicationSupportDirectory();

  return Directory(p.join(support.path, 'database'));
}

/// Scratch space for processing. Private, and swept at every launch.
Future<Directory> temporaryDirectory() async {
  final temp = await getTemporaryDirectory();

  return Directory(p.join(temp.path, tempDirectoryName));
}

/// Plaintext files staged for the platform share sheet. Swept at launch so
/// a crash between writing and sharing cannot leave a copy behind.
Future<Directory> shareDirectory() async {
  final temp = await getTemporaryDirectory();

  return Directory(p.join(temp.path, shareDirectoryName));
}

/// The "delete all app data" operation over the database, vault, and
/// scratch directories.
@Riverpod(keepAlive: true)
AppDataWipe appDataWipe(Ref ref) => AppDataWipeImpl(
  database: ref.watch(appDatabaseProvider),
  vault: ref.watch(secureFileVaultProvider),
  directories: [temporaryDirectory, shareDirectory],
);

/// The vault's staging directory, where atomic writes park a partial blob.
Future<Directory> vaultStagingDirectory() async {
  final vault = await vaultDirectory();

  return Directory(p.join(vault.path, '.staging'));
}
