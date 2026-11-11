import 'dart:io';
import 'dart:typed_data';

import 'package:docmark/src/core/security/encryption_service.dart';
import 'package:docmark/src/core/security/key_manager.dart';
import 'package:docmark/src/core/security/src/aes_gcm_encryption_service.dart';
import 'package:docmark/src/core/storage/app_data_wipe.dart';
import 'package:docmark/src/core/storage/db/app_database.dart';
import 'package:docmark/src/core/storage/db/dao/asset_dao.dart';
import 'package:docmark/src/core/storage/vault/secure_file_vault_impl.dart';
import 'package:docmark/src/core/storage/vault/watermark_asset_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late SecureFileVaultImpl vault;
  late WatermarkAssetStore images;
  late Directory scratch;
  late Directory share;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('docmark_wipe_test');
    scratch = Directory('${root.path}/scratch')..createSync();
    share = Directory('${root.path}/share')..createSync();
    File('${scratch.path}/part.tmp').writeAsStringSync('scratch');
    File('${share.path}/export.png').writeAsStringSync('plaintext');

    database = AppDatabase(NativeDatabase.memory());
    vault = SecureFileVaultImpl(
      encryption: AesGcmEncryptionService(),
      keyManager: _StaticKeyManager(),
      rootDirectory: () async => Directory('${root.path}/vault'),
    );
    images = WatermarkAssetStore(
      vault: vault,
      assets: AssetDao(database),
    );
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('wipeAll empties every table, every blob, and the scratch dirs',
      () async {
    final now = DateTime.utc(2026, 3, 1);
    final logo = await images.putImage(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      extension: 'png',
      mime: 'image/png',
    );
    // A second blob with no metadata row at all.
    await vault.put(
      bytes: Uint8List.fromList([9, 9, 9]),
      extension: 'png',
    );

    await database.into(database.documents).insert(
      DocumentRow(
        id: 'doc-1',
        name: 'contract.pdf',
        kind: 'pdf',
        pageCount: 1,
        configJson: '{"elements":[]}',
        createdAt: now,
      ),
    );
    await database.into(database.documentPages).insert(
      DocumentPageRow(
        docId: 'doc-1',
        pageIndex: 0,
        widthPt: 595,
        heightPt: 842,
      ),
    );
    await database.into(database.documentAssets).insert(
      DocumentAssetRow(
        docId: 'doc-1',
        assetId: 'source-1',
        blobPath: 'source-1.pdf',
        mime: 'application/pdf',
        createdAt: now,
      ),
    );
    await database.into(database.presets).insert(
      PresetRow(
        id: 'preset-1',
        name: 'Brand',
        elementsJson: '[]',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.into(database.presetAssets).insert(
      PresetAssetRow(presetId: 'preset-1', assetId: logo.id),
    );
    await database.into(database.assetLinks).insert(
      AssetLinkRow(
        assetId: logo.id,
        ownerType: 'document',
        ownerId: 'doc-1',
      ),
    );
    await database.into(database.historyEntries).insert(
      HistoryEntryRow(
        id: 'history-1',
        documentName: 'contract.pdf',
        status: 'completed',
        createdAt: now,
      ),
    );

    final wipe = AppDataWipeImpl(
      database: database,
      vault: vault,
      directories: [() async => scratch, () async => share],
    );
    await wipe.wipeAll();

    expect(await database.select(database.documents).get(), isEmpty);
    expect(await database.select(database.documentPages).get(), isEmpty);
    expect(await database.select(database.documentAssets).get(), isEmpty);
    expect(await database.select(database.presets).get(), isEmpty);
    expect(await database.select(database.presetAssets).get(), isEmpty);
    expect(await database.select(database.watermarkAssets).get(), isEmpty);
    expect(await database.select(database.assetLinks).get(), isEmpty);
    expect(await database.select(database.historyEntries).get(), isEmpty);

    expect(await _filesUnder(Directory('${root.path}/vault')), isEmpty);
    expect(await scratch.exists(), isFalse);
    expect(await share.exists(), isFalse);
  });
}

Future<List<File>> _filesUnder(Directory directory) async {
  if (!await directory.exists()) return const [];
  final files = <File>[];
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File) files.add(entity);
  }

  return files;
}

final class _StaticKeyManager implements KeyManager {
  final AesKey _key = AesKey(
    Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
  );

  @override
  Future<AesKey> createOrGetKek() async => _key;
}
