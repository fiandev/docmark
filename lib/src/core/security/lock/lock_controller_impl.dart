import 'dart:async';

import '../../base/base.dart';
import '../../logger/log.dart';
import '../encryption_service.dart';
import '../key_manager.dart';
import '../lock_controller.dart';
import 'app_lock_failure.dart';
import 'app_lock_service.dart';
import 'biometric_authenticator.dart';
import 'lock_state.dart';
import 'lock_state_store.dart';
import 'pin_verifier.dart';

/// The App Lock state machine.
///
/// Security rules this class owns:
///
/// - The persisted state is one AES-GCM blob under the KEK; only the salt,
///   verifier, policy, and biometrics flag live inside it. No PIN, verifier,
///   or key is ever written in the clear, and none is logged.
/// - A cold start with a blob present is [LockStatus.locked]; there is no
///   path from process start to the document tree that skips the gate.
/// - The status starts locked before storage answers (fail closed) and only
///   settles on disabled when storage confirms there is no blob.
/// - A failed state read is not cached: initialize() retries on the next
///   call, so a transient keystore failure cannot pin the lock screen until
///   the process is killed.
/// - Misses double the cooldown from one second after the policy's
///   `maxPinAttempts`; during a cooldown neither PIN nor biometrics unlock.
///   The counter and deadline are persisted in the blob, so a restart keeps
///   the backoff instead of granting a fresh budget.
final class LockControllerImpl implements AppLockService {
  LockControllerImpl({
    required KeyManager keyManager,
    required EncryptionService encryptionService,
    required LockStateStore store,
    required BiometricAuthenticator biometrics,
    PinVerifier pinVerifier = const PinVerifier(),
    DateTime Function()? now,
  }) : _keyManager = keyManager,
       _encryption = encryptionService,
       _store = store,
       _biometrics = biometrics,
       _pinVerifier = pinVerifier,
       _now = now ?? DateTime.now;

  final KeyManager _keyManager;
  final EncryptionService _encryption;
  final LockStateStore _store;
  final BiometricAuthenticator _biometrics;
  final PinVerifier _pinVerifier;
  final DateTime Function() _now;

  final StreamController<AppLockState> _changes =
      StreamController<AppLockState>.broadcast(sync: true);

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  AppLockState _state = AppLockState.initial();
  Future<void>? _initialization;
  DateTime? _backgroundedAt;
  bool _promptInFlight = false;

  @override
  AppLockState get state => _state;

  @override
  Stream<AppLockState> get changes => _changes.stream;

  @override
  LockPolicy get policy => _state.policy;

  @override
  Future<LockStatus> status() async {
    await initialize();

    return _state.status;
  }

  @override
  Future<void> initialize() {
    final pending = _initialization;
    if (pending != null) return pending;

    final loading = _load();
    _initialization = loading;

    return loading;
  }

  Future<void> _load() async {
    try {
      final raw = await _store.read();
      if (raw == null) {
        _emit(_state.copyWith(status: LockStatus.disabled));
        return;
      }

      final kek = await _keyManager.createOrGetKek();
      final plaintext = await _encryption.decrypt(
        payload: LockBlob.decode(raw).payload,
        key: kek,
      );
      final secret = LockSecret.fromBytes(plaintext);
      final normalized = secret.copyWith(policy: _normalized(secret.policy));

      _emit(
        _state.copyWith(
          status: LockStatus.locked,
          secret: normalized,
          failedAttempts: normalized.failedAttempts,
          lockedUntil: normalized.lockedUntil,
          clearLockedUntil: normalized.lockedUntil == null,
        ),
      );
    } catch (error) {
      // Fail closed: an unreadable blob must never open the app. Only the
      // error type is logged — the blob and key material stay out of logs.
      Log.error('App Lock: state could not be read (${error.runtimeType})');
      // Do not cache the failed attempt: the keystore may simply be busy.
      // A later initialize() (router retry, settings open) tries again.
      _initialization = null;
      _emit(_state.copyWith(status: LockStatus.locked));
    }
  }

  @override
  Future<void> enable({String? pin}) async {
    _throwOnError(await enableLock(pin: pin));
  }

