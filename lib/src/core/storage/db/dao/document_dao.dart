import 'package:drift/drift.dart';

import '../app_database.dart';

/// Reads and writes document metadata, page sizes, and the source asset
/// reference. Asset bytes are the vault's business; this DAO only keeps
/// the pointer.
final class DocumentDao {
  DocumentDao(this._db);

  final AppDatabase _db;

  Future<DocumentRow?> find(String documentId) async {
    final rows = await (_db.select(_db.documents)
          ..where((table) => table.id.equals(documentId))
          ..limit(1))
        .get();

    return rows.isEmpty ? null : rows.first;
  }

  Future<List<DocumentRow>> all() async {
    return (_db.select(_db.documents)
          ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
        .get();
  }

  Future<List<DocumentPageRow>> pagesFor(String documentId) async {
    return (_db.select(_db.documentPages)
          ..where((table) => table.docId.equals(documentId))
          ..orderBy([(table) => OrderingTerm.asc(table.pageIndex)]))
        .get();
  }

  Future<List<DocumentPageRow>> allPages() async {
    return (_db.select(_db.documentPages)
          ..orderBy([(table) => OrderingTerm.asc(table.pageIndex)]))
        .get();
  }

  Future<DocumentPageRow?> findPage(String documentId, int pageIndex) async {
    final rows = await (_db.select(_db.documentPages)
          ..where(
            (table) =>
                table.docId.equals(documentId) &
                table.pageIndex.equals(pageIndex),
          )
          ..limit(1))
        .get();

    return rows.isEmpty ? null : rows.first;
  }

  Future<DocumentAssetRow?> findSourceAsset(String documentId) async {
    final rows = await (_db.select(_db.documentAssets)
          ..where((table) => table.docId.equals(documentId))
          ..limit(1))
        .get();

    return rows.isEmpty ? null : rows.first;
  }

  Future<void> insert(DocumentRow row) async {
    await _db.into(_db.documents).insert(row);
  }

  Future<void> insertPages(List<DocumentPageRow> rows) async {
    for (final row in rows) {
      await _db.into(_db.documentPages).insert(row);
    }
  }

  Future<void> insertSourceAsset(DocumentAssetRow row) async {
    await _db.into(_db.documentAssets).insert(row);
  }

  Future<void> updateConfig(String documentId, String? configJson) async {
    final row = await find(documentId);
    if (row == null) return;
    final updated = DocumentRow(
      id: row.id,
      name: row.name,
      kind: row.kind,
      pageCount: row.pageCount,
      configJson: configJson,
      createdAt: row.createdAt,
    );
    await (_db.update(_db.documents)
          ..where((table) => table.id.equals(documentId)))
        .write(updated);
  }

  Future<void> deletePages(String documentId) async {
    await (_db.delete(_db.documentPages)
          ..where((table) => table.docId.equals(documentId)))
        .go();
  }

  Future<void> deleteSourceAssets(String documentId) async {
    await (_db.delete(_db.documentAssets)
          ..where((table) => table.docId.equals(documentId)))
        .go();
  }

  Future<void> delete(String documentId) async {
    await (_db.delete(_db.documents)
          ..where((table) => table.id.equals(documentId)))
        .go();
  }

  /// Empties the source references, pages, and document metadata.
  Future<void> deleteAll() async {
    await _db.delete(_db.documentAssets).go();
    await _db.delete(_db.documentPages).go();
    await _db.delete(_db.documents).go();
  }
}
