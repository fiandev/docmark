import 'package:flutter_template/src/core/base/result.dart';
import 'package:flutter_template/src/core/base/unit.dart';
import 'package:flutter_template/src/domain/entities/preset.dart';
import 'package:flutter_template/src/domain/entities/watermark_element.dart';
import 'package:flutter_template/src/domain/failures/business_failure.dart';
import 'package:flutter_template/src/domain/repositories/preset_repository.dart';

/// In-memory [PresetRepository] for widget tests.
///
/// It models the contract, not the vault: ids are generated, a duplicate
/// reuses the source asset ids, and nothing is encrypted. Asset copying is
/// covered against the real repository in `preset_repository_test.dart`.
final class FakePresetRepository implements PresetRepository {
  FakePresetRepository({List<PresetEntity> seed = const []})
    : presets = [...seed];

  final List<PresetEntity> presets;
  final List<String> deletedAssetIds = [];

  /// When set, every call returns this failure instead of touching storage.
  BusinessFailure? failure;

  int _nextId = 1;

  Result<T, BusinessFailure>? _forced<T>() {
    final forced = failure;

    return forced == null ? null : Error<T, BusinessFailure>(forced);
  }

  @override
  Future<Result<List<PresetEntity>, BusinessFailure>> list() async {
    final forced = _forced<List<PresetEntity>>();
    if (forced != null) return forced;

    return Success(List<PresetEntity>.unmodifiable(presets));
  }

  @override
  Future<Result<PresetEntity?, BusinessFailure>> get(String presetId) async {
    final forced = _forced<PresetEntity?>();
    if (forced != null) return forced;

    for (final preset in presets) {
      if (preset.id == presetId) return Success(preset);
    }

    return const Success<PresetEntity?, BusinessFailure>(null);
  }

  @override
  Future<Result<PresetEntity, BusinessFailure>> create({
    required String name,
    required List<WatermarkElement> elements,
    required List<String> imageAssetIds,
  }) async {
    final forced = _forced<PresetEntity>();
    if (forced != null) return forced;

    final now = DateTime.now();
    final preset = PresetEntity(
      id: 'preset-${_nextId++}',
      name: name.trim(),
      elements: elements,
      imageAssetIds: imageAssetIds,
      createdAt: now,
      updatedAt: now,
    );
    presets.add(preset);

    return Success(preset);
  }

  @override
  Future<Result<PresetEntity, BusinessFailure>> update(
    PresetEntity preset,
  ) async {
    final forced = _forced<PresetEntity>();
    if (forced != null) return forced;

    final index = presets.indexWhere((item) => item.id == preset.id);
    if (index < 0) {
      return const Error<PresetEntity, BusinessFailure>(
        BusinessFailure.notFound(),
      );
    }
    final updated = preset.copyWith(updatedAt: DateTime.now());
    presets[index] = updated;

    return Success(updated);
  }

  @override
  Future<Result<PresetEntity, BusinessFailure>> duplicate(
    String presetId,
  ) async {
    final forced = _forced<PresetEntity>();
    if (forced != null) return forced;

    final source = await get(presetId);
    if (source case Success(:final data)) {
      if (data == null) {
        return const Error<PresetEntity, BusinessFailure>(
          BusinessFailure.notFound(),
        );
      }
      final now = DateTime.now();
      final copy = PresetEntity(
        id: 'preset-${_nextId++}',
        name: data.name,
        elements: data.elements,
        imageAssetIds: data.imageAssetIds,
        createdAt: now,
        updatedAt: now,
      );
      presets.add(copy);

      return Success(copy);
    }

    return const Error<PresetEntity, BusinessFailure>(
      BusinessFailure.notFound(),
    );
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String presetId) async {
    final forced = _forced<Unit>();
    if (forced != null) return forced;

    final index = presets.indexWhere((item) => item.id == presetId);
    if (index < 0) {
      return const Error<Unit, BusinessFailure>(BusinessFailure.notFound());
    }
    deletedAssetIds.addAll(presets.removeAt(index).imageAssetIds);

    return const Success(Unit.value);
  }

  @override
  Future<Result<List<WatermarkElement>, BusinessFailure>> apply(
    String presetId,
    String documentId,
  ) async {
    final forced = _forced<List<WatermarkElement>>();
    if (forced != null) return forced;

    final source = await get(presetId);
    if (source case Success(:final data)) {
      if (data == null) {
        return const Error<List<WatermarkElement>, BusinessFailure>(
          BusinessFailure.notFound(),
        );
      }

      return Success(data.elements);
    }

    return const Error<List<WatermarkElement>, BusinessFailure>(
      BusinessFailure.notFound(),
    );
  }
}
