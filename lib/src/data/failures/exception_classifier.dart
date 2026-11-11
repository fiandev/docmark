import 'infra_failure.dart';

/// Classifies any thrown object into an [InfraFailure]. Pass the stack
/// trace from the surrounding `catch (e, stackTrace)` so the failure
/// preserves it for logging.
///
/// The default branches cover [FormatException] (malformed data — the
/// common `jsonDecode`, `int.parse`, `DateTime.parse` failures) and Dart
/// `Error` (a programmer bug — null dereference, bad cast — classified as
/// `defect`, never as a data problem). Anything else is folded into
/// [InfraFailure.unknown] with the original exception attached as `cause`.
///
/// DocMark's storage, vault, and renderer layers throw their own exception
/// types; extend this extension with branches for them as those layers
/// land so their failures keep a specific business meaning.
extension ExceptionClassifier on Object {
  InfraFailure toInfraFailure([StackTrace? stackTrace]) {
    final self = this;
    StackTrace? trace = stackTrace;
    if (trace == null && self is Error) {
      trace = self.stackTrace;
    }

    return switch (self) {
      FormatException(:final message) => .parsing(
        message: message,
        cause: self,
        stackTrace: trace,
      ),
      Error() => .defect(
        message: self.toString(),
        cause: self,
        stackTrace: trace,
      ),
      _ => .unknown(message: self.toString(), cause: self, stackTrace: trace),
    };
  }
}
