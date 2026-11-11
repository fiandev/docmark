import '../../core/base/result.dart';
import '../../core/base/unit.dart';
import '../../core/security/secure_file_vault.dart';
import '../entities/history.dart';
import '../failures/business_failure.dart';

/// Processing history.
///
/// A history entry owns two encrypted assets (original and processed).
/// [delete] and [clear] cascade: deleting the row also deletes the bytes,
/// so "delete my data" leaves nothing recoverable behind.
abstract interface class HistoryRepository {
  /// Newest first.
  Future<Result<List<HistoryEntryEntity>, BusinessFailure>> list();

  /// A vault reference for the processed preview image.
  Future<Result<AssetRef, BusinessFailure>> previewRef(String entryId);

  /// Persists a completed or in-flight processing run.
  Future<Result<HistoryEntryEntity, BusinessFailure>> record(
    HistoryEntryEntity entry,
  );

  /// Deletes the entry and both of its encrypted assets.
  Future<Result<Unit, BusinessFailure>> delete(String entryId);

  /// Deletes every entry and every asset they own.
  Future<Result<Unit, BusinessFailure>> clear();
}
