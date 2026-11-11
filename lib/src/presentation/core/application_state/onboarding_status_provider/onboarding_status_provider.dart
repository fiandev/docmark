import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/di/dependency_injection.dart';

part 'onboarding_status_provider.g.dart';

/// Whether the first-run onboarding has been completed.
///
/// `routerState` watches this after startup has resolved (preferences are
/// loaded by then). The onboarding page writes the flag and invalidates
/// this provider, which moves the gate forward — no imperative navigation.
@Riverpod(keepAlive: true)
bool onboardingStatus(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;

  return prefs.getBool(StorageKeys.onboardingCompleted) ?? false;
}
