import 'dart:typed_data';

/// Renders a page of PDF bytes that have not been imported yet.
///
/// The picker needs thumbnails before a document id exists, so it cannot go
/// through `WatermarkRenderer.thumbnail`, which is keyed by document id.
/// Implementations render in memory only and never write the picked bytes
/// to disk.
abstract interface class PdfPagePreviewService {
  Future<Uint8List> renderPageThumbnail(
    Uint8List pdfBytes,
    int pageIndex, {
    int maxPx = 160,
  });
}
