import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/dependency_injection.dart';
import '../localization_provider/localization_provider.dart';

part 'startup_provider.g.dart';

/// One-time process startup: load preferences and restore the persisted
/// locale.
///
/// It deliberately does not open the database or touch the vault — those
/// are lazy, so a cold start never blocks on native initialization. A
/// failure here keeps the router on splash with its retry UI.
@Riverpod(keepAlive: true)
Future<void> startup(Ref ref) async {
  ref.onDispose(() {
    ref.invalidate(sharedPreferencesProvider);
  });

  await ref.watch(sharedPreferencesProvider.future);

  await ref.read(localizationProvider.notifier).setCurrentLocal();
}
