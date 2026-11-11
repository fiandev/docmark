import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../../../domain/entities/image_format.dart';
import '../../../domain/entities/watermark_element.dart';
import '../../../domain/services/format_probe.dart';
import '../../../domain/services/render_contract.dart';
import 'pdf_composer.dart';
import 'pdf_page_rasterizer.dart';
import 'watermark_image_cache.dart';

/// Draws a page's elements onto a raw canvas.
///
/// The implementation is the editor's shared painter, injected through the
/// DI seam so this data-layer renderer never imports the presentation
/// layer. A fake can be supplied for renderer tests.
typedef WatermarkPagePainter = void Function(
  ui.Canvas canvas,
  ui.Size pageSize,
  List<WatermarkElement> elements,
  ui.Image? Function(String assetId) imageResolver,
);

/// Decrypted source bytes for one document page.
typedef DocumentPageBytesLoader = Future<Uint8List> Function(
  String documentId,
  int pageIndex,
);

/// The single renderer behind previews and every export.
///
/// It is deliberately storage-agnostic: source bytes and watermark assets
/// arrive through injected loaders, and the returned bytes never touch
/// disk. The caller decides whether they go to the vault, the share sheet,
/// or a history row.
final class WatermarkRendererImpl implements WatermarkRenderer {
  WatermarkRendererImpl({
    required WatermarkPagePainter painter,
    required PdfPageRasterizer rasterizer,
    required DocumentPageBytesLoader pageLoader,
    required WatermarkAssetBytesLoader assetLoader,
    this.composer = const PdfPackageComposer(),
    this.jpegQuality = _defaultJpegQuality,
    WatermarkImageCache? imageCache,
  }) : _painter = painter,
       _rasterizer = rasterizer,
       _pageLoader = pageLoader,
       _images = imageCache ?? WatermarkImageCache(loader: assetLoader);

  final WatermarkPagePainter _painter;
  final PdfPageRasterizer _rasterizer;
  final DocumentPageBytesLoader _pageLoader;
  final WatermarkImageCache _images;
  final PdfComposer composer;

  /// 0..1. The export screen writes its quality choice into a DI-owned
  /// value and the renderer reads it through this getter.
  final double Function() jpegQuality;

  @override
  Future<RenderResult> rasterizePage(RenderRequest request) async {
    final loaded = await _loadPage(request);
    try {
      final composed = await _composePage(
        pageImage: loaded.image,
        pageSize: loaded.sizePt,
        pixelRatio: request.pixelRatio,
        elements: request.elements,
        opaqueBackground: false,
      );
      try {
        return RenderResult(
          bytes: await _encodePng(composed),
          size: _imageSize(composed),
          format: ImageFormat.png,
        );
      } finally {
        composed.dispose();
      }
    } finally {
      loaded.image.dispose();
    }
  }

  @override
  Future<RenderResult> renderImage(
    RenderRequest request, {
    required ImageFormat format,
  }) async {
    if (format != ImageFormat.png && format != ImageFormat.jpeg) {
      throw ArgumentError.value(
        format,
        'format',
        'renderImage encodes PNG or JPEG only',
      );
    }

    final loaded = await _loadPage(request);
    try {
      final composed = await _composePage(
        pageImage: loaded.image,
        pageSize: loaded.sizePt,
        pixelRatio: request.pixelRatio,
        elements: request.elements,
        // JPEG has no alpha channel; flatten transparent source pages onto
        // white instead of letting them decode to black.
        opaqueBackground: format == ImageFormat.jpeg,
      );
      try {
        final bytes = format == ImageFormat.png
            ? await _encodePng(composed)
            : await _encodeJpeg(composed, jpegQuality());
        return RenderResult(
          bytes: bytes,
          size: _imageSize(composed),
          format: format,
        );
      } finally {
        composed.dispose();
      }
    } finally {
      loaded.image.dispose();
    }
  }

  @override
  Future<RenderResult> renderPdfPdf(ExportRequest request) async {
    final scale = request.options.pdfDpi <= 0
        ? 1.0
        : request.options.pdfDpi / 72;

    final pages = <RasterPdfPage>[];
    // Every index here is a SOURCE page index; the request already narrowed
    // that to the imported subset.
    for (final pageIndex in request.resolvedPages) {
      final bytes = await _pageLoader(request.document.id, pageIndex);
      final documentPage = request.document.pageAt(pageIndex);
      final loaded = await _rasterizeSource(
        sourceBytes: bytes,
        pageIndex: pageIndex,
        scale: scale,
        fallbackPageSize: documentPage?.sizePt ?? ui.Size.zero,
      );
      try {
        if (loaded.sizePt.width <= 0 || loaded.sizePt.height <= 0) {
          throw StateError('Page $pageIndex has no usable size.');
        }
        final composed = await _composePage(
          pageImage: loaded.image,
          pageSize: loaded.sizePt,
          pixelRatio: scale,
          elements: request.config.elementsForPage(pageIndex),
          opaqueBackground: true,
        );
        try {
          pages.add(
            RasterPdfPage(
              pngBytes: await _encodePng(composed),
              sizePt: loaded.sizePt,
            ),
          );
        } finally {
          composed.dispose();
        }
      } finally {
        loaded.image.dispose();
      }
    }

    final documentBytes = await composer.compose(pages);

    return RenderResult(
      bytes: documentBytes,
      size: pages.first.sizePt,
      format: ImageFormat.pdf,
    );
  }

