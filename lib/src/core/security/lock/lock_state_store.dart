import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the single encrypted App Lock blob.
///
/// The interface is deliberately tiny: one opaque string in, one opaque
/// string out. It sits in front of `flutter_secure_storage` so the
/// controller is unit-testable without platform channels.
abstract interface class LockStateStore {
  Future<String?> read();

  Future<void> write(String blob);

  Future<void> clear();
}

/// The production store: the platform keystore/keychain via
/// `flutter_secure_storage`.
final class SecureStorageLockStateStore implements LockStateStore {
  const SecureStorageLockStateStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  /// Versioned so a future format change can be migrated, not guessed at.
  static const String storageKey = 'docmark.app_lock.state.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<void> write(String blob) =>
      _storage.write(key: storageKey, value: blob);

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}
