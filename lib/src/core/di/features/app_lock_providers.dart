/// OWNER: T10 (app lock).
///
/// DI seam between the router gate, App Lock, and the bootstrap lifecycle
/// hook. The gate reads `appLockStatusProvider` and nothing else.
library;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../security/app_lifecycle_observer.dart';
import '../../security/lock/app_lock_service.dart';
import '../../security/lock/biometric_authenticator.dart';
import '../../security/lock/lock_controller_impl.dart';
import '../../security/lock/lock_state_store.dart';
import '../../security/lock_controller.dart';
import 'security_providers.dart';

export '../../security/app_lifecycle_observer.dart';

part 'app_lock_providers.g.dart';

/// The encrypted-blob store; overridden in tests with an in-memory fake.
@Riverpod(keepAlive: true)
LockStateStore lockStateStore(Ref ref) => const SecureStorageLockStateStore();

/// The platform biometric prompt; overridden in tests with a fake.
@Riverpod(keepAlive: true)
BiometricAuthenticator biometricAuthenticator(Ref ref) =>
    LocalAuthBiometricAuthenticator();

/// The state machine. Reading it starts the one persisted-state read, so
/// the lifecycle observer and the gate share a single initialization.
@Riverpod(keepAlive: true)
AppLockService appLockService(Ref ref) {
  final service = LockControllerImpl(
    keyManager: ref.watch(keyManagerProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    store: ref.watch(lockStateStoreProvider),
    biometrics: ref.watch(biometricAuthenticatorProvider),
  );
  unawaited(service.initialize());

  return service;
}

/// The frozen controller surface. Kept for callers that only need the
/// interface, including the settings feature's future wiring.
@Riverpod(keepAlive: true)
AppLockController appLockController(Ref ref) =>
    ref.watch(appLockServiceProvider);

/// The gate input. Synchronous on purpose: the gate must decide a
/// destination in one frame, so the controller publishes a status rather
/// than an `AsyncValue`.
///
/// The subscription is what makes this reactive without the router reading
/// the controller: a transition invalidates this provider, and the router's
/// `refreshListenable` follows.
@Riverpod(keepAlive: true)
LockStatus appLockStatus(Ref ref) {
  final service = ref.watch(appLockServiceProvider);
  final subscription = service.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(subscription.cancel);

  return service.state.status;
}

/// The full snapshot the lock and setup screens render.
@Riverpod(keepAlive: true)
AppLockState appLockState(Ref ref) {
  final service = ref.watch(appLockServiceProvider);
  final subscription = service.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(subscription.cancel);

  return service.state;
}

/// The bootstrap hook that re-locks after the grace period.
@Riverpod(keepAlive: true)
AppLifecycleObserver appLifecycleObserver(Ref ref) =>
    LockLifecycleObserver(service: ref.watch(appLockServiceProvider));
