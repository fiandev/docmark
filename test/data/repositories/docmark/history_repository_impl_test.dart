import 'package:flutter_template/src/core/base/result.dart';
import 'package:flutter_template/src/core/base/unit.dart';
import 'package:flutter_template/src/domain/entities/history.dart';
import 'package:flutter_template/src/domain/failures/business_failure.dart';
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
