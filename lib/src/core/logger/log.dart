import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Debug-only log facade.
///
/// Release builds print nothing: a log line is the easiest way for document
/// names, storage paths, or key material to escape the encrypted boundary,
/// and there is no console on a shipped device that justifies the risk.
class Log {
  Log._internal() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: lineLength,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.none,
      ),
    );
  }

  static final Log _singleton = Log._internal();

  late Logger _logger;
  static const lineLength = 80;

  static void fatal({required Object error, required StackTrace stackTrace}) {
    if (!kDebugMode) return;
    _singleton._logger.f('Fatal', error: error, stackTrace: stackTrace);
  }

  static void debug(String message) {
    if (!kDebugMode) return;
    _singleton._logger.d(message);
  }

  static void info(String message) {
    if (!kDebugMode) return;
    _singleton._logger.i(message);
  }

  static void error(String message) {
    if (!kDebugMode) return;
    _singleton._logger.e(message);
  }

  static void warning(String message) {
    if (!kDebugMode) return;
    _singleton._logger.w(message);
  }
}
