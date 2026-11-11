import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:docmark/src/domain/entities/normalized_rect.dart';
import 'package:docmark/src/domain/entities/watermark_element.dart';
import 'package:docmark/src/presentation/core/widgets/watermark/watermark_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('paintWatermarkElements', () {
    test('element opacity fades the whole element', () async {
      final source = await _image();
      const element = ImageWatermark(
        id: 'image',
        rect: NormalizedRect.fromLTWH(0.25, 0.25, 0.5, 0.5),
        assetId: 'asset',
      );
      WatermarkImageResolver resolver(String _) => source;

      final opaque = await _pixels(
        await _render([element], imageResolver: resolver),
      );
      final half = await _pixels(
        await _render(
          [element.copyWith(opacity: 0.5)],
          imageResolver: resolver,
        ),
      );
      final invisible = await _pixels(
        await _render(
          [element.copyWith(opacity: 0)],
          imageResolver: resolver,
        ),
      );

      expect(_pixelAt(opaque, 200, 100, 100).a, closeTo(1, 0.02));
      expect(_pixelAt(half, 200, 100, 100).a, closeTo(0.5, 0.05));
      expect(_pixelAt(invisible, 200, 100, 100).a, closeTo(0, 0.02));
    });

    test('rotation expands the painted bounds', () async {
      final source = await _image();
      const element = ImageWatermark(
        id: 'image',
        rect: NormalizedRect.fromLTWH(0.35, 0.35, 0.3, 0.3),
        assetId: 'asset',
      );
      WatermarkImageResolver resolver(String _) => source;

      final straight = _alphaBounds(
        await _pixels(await _render([element], imageResolver: resolver)),
        200,
        200,
      );
      final rotated = _alphaBounds(
        await _pixels(
          await _render(
            [element.copyWith(rotationDeg: 45)],
            imageResolver: resolver,
          ),
        ),
        200,
        200,
      );

      expect(rotated.width, greaterThan(straight.width));
      expect(rotated.height, greaterThan(straight.height));
    });

    test('crop selects a distinct window of the source image', () async {
      final source = await _image(split: true);
      const element = ImageWatermark(
        id: 'image',
        rect: NormalizedRect.fromLTWH(0.25, 0.25, 0.5, 0.5),
        assetId: 'asset',
        crop: CropRect.fromLTWH(0, 0, 0.5, 1),
      );
      WatermarkImageResolver resolver(String _) => source;

      final left = _pixelAt(
        await _pixels(await _render([element], imageResolver: resolver)),
        200,
        100,
        100,
      );
      final right = _pixelAt(
        await _pixels(
          await _render(
            [element.copyWith(crop: const CropRect.fromLTWH(0.5, 0, 0.5, 1))],
            imageResolver: resolver,
          ),
        ),
        200,
        100,
        100,
      );

      expect(left.r, greaterThan(0.8));
      expect(left.b, lessThan(0.2));
      expect(right.b, greaterThan(0.8));
      expect(right.r, lessThan(0.2));
    });

    test('a background plate adds pixels around the text block', () async {
      const text = TextWatermark(
        id: 'text',
        rect: NormalizedRect.fromLTWH(0.2, 0.4, 0.6, 0.2),
        content: 'AA',
        sizeLogical: 60,
      );

      final plainBytes = await _renderBytes([text]);
      final plateBytes = await _renderBytes([
        text.copyWith(
          background: const BackgroundSpec(
            colorArgb: 0xFFFF0000,
            paddingLogical: 10,
            radiusLogical: 4,
          ),
        ),
      ]);

      expect(plateBytes, isNot(equals(plainBytes)));
      expect(
        _alphaCoverage(plateBytes),
        greaterThan(_alphaCoverage(plainBytes)),
      );
    });

    test('the background wraps the block expanded by the padding', () async {
      const element = TextWatermark(
        id: 'text',
        rect: NormalizedRect.fromLTWH(0.2, 0.4, 0.6, 0.1),
        content: 'A',
        sizeLogical: 20,
        background: BackgroundSpec(
          colorArgb: 0xFFFF0000,
          paddingLogical: 10,
          radiusLogical: 0,
        ),
      );

      final bounds = _alphaBounds(
        await _renderBytes([element], pageSize: const Size(1000, 1000)),
        1000,
        1000,
      );

      expect(bounds.left, closeTo(190, 2));
      expect(bounds.right, closeTo(810, 2));
    });

    test('an outline adds pixels behind the fill', () async {
      const text = TextWatermark(
        id: 'text',
        rect: NormalizedRect.fromLTWH(0.2, 0.4, 0.6, 0.2),
        content: 'A',
        sizeLogical: 60,
      );

      final plainBytes = await _renderBytes([text]);
      final outlinedBytes = await _renderBytes([
        text.copyWith(
          outline: const OutlineSpec(
            widthLogical: 20,
            colorArgb: 0xFFFF0000,
          ),
        ),
      ]);

      expect(outlinedBytes, isNot(equals(plainBytes)));
    });

    test('a missing image asset paints nothing', () async {
      const element = ImageWatermark(
        id: 'image',
        rect: NormalizedRect.fromLTWH(0.25, 0.25, 0.5, 0.5),
        assetId: 'missing',
      );

      final bytes = await _renderBytes([element]);

      expect(_alphaCoverage(bytes), 0);
    });
  });
}

Future<ui.Image> _image({bool split = false}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (split) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 20, 40),
      Paint()..color = const Color(0xFFFF0000),
    );
    canvas.drawRect(
      const Rect.fromLTWH(20, 0, 20, 40),
      Paint()..color = const Color(0xFF0000FF),
    );
  } else {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 40, 40),
      Paint()..color = const Color(0xFF3366FF),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 40);
  picture.dispose();

  return image;
}

Future<ui.Image> _render(
  List<WatermarkElement> elements, {
  Size pageSize = const Size(200, 200),
  WatermarkImageResolver? imageResolver,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintWatermarkElements(
    canvas,
    pageSize,
    elements,
    imageResolver ?? (String _) => null,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    pageSize.width.round(),
    pageSize.height.round(),
  );
  picture.dispose();

  return image;
}

Future<Uint8List> _renderBytes(
  List<WatermarkElement> elements, {
  Size pageSize = const Size(200, 200),
}) async {
  return _pixels(await _render(elements, pageSize: pageSize));
}

Future<Uint8List> _pixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  final bytes = data!;

  return bytes.buffer.asUint8List(
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );
}

Color _pixelAt(Uint8List rgba, int width, int x, int y) {
  final offset = (y * width + x) * 4;

  return Color.fromARGB(
    rgba[offset + 3],
    rgba[offset],
    rgba[offset + 1],
    rgba[offset + 2],
  );
}

int _alphaCoverage(Uint8List rgba) {
  var count = 0;
  for (var index = 3; index < rgba.length; index += 4) {
    if (rgba[index] > 0) count += 1;
  }

  return count;
}

Rect _alphaBounds(Uint8List rgba, int width, int height) {
  var minX = width;
  var minY = height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (rgba[(y * width + x) * 4 + 3] == 0) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX < 0) return Rect.zero;

  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    (maxX + 1).toDouble(),
    (maxY + 1).toDouble(),
  );
}
