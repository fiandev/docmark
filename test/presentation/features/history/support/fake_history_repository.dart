import 'package:flutter_template/src/core/base/result.dart';
import 'package:flutter_template/src/core/base/unit.dart';
import 'package:flutter_template/src/core/security/secure_file_vault.dart';
import 'package:flutter_template/src/domain/entities/history.dart';
import 'package:flutter_template/src/domain/failures/business_failure.dart';
import 'package:flutter_template/src/domain/repositories/history_repository.dart';

/// In-memory history store for page tests.
final class FakeHistoryRepository implements HistoryRepository {
  FakeHistoryRepository({List<HistoryEntryEntity>? entries})
    : entries = [...?entries];

  final List<HistoryEntryEntity> entries;
  final List<String> deleted = <String>[];
  int clearCalls = 0;

  @override
  Future<Result<List<HistoryEntryEntity>, BusinessFailure>> list() async {
    return Success(List<HistoryEntryEntity>.unmodifiable(entries));
  }

  @override
  Future<Result<AssetRef, BusinessFailure>> previewRef(String entryId) async {
    final entry = _find(entryId);
    final reference = entry?.processedRef ?? entry?.originalRef;
    if (reference == null) return const Error(BusinessFailure.notFound());

    return Success(reference);
  }

  @override
  Future<Result<HistoryEntryEntity, BusinessFailure>> record(
    HistoryEntryEntity entry,
  ) async {
    entries
      ..removeWhere((current) => current.id == entry.id)
      ..add(entry);

    return Success(entry);
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String entryId) async {
    deleted.add(entryId);
    entries.removeWhere((entry) => entry.id == entryId);

    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit, BusinessFailure>> clear() async {
    clearCalls += 1;
    entries.clear();

    return const Success(Unit.value);
  }

  HistoryEntryEntity? _find(String entryId) {
    for (final entry in entries) {
      if (entry.id == entryId) return entry;
    }

    return null;
  }
}
