import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base/global_error_handlers.dart';
import 'di/dependency_injection.dart';
import 'di/features/app_lock_providers.dart';
import 'di/features/storage_providers.dart';
import 'logger/riverpod_log.dart';

/// Process-level setup, kept out of `main` so the entry point stays a
/// single expression.
///
/// Builds the app's one [ProviderContainer] and installs the process-wide
/// error handlers against it, so the `CrashReporter` the handlers use and
/// the one the widget tree injects are the same instance. `main` hands
/// the returned container to an `UncontrolledProviderScope`.
///
/// Two seams are called here, both placeholders until their owner lands:
///
/// - the app-lifecycle observer (`appLifecycleObserverProvider`), which
///   T10 replaces with the App Lock resume/relock hook;
/// - abandoned-temp-file cleanup (`tempFileCleanupServiceProvider`), which
///   T1 replaces with the vault-aware sweeper.
///
/// Cleanup is fire-and-forget: startup must not wait on disk work, and a
/// failure there must never prevent the UI from opening. The placeholder
/// cannot fail, and the real implementation is expected to swallow its own
/// errors and log them.
///
/// The container is never disposed: it lives for the process, matching
/// the `keepAlive` providers it hosts.
///
/// Provider retry is disabled: Riverpod 3 retries failed providers with
/// backoff by default, which breaks fail-fast semantics — the router gate
/// shows splash with retry UI on a startup failure, and a silently
/// retrying provider would never settle into that error state. Opt back
/// in per provider where a retry is genuinely wanted.
ProviderContainer bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    observers: [RiverpodObserver()],
  );
  installGlobalErrorHandlers(container.read(crashReporterProvider));

  container.read(appLifecycleObserverProvider).register();
  unawaited(container.read(tempFileCleanupServiceProvider).cleanupAbandoned());

  return container;
}
