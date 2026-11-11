import 'dart:typed_data';

import 'package:flutter_template/src/data/services/media/image_media_normalizer.dart';
import 'package:flutter_template/src/domain/entities/image_format.dart';
import 'package:flutter_template/src/domain/services/format_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const normalizer = ImageMediaNormalizer();

  group('ImageMediaNormalizer.normalizeAsPng', () {
    test('WebP with alpha becomes a PNG that keeps alpha', () async {
      final source = img.Image(width: 2, height: 2, numChannels: 4);
      source.setPixelRgba(0, 0, 255, 0, 0, 128);
      source.setPixelRgba(1, 0, 0, 255, 0, 0);
      source.setPixelRgba(0, 1, 0, 0, 255, 255);
      source.setPixelRgba(1, 1, 0, 0, 0, 255);

      final webp = Uint8List.fromList(img.encodeWebP(source));
      expect(FormatProbe.probe(webp), ImageFormat.webp);

      final normalized = await normalizer.normalizeAsPng(webp);

      expect(FormatProbe.probe(normalized.pngBytes), ImageFormat.png);
      expect(normalized.sourceFormat, ImageFormat.webp);
      expect(normalized.width, 2);
      expect(normalized.height, 2);
      expect(normalized.hasAlpha, isTrue);

      final decoded = img.decodePng(normalized.pngBytes);
      expect(decoded, isNotNull);
      expect(decoded!.hasAlpha, isTrue);
      expect(decoded.getPixel(0, 0).a, 128);
      expect(decoded.getPixel(1, 0).a, 0);
    });

    test('JPEG becomes an opaque PNG', () async {
      final source = img.Image(width: 4, height: 3, numChannels: 3);
      source.clear(img.ColorRgb8(10, 20, 30));

      final jpeg = Uint8List.fromList(img.encodeJpg(source, quality: 90));
      expect(FormatProbe.probe(jpeg), ImageFormat.jpeg);

      final normalized = await normalizer.normalizeAsPng(jpeg);

      expect(FormatProbe.probe(normalized.pngBytes), ImageFormat.png);
      expect(normalized.sourceFormat, ImageFormat.jpeg);
      expect(normalized.width, 4);
      expect(normalized.height, 3);
      expect(normalized.hasAlpha, isFalse);
      expect(img.decodePng(normalized.pngBytes), isNotNull);
    });

    test('refuses bytes that are not an image', () async {
      final pdf = Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]);

      expect(
        () => normalizer.normalizeAsPng(pdf),
        throwsFormatException,
      );
    });
  });

  group('ImageMediaNormalizer.probe', () {
    test('reports image format and dimensions', () async {
      final source = img.Image(width: 7, height: 5, numChannels: 3);
      final png = Uint8List.fromList(img.encodePng(source));

      final probe = await normalizer.probe(png);

      expect(probe.format, ImageFormat.png);
      expect(probe.width, 7);
      expect(probe.height, 5);
    });

    test('unknown bytes stay unknown instead of throwing', () async {
      final probe = await normalizer.probe(
        Uint8List.fromList(const [0x00, 0x01, 0x02]),
      );

      expect(probe.format, ImageFormat.unknown);
    });
  });
}
