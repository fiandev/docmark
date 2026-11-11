import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_template/src/data/services/render/pdf_composer.dart';
import 'package:flutter_template/src/data/services/render/pdf_page_rasterizer.dart';
import 'package:flutter_template/src/data/services/render/watermark_renderer_impl.dart';
import 'package:flutter_template/src/domain/entities/document.dart';
import 'package:flutter_template/src/domain/entities/image_format.dart';
import 'package:flutter_template/src/domain/entities/normalized_rect.dart';
import 'package:flutter_template/src/domain/entities/watermark_element.dart';
import 'package:flutter_template/src/domain/services/render_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatermarkRendererImpl image encoding', () {
    test('PNG output keeps the requested pixel ratio', () async {
      final renderer = _renderer();
      final source = _sourcePng(width: 100, height: 80);

      final result = await renderer.renderImage(
        RenderRequest(
          sourceBytes: source,
          pageIndex: 0,
          pageSize: const Size(100, 80),
          elements: const [],
          pixelRatio: 2,
        ),
        format: ImageFormat.png,
      );

      final decoded = img.decodePng(result.bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 200);
      expect(decoded.height, 160);
      expect(result.format, ImageFormat.png);
    });

    test('JPEG output uses the quality getter and encodes', () async {
      var requested = false;
      final renderer = _renderer(
        jpegQuality: () {
          requested = true;

          return 0.5;
        },
      );
      final source = _sourcePng(width: 100, height: 80);

      final result = await renderer.renderImage(
        RenderRequest(
          sourceBytes: source,
          pageIndex: 0,
          pageSize: const Size(100, 80),
          elements: const [],
          pixelRatio: 1,
        ),
        format: ImageFormat.jpeg,
      );

      final decoded = img.decodeJpg(result.bytes);
      expect(requested, isTrue);
      expect(decoded, isNotNull);
      expect(decoded!.width, 100);
      expect(decoded.height, 80);
      expect(result.format, ImageFormat.jpeg);
    });

    test('rasterizePage always produces PNG', () async {
      final renderer = _renderer();

      final result = await renderer.rasterizePage(
        RenderRequest(
          sourceBytes: _sourcePng(width: 64, height: 32),
          pageIndex: 0,
          pageSize: const Size(64, 32),
          elements: const [],
        ),
      );

      expect(result.bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
      expect(result.format, ImageFormat.png);
    });

    test('thumbnail caps the width at maxWidth', () async {
      final renderer = _renderer();

      final bytes = await renderer.thumbnail(
        RenderRequest(
          sourceBytes: _sourcePng(width: 1000, height: 800),
          pageIndex: 0,
          pageSize: const Size(1000, 800),
          elements: const [],
        ),
        maxWidth: 320,
      );

      final decoded = img.decodePng(bytes);
      expect(decoded!.width, 320);
      expect(decoded.height, 256);
    });
  });

  group('WatermarkRendererImpl PDF rebuild', () {
    test(
      'rebuilds only the selected pages at their exact point size',
      () async {
        final sourceSizes = <int, Size>{
          0: const Size(300, 400),
          1: const Size(200, 500),
          2: const Size(250, 350),
        };
        final loader = _RecordingPageLoader();
        final rasterizer = _FakeRasterizer(sourceSizes);
        final composer = _RecordingComposer();
        final renderer = _renderer(
          pageLoader: loader.call,
          rasterizer: rasterizer,
          composer: composer,
        );
        final request = ExportRequest(
          document: _pdfDocument(sourceSizes),
          config: const WatermarkConfig(
            elements: <WatermarkElement>[
              TextWatermark(
                id: 'text',
                rect: NormalizedRect.fromLTWH(0.1, 0.1, 0.4, 0.2),
                content: 'Confidential',
              ),
            ],
          ),
          pageIndexes: const <int>[0, 2],
          options: const ExportOptions(pdfDpi: 144),
        );

        final result = await renderer.renderPdfPdf(request);

        expect(loader.calls, <int>[0, 2]);
        expect(composer.pages, hasLength(2));
        expect(composer.pages[0].sizePt, const Size(300, 400));
        expect(composer.pages[1].sizePt, const Size(250, 350));
        expect(composer.pages[0].pngBytes.sublist(0, 4), <int>[
          0x89,
          0x50,
          0x4E,
          0x47,
        ]);
        expect(result.format, ImageFormat.pdf);
        expect(result.bytes, composer.output);
      },
    );

    test('an empty selection rebuilds the imported subset only', () async {
      final loader = _RecordingPageLoader();
      final rasterizer = _FakeRasterizer(<int, Size>{
        1: const Size(200, 500),
        2: const Size(250, 350),
      });
      final composer = _RecordingComposer();
      final renderer = _renderer(
        pageLoader: loader.call,
        rasterizer: rasterizer,
        composer: composer,
      );
      final full = _pdfDocument(<int, Size>{
        0: const Size(300, 400),
        1: const Size(200, 500),
        2: const Size(250, 350),
      });
      final subset = full.copyWith(
        pageSizes: full.pageSizes
            .where((page) => page.index != 0)
            .toList(),
      );

      await renderer.renderPdfPdf(
        ExportRequest(document: subset, config: WatermarkConfig.empty),
      );

      expect(loader.calls, <int>[1, 2]);
      expect(composer.pages, hasLength(2));
    });

    test('a page loader read never mutates the source bytes', () async {
      final original = Uint8List.fromList(<int>[
        0x25,
        0x50,
        0x44,
        0x46,
        0x00,
      ]);
      final snapshot = Uint8List.fromList(original);
      final loader = _RecordingPageLoader(
        bytesForPage: (page) => Uint8List.fromList(original),
      );
      final rasterizer = _FakeRasterizer(<int, Size>{
        0: const Size(100, 100),
      });
      final composer = _RecordingComposer();
      final renderer = _renderer(
        pageLoader: loader.call,
        rasterizer: rasterizer,
        composer: composer,
      );

      await renderer.renderPdfPdf(
        ExportRequest(
          document: _pdfDocument(<int, Size>{0: const Size(100, 100)}),
          config: WatermarkConfig.empty,
        ),
      );

      expect(original, snapshot);
    });
  });
}

