import 'dart:typed_data';

import 'package:docmark/src/core/security/lock/pin_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PinVerifier', () {
    test('ships with a 600k-iteration floor', () {
      expect(PinVerifier.defaultIterations, greaterThanOrEqualTo(600000));
    });

    test('derives the same verifier for the same PIN and salt', () async {
      const verifier = PinVerifier();
      final salt = verifier.newSalt();

      final first = await verifier.derive('123456', salt);
      final second = await verifier.derive('123456', salt);

      expect(first, orderedEquals(second));
      expect(first.length, PinVerifier.verifierLength);
      expect(salt.length, PinVerifier.saltLength);
    });

    test('a different salt or PIN changes the verifier', () async {
      const verifier = PinVerifier(iterations: 1000);
      final salt = verifier.newSalt();
      final otherSalt = verifier.newSalt();

      final base = await verifier.derive('123456', salt);
      final otherPin = await verifier.derive('654321', salt);
      final otherSaltVerifier = await verifier.derive('123456', otherSalt);

      expect(orderedEquals(base, otherPin), isFalse);
      expect(orderedEquals(base, otherSaltVerifier), isFalse);
    });

    test('constant-time comparison rejects length and value differences', () {
      final value = Uint8List.fromList([1, 2, 3]);

      expect(
        PinVerifier.constantTimeEquals(value, Uint8List.fromList([1, 2, 3])),
        isTrue,
      );
      expect(
        PinVerifier.constantTimeEquals(value, Uint8List.fromList([1, 2, 4])),
        isFalse,
      );
      expect(
        PinVerifier.constantTimeEquals(value, Uint8List.fromList([1, 2])),
        isFalse,
      );
    });
  });
}
