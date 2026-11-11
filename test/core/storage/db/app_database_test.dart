import 'package:drift/native.dart';
import 'package:flutter_template/src/core/storage/db/app_database.dart';
import 'package:flutter_template/src/core/storage/db/dao/asset_dao.dart';
import 'package:flutter_template/src/core/storage/db/dao/document_dao.dart';
import 'package:flutter_template/src/core/storage/db/dao/history_dao.dart';
import 'package:flutter_template/src/core/storage/db/dao/meta_dao.dart';
import 'package:flutter_template/src/core/storage/db/dao/preset_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('DocumentDao', () {
    test('inserts, reads, and orders pages', () async {
      final dao = DocumentDao(database);
      final createdAt = DateTime.utc(2026, 1, 1);
      await dao.insert(
        DocumentRow(
          id: 'doc-1',
          name: 'invoice.pdf',
          kind: 'pdf',
          pageCount: 2,
          configJson: null,
          createdAt: createdAt,
        ),
      );
      await dao.insertPages(const [
        DocumentPageRow(
          docId: 'doc-1',
          pageIndex: 1,
          widthPt: 612.0,
          heightPt: 792.0,
        ),
        DocumentPageRow(
          docId: 'doc-1',
          pageIndex: 0,
          widthPt: 595.0,
          heightPt: 842.0,
        ),
      ]);

      final row = await dao.find('doc-1');
      final pages = await dao.pagesFor('doc-1');

      expect(row, isNotNull);
      expect(row!.kind, 'pdf');
      expect(pages.map((page) => page.pageIndex), [0, 1]);
    });

    test('updates the stored watermark configuration', () async {
      final dao = DocumentDao(database);
      await dao.insert(
        DocumentRow(
          id: 'doc-1',
          name: 'photo.png',
          kind: 'image',
          pageCount: 1,
          configJson: null,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await dao.updateConfig('doc-1', '{"elements":[]}');

      expect((await dao.find('doc-1'))!.configJson, '{"elements":[]}');
    });

    test('deleting a document removes its pages and source row', () async {
      final dao = DocumentDao(database);
      await dao.insert(
        DocumentRow(
          id: 'doc-1',
          name: 'photo.png',
          kind: 'image',
          pageCount: 1,
          configJson: null,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await dao.insertSourceAsset(
        DocumentAssetRow(
          docId: 'doc-1',
          assetId: 'asset-1',
          blobPath: 'asset-1.png',
          mime: 'image/png',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await dao.deletePages('doc-1');
      await dao.deleteSourceAssets('doc-1');
      await dao.delete('doc-1');

      expect(await dao.find('doc-1'), isNull);
      expect(await dao.pagesFor('doc-1'), isEmpty);
      expect(await dao.findSourceAsset('doc-1'), isNull);
    });
  });

  group('PresetDao', () {
    test('stores a preset and its asset ids', () async {
      final dao = PresetDao(database);
      final now = DateTime.utc(2026, 2, 1);
      await dao.insert(
        PresetRow(
          id: 'preset-1',
          name: 'corner mark',
          elementsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.replaceAssetIds('preset-1', ['asset-1', 'asset-2']);

      expect(await dao.assetIdsFor('preset-1'), ['asset-1', 'asset-2']);
      expect((await dao.find('preset-1'))!.name, 'corner mark');
    });

    test('replace keeps only the new associations', () async {
      final dao = PresetDao(database);
      final now = DateTime.utc(2026, 2, 1);
      await dao.insert(
        PresetRow(
          id: 'preset-1',
          name: 'mark',
          elementsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.replaceAssetIds('preset-1', ['asset-1', 'asset-2']);

      await dao.replaceAssetIds('preset-1', ['asset-2']);

      expect(await dao.assetIdsFor('preset-1'), ['asset-2']);
    });

    test('delete removes the row and its associations', () async {
      final dao = PresetDao(database);
      final now = DateTime.utc(2026, 2, 1);
      await dao.insert(
        PresetRow(
          id: 'preset-1',
          name: 'mark',
          elementsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dao.replaceAssetIds('preset-1', ['asset-1']);

      await dao.delete('preset-1');

      expect(await dao.find('preset-1'), isNull);
      expect(await dao.assetIdsFor('preset-1'), isEmpty);
    });
  });

  group('HistoryDao', () {
    test('lists newest first and upserts by id', () async {
      final dao = HistoryDao(database);
      await dao.upsert(_entryRow('old', DateTime.utc(2026, 3, 1)));
      await dao.upsert(_entryRow('new', DateTime.utc(2026, 3, 2)));

      final rows = await dao.all();

      expect(rows.map((row) => row.id), ['new', 'old']);

      await dao.upsert(
        HistoryEntryRow(
          id: 'new',
          documentName: 'done.pdf',
          documentId: null,
          originalRef: null,
          processedRef: null,
          configRef: null,
          status: 'completed',
          createdAt: DateTime.utc(2026, 3, 2),
        ),
      );

      expect((await dao.find('new'))!.status, 'completed');
      expect(await dao.all(), hasLength(2));
    });

    test('deleteAll empties the table', () async {
      final dao = HistoryDao(database);
      await dao.upsert(_entryRow('one', DateTime.utc(2026, 3, 1)));
      await dao.upsert(_entryRow('two', DateTime.utc(2026, 3, 2)));

      await dao.deleteAll();

      expect(await dao.all(), isEmpty);
    });
  });

  group('AssetDao reference counting', () {
    test('a registration alone is not a reference', () async {
      final dao = AssetDao(database);
      await dao.upsert(
        WatermarkAssetRow(
          id: 'asset-1',
          blobPath: 'asset-1.png',
          dekWrapped: 'wrapped',
          mime: 'image/png',
          createdAt: DateTime.utc(2026, 4, 1),
        ),
      );

      expect(await dao.isReferenced('asset-1'), isFalse);
    });

    test('links, document sources, and presets all count', () async {
      final dao = AssetDao(database);
      await dao.replaceLinks(
        ownerType: AssetDao.documentOwner,
        ownerId: 'doc-1',
        assetIds: ['asset-1'],
      );
      expect(await dao.isReferenced('asset-1'), isTrue);

      await dao.removeLinks(
        ownerType: AssetDao.documentOwner,
        ownerId: 'doc-1',
      );
      expect(await dao.isReferenced('asset-1'), isFalse);

      await dao.replaceLinks(
        ownerType: AssetDao.historyOwner,
        ownerId: 'entry-1',
        assetIds: ['asset-1'],
      );
      expect(await dao.isReferenced('asset-1'), isTrue);
      expect(
        await dao.linkedAssetIds(
          ownerType: AssetDao.historyOwner,
          ownerId: 'entry-1',
        ),
        ['asset-1'],
      );
    });

    test('a preset association counts as a reference', () async {
      final dao = AssetDao(database);
      final presets = PresetDao(database);
      final now = DateTime.utc(2026, 4, 1);
      await presets.insert(
        PresetRow(
          id: 'preset-1',
          name: 'mark',
          elementsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await presets.replaceAssetIds('preset-1', ['asset-9']);

      expect(await dao.isReferenced('asset-9'), isTrue);

      await presets.removeAssociations('preset-1');

      expect(await dao.isReferenced('asset-9'), isFalse);
    });
  });

  group('MetaDao', () {
    test('stores and overwrites a value', () async {
      final dao = MetaDao(database);

      expect(await dao.read('schema'), isNull);
      await dao.write('schema', '1');
      await dao.write('schema', '2');

      expect(await dao.read('schema'), '2');
    });
  });
}

HistoryEntryRow _entryRow(String id, DateTime createdAt) {
  return HistoryEntryRow(
    id: id,
    documentName: '$id.pdf',
    documentId: null,
    originalRef: null,
    processedRef: null,
    configRef: null,
    status: 'pending',
    createdAt: createdAt,
  );
}
