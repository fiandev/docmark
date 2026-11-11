import 'package:docmark/src/data/failures/exception_classifier.dart';
import 'package:docmark/src/data/failures/infra_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Produces a real [TypeError] via a deliberate bad cast.
TypeError _captureTypeError() {
  try {
    (42 as dynamic) as String;
  } on TypeError catch (e) {
    return e;
  }
  throw StateError('the bad cast did not throw a TypeError');
}

void main() {
  group('Object.toInfraFailure', () {
    test('TypeError (a Dart Error — a bug) → defect', () {
      expect(_captureTypeError().toInfraFailure(), isA<DefectFailure>());
    });

    test('FormatException (malformed data) → parsing', () {
      expect(
        const FormatException('Unexpected character').toInfraFailure(),
        isA<ParsingFailure>().having(
          (f) => f.message,
          'message',
          'Unexpected character',
        ),
      );
    });

    test('StateError → defect with the passed stack trace preserved', () {
      final trace = StackTrace.current;

      expect(
        StateError('impossible state').toInfraFailure(trace),
        isA<DefectFailure>().having(
          (f) => f.stackTrace,
          'stackTrace',
          same(trace),
        ),
      );
    });

    test('Generic Exception → unknown', () {
      final ex = Exception('something');

      expect(ex.toInfraFailure(), isA<UnknownFailure>());
    });

    test('an Error keeps the original object as its cause', () {
      final error = _captureTypeError();

      expect(
        error.toInfraFailure(),
        isA<DefectFailure>().having((f) => f.cause, 'cause', same(error)),
      );
    });
  });
}
