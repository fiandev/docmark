import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_key_value_store.dart';

/// [SecureKeyValueStore] over `flutter_secure_storage`.
///
/// The plugin's defaults are the ones we want: Android Keystore-backed
/// encryption on Android and the app Keychain on iOS. No options are
/// passed, so a future plugin default change applies here once instead of
/// being overridden by a stale configuration.
final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
