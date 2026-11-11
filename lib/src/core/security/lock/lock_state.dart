import 'dart:convert';
import 'dart:typed_data';

import '../encryption_service.dart';
import '../lock_controller.dart';

/// The secret half of App Lock: the salt, the PIN verifier, the policy, and
/// the biometrics flag.
///
/// The failed-attempt counter and cooldown deadline live here too. They are
/// not secret, but they must survive a restart: an attacker who could reset
/// the backoff by killing the process would turn a paced guessing attack
/// into an unlimited one.
///
/// This never reaches storage as-is. The controller serializes it with
/// [toBytes] and seals the result with AES-GCM under the key-encryption key;
/// only the [LockBlob] envelope is written to secure storage. [toString] is
/// redacted so an accidental log cannot print verifier bytes.
final class LockSecret {
  const LockSecret({
    required this.salt,
    required this.verifier,
    required this.iterations,
    required this.policy,
    required this.biometricsEnabled,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  /// Rebuilds a secret from the decrypted JSON payload.
  ///
  /// Throws [FormatException] when a field is missing or the wrong type; the
  /// controller treats that as a corrupt blob and fails closed.
  factory LockSecret.fromJson(Map<String, dynamic> json) {
    final policy = json['policy'];
    if (policy is! Map<String, dynamic>) {
      throw const FormatException('App Lock state has no policy');
    }

    return LockSecret(
      salt: base64Decode(json['salt'] as String),
      verifier: base64Decode(json['verifier'] as String),
      iterations: json['iterations'] as int,
      policy: LockPolicy(
        gracePeriod: Duration(
          seconds: policy['gracePeriodSeconds'] as int,
        ),
        maxPinAttempts: policy['maxPinAttempts'] as int,
        pinLength: policy['pinLength'] as int,
      ),
      biometricsEnabled: json['biometricsEnabled'] as bool? ?? false,
      failedAttempts: json['failedAttempts'] as int? ?? 0,
      lockedUntil: _deadlineFromJson(json['lockedUntil']),
    );
  }

  /// Decrypts a UTF-8 JSON payload back into a secret.
  factory LockSecret.fromBytes(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('App Lock state is not a JSON object');
    }

    return LockSecret.fromJson(decoded);
  }

  static const int version = 1;

  final Uint8List salt;
  final Uint8List verifier;
  final int iterations;
  final LockPolicy policy;
  final bool biometricsEnabled;

  /// Consecutive misses recorded so far, including across restarts.
  final int failedAttempts;

  /// When the current cooldown expires; null when no cooldown is active.
  final DateTime? lockedUntil;

  LockSecret copyWith({
    LockPolicy? policy,
    bool? biometricsEnabled,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) {
    return LockSecret(
      salt: salt,
      verifier: verifier,
      iterations: iterations,
      policy: policy ?? this.policy,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLockedUntil
          ? null
          : lockedUntil ?? this.lockedUntil,
    );
  }

  /// The plaintext handed to `EncryptionService.encrypt`.
  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  Map<String, dynamic> toJson() => {
    'version': version,
    'salt': base64Encode(salt),
    'verifier': base64Encode(verifier),
    'iterations': iterations,
    'policy': {
      'gracePeriodSeconds': policy.gracePeriod.inSeconds,
      'maxPinAttempts': policy.maxPinAttempts,
      'pinLength': policy.pinLength,
    },
    'biometricsEnabled': biometricsEnabled,
    'failedAttempts': failedAttempts,
    'lockedUntil': lockedUntil?.toUtc().millisecondsSinceEpoch,
  };

  @override
  String toString() => 'LockSecret(redacted)';
}

/// Reads the epoch-millisecond deadline the current format writes. Older
/// blobs have no field, and a non-numeric value is treated as "no cooldown"
/// rather than corrupting the whole blob.
DateTime? _deadlineFromJson(Object? value) {
  if (value is! int) return null;

  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}

/// The only bytes App Lock writes to storage: an AES-GCM envelope.
///
/// The plaintext is [LockSecret]'s JSON; the key is the KEK from
/// `KeyManager`. Base64 fields keep the value printable for secure storage,
/// which stores strings, without ever exposing verifier bytes.
final class LockBlob {
  const LockBlob({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  factory LockBlob.fromPayload(EncryptedPayload payload) {
    return LockBlob(
      ciphertext: payload.ciphertext,
      nonce: payload.nonce,
      mac: payload.mac,
    );
  }

  /// Parses the stored envelope. Throws [FormatException] when the value is
  /// not a well-formed blob.
  factory LockBlob.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('App Lock blob is not a JSON object');
    }

    return LockBlob(
      ciphertext: base64Decode(decoded['c'] as String),
      nonce: base64Decode(decoded['n'] as String),
      mac: base64Decode(decoded['m'] as String),
    );
  }

  static const int version = 1;

  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List mac;

  EncryptedPayload get payload => EncryptedPayload(
    ciphertext: ciphertext,
    nonce: nonce,
    mac: mac,
  );

  String encode() => jsonEncode({
    'v': version,
    'c': base64Encode(ciphertext),
    'n': base64Encode(nonce),
    'm': base64Encode(mac),
  });
}
