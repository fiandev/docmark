import 'dart:typed_data';

/// A 256-bit AES key. Wrapped in a type so a raw `Uint8List` cannot be
/// passed where a key is expected by accident.
final class AesKey {
  AesKey(this.bytes);

  final Uint8List bytes;

  @override
  String toString() => 'AesKey(${bytes.length} bytes)';
}

/// A data key encrypted under the key-encryption key (envelope encryption).
///
/// Persisted as three base64 fields by the storage layer; the plaintext
/// data key never reaches storage.
final class WrappedKey {
  const WrappedKey({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List mac;

  @override
  String toString() => 'WrappedKey(${ciphertext.length} bytes)';
}

/// AES-256-GCM output: the nonce is stored beside the ciphertext, and the
/// authentication tag travels as [mac].
final class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List mac;
}

/// Envelope encryption for files and database blobs.
///
/// The contract is deliberately byte-in/byte-out: implementations may use
/// `cryptography` (AES-GCM) or a platform keystore-backed equivalent, and
/// callers stay unaware. Every operation that can fail throws rather than
/// returning a partially decrypted buffer.
abstract interface class EncryptionService {
  /// Generates a fresh data key from a cryptographically secure source.
  AesKey generateDataKey();

  Future<EncryptedPayload> encrypt({
    required Uint8List plaintext,
    required AesKey key,
  });

  Future<Uint8List> decrypt({
    required EncryptedPayload payload,
    required AesKey key,
  });

  Future<WrappedKey> wrapKey({
    required AesKey keyEncryptionKey,
    required AesKey dataKey,
  });

  Future<AesKey> unwrapKey({
    required AesKey keyEncryptionKey,
    required WrappedKey wrapped,
  });
}
