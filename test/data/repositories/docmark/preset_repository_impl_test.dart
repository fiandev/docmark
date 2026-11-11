import 'dart:typed_data';

import 'package:docmark/src/core/base/result.dart';
import 'package:docmark/src/core/base/unit.dart';
import 'package:docmark/src/core/security/secure_file_vault.dart';
import 'package:docmark/src/core/storage/db/dao/asset_dao.dart';
import 'package:docmark/src/core/storage/vault/watermark_asset_store.dart';
import 'package:docmark/src/data/repositories/preset_repository_impl.dart';
import 'package:docmark/src/domain/entities/normalized_rect.dart';
import 'package:docmark/src/domain/entities/preset.dart';
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

  group('PresetRepositoryImpl', () {
    test('create copies referenced assets into preset ids', () async {
      final repository = harness.presets();
      final source = await _seedImage(harness, 'brand-logo');
      final element = _imageElement(source.id);

      final preset = dataOf(
        await repository.create(
          name: 'Brand',
          elements: [element],
          imageAssetIds: [source.id],
        ),
      );

      expect(preset.name, 'Brand');
      final copiedId = preset.imageAssetIds.single;
      expect(copiedId, isNot(source.id));
      expect(
        (preset.elements.single as ImageWatermark).assetId,
        copiedId,
      );
      expect(await harness.images.refFor(copiedId), isNotNull);
      expect(await harness.images.refFor(source.id), isNotNull);
    });

    test('list and get return the stored elements', () async {
      final repository = harness.presets();
      final source = await _seedImage(harness, 'brand-logo');
      final created = dataOf(
        await repository.create(
          name: 'Brand',
          elements: [_imageElement(source.id)],
          imageAssetIds: [source.id],
        ),
      );

      final listed = dataOf(await repository.list());
      final fetched = dataOf(await repository.get(created.id))!;

      expect(listed.map((preset) => preset.id), [created.id]);
      expect(fetched.elements, hasLength(1));
      expect(fetched.imageAssetIds, created.imageAssetIds);
    });

    test('apply re-points the preset at a document', () async {
      final repository = harness.presets();
      final documents = harness.documents();
      final source = await _seedImage(harness, 'brand-logo');
      final preset = dataOf(
        await repository.create(
          name: 'Brand',
          elements: [_imageElement(source.id)],
          imageAssetIds: [source.id],
        ),
      );
      final document = dataOf(
        await documents.importDocument(
          ImportRequest(
            source: ImportSource.gallery,
            fileName: 'one.png',
            bytes: pngBytes('one'),
          ),
        ),
      );

      final elements = dataOf(await repository.apply(preset.id, document.id));

      expect(elements, hasLength(1));
      expect(
        (elements.single as ImageWatermark).assetId,
        preset.imageAssetIds.single,
      );
    });

    test(
      'delete commits the preset before the blob delete can fail',
      () async {
        final source = await _seedImage(harness, 'brand-logo');
        final preset = dataOf(
          await harness.presets().create(
            name: 'Brand',
            elements: [_imageElement(source.id)],
            imageAssetIds: [source.id],
          ),
        );
        final repository = PresetRepositoryImpl(
          crashReporter: harness.crashReporter,
          database: harness.database,
          images: WatermarkAssetStore(
            vault: _VaultWithFailingDelete(harness.vault),
            assets: AssetDao(harness.database),
          ),
        );
        final copiedId = preset.imageAssetIds.single;

        final result = await repository.delete(preset.id);

        expect(result, isA<Error<Unit, BusinessFailure>>());
        expect(
          await harness.database.select(harness.database.presets).get(),
          isEmpty,
        );
        expect(
          await harness.database.select(harness.database.presetAssets).get(),
          isEmpty,
        );
        // The asset row and blob survive; only the preset rows committed.
        expect(await harness.images.refFor(copiedId), isNotNull);
      },
    );

    test('delete removes the preset and its copied asset', () async {
      final repository = harness.presets();
      final source = await _seedImage(harness, 'brand-logo');
      final preset = dataOf(
        await repository.create(
          name: 'Brand',
          elements: [_imageElement(source.id)],
          imageAssetIds: [source.id],
        ),
      );
      final copiedId = preset.imageAssetIds.single;

      final deleted = await repository.delete(preset.id);

      expect(deleted, const Success<Unit, BusinessFailure>(Unit.value));
      expect(
        await repository.get(preset.id),
        const Success<PresetEntity?, BusinessFailure>(null),
      );
      expect(await harness.images.refFor(copiedId), isNull);
      expect(await harness.images.refFor(source.id), isNotNull);
    });

    test('duplicate survives deleting the original', () async {
      final repository = harness.presets();
      final source = await _seedImage(harness, 'brand-logo');
      final original = dataOf(
        await repository.create(
          name: 'Brand',
          elements: [_imageElement(source.id)],
          imageAssetIds: [source.id],
        ),
      );

      final duplicated = dataOf(await repository.duplicate(original.id));

      expect(duplicated.id, isNot(original.id));
      expect(
        duplicated.imageAssetIds.single,
        isNot(original.imageAssetIds.single),
      );

      await repository.delete(original.id);

      expect(
        await harness.images.refFor(duplicated.imageAssetIds.single),
        isNotNull,
      );
    });

    test('rejects an empty name', () async {
      final repository = harness.presets();

      final result = await repository.create(
        name: '   ',
        elements: const [],
        imageAssetIds: const [],
      );

      expect(result, isA<Error<dynamic, BusinessFailure>>());
    });
  });
}

Future<AssetRef> _seedImage(DocmarkHarness harness, String marker) {
  return harness.images.putImage(
    bytes: pngBytes(marker),
    extension: 'png',
    mime: 'image/png',
  );
}

ImageWatermark _imageElement(String assetId) {
  return ImageWatermark(
    id: 'element-1',
    rect: const NormalizedRect.fromLTWH(0.1, 0.1, 0.2, 0.2),
    assetId: assetId,
  );
}

/// Delegates reads and writes but refuses to delete, so the ordering test can
/// let the row transaction commit and fail at the blob step.
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
