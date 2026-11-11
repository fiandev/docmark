import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/features/presets_providers.dart';

/// The one place the editor touches T5's preset handoff.
///
/// Expected API in `presets_providers.dart`:
///
/// ```dart
/// @Riverpod(keepAlive: true)
/// class PendingPresetId extends _$PendingPresetId {
///   @override
///   String? build() => null;
///   void set(String presetId) => state = presetId;
///   void clear() => state = null;
/// }
/// ```
///
/// That generates `pendingPresetIdProvider` (`String?` state, `.notifier`
/// with `set` and `clear`). Keeping the read and the clear here means a
/// rename in T5 is a one-file change, not a sweep through the editor.
String? readPendingPresetId(Ref ref) => ref.read(pendingPresetIdProvider);

/// Marks the handed-off preset as consumed. Called from the page once the
/// session has loaded it, never from a provider build.
void clearPendingPresetId(WidgetRef ref) {
  ref.read(pendingPresetIdProvider.notifier).clear();
}
