import 'package:uuid/uuid.dart';

import '../../core/base/result.dart';
import '../../core/base/unit.dart';
import '../../core/security/secure_file_vault.dart';
import '../../core/storage/db/app_database.dart';
import '../../core/storage/db/dao/document_dao.dart';
import '../../core/storage/db/dao/preset_dao.dart';
import '../../core/storage/vault/failures.dart';
import '../../core/storage/vault/watermark_asset_store.dart';
import '../../domain/entities/preset.dart';
import '../../domain/entities/watermark_element.dart';
import '../../domain/failures/business_failure.dart';
import '../../domain/repositories/preset_repository.dart';
import '../base/repository.dart';
import '../failures/infra_failure.dart';
import '../mappers/docmark_mappers.dart';

/// Presets over the encrypted vault.
///
/// Creating a preset copies the image assets it references into
/// preset-owned ids. That costs a little storage but buys a strong
/// guarantee: deleting the document a preset was built from cannot break
/// the preset, and a preset can be applied to any later document.
final class PresetRepositoryImpl extends Repository
    implements PresetRepository {
  PresetRepositoryImpl({
    required super.crashReporter,
    required AppDatabase database,
    required WatermarkAssetStore images,
    Uuid uuid = const Uuid(),
  }) : _database = database,
       _presets = PresetDao(database),
       _documents = DocumentDao(database),
       _images = images,
       _uuid = uuid;

  final AppDatabase _database;
  final PresetDao _presets;
  final DocumentDao _documents;
  final WatermarkAssetStore _images;
  final Uuid _uuid;

  @override
  Future<Result<List<PresetEntity>, BusinessFailure>> list() {
    return asyncGuard(() async {
      final rows = await _presets.all();
      final assetIds = await _presets.allAssetIds();

      return rows
          .map((row) => row.toEntity(assetIds[row.id] ?? const <String>[]))
          .toList();
    });
  }

  @override
  Future<Result<PresetEntity?, BusinessFailure>> get(String presetId) {
    return asyncGuard(() async {
      final row = await _presets.find(presetId);
      if (row == null) return null;
      final assetIds = await _presets.assetIdsFor(presetId);

      return row.toEntity(assetIds);
    });
  }

  @override
  Future<Result<PresetEntity, BusinessFailure>> create({
    required String name,
    required List<WatermarkElement> elements,
    required List<String> imageAssetIds,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Error<PresetEntity, BusinessFailure>(
        BusinessFailure.invalidInput(),
      );
    }

    return asyncGuard(
      () async {
        final copied = await _copyAssets(elements, imageAssetIds);
        final now = DateTime.now();
        final preset = PresetEntity(
          id: _uuid.v4(),
          name: trimmed,
          elements: copied.elements,
          imageAssetIds: copied.assetIds,
          createdAt: now,
          updatedAt: now,
        );

        try {
          await _databaseTransaction(() async {
            await _presets.insert(preset.toRow());
            await _presets.replaceAssetIds(preset.id, preset.imageAssetIds);
          });
        } catch (_) {
          for (final assetId in copied.assetIds) {
            await _images.deleteIfUnreferenced(assetId);
          }
          rethrow;
        }

        return preset;
      },
      recover: _recoverMissing<PresetEntity>,
    );
  }

  @override
  Future<Result<PresetEntity, BusinessFailure>> update(
    PresetEntity preset,
  ) async {
    final trimmed = preset.name.trim();
    if (trimmed.isEmpty) {
      return const Error<PresetEntity, BusinessFailure>(
        BusinessFailure.invalidInput(),
      );
    }

    return asyncGuard(
      () async {
        final existing = await _presets.find(preset.id);
        if (existing == null) throw _MissingPreset(preset.id);
        final previous = await _presets.assetIdsFor(preset.id);
        final next = PresetEntity(
          id: preset.id,
          name: trimmed,
          elements: preset.elements,
          imageAssetIds: _effectiveAssetIds(preset),
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        );

        await _databaseTransaction(() async {
          await _presets.update(next.toRow());
          await _presets.replaceAssetIds(next.id, next.imageAssetIds);
        });

        final removed =
            previous.toSet().difference(next.imageAssetIds.toSet());
        for (final assetId in removed) {
          await _images.deleteIfUnreferenced(assetId);
        }

        return next;
      },
      recover: _recoverMissing<PresetEntity>,
    );
  }

  @override
  Future<Result<PresetEntity, BusinessFailure>> duplicate(
    String presetId,
  ) {
    return asyncGuard(
      () async {
        final source = await _presets.find(presetId);
        if (source == null) throw _MissingPreset(presetId);
        final sourceAssetIds = await _presets.assetIdsFor(presetId);
        final copied = await _copyAssets(
          decodeElements(source.elementsJson),
          sourceAssetIds,
        );
        final now = DateTime.now();
        final duplicated = PresetEntity(
          id: _uuid.v4(),
          name: source.name,
          elements: copied.elements,
          imageAssetIds: copied.assetIds,
          createdAt: now,
          updatedAt: now,
        );

        try {
          await _databaseTransaction(() async {
            await _presets.insert(duplicated.toRow());
            await _presets.replaceAssetIds(
              duplicated.id,
              duplicated.imageAssetIds,
            );
          });
        } catch (_) {
          for (final assetId in copied.assetIds) {
            await _images.deleteIfUnreferenced(assetId);
          }
          rethrow;
        }

        return duplicated;
      },
      recover: _recoverMissing<PresetEntity>,
    );
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String presetId) {
    return asyncGuard(
      () async {
        final existing = await _presets.find(presetId);
        if (existing == null) throw _MissingPreset(presetId);
        final assetIds = await _presets.assetIdsFor(presetId);

        await _presets.removeAssociations(presetId);
        for (final assetId in assetIds) {
          await _images.deleteIfUnreferenced(assetId);
        }
        await _presets.delete(presetId);

        return Unit.value;
      },
      recover: _recoverMissing<Unit>,
    );
  }

  @override
  Future<Result<List<WatermarkElement>, BusinessFailure>> apply(
    String presetId,
    String documentId,
  ) {
    return asyncGuard(
      () async {
        final preset = await _presets.find(presetId);
        if (preset == null) throw _MissingPreset(presetId);
        final document = await _documents.find(documentId);
        if (document == null) throw _MissingDocument(documentId);

        // Geometry is normalized, so the same element list is valid on
        // every page size; the editor clamps to the target page when the
        // user drags, exactly as it does for a hand-built config.
        return decodeElements(preset.elementsJson);
      },
      recover: _recoverMissing<List<WatermarkElement>>,
    );
  }

  Future<void> _databaseTransaction(Future<void> Function() action) async {
    await _database.transaction(action);
  }

  Future<({List<WatermarkElement> elements, List<String> assetIds})>
  _copyAssets(
    List<WatermarkElement> elements,
    List<String> assetIds,
  ) async {
    final requested = <String>{
      ...assetIds,
      for (final element in elements)
        if (element is ImageWatermark) element.assetId,
    };
    final mapping = <String, AssetRef>{};
    try {
      for (final sourceId in requested) {
        if (sourceId.isEmpty) continue;
        mapping[sourceId] = await _images.copy(sourceId);
      }
    } catch (_) {
      // A half-copied asset set has no owner; erase it instead of leaking
      // encrypted bytes that no row will ever point at.
      for (final reference in mapping.values) {
        await _images.deleteIfUnreferenced(reference.id);
      }
      rethrow;
    }

    final remapped = <WatermarkElement>[];
    for (final element in elements) {
      if (element is ImageWatermark) {
        final copied = mapping[element.assetId];
        remapped.add(
          copied == null ? element : element.copyWith(assetId: copied.id),
        );
      } else {
        remapped.add(element);
      }
    }

    return (
      elements: remapped,
      assetIds: mapping.values.map((reference) => reference.id).toList(),
    );
  }

  List<String> _effectiveAssetIds(PresetEntity preset) {
    return <String>{
      ...preset.imageAssetIds,
      for (final element in preset.elements)
        if (element is ImageWatermark) element.assetId,
    }.where((assetId) => assetId.isNotEmpty).toList();
  }

  Result<T, BusinessFailure>? _recoverMissing<T>(InfraFailure failure) {
    final cause = failure.cause;
    if (cause is _MissingPreset ||
        cause is _MissingDocument ||
        cause is MissingAssetFailure) {
      return Error<T, BusinessFailure>(BusinessFailure.notFound());
    }

    return null;
  }
}

final class _MissingPreset implements Exception {
  const _MissingPreset(this.id);

  final String id;

  @override
  String toString() => 'MissingPreset($id)';
}

final class _MissingDocument implements Exception {
  const _MissingDocument(this.id);

  final String id;

  @override
  String toString() => 'MissingDocument($id)';
}
