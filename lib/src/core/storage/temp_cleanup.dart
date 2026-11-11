import 'dart:io';

import '../di/features/storage_providers.dart';

/// Sweeps abandoned temporary files from private app storage.
///
/// Renderers and normalizers stage plaintext briefly; a crash between
/// writing and deleting must not leave that copy behind forever. The sweep
/// runs at every launch, ignores files newer than [minimumAge] so a second
/// concurrent caller cannot delete a live file, and swallows every error
/// because startup must not fail over housekeeping.
final class TempFileCleanupServiceImpl implements TempFileCleanupService {
  TempFileCleanupServiceImpl({
    required List<Future<Directory> Function()> directories,
    this.minimumAge = const Duration(hours: 1),
    DateTime Function()? clock,
    void Function(Object error)? onError,
  }) : _directories = directories,
       _clock = clock ?? DateTime.now,
       _onError = onError;

  /// Directories to sweep. Missing directories are skipped, so a first run
  /// before any temp file exists is free.
  final List<Future<Directory> Function()> _directories;

  /// Files modified more recently than this are left alone.
  final Duration minimumAge;

  final DateTime Function() _clock;
  final void Function(Object error)? _onError;

  @override
  Future<void> cleanupAbandoned() async {
    final now = _clock();
    for (final resolve in _directories) {
      await _sweepDirectory(resolve, now);
    }
  }

  Future<void> _sweepDirectory(
    Future<Directory> Function() resolve,
    DateTime now,
  ) async {
    final Directory directory;
    try {
      directory = await resolve();
      if (!await directory.exists()) return;
    } catch (error) {
      _report(error);

      return;
    }

    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          if (now.difference(stat.modified) < minimumAge) continue;
          await entity.delete();
        } catch (error) {
          _report(error);
        }
      }
    } catch (error) {
      _report(error);
    }
  }

  void _report(Object error) {
    // The error type only: a path can contain a document name.
    _onError?.call(error);
  }
}
