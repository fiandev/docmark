import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'encryption_service.dart';
import 'key_manager.dart';
import 'src/failures.dart';
import 'src/secure_key_value_store.dart';

/// The key-encryption key, created once and kept in the platform keystore.
///
/// The KEK is a 32-byte random value stored base64-encoded through
/// [SecureKeyValueStore]. On a device that store is the Android Keystore
/// or the iOS Keychain, so the key never exists as a plaintext file. The
/// first call generates it, later calls read it back unchanged, and the
/// in-flight future is memoized so two concurrent callers cannot race into
/// creating two different keys.
final class KeyManagerImpl implements KeyManager {
  KeyManagerImpl({
    required SecureKeyValueStore store,
    this.storageKey = defaultStorageKey,
    Random? random,
  }) : _store = store,
       _random = random ?? Random.secure();

  /// Stable storage slot. Bump the suffix only for a deliberate rotation,
  /// which also has to re-wrap every existing data key.
  static const String defaultStorageKey = 'docmark.kek.v1';

  static const int keyLengthBytes = 32;

  final SecureKeyValueStore _store;
  final String storageKey;
  final Random _random;

  Future<AesKey>? _pending;

  @override
  Future<AesKey> createOrGetKek() async {
    final pending = _pending;
    if (pending != null) return pending;

    final future = _loadOrCreate();
    _pending = future;
    try {
      return await future;
    } catch (_) {
      // A failed read must not poison every later call. The next attempt
      // re-reads the store, which recovers from a transient platform error.
      _pending = null;
      rethrow;
    }
  }

  Future<AesKey> _loadOrCreate() async {
    final stored = await _store.read(storageKey);
    if (stored != null && stored.isNotEmpty) {
      final Uint8List bytes;
      try {
        bytes = base64Decode(stored);
      } on FormatException catch (error) {
        throw EncryptionFailure('Stored KEK is not base64', cause: error);
      }
      if (bytes.length != keyLengthBytes) {
        throw const KeyMaterialFailure('Stored KEK is not 256 bits');
      }

      return AesKey(bytes);
    }

    final bytes = Uint8List(keyLengthBytes);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    await _store.write(storageKey, base64Encode(bytes));

    return AesKey(bytes);
  }
}
