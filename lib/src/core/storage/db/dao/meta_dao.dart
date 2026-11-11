import '../app_database.dart';

/// Small key/value corner of the database for storage bookkeeping.
final class MetaDao {
  MetaDao(this._db);

  final AppDatabase _db;

  Future<String?> read(String key) async {
    final rows = await (_db.select(_db.appMeta)
          ..where((table) => table.key.equals(key))
          ..limit(1))
        .get();

    return rows.isEmpty ? null : rows.first.value;
  }

  Future<void> write(String key, String value) async {
    await _db.into(_db.appMeta).insertOnConflictUpdate(
      AppMetaRow(key: key, value: value),
    );
  }
}
