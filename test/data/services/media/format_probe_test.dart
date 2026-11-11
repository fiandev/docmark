import 'dart:typed_data';

import 'package:docmark/src/domain/entities/image_format.dart';
import 'package:docmark/src/domain/services/format_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormatProbe', () {
    test('detects JPEG from its magic bytes', () {
      final bytes = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xE0]);

      expect(FormatProbe.probe(bytes), ImageFormat.jpeg);
    });

    test('detects PNG from its magic bytes', () {
      final bytes = Uint8List.fromList(
        const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A],
      );

      expect(FormatProbe.probe(bytes), ImageFormat.png);
    });

    test('detects PDF from its magic bytes', () {
      final bytes = Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]);

      expect(FormatProbe.probe(bytes), ImageFormat.pdf);
    });

    test('detects WebP from RIFF/WEBP', () {
      final bytes = Uint8List.fromList(const [
        0x52,
        0x49,
        0x46,
        0x46,
        0x04,
        0x00,
        0x00,
        0x00,
        0x57,
        0x45,
        0x42,
        0x50,
      ]);

      expect(FormatProbe.probe(bytes), ImageFormat.webp);
    });

    test('unknown bytes are unknown rather than an exception', () {
      final bytes = Uint8List.fromList(const [0x00, 0x01, 0x02, 0x03]);

      expect(FormatProbe.probe(bytes), ImageFormat.unknown);
      expect(FormatProbe.isSupported(bytes), isFalse);
    });

    test('WebP and unknown are not importable documents', () {
      final webp = Uint8List.fromList(const [
        0x52,
        0x49,
        0x46,
        0x46,
        0x04,
        0x00,
        0x00,
        0x00,
        0x57,
        0x45,
        0x42,
        0x50,
      ]);

      expect(FormatProbe.isSupported(webp), isFalse);
      expect(
        FormatProbe.isSupported(
          Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]),
        ),
        isTrue,
      );
    });
  });
}
