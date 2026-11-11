import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

/// One PDF page rendered to a bitmap, plus the page's own point size.
///
/// [sizePt] is the source page's size in PDF points, read from the same
/// document that produced [image]. Emitting the new PDF against this value
/// is what preserves the exact page dimensions.
final class RasterPage {
  const RasterPage({required this.image, required this.sizePt});

  final ui.Image image;
  final ui.Size sizePt;
}

/// Rasterizes one page of a PDF. The seam exists so the PDF rebuild path
/// can be exercised without the native PDF engine.
abstract interface class PdfPageRasterizer {
  Future<RasterPage> rasterize(
    Uint8List pdfBytes,
    int pageIndex, {
    required double scale,
  });
}

/// The production rasterizer, backed by pdfrx's native PDFium bindings.
final class PdfrxPageRasterizer implements PdfPageRasterizer {
  const PdfrxPageRasterizer();

  @override
  Future<RasterPage> rasterize(
    Uint8List pdfBytes,
    int pageIndex, {
    required double scale,
  }) async {
    // Direct document access needs the engine initialised before the first
    // open. The call is idempotent, so wiring it here keeps the renderer
    // usable even if bootstrap has not touched pdfrx yet.
    await pdfrxFlutterInitialize();

    final document = await PdfDocument.openData(
      pdfBytes,
      sourceName: 'docmark:${identityHashCode(pdfBytes)}',
    );
    try {
      if (document.pages.isEmpty) {
        throw const FormatException('The PDF has no pages.');
      }

      final index = pageIndex.clamp(0, document.pages.length - 1).toInt();
      final page = document.pages[index];
      final safeScale = scale <= 0 ? 1.0 : scale;
      final width = math.max(1, (page.width * safeScale).round());
      final height = math.max(1, (page.height * safeScale).round());

      final rendered = await page.render(
        width: width,
        height: height,
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
      );
      if (rendered == null) {
        throw StateError('pdfrx returned no image for page $index.');
      }

      try {
        final image = await rendered.createImage();
        return RasterPage(
          image: image,
          sizePt: ui.Size(page.width, page.height),
        );
      } finally {
        rendered.dispose();
      }
    } finally {
      await document.dispose();
    }
  }
}
