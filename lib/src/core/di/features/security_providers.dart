/// OWNER: T1 (security core).
///
/// Envelope encryption, the key manager, and the secure file vault.
/// Provider names and return types are the frozen contract every other
/// feature reads.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../security/encryption_service.dart';
import '../../security/key_manager.dart';
import '../../security/key_manager_impl.dart';
import '../../security/secure_file_vault.dart';
import '../../security/src/aes_gcm_encryption_service.dart';
import '../../security/src/flutter_secure_key_value_store.dart';
import '../../storage/vault/secure_file_vault_impl.dart';

part 'security_providers.g.dart';

/// The long-lived key-encryption key owner.
@Riverpod(keepAlive: true)
KeyManager keyManager(Ref ref) =>
    KeyManagerImpl(store: FlutterSecureKeyValueStore());

/// AES-256-GCM envelope encryption.
@Riverpod(keepAlive: true)
EncryptionService encryptionService(Ref ref) => AesGcmEncryptionService();

/// Encrypted-at-rest storage for documents and watermark images.
@Riverpod(keepAlive: true)
SecureFileVault secureFileVault(Ref ref) => SecureFileVaultImpl(
  encryption: ref.watch(encryptionServiceProvider),
  keyManager: ref.watch(keyManagerProvider),
  rootDirectory: vaultDirectory,
);

/// Vault root inside private application storage.
///
/// `documents` is the app's own container on both platforms; nothing in
/// it is exposed to other apps, and the blobs are encrypted besides.
Future<Directory> vaultDirectory() async {
  final documents = await getApplicationDocumentsDirectory();

  return Directory(p.join(documents.path, 'docmark_vault'));
}
