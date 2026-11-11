/// OWNER: T5 (watermark presets).
///
/// Frozen DI contract for the preset store, the preset list every preset
/// surface watches, and the hand-off used by "apply preset". T3 reads
/// [presetListProvider] and [pendingPresetIdProvider]; the picker keeps the
/// pending id for the editor on success and clears it when a pick is
/// abandoned, while the editor clears it after applying.
library;

import 'dart:async';

import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/preset_repository_impl.dart';
import '../../../domain/entities/preset.dart';
import '../../../domain/entities/watermark_element.dart';
import '../../../domain/failures/business_failure.dart';
import '../../../domain/repositories/preset_repository.dart';
import '../../../presentation/core/router/routes.dart';
import '../../base/result.dart';
import '../../base/unit.dart';
import '../dependency_injection.dart';
import 'storage_providers.dart';

part 'presets_providers.g.dart';

/// Presets over the encrypted database and vault.
@Riverpod(keepAlive: true)
PresetRepository presetRepository(Ref ref) {
  return PresetRepositoryImpl(
    crashReporter: ref.watch(crashReporterProvider),
    database: ref.watch(appDatabaseProvider),
    images: ref.watch(watermarkAssetStoreProvider),
  );
}

/// The saved presets, newest first.
///
/// Mutations live on this notifier so the cached list is invalidated in one
/// place instead of at every call site. Each method returns the repository
/// [Result] unchanged, letting the caller localize the failure.
@Riverpod(keepAlive: true)
class PresetList extends _$PresetList {
  @override
  Future<List<PresetEntity>> build() async {
    final result = await ref.watch(presetRepositoryProvider).list();

    return switch (result) {
      Success(:final data) => data,
      Error(:final error) => throw error,
    };
  }

  Future<Result<PresetEntity, BusinessFailure>> create({
    required String name,
    required List<WatermarkElement> elements,
    required List<String> imageAssetIds,
  }) async {
    final result = await ref
        .read(presetRepositoryProvider)
        .create(name: name, elements: elements, imageAssetIds: imageAssetIds);
    if (result is Success<PresetEntity, BusinessFailure>) ref.invalidateSelf();

    return result;
  }

  /// Renames in place: the stored elements and asset ids are untouched.
  Future<Result<PresetEntity, BusinessFailure>> rename(
    PresetEntity preset,
    String name,
  ) async {
    final result = await ref
        .read(presetRepositoryProvider)
        .update(preset.copyWith(name: name));
    if (result is Success<PresetEntity, BusinessFailure>) ref.invalidateSelf();

    return result;
  }

  Future<Result<PresetEntity, BusinessFailure>> duplicate(
    String presetId,
  ) async {
    final result = await ref.read(presetRepositoryProvider).duplicate(presetId);
    if (result is Success<PresetEntity, BusinessFailure>) ref.invalidateSelf();

    return result;
  }

  Future<Result<Unit, BusinessFailure>> delete(String presetId) async {
    final result = await ref.read(presetRepositoryProvider).delete(presetId);
    if (result is Success<Unit, BusinessFailure>) ref.invalidateSelf();

    return result;
  }
}

/// The preset chosen on the presets tab, waiting for a document.
///
/// The picker reads it after the user chooses a document and clears it once
/// the editor has consumed the configuration, so a cancelled pick never
/// applies a stale preset to a later flow.
@Riverpod(keepAlive: true)
class PendingPresetId extends _$PendingPresetId {
  @override
  String? build() => null;

  void set(String? id) => state = id;

  void clear() => state = null;
}

/// Starts the "apply preset" flow.
///
/// Records [presetId] first, then pushes the picker above the shell. The
/// order matters: the picker's builder must never see a half-applied choice.
/// Pushing (not replacing) keeps a back destination for a cancelled pick.
/// Routing goes through [Routes] so no feature imports the import feature.
void applyPreset(WidgetRef ref, BuildContext context, String presetId) {
  ref.read(pendingPresetIdProvider.notifier).set(presetId);
  unawaited(context.pushNamed(Routes.documentPicker.name));
}
