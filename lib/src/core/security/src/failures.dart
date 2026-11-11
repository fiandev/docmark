/// Failures raised by the security primitives.
///
/// They implement [Exception], not [Error], so a repository guard treats
/// them as recoverable data problems instead of programmer bugs. The
/// messages never carry key material or plaintext.
final class EncryptionFailure implements Exception {
  const EncryptionFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'EncryptionFailure: $message';
}

/// The caller handed in a key, nonce, or wrapped key of the wrong length.
final class KeyMaterialFailure implements Exception {
  const KeyMaterialFailure(this.message);

  final String message;

  @override
  String toString() => 'KeyMaterialFailure: $message';
}
