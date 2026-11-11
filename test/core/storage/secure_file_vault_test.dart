import 'dart:io';
import 'dart:typed_data';

import 'package:docmark/src/core/security/encryption_service.dart';
import 'package:docmark/src/core/security/key_manager.dart';
import 'package:docmark/src/core/security/secure_file_vault.dart';
import 'package:docmark/src/core/security/src/aes_gcm_encryption_service.dart';
import 'package:docmark/src/core/storage/vault/secure_file_vault_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late SecureFileVaultImpl vault;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('docmark_vault_test');
    vault = SecureFileVaultImpl(
      encryption: AesGcmEncryptionService(),
      keyManager: _StaticKeyManager(),
      rootDirectory: () async => root,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('SecureFileVaultImpl', () {
    test('put stores ciphertext and read returns plaintext', () async {
      final plaintext = ascii('docmark-secret-payload');
      final reference = await vault.put(
        bytes: plaintext,
        extension: 'png',
      );

      expect(reference.relativePath, endsWith('.png'));
      expect(await vault.exists(reference), isTrue);
      expect(await vault.read(reference), plaintext);

      final stored = await File(
        p.join(root.path, reference.relativePath),
      ).readAsBytes();
      expect(stored.length, greaterThan(plaintext.length));
      expect(
        String.fromCharCodes(stored).contains('docmark-secret-payload'),
        isFalse,
      );
    });

    test('uses a unique data key per file', () async {
      final plaintext = ascii('same bytes in, different keys out');

      final first = await vault.put(bytes: plaintext, extension: 'png');
      final second = await vault.put(bytes: plaintext, extension: 'png');

      expect(first.id, isNot(second.id));
      final firstKey = await vault.wrappedKeyBase64(first);
      final secondKey = await vault.wrappedKeyBase64(second);
      expect(firstKey, isNotNull);
      expect(secondKey, isNotNull);
      expect(firstKey, isNot(secondKey));

      final firstBytes = await File(
        p.join(root.path, first.relativePath),
      ).readAsBytes();
      final secondBytes = await File(
        p.join(root.path, second.relativePath),
      ).readAsBytes();
      expect(firstBytes, isNot(secondBytes));
    });

    test('keeps a caller-supplied asset id', () async {
      final reference = await vault.put(
        bytes: ascii('preset asset'),
        extension: 'png',
        assetId: 'asset-42',
      );

      expect(reference.id, 'asset-42');
      expect(reference.relativePath, 'asset-42.png');
    });

    test('erasing an asset leaves no file behind', () async {
      final reference = await vault.put(
        bytes: ascii('erase me'),
        extension: 'jpg',
      );

      await vault.delete(reference);

      expect(await vault.exists(reference), isFalse);
      expect(
        await File(p.join(root.path, reference.relativePath)).exists(),
        isFalse,
      );
    });

    test('deleting an absent asset succeeds', () async {
      const reference = AssetRef(id: 'missing', relativePath: 'missing.png');

      await expectLater(vault.delete(reference), completes);
    });

    test('rejects a tampered blob', () async {
      final reference = await vault.put(
        bytes: ascii('tamper target'),
        extension: 'png',
      );
      final file = File(p.join(root.path, reference.relativePath));
      final bytes = await file.readAsBytes();
      bytes[bytes.length - 1] ^= 0xFF;
      await file.writeAsBytes(bytes, flush: true);

      await expectLater(
        vault.read(reference),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a truncated blob', () async {
      final reference = await vault.put(
        bytes: ascii('truncate target'),
        extension: 'png',
      );
      final file = File(p.join(root.path, reference.relativePath));
      final bytes = await file.readAsBytes();
      await file.writeAsBytes(bytes.sublist(0, 10), flush: true);

      await expectLater(vault.read(reference), throwsFormatException);
    });

    test('refuses a path outside the root', () async {
      const reference = AssetRef(id: 'x', relativePath: '../escape.bin');

      await expectLater(
        vault.read(reference),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deleteAll removes every blob', () async {
      await vault.put(bytes: ascii('one'), extension: 'png');
      await vault.put(bytes: ascii('two'), extension: 'pdf');

      await vault.deleteAll();

      final remaining = <File>[];
      await for (final entity in root.list(recursive: true)) {
        if (entity is File) remaining.add(entity);
      }
      expect(remaining, isEmpty);
    });
  });
}

Uint8List ascii(String value) => Uint8List.fromList(value.codeUnits);

final class _StaticKeyManager implements KeyManager {
  final AesKey _key = AesKey(
    Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
  );

  @override
  Future<AesKey> createOrGetKek() async => _key;
}
