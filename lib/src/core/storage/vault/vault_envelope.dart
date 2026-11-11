import 'dart:convert';
import 'dart:typed_data';

import '../../security/encryption_service.dart';

/// Binary layout of one encrypted vault blob.
///
/// ```text
/// magic       4 bytes   "DMK1"
/// version     1 byte
/// wrapped nonce      12 bytes
/// wrapped key        32 bytes
/// wrapped mac        16 bytes
/// payload nonce      12 bytes
/// payload ciphertext variable
/// payload mac        16 bytes
/// ```
///
/// The payload segment is the plain `nonce || ciphertext || mac` the
/// encryption service returns. The fixed header carries the data key that
/// protects that payload, wrapped by the KEK, so one file is a complete
/// envelope: deleting the file removes the ciphertext and the only wrapped
/// copy of its data key at once.
const List<int> vaultMagic = [0x44, 0x4D, 0x4B, 0x31];

const int vaultVersion = 1;

const int wrappedKeyCiphertextLength = 32;

const int wrappedKeyNonceLength = 12;

const int wrappedKeyMacLength = 16;

const int payloadNonceLength = 12;

const int payloadMacLength = 16;

const int _magicOffset = 0;

const int _versionOffset = 4;

const int _wrappedNonceOffset = 5;

const int _wrappedCipherOffset = _wrappedNonceOffset + wrappedKeyNonceLength;

const int _wrappedMacOffset =
    _wrappedCipherOffset + wrappedKeyCiphertextLength;

const int _payloadNonceOffset = _wrappedMacOffset + wrappedKeyMacLength;

/// Offset of the payload ciphertext; everything before it is fixed.
const int vaultHeaderLength = _payloadNonceOffset + payloadNonceLength;

/// A blob with an empty payload still needs the header and a tag.
const int minimumVaultBlobLength = vaultHeaderLength + payloadMacLength;

/// One decoded vault blob: the wrapped data key and the sealed payload.
final class VaultEnvelope {
  const VaultEnvelope({required this.wrappedKey, required this.payload});

  final WrappedKey wrappedKey;
  final EncryptedPayload payload;
}

/// Packs an envelope into the on-disk representation.
Uint8List encodeVaultEnvelope(VaultEnvelope envelope) {
  final ciphertext = envelope.payload.ciphertext;
  final total = vaultHeaderLength + ciphertext.length + payloadMacLength;
  final bytes = Uint8List(total);

  bytes.setRange(_magicOffset, _versionOffset, vaultMagic);
  bytes[_versionOffset] = vaultVersion;
  bytes.setRange(
    _wrappedNonceOffset,
    _wrappedNonceOffset + wrappedKeyNonceLength,
    envelope.wrappedKey.nonce,
  );
  bytes.setRange(
    _wrappedCipherOffset,
    _wrappedCipherOffset + wrappedKeyCiphertextLength,
    envelope.wrappedKey.ciphertext,
  );
  bytes.setRange(
    _wrappedMacOffset,
    _wrappedMacOffset + wrappedKeyMacLength,
    envelope.wrappedKey.mac,
  );
  bytes.setRange(
    _payloadNonceOffset,
    _payloadNonceOffset + payloadNonceLength,
    envelope.payload.nonce,
  );
  bytes.setRange(
    vaultHeaderLength,
    vaultHeaderLength + ciphertext.length,
    ciphertext,
  );
  bytes.setRange(
    vaultHeaderLength + ciphertext.length,
    total,
    envelope.payload.mac,
  );

  return bytes;
}

/// Reads the header and payload back. Throws [FormatException] for a
/// truncated, foreign, or unsupported file; the caller must not guess at a
/// partially valid blob.
VaultEnvelope decodeVaultEnvelope(Uint8List bytes) {
  if (bytes.length < minimumVaultBlobLength) {
    throw const FormatException('Vault blob is too short');
  }
  for (var i = 0; i < vaultMagic.length; i++) {
    if (bytes[_magicOffset + i] != vaultMagic[i]) {
      throw const FormatException('Vault blob has a bad magic value');
    }
  }
  if (bytes[_versionOffset] != vaultVersion) {
    throw FormatException(
      'Unsupported vault blob version ${bytes[_versionOffset]}',
    );
  }

  final ciphertextStart = vaultHeaderLength;
  final ciphertextEnd = bytes.length - payloadMacLength;

  return VaultEnvelope(
    wrappedKey: WrappedKey(
      ciphertext: _slice(
        bytes,
        _wrappedCipherOffset,
        _wrappedCipherOffset + wrappedKeyCiphertextLength,
      ),
      nonce: _slice(
        bytes,
        _wrappedNonceOffset,
        _wrappedNonceOffset + wrappedKeyNonceLength,
      ),
      mac: _slice(
        bytes,
        _wrappedMacOffset,
        _wrappedMacOffset + wrappedKeyMacLength,
      ),
    ),
    payload: EncryptedPayload(
      ciphertext: _slice(bytes, ciphertextStart, ciphertextEnd),
      nonce: _slice(
        bytes,
        _payloadNonceOffset,
        _payloadNonceOffset + payloadNonceLength,
      ),
      mac: _slice(bytes, ciphertextEnd, bytes.length),
    ),
  );
}

/// The wrapped block as base64, for the database column that mirrors it.
String wrappedKeyBase64Of(WrappedKey wrapped) {
  final total = wrappedKeyNonceLength +
      wrappedKeyCiphertextLength +
      wrappedKeyMacLength;
  final bytes = Uint8List(total);

  bytes.setRange(0, wrappedKeyNonceLength, wrapped.nonce);
  bytes.setRange(
    wrappedKeyNonceLength,
    wrappedKeyNonceLength + wrappedKeyCiphertextLength,
    wrapped.ciphertext,
  );
  bytes.setRange(
    wrappedKeyNonceLength + wrappedKeyCiphertextLength,
    bytes.length,
    wrapped.mac,
  );

  return base64Encode(bytes);
}

Uint8List _slice(Uint8List source, int start, int end) {
  return Uint8List.fromList(source.sublist(start, end));
}
