import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

import 'pdf_page_preview_service.dart';

/// Pre-import PDF page thumbnails, rendered in memory with pdfrx.
///
/// This is the only place the import feature touches the PDF engine. The
/// presentation layer sees [PdfPagePreviewService] through DI, so a fake
/// can replace it in widget tests without native bindings.
final class PdfrxPdfPagePreviewService implements PdfPagePreviewService {
  const PdfrxPdfPagePreviewService();

  @override
  Future<Uint8List> renderPageThumbnail(
    Uint8List pdfBytes,
    int pageIndex, {
    int maxPx = 160,
  }) async {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(
      pdfBytes,
      sourceName: 'docmark-preview:${identityHashCode(pdfBytes)}',
    );
    try {
      if (document.pages.isEmpty) {
        throw const FormatException('The PDF has no pages.');
      }
      final page = document
          .pages[pageIndex.clamp(0, document.pages.length - 1).toInt()];
      final limit = maxPx <= 0 ? 1 : maxPx;
      final longest = math.max(page.width, page.height);
      final scale = longest <= 0 ? 1.0 : limit / longest;
      final width = math.max(1, (page.width * scale).round());
      final height = math.max(1, (page.height * scale).round());

      final rendered = await page.render(
        width: width,
        height: height,
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
      );
      if (rendered == null) {
        throw StateError('pdfrx returned no image for page $pageIndex.');
      }

      try {
        final image = await rendered.createImage();
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) {
            throw StateError('Could not encode PDF page $pageIndex.');
          }

          return data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } finally {
          image.dispose();
        }
      } finally {
        rendered.dispose();
      }
    } finally {
      await document.dispose();
    }
  }
}
