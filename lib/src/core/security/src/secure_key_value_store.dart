/// The narrow slice of a platform secure store that [KeyManagerImpl] uses.
///
/// Scoping the dependency this way keeps the key manager testable on a
/// plain Dart VM (the real store needs a device) without weakening the
/// production path: `flutter_secure_storage` is backed by the Android
/// Keystore and the iOS Keychain.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}
