import 'dart:typed_data';

import 'package:docmark/src/core/security/secure_file_vault.dart';

/// In-memory [SecureFileVault] for tests and placeholder repositories.
///
/// It stores bytes verbatim — the point is the [AssetRef] lifecycle, not
/// encryption. Encryption itself is covered by T1's own tests.
class FakeSecureFileVault implements SecureFileVault {
  final Map<String, Uint8List> assets = {};

  var _nextId = 0;

  @override
  Future<AssetRef> put({
    required Uint8List bytes,
    required String extension,
    String? assetId,
  }) async {
    final id = assetId ?? 'asset-${_nextId++}';
    assets[id] = Uint8List.fromList(bytes);

    return AssetRef(id: id, relativePath: '$id.$extension');
  }

  @override
  Future<Uint8List> read(AssetRef ref) async {
    final bytes = assets[ref.id];
    if (bytes == null) {
      throw StateError('FakeSecureFileVault has no asset ${ref.id}');
    }

    return Uint8List.fromList(bytes);
  }

  @override
  Future<bool> exists(AssetRef ref) async => assets.containsKey(ref.id);

  @override
  Future<void> delete(AssetRef ref) async {
    assets.remove(ref.id);
  }

  @override
  Future<void> deleteAll() async {
    assets.clear();
  }
}