  @override
  Future<Uint8List> thumbnail(
    RenderRequest request, {
    int maxWidth = 320,
  }) async {
    final width = request.pageSize.width;
    final ratio = width <= 0
        ? 1.0
        : math.min(1.0, math.max(0.01, maxWidth / width));

    final result = await rasterizePage(
      RenderRequest(
        sourceBytes: request.sourceBytes,
        pageIndex: request.pageIndex,
        pageSize: request.pageSize,
        elements: request.elements,
        pixelRatio: ratio,
      ),
    );

    return result.bytes;
  }

  /// Drops decoded watermark assets. The DI container keeps the renderer
  /// alive for the app's lifetime, so this is only for explicit resets.
  void dispose() => _images.clear();

  Future<_LoadedPage> _loadPage(RenderRequest request) {
    return _rasterizeSource(
      sourceBytes: request.sourceBytes,
      pageIndex: request.pageIndex,
      scale: request.pixelRatio,
      fallbackPageSize: request.pageSize,
    );
  }

  /// Decodes the source at [scale]: a PDF page through the native
  /// rasterizer, an image document through the Flutter codec.
  Future<_LoadedPage> _rasterizeSource({
    required Uint8List sourceBytes,
    required int pageIndex,
    required double scale,
    required ui.Size fallbackPageSize,
  }) async {
    final ratio = scale <= 0 ? 1.0 : scale;

    if (FormatProbe.probe(sourceBytes) == ImageFormat.pdf) {
      final raster = await _rasterizer.rasterize(
        sourceBytes,
        pageIndex,
        scale: ratio,
      );

      return _LoadedPage(image: raster.image, sizePt: raster.sizePt);
    }

    final image = await _decodeImage(sourceBytes);

    return _LoadedPage(
      image: image,
      // An image document's point size is its pixel size at 72 dpi.
      sizePt: fallbackPageSize,
    );
  }

  Future<ui.Image> _composePage({
    required ui.Image pageImage,
    required ui.Size pageSize,
    required double pixelRatio,
    required List<WatermarkElement> elements,
    required bool opaqueBackground,
  }) async {
    final ratio = pixelRatio <= 0 ? 1.0 : pixelRatio;
    final width = math.max(1, (pageSize.width * ratio).round());
    final height = math.max(1, (pageSize.height * ratio).round());
    final canvasSize = ui.Size(width.toDouble(), height.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    if (opaqueBackground) {
      canvas.drawRect(
        ui.Offset.zero & canvasSize,
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
    }

    canvas.drawImageRect(
      pageImage,
      ui.Rect.fromLTWH(
        0,
        0,
        pageImage.width.toDouble(),
        pageImage.height.toDouble(),
      ),
      ui.Offset.zero & canvasSize,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );

    final resolver = await _resolveImages(elements);
    _painter(canvas, canvasSize, elements, resolver);

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  Future<ui.Image? Function(String assetId)> _resolveImages(
    List<WatermarkElement> elements,
  ) async {
    final ids = <String>{
      for (final element in elements)
        if (element is ImageWatermark && element.visible) element.assetId,
    };
    final resolved = <String, ui.Image>{};

    for (final id in ids) {
      final image = await _images.resolve(id);
      if (image != null) resolved[id] = image;
    }

    return (assetId) => resolved[assetId];
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  static Future<Uint8List> _encodePng(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Could not encode the page as PNG.');
    }

    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static Future<Uint8List> _encodeJpeg(
    ui.Image image,
    double quality,
  ) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      throw StateError('Could not read the page pixels for JPEG encoding.');
    }

    final raster = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: data.buffer,
      bytesOffset: data.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final value = (quality.clamp(0.0, 1.0) * 100).round().clamp(1, 100).toInt();

    return img.encodeJpg(raster, quality: value);
  }

  static ui.Size _imageSize(ui.Image image) {
    return ui.Size(image.width.toDouble(), image.height.toDouble());
  }
}

double _defaultJpegQuality() => 0.92;

final class _LoadedPage {
  const _LoadedPage({required this.image, required this.sizePt});

  final ui.Image image;
  final ui.Size sizePt;
}
