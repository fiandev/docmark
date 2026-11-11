import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_template/src/core/base/base.dart';
import 'package:flutter_template/src/core/security/encryption_service.dart';
import 'package:flutter_template/src/core/security/key_manager.dart';
import 'package:flutter_template/src/core/security/lock/app_lock_failure.dart';
import 'package:flutter_template/src/core/security/lock/biometric_authenticator.dart';
import 'package:flutter_template/src/core/security/lock/lock_controller_impl.dart';
import 'package:flutter_template/src/core/security/lock/lock_state_store.dart';
import 'package:flutter_template/src/core/security/lock/pin_verifier.dart';

/// Fast-enough PBKDF2 for state-machine tests. The shipped default is
/// asserted separately in `pin_verifier_test.dart`.
const int testIterations = 1000;

/// In-memory stand-in for `flutter_secure_storage`.
final class MemoryLockStateStore implements LockStateStore {
  MemoryLockStateStore([this.value]);

  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String blob) async {
    value = blob;
    writes += 1;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

final class FakeKeyManager implements KeyManager {
  FakeKeyManager([Uint8List? key])
    : _key = key ?? Uint8List.fromList(List<int>.generate(32, (i) => i));

  final Uint8List _key;

  @override
  Future<AesKey> createOrGetKek() async => AesKey(_key);
}

/// Real AES-GCM (from `cryptography`) behind the interface, so the
/// controller's envelope round-trips without a platform channel.
final class TestEncryptionService implements EncryptionService {
  final AesGcm _cipher = AesGcm.with256bits();

  @override
  AesKey generateDataKey() =>
      AesKey(Uint8List.fromList(List<int>.generate(32, (i) => i + 1)));

  @override
  Future<EncryptedPayload> encrypt({
    required Uint8List plaintext,
    required AesKey key,
  }) async {
    final box = await _cipher.encrypt(
      plaintext,
      secretKey: SecretKey(key.bytes),
    );

    return EncryptedPayload(
      ciphertext: Uint8List.fromList(box.cipherText),
      nonce: Uint8List.fromList(box.nonce),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  @override
  Future<Uint8List> decrypt({
    required EncryptedPayload payload,
    required AesKey key,
  }) async {
    final clear = await _cipher.decrypt(
      SecretBox(
        payload.ciphertext,
        nonce: payload.nonce,
        mac: Mac(payload.mac),
      ),
      secretKey: SecretKey(key.bytes),
    );

    return Uint8List.fromList(clear);
  }

  @override
  Future<WrappedKey> wrapKey({
    required AesKey keyEncryptionKey,
    required AesKey dataKey,
  }) async {
    final box = await _cipher.encrypt(
      dataKey.bytes,
      secretKey: SecretKey(keyEncryptionKey.bytes),
    );

    return WrappedKey(
      ciphertext: Uint8List.fromList(box.cipherText),
      nonce: Uint8List.fromList(box.nonce),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  @override
  Future<AesKey> unwrapKey({
    required AesKey keyEncryptionKey,
    required WrappedKey wrapped,
  }) async {
    final clear = await _cipher.decrypt(
      SecretBox(
        wrapped.ciphertext,
        nonce: wrapped.nonce,
        mac: Mac(wrapped.mac),
      ),
      secretKey: SecretKey(keyEncryptionKey.bytes),
    );

    return AesKey(Uint8List.fromList(clear));
  }
}

final class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({this.available = true, this.succeeds = true});

  bool available;
  bool succeeds;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts += 1;

    return available && succeeds;
  }
}

/// A movable wall clock, so grace periods and backoff need no real waiting.
final class TestClock {
  TestClock([DateTime? start]) : now = start ?? DateTime.utc(2026);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

LockControllerImpl buildController({
  MemoryLockStateStore? store,
  FakeKeyManager? keyManager,
  FakeBiometricAuthenticator? biometrics,
  TestClock? clock,
}) {
  final testClock = clock ?? TestClock();

  return LockControllerImpl(
    keyManager: keyManager ?? FakeKeyManager(),
    encryptionService: TestEncryptionService(),
    store: store ?? MemoryLockStateStore(),
    biometrics: biometrics ?? FakeBiometricAuthenticator(),
    pinVerifier: const PinVerifier(iterations: testIterations),
    now: testClock.call,
  );
}

T? successValue<T, E>(Result<T, E> result) => switch (result) {
  Success(:final data) => data,
  Error() => null,
};

AppLockFailure? failureOf<T>(Result<T, AppLockFailure> result) =>
    switch (result) {
      Success() => null,
      Error(:final error) => error,
    };
