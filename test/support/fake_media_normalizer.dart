import 'dart:typed_data';

import 'package:flutter_template/src/domain/entities/image_format.dart';
import 'package:flutter_template/src/domain/services/format_probe.dart';
import 'package:flutter_template/src/domain/services/media_normalizer.dart';

/// [MediaNormalizerService] that trusts the probe and copies bytes through
/// as "PNG". Tests that need real decoding use the platform `image`
/// package instead.
class FakeMediaNormalizer implements MediaNormalizerService {
  @override
  Future<NormalizedMedia> normalizeAsPng(Uint8List bytes) async {
    final format = FormatProbe.probe(bytes);

    return NormalizedMedia(
      pngBytes: Uint8List.fromList(bytes),
      width: 1,
      height: 1,
      hasAlpha: format == ImageFormat.png || format == ImageFormat.webp,
      sourceFormat: format,
    );
  }

  @override
  Future<MediaProbe> probe(Uint8List bytes) async {
    return MediaProbe(format: FormatProbe.probe(bytes));
  }
}
