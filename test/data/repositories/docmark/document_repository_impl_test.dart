import 'dart:typed_data';

import 'package:docmark/src/core/base/result.dart';
import 'package:docmark/src/core/base/unit.dart';
import 'package:docmark/src/core/security/secure_file_vault.dart';
import 'package:docmark/src/core/storage/db/app_database.dart';
import 'package:docmark/src/core/storage/db/dao/preset_dao.dart';
import 'package:docmark/src/data/repositories/document_repository_impl.dart';
import 'package:docmark/src/domain/entities/document.dart';
import 'package:docmark/src/domain/entities/normalized_rect.dart';
import 'package:docmark/src/domain/entities/watermark_element.dart';
import 'package:docmark/src/domain/failures/business_failure.dart';
import 'package:docmark/src/domain/repositories/document_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  late DocmarkHarness harness;

  setUp(() async {
    harness = await DocmarkHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  group('DocumentRepositoryImpl.importDocument', () {
    test('stores an image encrypted and reads it back', () async {
      final repository = harness.documents();
      final bytes = pngBytes('quarterly-photo');

      final entity = dataOf(
        await repository.importDocument(
          ImportRequest(
            source: ImportSource.gallery,
            fileName: 'photo.png',
            bytes: bytes,
          ),
        ),
      );

      expect(entity.kind, DocumentKind.image);
      expect(entity.pageCount, 1);
      expect(entity.name, 'photo.png');
      expect(entity.pageSizes.single.widthPt, 800);
      expect(entity.pageSizes.single.heightPt, 600);

      final files = await harness.files();
      expect(files, hasLength(1));
      final stored = await files.single.readAsBytes();
      expect(
        String.fromCharCodes(stored).contains('quarterly-photo'),
        isFalse,
      );

      expect(dataOf(await repository.readPage(entity.id, 0)), bytes);
    });

    test('records every page of a PDF', () async {
      final repository = harness.documents();

      final entity = dataOf(
        await repository.importDocument(
          ImportRequest(
            source: ImportSource.filePicker,
            fileName: 'report.pdf',
            bytes: pdfBytes(),
          ),
        ),
      );

      expect(entity.kind, DocumentKind.pdf);
      expect(entity.pageCount, 3);
      expect(entity.pageSizes.map((page) => page.index), [0, 1, 2]);
      expect(entity.pageSourceIndices, [0, 1, 2]);
      expect(entity.selectedPageCount, 3);
      expect(entity.pageSizes.first.widthPt, 612);
    });

    test('records each mixed-size PDF page with its own dimensions', () async {
      final repository = harness.documents();

      final entity = dataOf(
        await repository.importDocument(
          ImportRequest(
            source: ImportSource.filePicker,
            fileName: 'mixed.pdf',
            bytes: pdfBytes('mixed'),
          ),
        ),
      );

      expect(entity.pageSizes.map((page) => page.widthPt), [612, 400, 300]);
      expect(entity.pageSizes.map((page) => page.heightPt), [792, 600, 500]);

      // The same per-page sizes survive a round trip through storage.
      final fetched = dataOf(await repository.get(entity.id))!;
      expect(fetched.pageSizes, entity.pageSizes);

      final listed = dataOf(await repository.list()).single;
      expect(listed.pageSizes, entity.pageSizes);
    });

    test('honours the selected PDF pages', () async {
      final repository = harness.documents();

      final entity = dataOf(
        await repository.importDocument(
          ImportRequest(
            source: ImportSource.filePicker,
            fileName: 'report.pdf',
            bytes: pdfBytes(),
            selectedPages: const [1, 2],
          ),
        ),
      );

      // pageCount stays the source total; only pageSizes is the subset.
      expect(entity.pageCount, 3);
      expect(entity.pageSizes.map((page) => page.index), [1, 2]);
      expect(entity.pageSourceIndices, [1, 2]);
      expect(entity.selectedPageCount, 2);
      // A subset keeps the selected pages' own sizes too.
      expect(entity.pageSizes.map((page) => page.widthPt), [400, 300]);

      expect(dataOf(await repository.readPage(entity.id, 1)), isNotEmpty);
      expect(
        await repository.readPage(entity.id, 0),
        isA<Error<Uint8List, BusinessFailure>>(),
      );
    });

    test('refuses an unsupported format before writing', () async {
      final repository = harness.documents();
      final webp = pngBytes('riff');
      webp[0] = 0x52;
      webp[1] = 0x49;
      webp[2] = 0x46;
      webp[3] = 0x46;

      final result = await repository.importDocument(
        ImportRequest(
          source: ImportSource.gallery,
          fileName: 'animation.webp',
          bytes: webp,
        ),
      );

      expect(result, isA<Error<DocumentEntity, BusinessFailure>>());
      expect(await harness.files(), isEmpty);
    });

    test('refuses empty bytes', () async {
      final repository = harness.documents();

      final result = await repository.importDocument(
        ImportRequest(
          source: ImportSource.gallery,
          fileName: 'empty.png',
          bytes: Uint8List(0),
        ),
      );

      expect(result, isA<Error<DocumentEntity, BusinessFailure>>());
    });
  });

  group('DocumentRepositoryImpl', () {
    test('lists and gets saved documents', () async {
      final repository = harness.documents();
      final imported = dataOf(
        await repository.importDocument(
          ImportRequest(
            source: ImportSource.gallery,
            fileName: 'one.png',
            bytes: pngBytes('one'),
          ),
        ),
      );

      final listed = dataOf(await repository.list());
      final fetched = dataOf(await repository.get(imported.id));

      expect(listed.map((entity) => entity.id), [imported.id]);
      expect(fetched, isNotNull);
      expect(fetched!.pageSizes, hasLength(1));
    });

    test('returns notFound for an unknown page', () async {
      final repository = harness.documents();
      final imported = dataOf(
        await repository.importDocument(
          ImportRequest(
            source: ImportSource.gallery,
            fileName: 'one.png',
            bytes: pngBytes('one'),
          ),
        ),
      );

      final result = await repository.readPage(imported.id, 4);

      expect(result, isA<Error<Uint8List, BusinessFailure>>());
    });

    test('persists a watermark configuration', () async {
      final repository = harness.documents();
      final imported = dataOf(
        await repository.importDocument(
          ImportRequest(
            source: ImportSource.gallery,
            fileName: 'one.png',
            bytes: pngBytes('one'),
          ),
        ),
      );
      final config = WatermarkConfig(
        elements: [_imageElement('asset-7')],
      );

      final saved = await repository.saveWatermarkConfig(
        imported.id,
        config,
      );
      final fetched = dataOf(await repository.get(imported.id))!;

      expect(saved, const Success<Unit, BusinessFailure>(Unit.value));
      expect(fetched.watermarkConfigJson, isNotNull);
      expect(
        WatermarkConfig.fromJsonString(fetched.watermarkConfigJson!),
        config,
      );

      final links = await harness.images.linkedAssetIds(
        ownerType: 'document',
        ownerId: imported.id,
      );
      expect(links, ['asset-7']);
    });

    test('delete removes the blob, rows, and linked assets', () async {
      final repository = harness.documents();
      final imported = dataOf(
        await repository.importDocument(
          ImportRequest(
            source: ImportSource.gallery,
            fileName: 'one.png',
            bytes: pngBytes('one'),
          ),
        ),
      );
      final logo = await harness.images.putImage(
        bytes: pngBytes('logo'),
        extension: 'png',
        mime: 'image/png',
      );
      await repository.saveWatermarkConfig(
        imported.id,
        WatermarkConfig(elements: [_imageElement(logo.id)]),
      );

      final deleted = await repository.delete(imported.id);

      expect(deleted, const Success<Unit, BusinessFailure>(Unit.value));
      expect(await harness.files(), isEmpty);
      expect(await harness.images.refFor(logo.id), isNull);
      expect(
        await harness.database.select(harness.database.documents).get(),
        isEmpty,
      );
      expect(
        await harness.database.select(harness.database.documentPages).get(),
        isEmpty,
      );
    });

    test('delete commits rows before the blob delete can fail', () async {
      final imported = dataOf(
        await harness.documents().importDocument(
          ImportRequest(
            source: ImportSource.gallery,
            fileName: 'one.png',
            bytes: pngBytes('one'),
          ),
        ),
      );
      final repository = DocumentRepositoryImpl(
        crashReporter: harness.crashReporter,
        database: harness.database,
        vault: _VaultWithFailingDelete(harness.vault),
        normalizer: harness.normalizer,
        images: harness.images,
      );

      final result = await repository.delete(imported.id);

      // The opaque exception surfaces as a failure...
      expect(result, isA<Error<Unit, BusinessFailure>>());
      // ...but the rows are already committed: no dangling metadata.
      expect(
        await harness.database.select(harness.database.documents).get(),
        isEmpty,
      );
      expect(
        await harness.database.select(harness.database.documentPages).get(),
        isEmpty,
      );
      // The blob survived a failed delete, which is the recoverable state.
      expect(await harness.files(), hasLength(1));
    });

    test('delete keeps an asset a preset still references', () async {
      final repository = harness.documents();
      final imported = dataOf(
        await repository.importDocument(
          ImportRequest(
            source: ImportSource.gallery,
            fileName: 'one.png',
            bytes: pngBytes('one'),
          ),
        ),
      );
      final logo = await harness.images.putImage(
        bytes: pngBytes('logo'),
        extension: 'png',
        mime: 'image/png',
      );
      await repository.saveWatermarkConfig(
        imported.id,
        WatermarkConfig(elements: [_imageElement(logo.id)]),
      );
      final presets = PresetDao(harness.database);
      final now = DateTime.utc(2026, 5, 1);
      await presets.insert(
        PresetRow(
          id: 'preset-1',
          name: 'mark',
          elementsJson: '[]',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await presets.replaceAssetIds('preset-1', [logo.id]);

      await repository.delete(imported.id);

      expect(await harness.images.refFor(logo.id), isNotNull);
    });
  });
}

ImageWatermark _imageElement(String assetId) {
  return ImageWatermark(
    id: 'element-1',
    rect: const NormalizedRect.fromLTWH(0.1, 0.1, 0.2, 0.2),
    assetId: assetId,
  );
}

/// Delegates every read and write, but refuses to delete: the ordering test
/// needs the row transaction to succeed while the blob step fails.
final class _VaultWithFailingDelete implements SecureFileVault {
  _VaultWithFailingDelete(this._inner);

  final SecureFileVault _inner;

  @override
  Future<AssetRef> put({
    required Uint8List bytes,
    required String extension,
    String? assetId,
  }) => _inner.put(bytes: bytes, extension: extension, assetId: assetId);

  @override
  Future<Uint8List> read(AssetRef ref) => _inner.read(ref);

  @override
  Future<bool> exists(AssetRef ref) => _inner.exists(ref);

  @override
  Future<void> delete(AssetRef ref) async => throw _VaultLocked();

  @override
  Future<void> deleteAll() => _inner.deleteAll();
}

final class _VaultLocked implements Exception {
  const _VaultLocked();
}
