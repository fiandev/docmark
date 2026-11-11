import 'dart:typed_data';

import '../entities/image_format.dart';

/// A page's physical size in PDF points.
///
/// PDFs may mix page sizes, so a probe reports one of these per source page
/// instead of a single document-wide size.
final class SizePt {
  const SizePt({required this.width, required this.height});

  final double width;
  final double height;

  @override
  bool operator ==(Object other) {
    return other is SizePt && other.width == width && other.height == height;
  }

  @override
  int get hashCode => Object.hash(width, height);
}

/// The metadata a normalizer can recover from image or PDF bytes.
final class MediaProbe {
  const MediaProbe({
    required this.format,
    this.width,
    this.height,
    this.hasAlpha = false,
    this.pageCount,
    this.pageSizesPt = const <SizePt>[],
  });

  final ImageFormat format;

  /// The first page's size. Kept alongside [pageSizesPt] so callers that
  /// only need "a representative size" (and every image) stay unchanged.
  final int? width;
  final int? height;

  /// PNG/WebP alpha survives normalization; JPEG never has any.
  final bool hasAlpha;

  /// Populated for PDFs.
  final int? pageCount;

  /// Per-page sizes for PDFs, indexed by SOURCE page index. Empty when the
  /// probe could not report them, in which case [width]/[height] is the
  /// only size available.
  final List<SizePt> pageSizesPt;

  /// The size of one source page.
  ///
  /// Falls back to [width]/[height] so an image, or a PDF from a probe that
  /// predates per-page sizes, still yields a usable dimension.
  SizePt? sizeForPage(int index) {
    if (index >= 0 && index < pageSizesPt.length) return pageSizesPt[index];
    final probeWidth = width;
    final probeHeight = height;
    if (probeWidth == null || probeHeight == null) return null;

    return SizePt(
      width: probeWidth.toDouble(),
      height: probeHeight.toDouble(),
    );
  }
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
