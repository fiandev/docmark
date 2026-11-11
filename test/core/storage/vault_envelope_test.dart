import 'dart:typed_data';

import 'package:docmark/src/core/security/encryption_service.dart';
import 'package:docmark/src/core/storage/vault/vault_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('vault envelope', () {
    test('roundtrips an envelope', () {
      final envelope = VaultEnvelope(
        wrappedKey: _wrappedKey(),
        payload: EncryptedPayload(
          ciphertext: Uint8List.fromList(const [1, 2, 3, 4, 5]),
          nonce: Uint8List.fromList(List<int>.filled(12, 9)),
          mac: Uint8List.fromList(List<int>.filled(16, 7)),
        ),
      );

      final encoded = encodeVaultEnvelope(envelope);
      final decoded = decodeVaultEnvelope(encoded);

      expect(decoded.wrappedKey.nonce, envelope.wrappedKey.nonce);
      expect(decoded.wrappedKey.ciphertext, envelope.wrappedKey.ciphertext);
      expect(decoded.wrappedKey.mac, envelope.wrappedKey.mac);
      expect(decoded.payload.nonce, envelope.payload.nonce);
      expect(decoded.payload.ciphertext, envelope.payload.ciphertext);
      expect(decoded.payload.mac, envelope.payload.mac);
    });

    test('stores the wrapped key before the payload', () {
      final envelope = VaultEnvelope(
        wrappedKey: _wrappedKey(),
        payload: EncryptedPayload(
          ciphertext: Uint8List.fromList(const [0xAA, 0xBB]),
          nonce: Uint8List.fromList(List<int>.filled(12, 1)),
          mac: Uint8List.fromList(List<int>.filled(16, 2)),
        ),
      );

      final encoded = encodeVaultEnvelope(envelope);

      expect(encoded.length, vaultHeaderLength + 2 + payloadMacLength);
      expect(
        encoded.sublist(0, 4),
        vaultMagic,
      );
      expect(encoded[4], vaultVersion);
      expect(
        encoded.sublist(vaultHeaderLength, vaultHeaderLength + 2),
        const [0xAA, 0xBB],
      );
    });

    test('rejects a short blob', () {
      expect(
        () => decodeVaultEnvelope(Uint8List.fromList(const [1, 2, 3])),
        throwsFormatException,
      );
    });

    test('rejects a blob with a foreign magic value', () {
      final envelope = VaultEnvelope(
        wrappedKey: _wrappedKey(),
        payload: EncryptedPayload(
          ciphertext: Uint8List(0),
          nonce: Uint8List.fromList(List<int>.filled(12, 0)),
          mac: Uint8List.fromList(List<int>.filled(16, 0)),
        ),
      );
      final encoded = encodeVaultEnvelope(envelope);
      encoded[0] = 0x00;

      expect(() => decodeVaultEnvelope(encoded), throwsFormatException);
    });

    test('supports an empty payload', () {
      final envelope = VaultEnvelope(
        wrappedKey: _wrappedKey(),
        payload: EncryptedPayload(
          ciphertext: Uint8List(0),
          nonce: Uint8List.fromList(List<int>.filled(12, 0)),
          mac: Uint8List.fromList(List<int>.filled(16, 0)),
        ),
      );

      final decoded = decodeVaultEnvelope(encodeVaultEnvelope(envelope));

      expect(decoded.payload.ciphertext, isEmpty);
    });
  });
}

WrappedKey _wrappedKey() {
  return WrappedKey(
    ciphertext: Uint8List.fromList(List<int>.generate(32, (index) => index)),
    nonce: Uint8List.fromList(List<int>.filled(12, 5)),
    mac: Uint8List.fromList(List<int>.filled(16, 6)),
  );
}
