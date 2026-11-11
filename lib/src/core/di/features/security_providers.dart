/// OWNER: T1 (security core).
///
/// Frozen DI contract for envelope encryption, the key manager, and the
/// secure file vault. T1 replaces the placeholder bodies with the real
/// implementations; the provider names and return types below are the
/// contract every other feature reads.
library;

import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../security/encryption_service.dart';
import '../../security/key_manager.dart';
import '../../security/secure_file_vault.dart';

part 'security_providers.g.dart';

/// The long-lived key-encryption key owner.
@Riverpod(keepAlive: true)
KeyManager keyManager(Ref ref) => const _UnavailableKeyManager();

/// AES-256-GCM envelope encryption.
@Riverpod(keepAlive: true)
EncryptionService encryptionService(Ref ref) =>
    const _UnavailableEncryptionService();

/// Encrypted-at-rest storage for documents and watermark images.
@Riverpod(keepAlive: true)
SecureFileVault secureFileVault(Ref ref) => const _UnavailableSecureFileVault();

class _UnavailableKeyManager implements KeyManager {
  const _UnavailableKeyManager();

  @override
  Future<AesKey> createOrGetKek() =>
      throw UnimplementedError('KeyManager is implemented by T1');
}

class _UnavailableEncryptionService implements EncryptionService {
  const _UnavailableEncryptionService();

  @override
  AesKey generateDataKey() =>
      throw UnimplementedError('EncryptionService is implemented by T1');

  @override
  Future<EncryptedPayload> encrypt({
    required Uint8List plaintext,
    required AesKey key,
  }) => throw UnimplementedError('EncryptionService is implemented by T1');

  @override
  Future<Uint8List> decrypt({
    required EncryptedPayload payload,
    required AesKey key,
  }) => throw UnimplementedError('EncryptionService is implemented by T1');

  @override
  Future<WrappedKey> wrapKey({
    required AesKey keyEncryptionKey,
    required AesKey dataKey,
  }) => throw UnimplementedError('EncryptionService is implemented by T1');

  @override
  Future<AesKey> unwrapKey({
    required AesKey keyEncryptionKey,
    required WrappedKey wrapped,
  }) => throw UnimplementedError('EncryptionService is implemented by T1');
}

class _UnavailableSecureFileVault implements SecureFileVault {
  const _UnavailableSecureFileVault();

  @override
  Future<AssetRef> put({
    required Uint8List bytes,
    required String extension,
    String? assetId,
  }) => throw UnimplementedError('SecureFileVault is implemented by T1');

  @override
  Future<Uint8List> read(AssetRef ref) =>
      throw UnimplementedError('SecureFileVault is implemented by T1');

  @override
  Future<bool> exists(AssetRef ref) =>
      throw UnimplementedError('SecureFileVault is implemented by T1');

  @override
  Future<void> delete(AssetRef ref) =>
      throw UnimplementedError('SecureFileVault is implemented by T1');

  @override
  Future<void> deleteAll() =>
      throw UnimplementedError('SecureFileVault is implemented by T1');
}
