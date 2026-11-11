import 'dart:typed_data';

import 'package:docmark/src/core/base/result.dart';
import 'package:docmark/src/core/base/unit.dart';
import 'package:docmark/src/core/security/secure_file_vault.dart';
import 'package:docmark/src/core/storage/db/dao/asset_dao.dart';
import 'package:docmark/src/core/storage/vault/watermark_asset_store.dart';
import 'package:docmark/src/data/repositories/history_repository_impl.dart';
import 'package:docmark/src/domain/entities/history.dart';
import 'package:docmark/src/domain/failures/business_failure.dart';
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

  group('HistoryRepositoryImpl', () {
    test('records, lists newest first, and updates by id', () async {
      final repository = harness.history();
      final first = await _entry(harness, 'h1', DateTime.utc(2026, 6, 1));
      final second = await _entry(harness, 'h2', DateTime.utc(2026, 6, 2));

      await repository.record(first);
      final recorded = await repository.record(second);

      expect(recorded, isA<Success<HistoryEntryEntity, BusinessFailure>>());
      final listed = dataOf(await repository.list());
      expect(listed.map((entry) => entry.id), ['h2', 'h1']);

      await repository.record(
        second.copyWith(status: HistoryStatus.completed),
      );

      final updated = dataOf(await repository.list());
      expect(updated.first.status, HistoryStatus.completed);
      expect(updated, hasLength(2));
    });

    test('previewRef returns the processed asset', () async {
      final repository = harness.history();
      final entry = await _entry(harness, 'h1', DateTime.utc(2026, 6, 1));
      await repository.record(entry);

      final preview = dataOf(await repository.previewRef('h1'));

      expect(preview, entry.processedRef);
    });

    test('previewRef reports notFound for a missing entry', () async {
      final repository = harness.history();

      final result = await repository.previewRef('missing');

      expect(result, isA<Error<dynamic, BusinessFailure>>());
    });

    test('delete erases both encrypted assets', () async {
      final repository = harness.history();
      final entry = await _entry(harness, 'h1', DateTime.utc(2026, 6, 1));
      await repository.record(entry);

      final deleted = await repository.delete('h1');

      expect(deleted, const Success<Unit, BusinessFailure>(Unit.value));
      expect(await harness.vault.exists(entry.originalRef!), isFalse);
      expect(await harness.vault.exists(entry.processedRef!), isFalse);
      expect(await harness.files(), isEmpty);
      final listed = dataOf(await repository.list());
      expect(listed, isEmpty);
    });

    test('delete commits the row before the blob delete can fail', () async {
      final entry = await _entry(harness, 'h1', DateTime.utc(2026, 6, 1));
      await harness.history().record(entry);
      final repository = HistoryRepositoryImpl(
        crashReporter: harness.crashReporter,
        database: harness.database,
        images: WatermarkAssetStore(
          vault: _VaultWithFailingDelete(harness.vault),
          assets: AssetDao(harness.database),
        ),
      );

      final result = await repository.delete('h1');

      expect(result, isA<Error<Unit, BusinessFailure>>());
      expect(
        await harness.database.select(harness.database.historyEntries).get(),
        isEmpty,
      );
      expect(
        await harness.database.select(harness.database.assetLinks).get(),
        isEmpty,
      );
      // The row is gone; the two blobs remain orphaned and sweepable.
      expect(await harness.files(), hasLength(2));
    });

    test('clear removes every entry and every asset', () async {
      final repository = harness.history();
      final first = await _entry(harness, 'h1', DateTime.utc(2026, 6, 1));
      final second = await _entry(harness, 'h2', DateTime.utc(2026, 6, 2));
      await repository.record(first);
      await repository.record(second);

      final cleared = await repository.clear();

      expect(cleared, const Success<Unit, BusinessFailure>(Unit.value));
      for (final reference in [
        first.originalRef!,
        first.processedRef!,
        second.originalRef!,
        second.processedRef!,
      ]) {
        expect(await harness.vault.exists(reference), isFalse);
      }
      expect(await harness.files(), isEmpty);
    });
  });
}

Future<HistoryEntryEntity> _entry(
  DocmarkHarness harness,
  String id,
  DateTime createdAt,
) async {
  final original = await harness.vault.put(
    bytes: pngBytes('$id-original'),
    extension: 'png',
  );
  final processed = await harness.vault.put(
    bytes: pngBytes('$id-processed'),
    extension: 'png',
  );

  return HistoryEntryEntity(
    id: id,
    documentName: '$id.png',
    createdAt: createdAt,
    status: HistoryStatus.pending,
    originalRef: original,
    processedRef: processed,
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
