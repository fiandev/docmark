import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../encryption_service.dart';
import 'failures.dart';

/// AES-256-GCM envelope encryption backed by `package:cryptography`.
///
/// The data key is a plain 32-byte random value. It is always used through
/// [AesKey] wrappers so a buffer cannot be passed where a key belongs by
/// accident. Every encryption gets a fresh nonce from the algorithm; the
/// authentication tag is returned separately as [EncryptedPayload.mac] and
/// the vault stores it after the ciphertext.
final class AesGcmEncryptionService implements EncryptionService {
  AesGcmEncryptionService({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  /// AES-256 key size.
  static const int keyLengthBytes = 32;

  /// GCM authentication tag size.
  static const int macLengthBytes = 16;

  final AesGcm _algorithm;
  final Random _random = Random.secure();

  @override
  AesKey generateDataKey() {
    final bytes = Uint8List(keyLengthBytes);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }

    return AesKey(bytes);
  }

  @override
  Future<EncryptedPayload> encrypt({
    required Uint8List plaintext,
    required AesKey key,
  }) async {
    _requireKeyLength(key);
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKeyData(key.bytes),
      nonce: nonce,
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
    _requireKeyLength(key);
    if (payload.nonce.isEmpty ||
        payload.mac.length != macLengthBytes ||
        payload.nonce.length != _algorithm.nonceLength) {
      throw const EncryptionFailure('Malformed authenticated payload');
    }

    try {
      final clear = await _algorithm.decrypt(
        SecretBox(
          payload.ciphertext,
          nonce: payload.nonce,
          mac: Mac(payload.mac),
        ),
        secretKey: SecretKeyData(key.bytes),
      );

      return Uint8List.fromList(clear);
    } catch (error) {
      // A wrong key and a tampered ciphertext both surface here: GCM cannot
      // tell them apart, which is exactly the property that makes it safe.
      throw EncryptionFailure('Authentication failed', cause: error);
    }
  }

  @override
  Future<WrappedKey> wrapKey({
    required AesKey keyEncryptionKey,
    required AesKey dataKey,
  }) async {
    _requireKeyLength(dataKey);
    final sealed = await encrypt(
      plaintext: dataKey.bytes,
      key: keyEncryptionKey,
    );

    return WrappedKey(
      ciphertext: sealed.ciphertext,
      nonce: sealed.nonce,
      mac: sealed.mac,
    );
  }

  @override
  Future<AesKey> unwrapKey({
    required AesKey keyEncryptionKey,
    required WrappedKey wrapped,
  }) async {
    final clear = await decrypt(
      payload: EncryptedPayload(
        ciphertext: wrapped.ciphertext,
        nonce: wrapped.nonce,
        mac: wrapped.mac,
      ),
      key: keyEncryptionKey,
    );
    if (clear.length != keyLengthBytes) {
      throw const KeyMaterialFailure('Wrapped data key is not 256 bits');
    }

    return AesKey(clear);
  }

  void _requireKeyLength(AesKey key) {
    if (key.bytes.length != keyLengthBytes) {
      throw const KeyMaterialFailure('AES-256 needs a 32-byte key');
    }
  }
}
