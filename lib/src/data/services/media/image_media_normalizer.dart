import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../../../domain/entities/image_format.dart';
import '../../../domain/services/format_probe.dart';
import '../../../domain/services/media_normalizer.dart';

/// Decodes with `package:image`, bakes EXIF orientation, and re-encodes as
/// PNG so an image watermark keeps its alpha channel.
///
/// PDFs are not images: [probe] reads their page count and first-page size
/// from pdfrx, and [normalizeAsPng] refuses them.
final class ImageMediaNormalizer implements MediaNormalizerService {
  const ImageMediaNormalizer();

  @override
  Future<NormalizedMedia> normalizeAsPng(Uint8List bytes) async {
    final format = FormatProbe.probe(bytes);
    if (format != ImageFormat.jpeg &&
        format != ImageFormat.png &&
        format != ImageFormat.webp) {
      throw const FormatException('Not a decodable image.');
    }

    final upright = img.bakeOrientation(_decode(bytes));

    return NormalizedMedia(
      pngBytes: Uint8List.fromList(img.encodePng(upright)),
      width: upright.width,
      height: upright.height,
      hasAlpha: upright.hasAlpha,
      sourceFormat: format,
    );
  }

  @override
  Future<MediaProbe> probe(Uint8List bytes) async {
    final format = FormatProbe.probe(bytes);
    if (format == ImageFormat.pdf) return _probePdf(bytes);
    if (format == ImageFormat.unknown) {
      return const MediaProbe(format: ImageFormat.unknown);
    }

    final decoded = _decode(bytes);

    return MediaProbe(
      format: format,
      width: decoded.width,
      height: decoded.height,
      hasAlpha: decoded.hasAlpha,
    );
  }

  img.Image _decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Not a decodable image.');
    }

    return decoded;
  }

  Future<MediaProbe> _probePdf(Uint8List bytes) async {
    try {
      await pdfrxFlutterInitialize();
      final document = await PdfDocument.openData(
        bytes,
        sourceName: 'docmark-probe:${identityHashCode(bytes)}',
      );
      try {
        if (document.pages.isEmpty) {
          throw const FormatException('The PDF has no pages.');
        }
        final first = document.pages.first;

        return MediaProbe(
          format: ImageFormat.pdf,
          width: first.width.round(),
          height: first.height.round(),
          pageCount: document.pages.length,
        );
      } finally {
        await document.dispose();
      }
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Not a readable PDF: ${error.runtimeType}');
    }
  }
}
