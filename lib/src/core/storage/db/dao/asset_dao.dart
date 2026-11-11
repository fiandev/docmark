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

  /// True while any preset or link-table owner points at [assetId]. This
  /// deliberately ignores [DocumentAssets] rows, so a document can ask
  /// whether its own source blob is also someone else's asset.
  Future<bool> hasOwnerLink(String assetId) async {
    if (await _hasPresetLink(assetId)) return true;

    return _hasAssetLink(assetId);
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

  /// Empties the owner-link table.
  ///
  /// A full wipe removes owners first and assets last, so this is the half
  /// that stops the registry rows from dangling.
  Future<void> deleteAllLinks() async {
    await _db.delete(_db.assetLinks).go();
  }

  /// Empties the watermark asset registry.
  Future<void> deleteAllAssets() async {
    await _db.delete(_db.watermarkAssets).go();
  }

  /// Empties both the owner links and the registry.
  Future<void> deleteAll() async {
    await deleteAllLinks();
    await deleteAllAssets();
  }
}
