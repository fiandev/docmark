import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_template/src/core/security/secure_file_vault.dart';
import 'package:flutter_template/src/core/storage/db/app_database.dart';
import 'package:flutter_template/src/core/storage/db/dao/asset_dao.dart';
import 'package:flutter_template/src/core/storage/vault/watermark_asset_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late _PathKeyedVault vault;
  late WatermarkAssetStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    vault = _PathKeyedVault();
    store = WatermarkAssetStore(vault: vault, assets: AssetDao(database));
  });

  tearDown(() async {
    await database.close();
  });

  test('an image id resolves to its blob path before the read', () async {
    final bytes = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
    final written = await store.putImage(
      bytes: bytes,
      extension: 'png',
      mime: 'image/png',
    );

    expect(written.relativePath, isNot(written.id));
    expect(vault.paths, contains(written.relativePath));

    final resolved = await store.refFor(written.id);
    expect(resolved, written);
    expect(await vault.exists(resolved!), isTrue);
    expect(await vault.read(resolved), bytes);

    // The id alone is not a blob path; files are named `<id>.<extension>`.
    final idOnly = AssetRef(id: written.id, relativePath: written.id);
    expect(await vault.exists(idOnly), isFalse);
  });

  test('an unknown image id resolves to null', () async {
    expect(await store.refFor('missing'), isNull);
  });
}

/// Mirrors the real vault's layout: a blob is addressed by its relative
/// path, so a reference carrying only the id cannot be read.
final class _PathKeyedVault implements SecureFileVault {
  final Map<String, Uint8List> _blobs = {};
  var _nextId = 0;

  Iterable<String> get paths => _blobs.keys;

  @override
  Future<AssetRef> put({
    required Uint8List bytes,
    required String extension,
    String? assetId,
  }) async {
    final id = assetId ?? 'asset-${_nextId++}';
    final relativePath = '$id.$extension';
    _blobs[relativePath] = Uint8List.fromList(bytes);

    return AssetRef(id: id, relativePath: relativePath);
  }

  @override
  Future<Uint8List> read(AssetRef ref) async {
    final bytes = _blobs[ref.relativePath];
    if (bytes == null) throw StateError('no blob at ${ref.relativePath}');

    return Uint8List.fromList(bytes);
  }

  @override
  Future<bool> exists(AssetRef ref) async {
    return _blobs.containsKey(ref.relativePath);
  }

  @override
  Future<void> delete(AssetRef ref) async {
    _blobs.remove(ref.relativePath);
  }

  @override
  Future<void> deleteAll() async {
    _blobs.clear();
  }
}
