import 'encryption_service.dart';

/// Owns the one long-lived key-encryption key (KEK).
///
/// The KEK lives in the Android Keystore / iOS Keychain through
/// `flutter_secure_storage`; it is created on first launch and returned
/// unchanged on every later call. Data keys are wrapped by it
/// (`EncryptionService.wrapKey`), so a lock-screen change or app restart
/// never leaves data undecryptable.
abstract interface class KeyManager {
  Future<AesKey> createOrGetKek();
}