WatermarkRendererImpl _renderer({
  PdfPageRasterizer? rasterizer,
  DocumentPageBytesLoader? pageLoader,
  PdfComposer? composer,
  double Function()? jpegQuality,
}) {
  return WatermarkRendererImpl(
    painter: _paintNothing,
    rasterizer: rasterizer ?? _FakeRasterizer(<int, Size>{}),
    pageLoader: pageLoader ?? (_, _) async => _sourcePng(width: 10, height: 10),
    assetLoader: (assetId) async => null,
    composer: composer ?? const PdfPackageComposer(),
    jpegQuality: jpegQuality ?? () => 0.92,
  );
}

void _paintNothing(
  ui.Canvas canvas,
  ui.Size pageSize,
  List<WatermarkElement> elements,
  ui.Image? Function(String assetId) imageResolver,
) {}

Uint8List _sourcePng({required int width, required int height}) {
  final image = img.Image(width: width, height: height);

  return img.encodePng(image);
}

DocumentEntity _pdfDocument(Map<int, Size> sizes) {
  final pages = sizes.entries
      .map(
        (entry) => DocumentPage(
          index: entry.key,
          widthPt: entry.value.width,
          heightPt: entry.value.height,
        ),
      )
      .toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  return DocumentEntity(
    id: 'doc',
    name: 'report.pdf',
    kind: DocumentKind.pdf,
    pageCount: pages.length,
    pageSizes: pages,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

class _RecordingPageLoader {
  _RecordingPageLoader({this.bytesForPage});

  final Uint8List Function(int pageIndex)? bytesForPage;
  final List<int> calls = <int>[];

  Future<Uint8List> call(String documentId, int pageIndex) async {
    calls.add(pageIndex);

    return bytesForPage?.call(pageIndex) ??
        Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46, pageIndex]);
  }
}

class _FakeRasterizer implements PdfPageRasterizer {
  _FakeRasterizer(this.sizes);

  final Map<int, Size> sizes;

  @override
  Future<RasterPage> rasterize(
    Uint8List pdfBytes,
    int pageIndex, {
    required double scale,
  }) async {
    final index = pdfBytes.isEmpty ? pageIndex : pdfBytes.last;
    final size = sizes[index] ?? const Size(100, 100);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 10, 10),
      Paint()..color = const Color(0xFF00FF00),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(10, 10);
    picture.dispose();

    return RasterPage(image: image, sizePt: size);
  }
}

class _RecordingComposer implements PdfComposer {
  final List<RasterPdfPage> pages = <RasterPdfPage>[];
  final Uint8List output = Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46]);

  @override
  Future<Uint8List> compose(List<RasterPdfPage> pages) async {
    this.pages
      ..clear()
      ..addAll(pages);

    return output;
  }
}
