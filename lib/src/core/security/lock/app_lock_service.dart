import '../../base/base.dart';
import '../lock_controller.dart';
import 'app_lock_failure.dart';
import 'lock_state.dart';

/// App Lock's defaults. The PIN length is fixed at six digits: long enough
/// to survive shoulder-surfing, short enough to type from memory.
abstract final class AppLockDefaults {
  static const int pinLength = 6;
  static const int maxPinAttempts = 5;
  static const Duration gracePeriod = Duration(seconds: 30);

  /// First cooldown after [maxPinAttempts] misses; doubles from there.
  static const Duration initialBackoff = Duration(seconds: 1);

  /// Upper bound so a long-running session cannot produce an hour-long
  /// lockout, which would read as a broken app.
  static const Duration maxBackoff = Duration(minutes: 5);

  /// The choices the settings UI offers for "lock after leaving the app".
  static const List<Duration> graceOptions = [
    Duration.zero,
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 300),
  ];

  static const LockPolicy policy = LockPolicy(
    gracePeriod: gracePeriod,
    maxPinAttempts: maxPinAttempts,
    pinLength: pinLength,
  );

  /// Fallback prompt copy for the frozen no-argument `unlockWithBiometrics`
  /// API. Feature code should pass the localized reason to
  /// [AppLockService.verifyBiometrics] instead.
  static const String biometricReason = 'Unlock DocMark';
}

/// One immutable snapshot of App Lock, for the UI and the router gate.
final class AppLockState {
  const AppLockState({
    required this.status,
    required this.secret,
    required this.failedAttempts,
    required this.lockedUntil,
  });

  /// Fail closed: until the persisted state is read, nothing is reachable.
  /// A cold start with App Lock enabled therefore begins locked, and a
  /// first run settles on [LockStatus.disabled] once storage answers.
  factory AppLockState.initial() => const AppLockState(
    status: LockStatus.locked,
    secret: null,
    failedAttempts: 0,
    lockedUntil: null,
  );

  final LockStatus status;

  /// Null exactly when App Lock was never enabled, or was disabled.
  final LockSecret? secret;

  /// Consecutive misses. Persisted with the lock blob, so restarting the
  /// app does not reset the backoff.
  final int failedAttempts;

  /// When the backoff expires; null when no cooldown is active. Persisted
  /// alongside [failedAttempts].
  final DateTime? lockedUntil;

  bool get isEnabled => secret != null;

  bool get biometricsEnabled => secret?.biometricsEnabled ?? false;

  LockPolicy get policy => secret?.policy ?? AppLockDefaults.policy;

  bool get isLocked => status == LockStatus.locked;

  /// Remaining cooldown at [now] (defaults to the wall clock).
  Duration backoffRemaining({DateTime? now}) {
    final until = lockedUntil;
    if (until == null) return Duration.zero;

    final remaining = until.difference(now ?? DateTime.now());

    return remaining.isNegative ? Duration.zero : remaining;
  }

  AppLockState copyWith({
    LockStatus? status,
    LockSecret? secret,
    bool clearSecret = false,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) {
    return AppLockState(
      status: status ?? this.status,
      secret: clearSecret ? null : secret ?? this.secret,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLockedUntil ? null : lockedUntil ?? this.lockedUntil,
    );
  }
}

/// App Lock's full API.
///
/// Extends the frozen [AppLockController] the router and tests already know.
/// The extra methods carry what the frozen interface cannot: a `Result`
/// channel for failures, the reactive [changes] stream the UI renders, and
/// the lifecycle hooks the bootstrap observer calls.
abstract interface class AppLockService implements AppLockController {
  /// The latest snapshot, available synchronously for first frame renders.
  AppLockState get state;

  /// Emits after every successful state transition. Synchronous broadcast:
  /// a status change is visible to the router in the same turn.
  Stream<AppLockState> get changes;

  /// Reads the persisted blob once. Safe to call repeatedly; every call
  /// after the first shares the same future.
  Future<void> initialize();

  /// Turns App Lock on with [pin], or — when [pin] is null — keeps the
  /// existing PIN and only toggles biometrics.
  Future<Result<Unit, AppLockFailure>> enableLock({
    String? pin,
    bool? biometricsEnabled,
    LockPolicy? policy,
  });

  /// Verifies [pin], applying backoff on a miss. Success unlocks.
  Future<Result<bool, AppLockFailure>> verifyPin(String pin);

  /// Shows the biometric prompt and unlocks on success.
  Future<Result<bool, AppLockFailure>> verifyBiometrics({
    required String reason,
  });

  /// Replaces the PIN. Requires [currentPin] to match and [newPin] to have
  /// the policy's digit count.
  Future<Result<Unit, AppLockFailure>> changePin({
    required String currentPin,
    required String newPin,
  });

  /// Turns App Lock off. Requires [pin] so a passer-by cannot disable it
  /// from an unlocked session.
  Future<Result<Unit, AppLockFailure>> disableLock(String pin);

  /// Deletes the persisted lock blob and lock state so a user who can no
  /// longer unlock can recover without losing documents. Refuses unless
  /// [confirmed] is true — the caller must show the confirmation first.
  ///
  /// On success the app settles on [LockStatus.disabled]; on a storage
  /// failure it stays locked (fail closed).
  Future<Result<Unit, AppLockFailure>> resetLockData({
    bool confirmed = false,
  });

  /// Updates the grace period and/or the biometrics flag without touching
  /// the verifier.
  Future<Result<Unit, AppLockFailure>> updateSettings({
    LockPolicy? policy,
    bool? biometricsEnabled,
  });

  /// Records the moment the app left the foreground.
  void onBackground();

  /// Re-locks when the background stay exceeded the policy's grace period.
  Future<void> onForeground();
}
