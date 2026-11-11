/// OWNER: T1 (storage + temp cleanup).
///
/// Frozen DI contract for startup storage maintenance. `bootstrap()`
/// awaits nothing here, so `cleanupAbandoned` must never throw
/// synchronously; the no-op below is the seam T1 replaces with the real
/// vault-aware cleanup.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_providers.g.dart';

/// Removes abandoned temporary plaintext files at startup.
abstract interface class TempFileCleanupService {
  /// Deletes temp files older than the grace window. Safe to call on every
  /// launch; a second call is a no-op.
  Future<void> cleanupAbandoned();
}

/// The bootstrap placeholder: does nothing and cannot fail.
final class NoopTempFileCleanupService implements TempFileCleanupService {
  const NoopTempFileCleanupService();

  @override
  Future<void> cleanupAbandoned() async {}
}

@Riverpod(keepAlive: true)
TempFileCleanupService tempFileCleanupService(Ref ref) =>
    const NoopTempFileCleanupService();
