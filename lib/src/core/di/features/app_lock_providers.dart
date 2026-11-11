/// OWNER: T10 (app lock).
///
/// Frozen DI seam between the router gate and App Lock. The gate reads
/// `appLockStatusProvider` and nothing else; T10 replaces the placeholder
/// controller with the PIN + biometric implementation and keeps the
/// status provider's name and return type.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../security/lock_controller.dart';

part 'app_lock_providers.g.dart';

/// Registers the lifecycle hooks that re-lock the app after the grace
/// period. `bootstrap()` calls `register()` once.
abstract interface class AppLifecycleObserver {
  void register();
}

/// The bootstrap placeholder: hooks nothing and cannot fail.
final class NoopAppLifecycleObserver implements AppLifecycleObserver {
  const NoopAppLifecycleObserver();

  @override
  void register() {}
}

/// The App Lock controller before T10 lands: always disabled.
final class DisabledAppLockController implements AppLockController {
  const DisabledAppLockController();

  @override
  LockPolicy get policy => const LockPolicy();

  @override
  Future<LockStatus> status() async => LockStatus.disabled;

  @override
  Future<void> enable({String? pin}) async {}

  @override
  Future<void> disable({required String pin}) async {}

  @override
  Future<bool> unlockWithPin(String pin) async => false;

  @override
  Future<bool> unlockWithBiometrics() async => false;

  @override
  Future<void> lock() async {}
}

/// The gate input. Synchronous on purpose: the gate must decide a
/// destination in one frame, so the controller publishes a status rather
/// than an `AsyncValue`.
@Riverpod(keepAlive: true)
LockStatus appLockStatus(Ref ref) => LockStatus.disabled;

@Riverpod(keepAlive: true)
AppLockController appLockController(Ref ref) =>
    const DisabledAppLockController();

@Riverpod(keepAlive: true)
AppLifecycleObserver appLifecycleObserver(Ref ref) =>
    const NoopAppLifecycleObserver();