  @override
  Future<void> disable({required String pin}) async {
    _throwOnError(await disableLock(pin));
  }

  @override
  Future<bool> unlockWithPin(String pin) async =>
      _boolValue(await verifyPin(pin));

  @override
  Future<bool> unlockWithBiometrics() async => _boolValue(
    await verifyBiometrics(reason: AppLockDefaults.biometricReason),
  );

  @override
  Future<void> lock() async {
    await initialize();

    if (_state.secret == null || _state.status == LockStatus.locked) return;

    _emit(_state.copyWith(status: LockStatus.locked));
  }

  @override
  Future<Result<Unit, AppLockFailure>> enableLock({
    String? pin,
    bool? biometricsEnabled,
    LockPolicy? policy,
  }) async {
    await initialize();

    final current = _state.secret;
    final requested = policy ?? current?.policy ?? AppLockDefaults.policy;
    final effectivePolicy = _normalized(requested);
    final withBiometrics =
        biometricsEnabled ??
        (pin == null || (current?.biometricsEnabled ?? false));

    if (pin == null) {
      if (current == null) return const Error(AppLockPinRequired());

      if (withBiometrics && !await _biometrics.isAvailable()) {
        return const Error(AppLockBiometricsUnavailable());
      }

      return _save(
        current.copyWith(
          policy: effectivePolicy,
          biometricsEnabled: withBiometrics,
        ),
        status: LockStatus.unlocked,
      );
    }

    if (!_isWellFormed(pin, effectivePolicy.pinLength)) {
      return Error(
        AppLockInvalidPinFormat(expectedLength: effectivePolicy.pinLength),
      );
    }

    if (withBiometrics && !await _biometrics.isAvailable()) {
      return const Error(AppLockBiometricsUnavailable());
    }

    final salt = _pinVerifier.newSalt();
    final verifier = await _pinVerifier.derive(pin, salt);
    final secret = LockSecret(
      salt: salt,
      verifier: verifier,
      iterations: _pinVerifier.iterations,
      policy: effectivePolicy,
      biometricsEnabled: withBiometrics,
    );

    return _save(secret, status: LockStatus.unlocked);
  }

  @override
  Future<Result<bool, AppLockFailure>> verifyPin(String pin) async {
    await initialize();

    final secret = _state.secret;
    if (secret == null) return const Error(AppLockNotEnabled());

    final remaining = _state.backoffRemaining(now: _now());
    if (remaining > Duration.zero) {
      return Error(AppLockLockedOut(remaining: remaining));
    }

    if (!_isWellFormed(pin, secret.policy.pinLength)) {
      return Error(await _recordMiss(secret));
    }

    final verifier = PinVerifier(iterations: secret.iterations);
    final candidate = await verifier.derive(pin, secret.salt);

    if (!PinVerifier.constantTimeEquals(candidate, secret.verifier)) {
      return Error(await _recordMiss(secret));
    }

    final cleared = secret.copyWith(
      failedAttempts: 0,
      clearLockedUntil: true,
    );
    _emit(
      _state.copyWith(
        status: LockStatus.unlocked,
        secret: cleared,
        failedAttempts: 0,
        clearLockedUntil: true,
      ),
    );
    await _persistSecret(cleared);

    return const Success(true);
  }

  @override
  Future<Result<bool, AppLockFailure>> verifyBiometrics({
    required String reason,
  }) async {
    await initialize();

    final secret = _state.secret;
    if (secret == null) return const Error(AppLockNotEnabled());

    if (!secret.biometricsEnabled) {
      return const Error(AppLockBiometricsUnavailable());
    }

    final remaining = _state.backoffRemaining(now: _now());
    if (remaining > Duration.zero) {
      return Error(AppLockLockedOut(remaining: remaining));
    }

    if (!await _biometrics.isAvailable()) {
      return const Error(AppLockBiometricsUnavailable());
    }

    // The platform prompt may pause the activity; the observer must not
    // interpret that pause as the user leaving the app.
    _promptInFlight = true;
    try {
      final unlocked = await _biometrics.authenticate(reason: reason);
      if (!unlocked) return const Success(false);
    } finally {
      _promptInFlight = false;
    }

    final cleared = secret.copyWith(
      failedAttempts: 0,
      clearLockedUntil: true,
    );
    _emit(
      _state.copyWith(
        status: LockStatus.unlocked,
        secret: cleared,
        failedAttempts: 0,
        clearLockedUntil: true,
      ),
    );
    await _persistSecret(cleared);

    return const Success(true);
  }

