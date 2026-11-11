import 'dart:typed_data';

/// A reference to one encrypted asset inside the app-private vault.
///
/// The vault owns the physical layout; callers only carry this handle. It
/// is safe to persist: it names an encrypted blob, never plaintext and
/// never an absolute external path.
final class AssetRef {
  const AssetRef({required this.id, required this.relativePath});

  final String id;

  /// Path relative to the vault root. Never absolute — a moved app
  /// container must not invalidate stored references.
  final String relativePath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'relativePath': relativePath,
  };

  static AssetRef fromJson(Map<String, dynamic> json) {
    return AssetRef(
      id: json['id'] as String,
      relativePath: json['relativePath'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssetRef &&
        other.id == id &&
        other.relativePath == relativePath;
  }

  @override
  int get hashCode => Object.hash(id, relativePath);

  @override
  String toString() => 'AssetRef($id)';
}

/// The only door to encrypted bytes on disk.
///
/// Implementations envelope-encrypt on write and decrypt on read, so a
/// caller never touches plaintext files. Reads return bytes in memory for
/// the shortest possible lifetime; callers must not write them to a new
/// plaintext file.
abstract interface class SecureFileVault {
  /// Encrypts [bytes] into a new asset. Pass [assetId] when the id is part
  /// of the caller's contract (a preset references it); leave it null to
  /// let the vault generate one.
  Future<AssetRef> put({
    required Uint8List bytes,
    required String extension,
    String? assetId,
  });

  Future<Uint8List> read(AssetRef ref);

  Future<bool> exists(AssetRef ref);

  /// Deletes one asset. Deleting an absent asset succeeds.
  Future<void> delete(AssetRef ref);

  /// Deletes every asset in the vault — the "clear all user data" path.
  Future<void> deleteAll();
}
