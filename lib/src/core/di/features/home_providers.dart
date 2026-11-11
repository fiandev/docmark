/// OWNER: T6 (home surface).
///
/// Frozen DI contract for the home dashboard. Home is a read-only summary
/// of documents, presets, and history; T6 wires these to the stores.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/entities/document.dart';
import '../../../domain/entities/history.dart';
import '../../../domain/entities/preset.dart';
import '../../base/base.dart';
import 'history_providers.dart';
import 'import_providers.dart';
import 'presets_providers.dart';

part 'home_providers.g.dart';

/// How many entries the dashboard strip shows before "View all" takes over.
const int _recentLimit = 4;

/// How many saved presets the dashboard previews.
const int _presetLimit = 3;

/// The dashboard's recent-processing strip.
///
/// Delegates to the history feature's own home-facing seam so the two
/// screens cannot drift: T6 fills `recentDocuments` and the dashboard
/// follows without a second query.
@riverpod
Future<List<HistoryEntryEntity>> recentProcessing(Ref ref) async {
  final entries = await ref.watch(recentDocumentsProvider.future);

  return entries.take(_recentLimit).toList(growable: false);
}

/// The most recently edited documents, newest first.
@riverpod
Future<List<DocumentEntity>> recentDocumentList(Ref ref) async {
  final result = await ref.watch(documentRepositoryProvider).list();

  return switch (result) {
    Success(:final data) =>
      data.take(_recentLimit).toList(growable: false),
    Error() => const <DocumentEntity>[],
  };
}

/// The presets shown on the home screen, most recently updated first.
@riverpod
Future<List<PresetEntity>> homePresetList(Ref ref) async {
  final result = await ref.watch(presetRepositoryProvider).list();

  return switch (result) {
    Success(:final data) => data.take(_presetLimit).toList(growable: false),
    Error() => const <PresetEntity>[],
  };
}
