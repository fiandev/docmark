import 'dart:typed_data';
import 'dart:ui' show Size;

import '../entities/document.dart';
import '../entities/image_format.dart';
import '../entities/watermark_element.dart';

/// One page, its source bytes, and the elements to draw on it.
///
/// The renderer receives resolved geometry: `elements` are already the
/// elements assigned to [pageIndex] and [pageSize] is that page's own
/// point size, so a mixed-size PDF needs no special case.
final class RenderRequest {
  const RenderRequest({
    required this.sourceBytes,
    required this.pageIndex,
    required this.pageSize,
    required this.elements,
    this.pixelRatio = 1,
  });

  final Uint8List sourceBytes;
  final int pageIndex;

  /// The page's size in PDF points (72 dpi).
  final Size pageSize;

  final List<WatermarkElement> elements;

  /// Output scale: 1 renders at point size, 2 at 144 dpi, and so on.
  final double pixelRatio;
}

/// Raster bytes produced by the renderer.
final class RenderResult {
  const RenderResult({
    required this.bytes,
    required this.size,
    required this.format,
  });

  final Uint8List bytes;

  /// Pixel dimensions of [bytes].
  final Size size;

  final ImageFormat format;
}

/// Options that shape an export.
final class ExportOptions {
  const ExportOptions({
    this.format = ImageFormat.pdf,
    this.jpegQuality = 0.92,
    this.pdfDpi = 150,
    this.flatten = true,
  });

  final ImageFormat format;

  /// 0..1; ignored for PNG and PDF.
  final double jpegQuality;

  /// Rasterization resolution when rebuilding a PDF.
  final int pdfDpi;

  /// Whether to flatten each page to a single raster image.
  final bool flatten;
}

/// Everything the export screen and the renderer need for one export.
///
/// Passed to `ExportPreviewPage` as its required constructor argument, and
/// to `WatermarkRenderer.renderPdfPdf` for the PDF rebuild path.
final class ExportRequest {
  const ExportRequest({
    required this.document,
    required this.config,
    this.pageIndexes = const [],
    this.options = const ExportOptions(),
  });

  final DocumentEntity document;
  final WatermarkConfig config;

  /// Selected pages. Empty means every page.
  final List<int> pageIndexes;

  final ExportOptions options;

  /// The pages to export, resolving the empty-list "all pages" shorthand.
  List<int> get resolvedPages {
    if (pageIndexes.isNotEmpty) return pageIndexes;

    return List<int>.generate(document.pageCount, (index) => index);
  }

  /// An empty request for the router while the export flow is a stub.
  ///
  /// The preview route takes its real request through `GoRouterState.extra`;
  /// when the user deep-links to the route there is nothing to preview, and
  /// the page renders its empty state. T7 may remove this once the export
  /// route reads the editor state directly.
  static final ExportRequest placeholder = ExportRequest(
    document: DocumentEntity(
      id: '',
      name: '',
      kind: DocumentKind.image,
      pageCount: 0,
      pageSizes: const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
    config: WatermarkConfig.empty,
  );
}

/// The rendering boundary. Implementations may be Dart-only (`pdf`,
/// `image`) or platform-backed (`pdfrx`); the domain sees only these
/// methods.
///
/// Renderers must never write plaintext to disk — every result is returned
/// as bytes for the vault or the share sheet.
abstract interface class WatermarkRenderer {
  /// Renders one page of an image or PDF document with its watermarks.
  Future<RenderResult> rasterizePage(RenderRequest request);

  /// Renders a single-image watermark source at export quality.
  Future<RenderResult> renderImage(
    RenderRequest request, {
    required ImageFormat format,
  });

  /// Rebuilds a PDF by rasterizing every requested page and writing a new
  /// PDF around the images. The original PDF bytes are never modified.
  Future<RenderResult> renderPdfPdf(ExportRequest request);

  /// A small preview image for lists and history rows.
  Future<Uint8List> thumbnail(RenderRequest request, {int maxWidth = 320});
}
