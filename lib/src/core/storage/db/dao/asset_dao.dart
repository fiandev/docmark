import '../app_database.dart';

/// The vault asset registry: watermark images, their wrapped data keys,
/// and the ownership links that decide when an asset may be deleted.
final class AssetDao {
  AssetDao(this._db);

  /// Owners are stored as short strings so a row is readable in a dump
  /// without a join.
  static const String documentOwner = 'document';
  static const String historyOwner = 'history';

  final AppDatabase _db;

  Future<WatermarkAssetRow?> find(String assetId) async {
    final rows = await (_db.select(_db.watermarkAssets)
          ..where((table) => table.id.equals(assetId))
          ..limit(1))
        .get();

    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsert(WatermarkAssetRow row) async {
    await _db.into(_db.watermarkAssets).insertOnConflictUpdate(row);
  }

  Future<void> remove(String assetId) async {
    await (_db.delete(_db.watermarkAssets)
          ..where((table) => table.id.equals(assetId)))
        .go();
  }

  /// True while any preset, document, or history entry still points at
  /// [assetId]. Callers remove their own links before asking.
  Future<bool> isReferenced(String assetId) async {
    if (await _hasPresetLink(assetId)) return true;
    if (await _hasAssetLink(assetId)) return true;

    return _hasDocumentSource(assetId);
  }

  Future<List<String>> linkedAssetIds({
    required String ownerType,
    required String ownerId,
  }) async {
    final rows = await (_db.select(_db.assetLinks)
          ..where(
            (table) =>
                table.ownerType.equals(ownerType) &
                table.ownerId.equals(ownerId),
          ))
        .get();

    return rows.map((row) => row.assetId).toList();
  }

  Future<void> replaceLinks({
    required String ownerType,
    required String ownerId,
    required Iterable<String> assetIds,
  }) async {
    await removeLinks(ownerType: ownerType, ownerId: ownerId);
    for (final assetId in assetIds.toSet()) {
      if (assetId.isEmpty) continue;
      await _db.into(_db.assetLinks).insertOnConflictUpdate(
        AssetLinkRow(
          assetId: assetId,
          ownerType: ownerType,
          ownerId: ownerId,
        ),
      );
    }
  }

  Future<void> removeLinks({
    required String ownerType,
    required String ownerId,
  }) async {
    await (_db.delete(_db.assetLinks)
          ..where(
            (table) =>
                table.ownerType.equals(ownerType) &
                table.ownerId.equals(ownerId),
          ))
        .go();
  }

  Future<void> removeLinksOfType(String ownerType) async {
    await (_db.delete(_db.assetLinks)
          ..where((table) => table.ownerType.equals(ownerType)))
        .go();
  }

  Future<bool> _hasPresetLink(String assetId) async {
    final rows = await (_db.select(_db.presetAssets)
          ..where((table) => table.assetId.equals(assetId))
          ..limit(1))
        .get();

    return rows.isNotEmpty;
  }

  Future<bool> _hasAssetLink(String assetId) async {
    final rows = await (_db.select(_db.assetLinks)
          ..where((table) => table.assetId.equals(assetId))
          ..limit(1))
        .get();

    return rows.isNotEmpty;
  }

  Future<bool> _hasDocumentSource(String assetId) async {
    final rows = await (_db.select(_db.documentAssets)
          ..where((table) => table.assetId.equals(assetId))
          ..limit(1))
        .get();

    return rows.isNotEmpty;
  }
}
