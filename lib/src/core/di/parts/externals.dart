part of '../dependency_injection.dart';

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) =>
    SharedPreferences.getInstance();

/// The single sink for programmer bugs — the repository guards and the
/// global error handlers both report here. Override with a Crashlytics- or
/// Sentry-backed implementation to ship crash telemetry; the default logs.
@Riverpod(keepAlive: true)
CrashReporter crashReporter(Ref ref) => const LoggingCrashReporter();
