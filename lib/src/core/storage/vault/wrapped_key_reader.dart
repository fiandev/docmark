import '../../security/secure_file_vault.dart';

/// Reads the KEK-wrapped data key that the vault stores inside a blob.
///
/// The bytes live in the blob header, which is where the vault needs them
/// to decrypt. The database keeps a base64 mirror purely as metadata, so
/// the mapping has to be asked of the vault rather than recomputed by a
/// caller that does not know the layout.
abstract interface class WrappedKeyReader {
  /// Base64 of the wrapped block, or null when the blob is absent.
  Future<String?> wrappedKeyBase64(AssetRef ref);
}
