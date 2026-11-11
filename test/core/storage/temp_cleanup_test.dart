import 'dart:io';

import 'package:flutter_template/src/core/storage/temp_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('docmark_temp_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('TempFileCleanupServiceImpl', () {
    test('deletes files older than the grace window', () async {
      final old = File('${root.path}/old-part.tmp')
        ..writeAsStringSync('old scratch');
      old.setLastModifiedSync(
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      final fresh = File('${root.path}/fresh-part.tmp')
        ..writeAsStringSync('fresh scratch');

      final service = TempFileCleanupServiceImpl(
        directories: [() async => root],
        minimumAge: const Duration(hours: 1),
      );
      await service.cleanupAbandoned();

      expect(await old.exists(), isFalse);
      expect(await fresh.exists(), isTrue);
    });

    test('sweeps every configured directory', () async {
      final first = Directory('${root.path}/first')..createSync();
      final second = Directory('${root.path}/second')..createSync();
      final firstFile = File('${first.path}/a.tmp')
        ..writeAsStringSync('a');
      final secondFile = File('${second.path}/b.tmp')
        ..writeAsStringSync('b');

      final service = TempFileCleanupServiceImpl(
        directories: [
          () async => first,
          () async => second,
        ],
        minimumAge: Duration.zero,
      );
      await service.cleanupAbandoned();

      expect(await firstFile.exists(), isFalse);
      expect(await secondFile.exists(), isFalse);
    });

    test('ignores a missing directory', () async {
      final service = TempFileCleanupServiceImpl(
        directories: [
          () async => Directory('${root.path}/does-not-exist'),
        ],
      );

      await expectLater(service.cleanupAbandoned(), completes);
    });

    test('swallows a resolver failure', () async {
      final errors = <Object>[];
      final service = TempFileCleanupServiceImpl(
        directories: [
          () async => throw const FileSystemException('denied'),
        ],
        onError: errors.add,
      );

      await expectLater(service.cleanupAbandoned(), completes);
      expect(errors, hasLength(1));
    });
  });
}
