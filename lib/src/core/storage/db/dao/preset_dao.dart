import 'package:drift/drift.dart';

import '../app_database.dart';

/// Preset rows plus their asset associations. A preset's asset ids are
/// stored separately so reference counting across presets stays a single
/// indexed lookup.
final class PresetDao {
  PresetDao(this._db);

  final AppDatabase _db;

  Future<List<PresetRow>> all() async {
    return (_db.select(_db.presets)
          ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]))
        .get();
  }

  Future<PresetRow?> find(String presetId) async {
    final rows = await (_db.select(_db.presets)
          ..where((table) => table.id.equals(presetId))
          ..limit(1))
        .get();

    return rows.isEmpty ? null : rows.first;
  }

  Future<List<String>> assetIdsFor(String presetId) async {
    final rows = await (_db.select(_db.presetAssets)
          ..where((table) => table.presetId.equals(presetId)))
        .get();

    return rows.map((row) => row.assetId).toList();
  }

  Future<Map<String, List<String>>> allAssetIds() async {
    final rows = await _db.select(_db.presetAssets).get();
    final grouped = <String, List<String>>{};
    for (final row in rows) {
      (grouped[row.presetId] ??= <String>[]).add(row.assetId);
    }

    return grouped;
  }

  Future<void> insert(PresetRow row) async {
    await _db.into(_db.presets).insert(row);
  }

  Future<void> update(PresetRow row) async {
    await (_db.update(_db.presets)
          ..where((table) => table.id.equals(row.id)))
        .write(row);
  }

  Future<void> replaceAssetIds(String presetId, List<String> assetIds) async {
    await _db.transaction(() async {
      await removeAssociations(presetId);
      for (final assetId in assetIds.toSet()) {
        if (assetId.isEmpty) continue;
        await _db.into(_db.presetAssets).insert(
          PresetAssetRow(presetId: presetId, assetId: assetId),
        );
      }
    });
  }

  Future<void> removeAssociations(String presetId) async {
    await (_db.delete(_db.presetAssets)
          ..where((table) => table.presetId.equals(presetId)))
        .go();
  }

  Future<void> delete(String presetId) async {
    await _db.transaction(() async {
      await removeAssociations(presetId);
      await (_db.delete(_db.presets)
            ..where((table) => table.id.equals(presetId)))
          .go();
    });
  }
}
