import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_template/src/core/security/encryption_service.dart';
import 'package:flutter_template/src/core/security/src/aes_gcm_encryption_service.dart';
import 'package:flutter_template/src/core/security/src/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AesGcmEncryptionService service;

  setUp(() {
    service = AesGcmEncryptionService();
  });

  group('AesGcmEncryptionService', () {
    test('roundtrips a payload', () async {
      final key = service.generateDataKey();
      final plaintext = Uint8List.fromList(
        utf8.encode('quarterly report, page one'),
      );

      final payload = await service.encrypt(plaintext: plaintext, key: key);
      final clear = await service.decrypt(payload: payload, key: key);

      expect(clear, plaintext);
    });

    test('generates a fresh 256-bit data key on every call', () {
      final first = service.generateDataKey();
      final second = service.generateDataKey();

      expect(first.bytes, hasLength(32));
      expect(second.bytes, hasLength(32));
      expect(first.bytes, isNot(second.bytes));
    });

    test('uses a fresh nonce for every encryption', () async {
      final key = service.generateDataKey();
      final plaintext = Uint8List.fromList(const [1, 2, 3, 4]);

      final first = await service.encrypt(plaintext: plaintext, key: key);
      final second = await service.encrypt(plaintext: plaintext, key: key);

      expect(first.nonce, isNot(second.nonce));
      expect(first.ciphertext, isNot(second.ciphertext));
    });

    test('rejects a tampered ciphertext', () async {
      final key = service.generateDataKey();
      final payload = await service.encrypt(
        plaintext: Uint8List.fromList(const [9, 9, 9, 9]),
        key: key,
      );
      final tamperedCiphertext = Uint8List.fromList(payload.ciphertext);
      tamperedCiphertext[0] ^= 0xFF;

      await expectLater(
        service.decrypt(
          payload: EncryptedPayload(
            ciphertext: tamperedCiphertext,
            nonce: payload.nonce,
            mac: payload.mac,
          ),
          key: key,
        ),
        throwsA(isA<EncryptionFailure>()),
      );
    });

    test('rejects a tampered mac', () async {
      final key = service.generateDataKey();
      final payload = await service.encrypt(
        plaintext: Uint8List.fromList(const [7, 7, 7]),
        key: key,
      );
      final tamperedMac = Uint8List.fromList(payload.mac);
      tamperedMac[0] ^= 0x01;

      await expectLater(
        service.decrypt(
          payload: EncryptedPayload(
            ciphertext: payload.ciphertext,
            nonce: payload.nonce,
            mac: tamperedMac,
          ),
          key: key,
        ),
        throwsA(isA<EncryptionFailure>()),
      );
    });

    test('fails to decrypt with the wrong key', () async {
      final payload = await service.encrypt(
        plaintext: Uint8List.fromList(const [5, 5, 5]),
        key: service.generateDataKey(),
      );

      await expectLater(
        service.decrypt(payload: payload, key: service.generateDataKey()),
        throwsA(isA<EncryptionFailure>()),
      );
    });

    test('wraps and unwraps a data key', () async {
      final kek = service.generateDataKey();
      final dataKey = service.generateDataKey();

      final wrapped = await service.wrapKey(
        keyEncryptionKey: kek,
        dataKey: dataKey,
      );
      final unwrapped = await service.unwrapKey(
        keyEncryptionKey: kek,
        wrapped: wrapped,
      );

      expect(unwrapped.bytes, dataKey.bytes);
    });

    test('fails to unwrap with the wrong KEK', () async {
      final wrapped = await service.wrapKey(
        keyEncryptionKey: service.generateDataKey(),
        dataKey: service.generateDataKey(),
      );

      await expectLater(
        service.unwrapKey(
          keyEncryptionKey: service.generateDataKey(),
          wrapped: wrapped,
        ),
        throwsA(isA<EncryptionFailure>()),
      );
    });

    test('rejects a key that is not 256 bits', () async {
      final shortKey = AesKey(Uint8List.fromList(const [1, 2, 3]));

      await expectLater(
        service.encrypt(
          plaintext: Uint8List.fromList(const [1]),
          key: shortKey,
        ),
        throwsA(isA<KeyMaterialFailure>()),
      );
    });
  });
}
