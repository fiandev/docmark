import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/features/app_lock_providers.dart';
import '../../../../core/security/lock_controller.dart';
import '../../application_state/onboarding_status_provider/onboarding_status_provider.dart';
import '../../application_state/startup_provider/startup_provider.dart';
import '../routes.dart';

part 'router_state_provider.g.dart';

/// The destination the router enforces, derived from app startup,
/// onboarding, and App Lock state — one fold, in priority order:
///
/// 1. Startup pending or failed → splash (the route hosts the retry UI).
/// 2. Onboarding not completed → onboarding.
/// 3. App Lock locked → lock; disabled or unlocked → home.
///
/// The router reacts to this alone and never reads the inputs directly.
/// Pages that change an input invalidate the matching provider; the gate
/// follows. No timers, no imperative transitions.
@Riverpod(keepAlive: true)
Routes routerState(Ref ref) {
  final startup = ref.watch(startupProvider);
  if (startup.isLoading || startup.hasError) return .splash;

  if (!ref.watch(onboardingStatusProvider)) return .onboarding;

  return switch (ref.watch(appLockStatusProvider)) {
    LockStatus.locked => .lock,
    LockStatus.disabled || LockStatus.unlocked => .home,
  };
}
