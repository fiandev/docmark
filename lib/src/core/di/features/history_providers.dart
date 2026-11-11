/// OWNER: T6 (processing history).
///
/// The history store, the screen's list, and the read-only thumbnail source.
/// T6 replaces the throwing repository body; `recentDocuments` keeps its
/// shape so the home page can be built against it now.
library;

import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/base/result.dart';
import '../../../data/repositories/history_repository_impl.dart';
import '../../../domain/entities/history.dart';
import '../../../domain/repositories/history_repository.dart';
import '../dependency_injection.dart';
import 'security_providers.dart';
import 'storage_providers.dart';

part 'history_providers.g.dart';

@Riverpod(keepAlive: true)
HistoryRepository historyRepository(Ref ref) => HistoryRepositoryImpl(
  crashReporter: ref.watch(crashReporterProvider),
  database: ref.watch(appDatabaseProvider),
  images: ref.watch(watermarkAssetStoreProvider),
);

/// The history screen's state and its mutations.
///
/// The provider is [AsyncValue]-shaped because the first paint waits on
/// storage; `deleteEntry` and `clearAll` update the list optimistically and
/// restore the previous snapshot when the repository rejects the change.
@Riverpod(keepAlive: true)
class HistoryList extends _$HistoryList {
  @override
  Future<List<HistoryEntryEntity>> build() async {
    final repository = ref.watch(historyRepositoryProvider);
    final result = await repository.list();

    return switch (result) {
      Success(:final data) => data,
      Error(:final error) => throw error,
    };
  }

  /// Removes one row immediately, then commits the cascading delete.
  ///
  /// Returns false and restores the row when the repository fails, so the
  /// caller can show a message without re-reading storage.
  Future<bool> deleteEntry(String entryId) async {
    final current = state.asData?.value;
    if (current == null) return false;

    final previous = state;
    state = AsyncData(
      current.where((entry) => entry.id != entryId).toList(growable: false),
    );

    final result = await ref.read(historyRepositoryProvider).delete(entryId);
    if (result is Error) {
      state = previous;

      return false;
    }

    return true;
  }

  /// Empties the list immediately, then deletes every entry and asset.
  Future<bool> clearAll() async {
    final previous = state;
    state = AsyncData(<HistoryEntryEntity>[]);

    final result = await ref.read(historyRepositoryProvider).clear();
    if (result is Error) {
      state = previous;

      return false;
    }

    return true;
  }

  /// Re-reads the list from storage, e.g. after returning from the editor.
  void refresh() => ref.invalidateSelf();
}

/// The home screen's "recent" strip: newest entries first.
@riverpod
Future<List<HistoryEntryEntity>> recentDocuments(Ref ref) async {
  final entries = await ref.watch(historyListProvider.future);

  return entries.take(5).toList(growable: false);
}

/// Decrypted bytes for a row's processed preview.
///
/// The vault is read-only here: nothing is written, and a missing or
/// undecryptable asset degrades to null so the tile shows its placeholder.
@riverpod
Future<Uint8List?> historyPreview(Ref ref, String entryId) async {
  final repository = ref.watch(historyRepositoryProvider);
  final result = await repository.previewRef(entryId);
  final reference = switch (result) {
    Success(:final data) => data,
    Error() => null,
  };
  if (reference == null) return null;

  final vault = ref.read(secureFileVaultProvider);
  try {
    if (!await vault.exists(reference)) return null;

    return await vault.read(reference);
  } catch (_) {
    return null;
  }
}
