import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/features/history_providers.dart';
import '../../../../core/di/features/presets_providers.dart';
import '../../../../domain/entities/document.dart';

/// The one place the editor touches the cross-feature hand-offs.
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

/// The watermark configuration History hands over when the original
/// document is gone. A preset id outranks it; the stored draft does not.
WatermarkConfig? readPendingWatermarkConfig(Ref ref) =>
    ref.read(pendingWatermarkConfigProvider);

/// Consumes the History hand-off after the session has applied it.
void clearPendingWatermarkConfig(WidgetRef ref) {
  ref.read(pendingWatermarkConfigProvider.notifier).clear();
}
