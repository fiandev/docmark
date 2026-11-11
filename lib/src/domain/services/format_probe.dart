import 'dart:typed_data';

import '../entities/image_format.dart';

/// Sniffs the format of a byte buffer from its magic bytes.
///
/// Import validation uses this rather than a file extension: pickers may
/// hand over an extension-less file, and a mislabelled `.png` must fail
/// before it reaches the renderer. The probe never throws — unknown
/// bytes are [ImageFormat.unknown].
abstract final class FormatProbe {
  /// The format of [bytes], or [ImageFormat.unknown].
  static ImageFormat probe(Uint8List bytes) {
    if (_startsWith(bytes, const [0x25, 0x50, 0x44, 0x46])) {
      return ImageFormat.pdf;
    }
    if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])) {
      return ImageFormat.png;
    }
    if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) {
      return ImageFormat.jpeg;
    }
    if (_isWebP(bytes)) return ImageFormat.webp;

    return ImageFormat.unknown;
  }

  /// Whether [bytes] is an importable MVP document.
  static bool isSupported(Uint8List bytes) => probe(bytes).isSupported;

  static bool _startsWith(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }

    return true;
  }

  /// A WebP file is `RIFF <size> WEBP`.
  static bool _isWebP(Uint8List bytes) {
    if (bytes.length < 12) return false;
    const riff = [0x52, 0x49, 0x46, 0x46]; // RIFF
    const webp = [0x57, 0x45, 0x42, 0x50]; // WEBP
    for (var i = 0; i < riff.length; i++) {
      if (bytes[i] != riff[i]) return false;
    }
    for (var i = 0; i < webp.length; i++) {
      if (bytes[8 + i] != webp[i]) return false;
    }

    return true;
  }
}
