import '../../core/base/result.dart';
import '../../core/base/unit.dart';
import '../../core/security/secure_file_vault.dart';
import '../../core/storage/db/app_database.dart';
import '../../core/storage/db/dao/history_dao.dart';
import '../../core/storage/vault/watermark_asset_store.dart';
import '../../domain/entities/history.dart';
import '../../domain/failures/business_failure.dart';
import '../../domain/repositories/history_repository.dart';
import '../base/repository.dart';
import '../failures/infra_failure.dart';
import '../mappers/docmark_mappers.dart';

/// Processing history over the encrypted vault.
///
/// A history row owns up to two encrypted assets. Deleting the row also
/// deletes those bytes unless another owner still references them, which
/// is what makes "clear processing history" remove recoverable data and
/// not just list entries.
final class HistoryRepositoryImpl extends Repository
    implements HistoryRepository {
  HistoryRepositoryImpl({
    required super.crashReporter,
    required AppDatabase database,
    required WatermarkAssetStore images,
  }) : _database = database,
       _history = HistoryDao(database),
       _images = images;

  final AppDatabase _database;
  final HistoryDao _history;
  final WatermarkAssetStore _images;

  @override
  Future<Result<List<HistoryEntryEntity>, BusinessFailure>> list() {
    return asyncGuard(() async {
      final rows = await _history.all();

      return rows.map((row) => row.toEntity()).toList();
    });
  }

  @override
  Future<Result<AssetRef, BusinessFailure>> previewRef(String entryId) {
    return asyncGuard(
      () async {
        final row = await _history.find(entryId);
        if (row == null) throw _MissingEntry(entryId);
        final entry = row.toEntity();
        final reference = entry.processedRef ?? entry.originalRef;
        if (reference == null) throw _MissingEntry(entryId);

        return reference;
      },
      recover: _recoverMissing<AssetRef>,
    );
  }

  @override
  Future<Result<HistoryEntryEntity, BusinessFailure>> record(
    HistoryEntryEntity entry,
  ) {
    return asyncGuard(() async {
      await _database.transaction(() async {
        await _history.upsert(entry.toRow());
        await _images.replaceLinks(
          ownerType: WatermarkAssetStore.historyOwner,
          ownerId: entry.id,
          assetIds: _referencedIds(entry),
        );
      });

      return entry;
    });
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String entryId) {
    return asyncGuard(
      () async {
        final row = await _history.find(entryId);
        if (row == null) throw _MissingEntry(entryId);
        final references = _referencesOf(row.toEntity());

        // Claim release first, then delete, so a shared asset survives.
        await _images.removeLinks(
          ownerType: WatermarkAssetStore.historyOwner,
          ownerId: entryId,
        );
        for (final reference in references) {
          await _images.deleteRefIfUnreferenced(reference);
        }
        await _history.delete(entryId);

        return Unit.value;
      },
      recover: _recoverMissing<Unit>,
    );
  }

  @override
  Future<Result<Unit, BusinessFailure>> clear() {
    return asyncGuard(() async {
      final rows = await _history.all();
      final references = <AssetRef>{
        for (final row in rows) ..._referencesOf(row.toEntity()),
      };

      await _images.removeLinksOfType(WatermarkAssetStore.historyOwner);
      for (final reference in references) {
        await _images.deleteRefIfUnreferenced(reference);
      }
      await _history.deleteAll();

      return Unit.value;
    });
  }

  List<String> _referencedIds(HistoryEntryEntity entry) {
    final references = _referencesOf(entry);

    return references.map((reference) => reference.id).toSet().toList();
  }

  List<AssetRef> _referencesOf(HistoryEntryEntity entry) {
    return [
      if (entry.originalRef != null) entry.originalRef!,
      if (entry.processedRef != null) entry.processedRef!,
    ];
  }

  Result<T, BusinessFailure>? _recoverMissing<T>(InfraFailure failure) {
    return failure.cause is _MissingEntry
        ? const Error(BusinessFailure.notFound())
        : null;
  }
}

final class _MissingEntry implements Exception {
  const _MissingEntry(this.id);

  final String id;

  @override
  String toString() => 'MissingEntry($id)';
}
