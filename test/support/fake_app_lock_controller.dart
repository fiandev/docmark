import 'package:flutter_template/src/core/security/lock_controller.dart';

/// Deterministic [AppLockController] for router and settings tests.
class FakeAppLockController implements AppLockController {
  FakeAppLockController({
    LockStatus initialStatus = LockStatus.disabled,
    this.pin = '1234',
    this.biometricsSucceed = true,
  }) : _status = initialStatus;

  /// The PIN that unlocks this fake.
  String pin;

  /// Whether [unlockWithBiometrics] succeeds.
  bool biometricsSucceed;

  LockStatus _status;
  int failedAttempts = 0;

  @override
  LockPolicy get policy => const LockPolicy();

  @override
  Future<LockStatus> status() async => _status;

  @override
  Future<void> enable({String? pin}) async {
    if (pin != null) this.pin = pin;
    _status = LockStatus.unlocked;
  }

  @override
  Future<void> disable({required String pin}) async {
    _status = LockStatus.disabled;
  }

  @override
  Future<bool> unlockWithPin(String pin) async {
    if (pin == this.pin) {
      _status = LockStatus.unlocked;
      failedAttempts = 0;

      return true;
    }
    failedAttempts += 1;

    return false;
  }

  @override
  Future<bool> unlockWithBiometrics() async {
    if (!biometricsSucceed) return false;
    _status = LockStatus.unlocked;

    return true;
  }

  @override
  Future<void> lock() async {
    if (_status != LockStatus.disabled) _status = LockStatus.locked;
  }
}
