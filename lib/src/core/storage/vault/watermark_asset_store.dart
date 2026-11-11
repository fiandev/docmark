import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../security/secure_file_vault.dart';
import '../db/app_database.dart';
import '../db/dao/asset_dao.dart';
import 'failures.dart';
import 'wrapped_key_reader.dart';

/// The watermark-image side of the vault.
///
/// An image that enters the editor has to be both encrypted and recorded,
/// otherwise a preset can hold an id it cannot resolve later. This facade
/// keeps those two steps inseparable and exposes the reference-counted
/// delete that every owner (document, preset, history) shares.
final class WatermarkAssetStore {
  WatermarkAssetStore({
    required SecureFileVault vault,
    required AssetDao assets,
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _vault = vault,
       _assets = assets,
       _uuid = uuid,
       _clock = clock ?? DateTime.now;

  final SecureFileVault _vault;
  final AssetDao _assets;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Owner tags used by [replaceLinks]; they match [AssetDao]'s values.
  static const String documentOwner = AssetDao.documentOwner;
  static const String historyOwner = AssetDao.historyOwner;

  Future<AssetRef> putImage({
    required Uint8List bytes,
    required String extension,
    required String mime,
  }) async {
    final reference = await _vault.put(bytes: bytes, extension: extension);
    final vault = _vault;
    final wrapped = vault is WrappedKeyReader
        ? await vault.wrappedKeyBase64(reference)
        : null;
    await _assets.upsert(
      WatermarkAssetRow(
        id: reference.id,
        blobPath: reference.relativePath,
        dekWrapped: wrapped ?? '',
        mime: mime,
        createdAt: _clock(),
      ),
    );

    return reference;
  }

  /// Resolves a stored id to its encrypted blob, or null when unknown.
  Future<AssetRef?> refFor(String assetId) async {
    final row = await _assets.find(assetId);
    if (row == null) return null;

    return AssetRef(id: row.id, relativePath: row.blobPath);
  }

  /// Deletes the blob and its metadata when no owner still points at it.
  Future<void> deleteIfUnreferenced(String assetId) async {
    final reference = await refFor(assetId);
    if (reference == null) {
      await _assets.remove(assetId);

      return;
    }
    await deleteRefIfUnreferenced(reference);
  }

  /// Deletes [reference] unless another owner still points at its id.
  ///
  /// History entries carry a full [AssetRef] because their blobs are not
  /// necessarily registered as watermark assets; taking the ref directly
  /// is what lets those bytes be erased.
  Future<void> deleteRefIfUnreferenced(AssetRef reference) async {
    if (await _assets.isReferenced(reference.id)) return;
    await _vault.delete(reference);
    await _assets.remove(reference.id);
  }

  Future<List<String>> linkedAssetIds({
    required String ownerType,
    required String ownerId,
  }) => _assets.linkedAssetIds(ownerType: ownerType, ownerId: ownerId);

  Future<void> replaceLinks({
    required String ownerType,
    required String ownerId,
    required Iterable<String> assetIds,
  }) => _assets.replaceLinks(
    ownerType: ownerType,
    ownerId: ownerId,
    assetIds: assetIds,
  );

  Future<void> removeLinks({
    required String ownerType,
    required String ownerId,
  }) => _assets.removeLinks(ownerType: ownerType, ownerId: ownerId);

  Future<void> removeLinksOfType(String ownerType) =>
      _assets.removeLinksOfType(ownerType);

  /// Copies an existing asset under a fresh id and returns the new ref.
  Future<AssetRef> copy(String assetId) async {
    final source = await refFor(assetId);
    if (source == null) throw MissingAssetFailure(assetId);
    final row = await _assets.find(assetId);
    final bytes = await _vault.read(source);
    final extension = _extensionOf(source.relativePath);
    final reference = await _vault.put(
      bytes: bytes,
      extension: extension,
      assetId: _uuid.v4(),
    );
    final vault = _vault;
    final wrapped = vault is WrappedKeyReader
        ? await vault.wrappedKeyBase64(reference)
        : null;
    await _assets.upsert(
      WatermarkAssetRow(
        id: reference.id,
        blobPath: reference.relativePath,
        dekWrapped: wrapped ?? '',
        mime: row?.mime ?? 'image/png',
        createdAt: _clock(),
      ),
    );

    return reference;
  }

  String _extensionOf(String relativePath) {
    final dot = relativePath.lastIndexOf('.');
    if (dot < 0 || dot == relativePath.length - 1) return 'bin';

    return relativePath.substring(dot + 1);
  }
}
