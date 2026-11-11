import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_template/src/core/base/base.dart';
import 'package:flutter_template/src/core/security/lock/app_lock_failure.dart';
import 'package:flutter_template/src/core/security/lock/app_lock_service.dart';
import 'package:flutter_template/src/core/security/lock/lock_state.dart';
import 'package:flutter_template/src/core/security/lock_controller.dart';
import 'package:flutter_template/src/core/security/secure_file_vault.dart';
import 'package:flutter_template/src/domain/entities/history.dart';
import 'package:flutter_template/src/domain/failures/business_failure.dart';
import 'package:flutter_template/src/domain/repositories/history_repository.dart';

/// An in-memory [AppLockService] that records every settings-triggered call.
final class FakeAppLockService implements AppLockService {
  FakeAppLockService({
    LockPolicy policy = const LockPolicy(pinLength: 6),
    bool enabled = false,
    String? initialPin,
  }) : _policy = policy {
    pin = initialPin;
    if (enabled) {
      pin ??= '123456';
      _state = AppLockState(
        status: LockStatus.unlocked,
        secret: _secret(),
        failedAttempts: 0,
        lockedUntil: null,
      );
    } else {
      _state = AppLockState.initial().copyWith(status: LockStatus.disabled);
    }
  }

  final StreamController<AppLockState> _changes =
      StreamController<AppLockState>.broadcast(sync: true);

  late AppLockState _state;
  LockPolicy _policy;

  String? pin;
  int enableCalls = 0;
  int disableCalls = 0;
  int changePinCalls = 0;
  int updateSettingsCalls = 0;
  Duration? lastGrace;
  AppLockFailure? failNext;

  @override
  AppLockState get state => _state;

  @override
  Stream<AppLockState> get changes => _changes.stream;

  @override
  LockPolicy get policy => _state.policy;

  @override
  Future<LockStatus> status() async => _state.status;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> enable({String? pin}) async {
    await enableLock(pin: pin);
  }

  @override
  Future<void> disable({required String pin}) async {
    await disableLock(pin);
  }

  @override
  Future<bool> unlockWithPin(String pin) async => pin == this.pin;

  @override
  Future<bool> unlockWithBiometrics() async => true;

  @override
  Future<void> lock() async {
    if (_state.isEnabled) {
      _emit(_state.copyWith(status: LockStatus.locked));
    }
  }

  @override
  Future<Result<Unit, AppLockFailure>> enableLock({
    String? pin,
    bool? biometricsEnabled,
    LockPolicy? policy,
  }) async {
    enableCalls += 1;

    final failed = _takeFailure();
    if (failed != null) return Error(failed);

    if (pin != null && pin.length != _policy.pinLength) {
      return Error(AppLockInvalidPinFormat(expectedLength: _policy.pinLength));
    }

    this.pin = pin ?? this.pin;

    _emit(
      AppLockState(
        status: LockStatus.unlocked,
        secret: _secret(),
        failedAttempts: 0,
        lockedUntil: null,
      ),
    );

    return const Success(Unit.value);
  }

  @override
  Future<Result<bool, AppLockFailure>> verifyPin(String pin) async {
    if (!_state.isEnabled) return const Error(AppLockNotEnabled());
    if (pin != this.pin) {
      return const Error(AppLockWrongPin(attemptsRemaining: 4));
    }

    return const Success(true);
  }

  @override
  Future<Result<bool, AppLockFailure>> verifyBiometrics({
    required String reason,
  }) async {
    if (!_state.isEnabled) return const Error(AppLockNotEnabled());

    return const Success(true);
  }

  @override
  Future<Result<Unit, AppLockFailure>> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    changePinCalls += 1;

    final failed = _takeFailure();
    if (failed != null) return Error(failed);

    if (newPin.length != _policy.pinLength) {
      return Error(AppLockInvalidPinFormat(expectedLength: _policy.pinLength));
    }

    if (currentPin != pin) {
      return const Error(AppLockWrongPin(attemptsRemaining: 4));
    }

    pin = newPin;

    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit, AppLockFailure>> disableLock(String pin) async {
    disableCalls += 1;

    final failed = _takeFailure();
    if (failed != null) return Error(failed);

    if (pin != this.pin) {
      return const Error(AppLockWrongPin(attemptsRemaining: 4));
    }

    _emit(
      _state.copyWith(status: LockStatus.disabled, clearSecret: true),
    );

    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit, AppLockFailure>> updateSettings({
    LockPolicy? policy,
    bool? biometricsEnabled,
  }) async {
    updateSettingsCalls += 1;
    lastGrace = policy?.gracePeriod;

    if (policy != null) {
      _policy = policy;
      final secret = _state.secret;
      if (secret != null) {
        _emit(_state.copyWith(secret: secret.copyWith(policy: policy)));
      }
    }

    if (biometricsEnabled != null) {
      final secret = _state.secret;
      if (secret != null) {
        _emit(
          _state.copyWith(
            secret: secret.copyWith(biometricsEnabled: biometricsEnabled),
          ),
        );
      }
    }

    return const Success(Unit.value);
  }

  @override
  void onBackground() {}

  @override
  Future<void> onForeground() async {}

  AppLockFailure? _takeFailure() {
    final failure = failNext;
    failNext = null;

    return failure;
  }

  LockSecret _secret() {
    return LockSecret(
      salt: Uint8List.fromList([1, 2, 3, 4]),
      verifier: Uint8List.fromList([5, 6, 7, 8]),
      iterations: 1000,
      policy: _policy,
      biometricsEnabled: false,
    );
  }

  void _emit(AppLockState next) {
    _state = next;
    _changes.add(next);
  }
}

/// An in-memory [HistoryRepository] that records destructive calls.
final class FakeHistoryRepository implements HistoryRepository {
  FakeHistoryRepository({List<HistoryEntryEntity>? entries})
    : entries = entries ?? [];

  List<HistoryEntryEntity> entries;
  int clearCalls = 0;
  int deleteCalls = 0;
  bool failClear = false;

  @override
  Future<Result<List<HistoryEntryEntity>, BusinessFailure>> list() async {
    return Success(entries);
  }

  @override
  Future<Result<AssetRef, BusinessFailure>> previewRef(String entryId) async {
    return Success(AssetRef(id: entryId, relativePath: '$entryId.png'));
  }

  @override
  Future<Result<HistoryEntryEntity, BusinessFailure>> record(
    HistoryEntryEntity entry,
  ) async {
    entries = [entry, ...entries];

    return Success(entry);
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String entryId) async {
    deleteCalls += 1;
    entries = entries.where((entry) => entry.id != entryId).toList();

    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit, BusinessFailure>> clear() async {
    clearCalls += 1;
    if (failClear) {
      return const Error(BusinessFailure.unexpected());
    }

    entries = [];

    return const Success(Unit.value);
  }
}