  @override
  Future<Result<Unit, AppLockFailure>> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    await initialize();

    final secret = _state.secret;
    if (secret == null) return const Error(AppLockNotEnabled());

    final remaining = _state.backoffRemaining(now: _now());
    if (remaining > Duration.zero) {
      return Error(AppLockLockedOut(remaining: remaining));
    }

    if (!_isWellFormed(newPin, secret.policy.pinLength)) {
      return Error(
        AppLockInvalidPinFormat(expectedLength: secret.policy.pinLength),
      );
    }

    if (!await _matches(secret, currentPin)) {
      return Error(await _recordMiss(secret));
    }

    final salt = _pinVerifier.newSalt();
    final verifier = await _pinVerifier.derive(newPin, salt);
    final updated = LockSecret(
      salt: salt,
      verifier: verifier,
      iterations: _pinVerifier.iterations,
      policy: secret.policy,
      biometricsEnabled: secret.biometricsEnabled,
    );

    return _save(updated, status: _state.status);
  }

  @override
  Future<Result<Unit, AppLockFailure>> disableLock(String pin) async {
    await initialize();

    final secret = _state.secret;
    if (secret == null) return const Error(AppLockNotEnabled());

    final remaining = _state.backoffRemaining(now: _now());
    if (remaining > Duration.zero) {
      return Error(AppLockLockedOut(remaining: remaining));
    }

    if (!await _matches(secret, pin)) {
      return Error(await _recordMiss(secret));
    }

    try {
      await _store.clear();
    } catch (error, stackTrace) {
      return Error(AppLockStorageFailure(cause: error, stackTrace: stackTrace));
    }

    _emit(
      _state.copyWith(
        status: LockStatus.disabled,
        clearSecret: true,
        failedAttempts: 0,
        clearLockedUntil: true,
      ),
    );

    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit, AppLockFailure>> resetLockData({
    bool confirmed = false,
  }) async {
    // Deliberately explicit: a caller cannot wipe the lock by accident.
    if (!confirmed) return const Error(AppLockResetNotConfirmed());

    try {
      await _store.clear();
    } catch (error, stackTrace) {
      // Fail closed: the blob is still there, so the app stays locked.
      return Error(AppLockStorageFailure(cause: error, stackTrace: stackTrace));
    }

    // Nothing is left to read, and the cached (possibly failed) load must
    // not be reused. Documents in the vault and database are untouched.
    _initialization = Future<void>.value();
    _emit(
      const AppLockState(
        status: LockStatus.disabled,
        secret: null,
        failedAttempts: 0,
        lockedUntil: null,
      ),
    );

    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit, AppLockFailure>> updateSettings({
    LockPolicy? policy,
    bool? biometricsEnabled,
  }) async {
    await initialize();

    final secret = _state.secret;
    if (secret == null) return const Error(AppLockNotEnabled());

    if (biometricsEnabled == true && !await _biometrics.isAvailable()) {
      return const Error(AppLockBiometricsUnavailable());
    }

    return _save(
      secret.copyWith(
        policy: policy == null ? null : _normalized(policy),
        biometricsEnabled: biometricsEnabled,
      ),
      status: _state.status,
    );
  }

  @override
  void onBackground() {
    if (_promptInFlight) return;

    _backgroundedAt = _now();
  }

  @override
  Future<void> onForeground() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;

    if (since == null || _promptInFlight) return;

    await initialize();

    if (_state.status != LockStatus.unlocked) return;

    final secret = _state.secret;
    if (secret == null) return;

    if (_now().difference(since) > secret.policy.gracePeriod) {
      await lock();
    }
  }

  Future<Result<Unit, AppLockFailure>> _save(
    LockSecret secret, {
    required LockStatus status,
  }) async {
    // A full save is an explicit state change: start from a clean backoff.
    final stored = secret.copyWith(
      failedAttempts: 0,
      clearLockedUntil: true,
    );
    try {
      final kek = await _keyManager.createOrGetKek();
      final payload = await _encryption.encrypt(
        plaintext: stored.toBytes(),
        key: kek,
      );
      await _store.write(LockBlob.fromPayload(payload).encode());
    } catch (error, stackTrace) {
      return Error(AppLockStorageFailure(cause: error, stackTrace: stackTrace));
    }

    _emit(
      _state.copyWith(
        secret: stored,
        status: status,
        failedAttempts: 0,
        clearLockedUntil: true,
      ),
    );

    return const Success(Unit.value);
  }

  Future<bool> _matches(LockSecret secret, String pin) async {
    if (!_isWellFormed(pin, secret.policy.pinLength)) return false;

    final candidate = await PinVerifier(
      iterations: secret.iterations,
    ).derive(pin, secret.salt);

    return PinVerifier.constantTimeEquals(candidate, secret.verifier);
  }

  Future<AppLockFailure> _recordMiss(LockSecret secret) async {
    final attempts = _state.failedAttempts + 1;
    final maxAttempts = secret.policy.maxPinAttempts;

    if (attempts < maxAttempts) {
      final updated = secret.copyWith(
        failedAttempts: attempts,
        clearLockedUntil: true,
      );
      _emit(
        _state.copyWith(
          secret: updated,
          failedAttempts: attempts,
          clearLockedUntil: true,
        ),
      );
      await _persistSecret(updated);

      return AppLockWrongPin(attemptsRemaining: maxAttempts - attempts);
    }

    final delay = _backoffDelay(attempts - maxAttempts);
    final until = _now().add(delay);
    final updated = secret.copyWith(
      failedAttempts: attempts,
      lockedUntil: until,
    );
    _emit(
      _state.copyWith(
        secret: updated,
        failedAttempts: attempts,
        lockedUntil: until,
      ),
    );
    await _persistSecret(updated);

    return AppLockLockedOut(remaining: delay);
  }

  /// Re-seals [secret] so the attempt counter and deadline survive a
  /// restart. Best-effort: if secure storage rejects the write, the
  /// in-memory pacing still applies for this session and the app stays
  /// locked. Losing durability is preferable to reporting a wrong PIN.
  Future<void> _persistSecret(LockSecret secret) async {
    try {
      final kek = await _keyManager.createOrGetKek();
      final payload = await _encryption.encrypt(
        plaintext: secret.toBytes(),
        key: kek,
      );
      await _store.write(LockBlob.fromPayload(payload).encode());
    } catch (error) {
      Log.warning(
        'App Lock: backoff could not be persisted (${error.runtimeType})',
      );
    }
  }

  /// One second after the threshold, doubling per extra miss, capped so the
  /// lockout never reads as a frozen app.
  Duration _backoffDelay(int over) {
    final shift = over < 16 ? over : 16;
    final seconds = AppLockDefaults.initialBackoff.inSeconds * (1 << shift);

    if (seconds >= AppLockDefaults.maxBackoff.inSeconds) {
      return AppLockDefaults.maxBackoff;
    }

    return Duration(seconds: seconds);
  }

  /// Product rule: the PIN is six digits, whatever policy a caller builds.
  /// A `LockPolicy`'s other fields stay caller-controlled.
  static LockPolicy _normalized(LockPolicy policy) => LockPolicy(
    gracePeriod: policy.gracePeriod,
    maxPinAttempts: policy.maxPinAttempts,
    pinLength: AppLockDefaults.pinLength,
  );

  static bool _isWellFormed(String pin, int length) =>
      pin.length == length && _digitsOnly.hasMatch(pin);

  void _emit(AppLockState next) {
    _state = next;
    _changes.add(next);
  }

  bool _boolValue(Result<bool, AppLockFailure> result) => switch (result) {
    Success(:final data) => data,
    Error() => false,
  };

  void _throwOnError(Result<Unit, AppLockFailure> result) {
    switch (result) {
      case Success():
        return;
      case Error(:final error):
        throw AppLockException(error);
    }
  }
}
