import 'dart:typed_data';

import '../entities/image_format.dart';

/// The metadata a normalizer can recover from image or PDF bytes.
final class MediaProbe {
  const MediaProbe({
    required this.format,
    this.width,
    this.height,
    this.hasAlpha = false,
    this.pageCount,
  });

  final ImageFormat format;
  final int? width;
  final int? height;

  /// PNG/WebP alpha survives normalization; JPEG never has any.
  final bool hasAlpha;

  /// Populated for PDFs.
  final int? pageCount;
}

/// The normalized byte stream the rest of the app stores and renders.
///
/// Image watermarks are always stored as PNG so transparency is preserved;
/// document pages keep their original format and are only probed.
final class NormalizedMedia {
  const NormalizedMedia({
    required this.pngBytes,
    required this.width,
    required this.height,
    required this.hasAlpha,
    required this.sourceFormat,
  });

  final Uint8List pngBytes;
  final int width;
  final int height;
  final bool hasAlpha;
  final ImageFormat sourceFormat;
}

/// Decodes, rotates and re-encodes imported media into the app's canonical
/// form, and reports what the bytes actually are.
///
/// Implementations use the `image` package and must be CPU-safe: large
/// images are downscaled only when the caller asks for it, never silently.
abstract interface class MediaNormalizerService {
  /// Re-encodes [bytes] as PNG, preserving alpha. Throws `FormatException`
  /// for bytes that are not a decodable image.
  Future<NormalizedMedia> normalizeAsPng(Uint8List bytes);

  /// Detects format and dimensions without re-encoding.
  Future<MediaProbe> probe(Uint8List bytes);
}
