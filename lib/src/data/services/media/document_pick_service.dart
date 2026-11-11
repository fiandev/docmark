import 'dart:typed_data';

import '../../../domain/entities/image_format.dart';

/// Bytes the picker has already read, before validation or storage.
///
/// The bytes arrive in memory exactly once. Nothing here names the source
/// path, so downstream code cannot reopen or move the original file.
final class PickedDocument {
  const PickedDocument({
    required this.fileName,
    required this.bytes,
    this.declaredFormat = ImageFormat.unknown,
  });

  final String fileName;
  final Uint8List bytes;

  /// The format the picker detected. [FormatProbe] is the authority before
  /// import; this is a hint for diagnostics and error messages only.
  final ImageFormat declaredFormat;
}

/// Where a document can be picked from on this device.
abstract interface class DocumentPickService {
  Future<PickedDocument?> pickFromGallery();

  Future<PickedDocument?> pickFromFiles();
}
