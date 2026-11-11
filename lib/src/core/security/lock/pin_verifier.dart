import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Derives and compares the PIN verifier.
///
/// The verifier is PBKDF2-HMAC-SHA256 over the PIN with a per-app random
/// salt. Only the derived bytes are persisted; the PIN itself never leaves
/// this method. Comparison is constant-time so a timing observer learns
/// nothing about how many leading bytes matched.
final class PinVerifier {
  const PinVerifier({this.iterations = defaultIterations});

  /// The floor the app ships with. Lowering it in a caller is a security
  /// regression; tests may pass a smaller value to stay fast.
  static const int defaultIterations = 300000;

  /// 128 bits of salt is plenty; the stored blob carries it next to the
  /// verifier.
  static const int saltLength = 16;

  /// 256-bit output, matching PBKDF2's SHA-256 digest size.
  static const int verifierLength = 32;

  final int iterations;

  /// A fresh cryptographically secure salt.
  Uint8List newSalt() {
    final random = Random.secure();

    return Uint8List.fromList(
      List<int>.generate(saltLength, (_) => random.nextInt(256)),
    );
  }

  /// PBKDF2-HMAC-SHA256([pin], [salt]) as raw bytes.
  Future<Uint8List> derive(String pin, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: verifierLength * 8,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );

    return Uint8List.fromList(await key.extractBytes());
  }

  /// Compares two verifiers without an early return on the first mismatch.
  ///
  /// A length difference is public information (the stored verifier is a
  /// fixed size), so returning early there leaks nothing.
  static bool constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }

    return difference == 0;
  }
}
