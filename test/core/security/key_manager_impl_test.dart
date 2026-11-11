import 'dart:convert';

import 'package:docmark/src/core/security/key_manager_impl.dart';
import 'package:docmark/src/core/security/src/secure_key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyManagerImpl', () {
    test('creates a 256-bit key on first use', () async {
      final store = InMemorySecureKeyValueStore();
      final manager = KeyManagerImpl(store: store);

      final key = await manager.createOrGetKek();

      expect(key.bytes, hasLength(32));
      expect(store.values, contains(KeyManagerImpl.defaultStorageKey));
    });

    test('returns the same key on later calls', () async {
      final store = InMemorySecureKeyValueStore();
      final manager = KeyManagerImpl(store: store);

      final first = await manager.createOrGetKek();
      final second = await manager.createOrGetKek();

      expect(second.bytes, first.bytes);
      expect(store.values, hasLength(1));
    });

    test('reads the key back from a new instance', () async {
      final store = InMemorySecureKeyValueStore();
      final first = await KeyManagerImpl(store: store).createOrGetKek();
      final second = await KeyManagerImpl(store: store).createOrGetKek();

      expect(second.bytes, first.bytes);
    });

    test('stores base64, never a raw byte list', () async {
      final store = InMemorySecureKeyValueStore();
      final manager = KeyManagerImpl(store: store);

      final key = await manager.createOrGetKek();
      final stored = store.values[KeyManagerImpl.defaultStorageKey];

      expect(stored, isNotNull);
      expect(base64Decode(stored!), key.bytes);
    });

    test('concurrent callers share one key', () async {
      final store = InMemorySecureKeyValueStore();
      final manager = KeyManagerImpl(store: store);

      final keys = await Future.wait([
        manager.createOrGetKek(),
        manager.createOrGetKek(),
        manager.createOrGetKek(),
      ]);

      expect(keys[0].bytes, keys[1].bytes);
      expect(keys[1].bytes, keys[2].bytes);
      expect(store.values, hasLength(1));
    });
  });
}

final class InMemorySecureKeyValueStore implements SecureKeyValueStore {
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
