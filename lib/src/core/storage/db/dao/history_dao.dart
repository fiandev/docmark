import 'package:drift/drift.dart';

import '../app_database.dart';

/// Processing history rows. The two `AssetRef` columns are serialized
/// JSON; callers map them through `docmark_mappers.dart`.
final class HistoryDao {
  HistoryDao(this._db);

  final AppDatabase _db;

  Future<List<HistoryEntryRow>> all() async {
    return (_db.select(_db.historyEntries)
          ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
        .get();
  }

  Future<HistoryEntryRow?> find(String entryId) async {
    final rows = await (_db.select(_db.historyEntries)
          ..where((table) => table.id.equals(entryId))
          ..limit(1))
        .get();

    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsert(HistoryEntryRow row) async {
    await _db.into(_db.historyEntries).insertOnConflictUpdate(row);
  }

  Future<void> delete(String entryId) async {
    await (_db.delete(_db.historyEntries)
          ..where((table) => table.id.equals(entryId)))
        .go();
  }

  Future<void> deleteAll() async {
    await _db.delete(_db.historyEntries).go();
  }
}
