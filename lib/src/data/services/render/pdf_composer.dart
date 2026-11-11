import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One page of the rebuilt PDF: a PNG raster and its original point size.
final class RasterPdfPage {
  const RasterPdfPage({required this.pngBytes, required this.sizePt});

  final Uint8List pngBytes;
  final ui.Size sizePt;
}

/// Writes a new PDF around already-composited page rasters.
abstract interface class PdfComposer {
  Future<Uint8List> compose(List<RasterPdfPage> pages);
}

/// The production composer, backed by the `pdf` package.
///
/// Each page is a full-bleed image inside a `PdfPageFormat` built from the
/// source page's point size, so the output keeps the original geometry
/// exactly (an A4 page stays 595.28 x 841.89 pt).
final class PdfPackageComposer implements PdfComposer {
  const PdfPackageComposer();

  @override
  Future<Uint8List> compose(List<RasterPdfPage> pages) async {
    if (pages.isEmpty) {
      throw ArgumentError.value(
        pages,
        'pages',
        'A PDF needs at least one page',
      );
    }

    final document = pw.Document();
    for (final page in pages) {
      final format = PdfPageFormat(page.sizePt.width, page.sizePt.height);
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(
              pw.MemoryImage(page.pngBytes),
              fit: pw.BoxFit.fill,
              width: format.width,
              height: format.height,
            ),
          ),
        ),
      );
    }

    return document.save();
  }
}
