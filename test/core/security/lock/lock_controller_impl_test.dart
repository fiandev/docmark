import 'package:flutter_template/src/core/base/base.dart';
import 'package:flutter_template/src/core/security/lock/app_lock_failure.dart';
import 'package:flutter_template/src/core/security/lock/app_lock_service.dart';
import 'package:flutter_template/src/core/security/lock/lock_controller_impl.dart';
import 'package:flutter_template/src/core/security/lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_lock_fakes.dart';

const String _pin = '123456';
const String _otherPin = '654321';
const String _wrongPin = '000000';

void main() {
  group('LockControllerImpl', () {
    late MemoryLockStateStore store;
    late FakeBiometricAuthenticator biometrics;
    late TestClock clock;
    late LockControllerImpl controller;

    setUp(() {
      store = MemoryLockStateStore();
      biometrics = FakeBiometricAuthenticator();
      clock = TestClock();
      controller = buildController(
        store: store,
        biometrics: biometrics,
        clock: clock,
      );
    });

    test('settles on disabled when no blob is stored', () async {
      expect(controller.state.status, LockStatus.locked);

      await controller.initialize();

      expect(controller.state.status, LockStatus.disabled);
      expect(await controller.status(), LockStatus.disabled);
      expect(store.value, isNull);
    });

    test('enable seals one blob and unlocks the session', () async {
      await controller.initialize();

      final result = await controller.enableLock(pin: _pin);

      expect(result, isA<Success<Unit, AppLockFailure>>());
      expect(controller.state.status, LockStatus.unlocked);
      expect(controller.state.isEnabled, isTrue);
      expect(store.value, isNotNull);
      expect(store.value, isNot(contains(_pin)));
      expect(store.value, contains('"v"'));
    });

    test('a PIN with the wrong digit count is rejected', () async {
      final failure = failureOf(await controller.enableLock(pin: '1234'));

      expect(failure, isA<AppLockInvalidPinFormat>());
      expect(controller.state.isEnabled, isFalse);
    });

    test('a cold start is locked; the PIN unlocks', () async {
      await controller.enableLock(pin: _pin);

      final restarted = buildController(
        store: store,
        biometrics: biometrics,
        clock: clock,
      );
      await restarted.initialize();

      expect(restarted.state.status, LockStatus.locked);
      expect(successValue(await restarted.verifyPin(_pin)), isTrue);
      expect(restarted.state.status, LockStatus.unlocked);
    });

    test('an unreadable blob fails closed', () async {
      store.value = '{"v":1,"c":"AA==","n":"AA==","m":"AA=="}';

      await controller.initialize();

      expect(controller.state.status, LockStatus.locked);
    });

    test('a wrong PIN is counted and does not unlock', () async {
      await controller.enableLock(pin: _pin);
      await controller.lock();

      final failure = failureOf(await controller.verifyPin(_wrongPin));

      expect(failure, isA<AppLockWrongPin>());
      expect((failure! as AppLockWrongPin).attemptsRemaining, 4);
      expect(controller.state.failedAttempts, 1);
      expect(controller.state.status, LockStatus.locked);
    });

    test('misses double the cooldown from one second', () async {
      await controller.enableLock(pin: _pin);

      final maxAttempts = AppLockDefaults.maxPinAttempts;

      for (var attempt = 1; attempt < maxAttempts; attempt++) {
        final failure = failureOf(await controller.verifyPin(_wrongPin));

        expect(failure, isA<AppLockWrongPin>());
        expect(
          (failure! as AppLockWrongPin).attemptsRemaining,
          maxAttempts - attempt,
        );
      }

      final fifth = failureOf(await controller.verifyPin(_wrongPin));

      expect(fifth, isA<AppLockLockedOut>());
      expect(
        (fifth! as AppLockLockedOut).remaining,
        AppLockDefaults.initialBackoff,
      );

      clock.advance(AppLockDefaults.initialBackoff);

      final sixth = failureOf(await controller.verifyPin(_wrongPin));

      expect(sixth, isA<AppLockLockedOut>());
      expect(
        (sixth! as AppLockLockedOut).remaining,
        const Duration(seconds: 2),
      );
    });

    test('attempts during a cooldown are rejected without counting', () async {
      await controller.enableLock(pin: _pin);

      final maxAttempts = AppLockDefaults.maxPinAttempts;

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        await controller.verifyPin(_wrongPin);
      }
      final attempts = controller.state.failedAttempts;

      final failure = failureOf(await controller.verifyPin(_wrongPin));

      expect(failure, isA<AppLockLockedOut>());
      expect(controller.state.failedAttempts, attempts);
    });

    test('the correct PIN unlocks and clears the failure counter', () async {
      await controller.enableLock(pin: _pin);
      await controller.verifyPin(_wrongPin);

      expect(successValue(await controller.verifyPin(_pin)), isTrue);
      expect(controller.state.failedAttempts, 0);
      expect(controller.state.status, LockStatus.unlocked);
    });

    test('changePin rejects a wrong current PIN', () async {
      await controller.enableLock(pin: _pin);

      final failure = failureOf(
        await controller.changePin(currentPin: _wrongPin, newPin: _otherPin),
      );

      expect(failure, isA<AppLockWrongPin>());
    });

    test('changePin replaces the verifier', () async {
      await controller.enableLock(pin: _pin);

      final changed = await controller.changePin(
        currentPin: _pin,
        newPin: _otherPin,
      );
      expect(changed, isA<Success<Unit, AppLockFailure>>());

      await controller.lock();

      expect(successValue(await controller.verifyPin(_pin)), isFalse);
      expect(successValue(await controller.verifyPin(_otherPin)), isTrue);
    });

    test('disable requires the PIN and clears the blob', () async {
      await controller.enableLock(pin: _pin);

      final rejected = await controller.disableLock(_wrongPin);

      expect(failureOf(rejected), isA<AppLockWrongPin>());
      expect(controller.state.status, LockStatus.unlocked);

      final disabled = await controller.disableLock(_pin);

      expect(disabled, isA<Success<Unit, AppLockFailure>>());
      expect(controller.state.status, LockStatus.disabled);
      expect(controller.state.isEnabled, isFalse);
      expect(store.value, isNull);
    });

    test('a short background stay keeps the session', () async {
      await controller.enableLock(pin: _pin);

      controller.onBackground();
      clock.advance(const Duration(seconds: 10));
      await controller.onForeground();

      expect(controller.state.status, LockStatus.unlocked);
    });

    test('a background stay beyond the grace period locks the app', () async {
      await controller.enableLock(pin: _pin);

      controller.onBackground();
      clock.advance(const Duration(seconds: 31));
      await controller.onForeground();

      expect(controller.state.status, LockStatus.locked);
    });

    test('a zero grace period locks on resume', () async {
      await controller.enableLock(
        pin: _pin,
        policy: const LockPolicy(gracePeriod: Duration.zero, pinLength: 6),
      );

      controller.onBackground();
      clock.advance(const Duration(seconds: 1));
      await controller.onForeground();

      expect(controller.state.status, LockStatus.locked);
    });

    test('biometrics unlock only when enabled and enrolled', () async {
      await controller.enableLock(pin: _pin);

      expect(
        failureOf(await controller.verifyBiometrics(reason: 'test')),
        isA<AppLockBiometricsUnavailable>(),
      );

      await controller.enableLock(pin: _pin, biometricsEnabled: true);
      await controller.lock();

      expect(
        successValue(await controller.verifyBiometrics(reason: 'test')),
        isTrue,
      );
      expect(controller.state.status, LockStatus.unlocked);
      expect(biometrics.prompts, 1);
    });

    test('a dismissed biometric prompt leaves the PIN as the way in', () async {
      biometrics.succeeds = false;
      await controller.enableLock(pin: _pin, biometricsEnabled: true);
      await controller.lock();

      expect(
        successValue(await controller.verifyBiometrics(reason: 'test')),
        isFalse,
      );
      expect(controller.state.status, LockStatus.locked);
      expect(successValue(await controller.verifyPin(_pin)), isTrue);
    });

    test('enabling biometrics without enrollment fails', () async {
      biometrics.available = false;

      final failure = failureOf(
        await controller.enableLock(pin: _pin, biometricsEnabled: true),
      );

      expect(failure, isA<AppLockBiometricsUnavailable>());
      expect(controller.state.isEnabled, isFalse);
    });

    test('updateSettings persists policy and biometrics', () async {
      await controller.enableLock(pin: _pin);

      final updated = await controller.updateSettings(
        policy: const LockPolicy(
          gracePeriod: Duration(seconds: 300),
          pinLength: 6,
        ),
        biometricsEnabled: true,
      );

      expect(updated, isA<Success<Unit, AppLockFailure>>());
      expect(controller.state.policy.gracePeriod, const Duration(seconds: 300));
      expect(controller.state.biometricsEnabled, isTrue);

      final restarted = buildController(
        store: store,
        biometrics: biometrics,
        clock: clock,
      );
      await restarted.initialize();

      expect(restarted.state.policy.gracePeriod, const Duration(seconds: 300));
      expect(restarted.state.biometricsEnabled, isTrue);
    });

    test('transitions are published on the changes stream', () async {
      final statuses = <LockStatus>[];
      final subscription = controller.changes.listen(
        (state) => statuses.add(state.status),
      );
      addTearDown(subscription.cancel);

      await controller.initialize();
      await controller.enableLock(pin: _pin);
      await controller.lock();

      expect(statuses, [
        LockStatus.disabled,
        LockStatus.unlocked,
        LockStatus.locked,
      ]);
    });

    test('the frozen API throws AppLockException', () async {
      await controller.initialize();

      await expectLater(
        controller.enable(),
        throwsA(isA<AppLockException>()),
      );
      await expectLater(
        controller.disable(pin: _pin),
        throwsA(isA<AppLockException>()),
      );
    });

    test('unlockWithPin reports false instead of throwing', () async {
      await controller.enableLock(pin: _pin);
      await controller.lock();

      expect(await controller.unlockWithPin(_wrongPin), isFalse);
      expect(await controller.unlockWithPin(_pin), isTrue);
    });
  });
}
