import 'dart:convert';
import 'dart:io';

import 'package:docmark/src/core/security/key_manager_impl.dart';
import 'package:docmark/src/core/security/src/aes_gcm_encryption_service.dart';
import 'package:docmark/src/core/security/src/secure_key_value_store.dart';
import 'package:docmark/src/core/storage/db/app_database.dart';
import 'package:docmark/src/core/storage/db/database_key_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late _MemoryKeyValueStore store;
  late AesGcmEncryptionService encryption;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('docmark_db_test');
    store = _MemoryKeyValueStore();
    encryption = AesGcmEncryptionService();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('DatabaseKeyStore', () {
    test('creates one key and reuses it across instances', () async {
      final file = File(p.join(root.path, 'docmark.key'));
      final firstKey = await DatabaseKeyStore(
        encryption: encryption,
        keyManager: KeyManagerImpl(store: store),
        keyFile: file,
      ).loadOrCreate();
      final secondKey = await DatabaseKeyStore(
        encryption: encryption,
        keyManager: KeyManagerImpl(store: store),
        keyFile: file,
      ).loadOrCreate();

      expect(secondKey.bytes, firstKey.bytes);
      expect(await file.exists(), isTrue);
    });

    test('stores only the wrapped form', () async {
      final file = File(p.join(root.path, 'docmark.key'));
      final key = await DatabaseKeyStore(
        encryption: encryption,
        keyManager: KeyManagerImpl(store: store),
        keyFile: file,
      ).loadOrCreate();

      final stored = await file.readAsString();
      final json = jsonDecode(stored) as Map<String, dynamic>;

      expect(json.keys, containsAll(['ciphertext', 'nonce', 'mac']));
      expect(stored.contains(base64Encode(key.bytes)), isFalse);
    });

    test('fails loudly on a corrupt key file', () async {
      final file = File(p.join(root.path, 'docmark.key'))
        ..writeAsStringSync('not json');

      await expectLater(
        DatabaseKeyStore(
          encryption: encryption,
          keyManager: KeyManagerImpl(store: store),
          keyFile: file,
        ).loadOrCreate(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('createAppDatabase', () {
    test('opens, persists, and reopens with the same key', () async {
      final directory = Directory(p.join(root.path, 'database'));
      KeyManagerImpl manager() => KeyManagerImpl(store: store);

      final database = createAppDatabase(
        directory: () async => directory,
        keyManager: manager(),
        encryption: encryption,
      );
      await database.into(database.appMeta).insert(
        const AppMetaRow(key: 'schema', value: '1'),
      );
      await database.close();

      final keyFile = File(p.join(directory.path, 'docmark.key'));
      final databaseFile = File(p.join(directory.path, 'docmark.sqlite'));
      expect(await keyFile.exists(), isTrue);
      expect(await databaseFile.exists(), isTrue);

      final reopened = createAppDatabase(
        directory: () async => directory,
        keyManager: manager(),
        encryption: encryption,
      );
      final rows = await reopened.select(reopened.appMeta).get();
      await reopened.close();

      expect(rows, hasLength(1));
      expect(rows.single.value, '1');
    });
  });
}

final class _MemoryKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
