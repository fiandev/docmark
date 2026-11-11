import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:docmark/src/domain/entities/image_format.dart';
import 'package:docmark/src/domain/services/render_contract.dart';

/// [WatermarkRenderer] that returns deterministic 1x1 output and records
/// every call. Useful for pages that only need the renderer to exist.
class FakeWatermarkRenderer implements WatermarkRenderer {
  final List<RenderRequest> rasterizeCalls = [];
  final List<ExportRequest> pdfCalls = [];
  final List<RenderRequest> imageCalls = [];
  final List<RenderRequest> thumbnailCalls = [];

  ImageFormat lastImageFormat = ImageFormat.png;

  @override
  Future<RenderResult> rasterizePage(RenderRequest request) async {
    rasterizeCalls.add(request);

    return RenderResult(
      bytes: Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]),
      size: request.pageSize,
      format: ImageFormat.png,
    );
  }

  @override
  Future<RenderResult> renderImage(
    RenderRequest request, {
    required ImageFormat format,
  }) async {
    imageCalls.add(request);
    lastImageFormat = format;

    return RenderResult(
      bytes: Uint8List.fromList(const [0x01, 0x02, 0x03]),
      size: request.pageSize,
      format: format,
    );
  }

  @override
  Future<RenderResult> renderPdfPdf(ExportRequest request) async {
    pdfCalls.add(request);

    return RenderResult(
      bytes: Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]),
      size: Size.zero,
      format: ImageFormat.pdf,
    );
  }

  @override
  Future<Uint8List> thumbnail(
    RenderRequest request, {
    int maxWidth = 320,
  }) async {
    thumbnailCalls.add(request);

    return Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]);
  }
}
