import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../security/encryption_service.dart';
import '../../security/key_manager.dart';

/// Creates and remembers the SQLCipher passphrase.
///
/// The passphrase is a fresh 256-bit random value wrapped by the KEK. Only
/// the wrapped form touches disk (a small JSON file next to the database),
/// so a copied app container holds no usable database key. Losing the KEK
/// already makes the database unreadable; regenerating the passphrase here
/// would not recover anything, which is why a broken wrapped key throws
/// instead of silently creating a new one.
final class DatabaseKeyStore {
  DatabaseKeyStore({
    required EncryptionService encryption,
    required KeyManager keyManager,
    required File keyFile,
  }) : _encryption = encryption,
       _keyManager = keyManager,
       _keyFile = keyFile;

  final EncryptionService _encryption;
  final KeyManager _keyManager;
  final File _keyFile;

  Future<AesKey> loadOrCreate() async {
    if (await _keyFile.exists()) {
      final wrapped = await _readWrapped();
      final kek = await _keyManager.createOrGetKek();

      return _encryption.unwrapKey(
        keyEncryptionKey: kek,
        wrapped: wrapped,
      );
    }

    final kek = await _keyManager.createOrGetKek();
    final dataKey = _encryption.generateDataKey();
    final wrapped = await _encryption.wrapKey(
      keyEncryptionKey: kek,
      dataKey: dataKey,
    );
    await _keyFile.parent.create(recursive: true);
    await _keyFile.writeAsString(
      jsonEncode({
        'version': 1,
        'ciphertext': base64Encode(wrapped.ciphertext),
        'nonce': base64Encode(wrapped.nonce),
        'mac': base64Encode(wrapped.mac),
      }),
      flush: true,
    );

    return dataKey;
  }

  Future<WrappedKey> _readWrapped() async {
    final source = await _keyFile.readAsString();
    final json = jsonDecode(source);
    if (json is! Map) {
      throw const FormatException('Database key file is malformed');
    }
    final ciphertext = json['ciphertext'];
    final nonce = json['nonce'];
    final mac = json['mac'];
    if (ciphertext is! String || nonce is! String || mac is! String) {
      throw const FormatException('Database key file is incomplete');
    }

    return WrappedKey(
      ciphertext: _decode(ciphertext),
      nonce: _decode(nonce),
      mac: _decode(mac),
    );
  }

  Uint8List _decode(String value) {
    try {
      return base64Decode(value);
    } on FormatException {
      throw const FormatException('Database key file is not base64');
    }
  }
}
