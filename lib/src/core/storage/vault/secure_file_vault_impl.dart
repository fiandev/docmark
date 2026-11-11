import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../security/encryption_service.dart';
import '../../security/key_manager.dart';
import '../../security/secure_file_vault.dart';
import 'failures.dart';
import 'vault_envelope.dart';
import 'wrapped_key_reader.dart';

/// Envelope-encrypted blob store under a private application directory.
///
/// Each asset is one file: a fixed header holding the KEK-wrapped data key
/// followed by `nonce || ciphertext || mac`. Writes go to a staging file
/// and are renamed into place, so a crash mid-write cannot leave a blob
/// that looks complete but decrypts to garbage.
///
/// The root is resolved lazily because `path_provider` is async while the
/// DI provider that owns this object is synchronous, and because tests
/// point it at a temp directory.
final class SecureFileVaultImpl implements SecureFileVault, WrappedKeyReader {
  SecureFileVaultImpl({
    required EncryptionService encryption,
    required KeyManager keyManager,
    required Future<Directory> Function() rootDirectory,
    this.stagingDirectoryName = '.staging',
    Uuid uuid = const Uuid(),
  }) : _encryption = encryption,
       _keyManager = keyManager,
       _rootDirectory = rootDirectory,
       _uuid = uuid;

  final EncryptionService _encryption;
  final KeyManager _keyManager;
  final Future<Directory> Function() _rootDirectory;
  final Uuid _uuid;

  /// Subdirectory used for atomic writes. It stays inside the vault root,
  /// so the startup sweep can clear abandoned parts without a second path.
  final String stagingDirectoryName;

  Future<Directory>? _rootPending;

  @override
  Future<AssetRef> put({
    required Uint8List bytes,
    required String extension,
    String? assetId,
  }) async {
    final id = _requireSafeId(assetId ?? _uuid.v4());
    final safeExtension = _sanitizeExtension(extension);
    final fileName = '$id.$safeExtension';
    final target = await _fileFor(fileName);
    final root = await _root();
    await target.parent.create(recursive: true);

    final dataKey = _encryption.generateDataKey();
    final payload = await _encryption.encrypt(
      plaintext: bytes,
      key: dataKey,
    );
    final wrappedKey = await _encryption.wrapKey(
      keyEncryptionKey: await _keyManager.createOrGetKek(),
      dataKey: dataKey,
    );
    final blob = encodeVaultEnvelope(
      VaultEnvelope(wrappedKey: wrappedKey, payload: payload),
    );

    final stagingDirectory = Directory(
      p.join(root.path, stagingDirectoryName),
    );
    await stagingDirectory.create(recursive: true);
    final stagingFile = File(p.join(stagingDirectory.path, '$fileName.part'));
    try {
      await stagingFile.writeAsBytes(blob, flush: true);
      await stagingFile.rename(target.path);
    } catch (_) {
      await _deleteIfPresent(stagingFile);
      rethrow;
    }

    return AssetRef(id: id, relativePath: fileName);
  }

  @override
  Future<Uint8List> read(AssetRef ref) async {
    final file = await _fileFor(ref.relativePath);
    if (!await file.exists()) throw MissingAssetFailure(ref.id);
    final envelope = decodeVaultEnvelope(await file.readAsBytes());

    return _decrypt(envelope);
  }

  @override
  Future<bool> exists(AssetRef ref) async {
    final file = await _fileFor(ref.relativePath);

    return file.exists();
  }

  @override
  Future<void> delete(AssetRef ref) async {
    final file = await _fileFor(ref.relativePath);
    await _deleteIfPresent(file);
  }

  @override
  Future<void> deleteAll() async {
    final root = await _root();
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      await _deleteEntity(entity);
    }
  }

  @override
  Future<String?> wrappedKeyBase64(AssetRef ref) async {
    final file = await _fileFor(ref.relativePath);
    if (!await file.exists()) return null;
    final envelope = decodeVaultEnvelope(await file.readAsBytes());

    return wrappedKeyBase64Of(envelope.wrappedKey);
  }

  Future<Uint8List> _decrypt(VaultEnvelope envelope) async {
    final dataKey = await _encryption.unwrapKey(
      keyEncryptionKey: await _keyManager.createOrGetKek(),
      wrapped: envelope.wrappedKey,
    );

    return _encryption.decrypt(payload: envelope.payload, key: dataKey);
  }

  Future<Directory> _root() {
    return _rootPending ??= () async {
      final directory = await _rootDirectory();
      await directory.create(recursive: true);

      return directory;
    }();
  }

  Future<File> _fileFor(String relativePath) async {
    final root = await _root();
    final normalized = p.normalize(relativePath);
    final resolved = p.join(root.path, normalized);
    if (p.isAbsolute(normalized) || !p.isWithin(root.path, resolved)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Points outside the vault root',
      );
    }

    return File(resolved);
  }

  String _requireSafeId(String id) {
    if (id.isEmpty ||
        id.contains('/') ||
        id.contains(r'\') ||
        id.contains('..')) {
      throw ArgumentError.value(id, 'assetId', 'Unsafe asset identifier');
    }

    return id;
  }

  String _sanitizeExtension(String extension) {
    final cleaned = extension.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    if (cleaned.isEmpty) return 'bin';

    return cleaned.toLowerCase().substring(0, min(cleaned.length, 8));
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    if (entity is Directory) {
      await entity.delete(recursive: true);
    } else {
      await entity.delete();
    }
  }
}
