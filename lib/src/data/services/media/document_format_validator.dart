import 'dart:typed_data';

import '../../../domain/entities/image_format.dart';
import '../../../domain/services/format_probe.dart';

/// The import pipeline's one format check.
///
/// It reads magic bytes rather than trusting the picker's file name: the
/// gallery may hand over a WebP or an extension-less file, and a `.png`
/// name is not proof of PNG bytes. WebP is a valid watermark image format
/// but not an importable document, so [isImportable] rejects it.
abstract final class DocumentFormatValidator {
  static ImageFormat validate(Uint8List bytes) => FormatProbe.probe(bytes);

  static bool isImportable(Uint8List bytes) =>
      DocumentFormatValidator.validate(bytes).isSupported;
}
