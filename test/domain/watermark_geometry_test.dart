import 'dart:ui' show Size;

import 'package:docmark/src/domain/entities/normalized_rect.dart';
import 'package:docmark/src/domain/services/watermark_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rect = NormalizedRect.fromLTWH(0.2, 0.2, 0.4, 0.4);

  group('NormalizedRect', () {
    test('converts to and from pixel space', () {
      const size = Size(200, 400);
      final pixels = rect.toRect(size);

      expect(pixels.left, closeTo(40, 1e-9));
      expect(pixels.top, closeTo(80, 1e-9));
      expect(pixels.width, closeTo(80, 1e-9));
      expect(pixels.height, closeTo(160, 1e-9));
      expect(
        NormalizedRect.fromRect(pixels, size).nearlyEquals(rect),
        isTrue,
        reason: 'the projection is exact up to floating-point rounding',
      );
    });

    test('clamps a rectangle inside the page', () {
      const escaped = NormalizedRect.fromLTWH(1.1, -0.1, 0.2, 0.2);
      final clamped = escaped.clampToPage();

      expect(clamped.x, closeTo(0.8, 1e-9));
      expect(clamped.y, 0);
      expect(clamped.w, 0.2);
    });
  });

  group('WatermarkGeometry.translate', () {
    test('moves by the normalized delta', () {
      final moved = WatermarkGeometry.translate(
        rect,
        const NormalizedOffset(0.1, 0.05),
      );

      expect(moved.x, closeTo(0.3, 1e-9));
      expect(moved.y, closeTo(0.25, 1e-9));
      expect(moved.w, 0.4);
    });

    test('stops at the page edge', () {
      final moved = WatermarkGeometry.translate(
        rect,
        const NormalizedOffset(0.5, 0.5),
      );

      expect(moved.x, closeTo(0.6, 1e-9));
      expect(moved.y, closeTo(0.6, 1e-9));
    });

    test('stops at the top-left edge', () {
      final moved = WatermarkGeometry.translate(
        rect,
        const NormalizedOffset(-0.5, -0.5),
      );

      expect(moved.x, 0);
      expect(moved.y, 0);
    });
  });

  group('WatermarkGeometry.hitTest', () {
    test('accepts a point inside an unrotated rect', () {
      expect(
        WatermarkGeometry.hitTest(
          rect,
          const NormalizedOffset(0.4, 0.4),
          0,
        ),
        isTrue,
      );
    });

    test('rejects a point outside an unrotated rect', () {
      expect(
        WatermarkGeometry.hitTest(
          rect,
          const NormalizedOffset(0.09, 0.4),
          0,
        ),
        isFalse,
      );
    });

    test('a rotated rect reaches the point that its rotated corner covers',
        () {
      const point = NormalizedOffset(0.15, 0.4);

      expect(WatermarkGeometry.hitTest(rect, point, 0), isFalse);
      expect(WatermarkGeometry.hitTest(rect, point, 45), isTrue);
    });

    test('rejects a far-away point at any rotation', () {
      expect(
        WatermarkGeometry.hitTest(
          rect,
          const NormalizedOffset(0.9, 0.9),
          90,
        ),
        isFalse,
      );
    });
  });

  group('WatermarkGeometry.rotateHandle', () {
    const center = NormalizedOffset(0.5, 0.5);

    test('turns a 12 o-clock grab into 90 degrees at 3 o-clock', () {
      final rotation = WatermarkGeometry.rotateHandle(
        center: center,
        grabPoint: const NormalizedOffset(0.5, 0.4),
        dragPoint: const NormalizedOffset(0.6, 0.5),
        initialRotationDeg: 0,
      );

      expect(rotation, closeTo(90, 1e-6));
    });

    test('adds to the initial rotation', () {
      final rotation = WatermarkGeometry.rotateHandle(
        center: center,
        grabPoint: const NormalizedOffset(0.5, 0.4),
        dragPoint: const NormalizedOffset(0.6, 0.5),
        initialRotationDeg: 10,
      );

      expect(rotation, closeTo(100, 1e-6));
    });

    test('wraps past 360', () {
      final rotation = WatermarkGeometry.rotateHandle(
        center: center,
        grabPoint: const NormalizedOffset(0.5, 0.4),
        dragPoint: const NormalizedOffset(0.6, 0.5),
        initialRotationDeg: 350,
      );

      expect(rotation, closeTo(80, 1e-6));
    });

    test('takes the shortest path across the 0/360 seam', () {
      final rotation = WatermarkGeometry.rotateHandle(
        center: center,
        grabPoint: const NormalizedOffset(0.48264, 0.40152),
        dragPoint: const NormalizedOffset(0.51736, 0.40152),
        initialRotationDeg: 350,
      );

      expect(rotation, closeTo(10, 1e-3));
    });

    test('positions the handle above the rect', () {
      final handle = WatermarkGeometry.rotationHandlePosition(rect);

      expect(handle.dx, closeTo(0.4, 1e-9));
      expect(handle.dy, closeTo(0.16, 1e-9));
    });
  });

  group('WatermarkGeometry.resize', () {
    test('drags the bottom-right corner', () {
      final resized = WatermarkGeometry.resize(
        rect,
        ResizeHandle.bottomRight,
        const NormalizedOffset(0.1, 0),
      );

      expect(resized.x, closeTo(0.2, 1e-9));
      expect(resized.w, closeTo(0.5, 1e-9));
      expect(resized.h, closeTo(0.4, 1e-9));
    });

    test('never shrinks below minSize', () {
      const small = NormalizedRect.fromLTWH(0.2, 0.2, 0.1, 0.1);
      final resized = WatermarkGeometry.resize(
        small,
        ResizeHandle.right,
        const NormalizedOffset(-0.5, 0),
      );

      expect(resized.w, closeTo(
        WatermarkGeometry.minNormalizedSize,
        1e-9,
      ));
    });

    test('keeps the source aspect ratio when locked', () {
      const wide = NormalizedRect.fromLTWH(0.2, 0.2, 0.4, 0.2);
      final resized = WatermarkGeometry.resize(
        wide,
        ResizeHandle.bottomRight,
        const NormalizedOffset(0.2, 0),
        lockAspect: true,
      );

      expect(resized.w, closeTo(0.6, 1e-9));
      expect(resized.h, closeTo(0.3, 1e-9));
    });

    test('anchors the opposite corner when locked and dragging top-left', () {
      const wide = NormalizedRect.fromLTWH(0.3, 0.3, 0.4, 0.2);
      final resized = WatermarkGeometry.resize(
        wide,
        ResizeHandle.topLeft,
        const NormalizedOffset(-0.2, 0),
        lockAspect: true,
      );

      expect(resized.x, closeTo(0.1, 1e-9));
      expect(resized.y, closeTo(0.2, 1e-9));
      expect(resized.w, closeTo(0.6, 1e-9));
      expect(resized.h, closeTo(0.3, 1e-9));
    });
  });

  group('WatermarkGeometry layer operations', () {
    final layers = ['a', 'b', 'c', 'd'];

    test('bringToFront moves to the end', () {
      expect(
        WatermarkGeometry.bringToFront(layers, 1),
        ['a', 'c', 'd', 'b'],
      );
    });

    test('sendToBack moves to the start', () {
      expect(WatermarkGeometry.sendToBack(layers, 2), ['c', 'a', 'b', 'd']);
    });

    test('moveForward swaps with the next layer', () {
      expect(WatermarkGeometry.moveForward(layers, 1), ['a', 'c', 'b', 'd']);
    });

    test('moveBackward swaps with the previous layer', () {
      expect(WatermarkGeometry.moveBackward(layers, 2), ['a', 'c', 'b', 'd']);
    });

    test('an out-of-range index leaves the order untouched', () {
      expect(WatermarkGeometry.bringToFront(layers, 9), layers);
      expect(WatermarkGeometry.moveForward(layers, 3), layers);
    });

    test('never mutates the input list', () {
      WatermarkGeometry.bringToFront(layers, 0);

      expect(layers, ['a', 'b', 'c', 'd']);
    });
  });

  group('crop math', () {
    test('applyCropDrag drags the left edge', () {
      final crop = WatermarkGeometry.applyCropDrag(
        const CropRect.full(),
        CropHandle.left,
        const NormalizedOffset(0.1, 0),
        0.05,
      );

      expect(crop.x, closeTo(0.1, 1e-9));
      expect(crop.w, closeTo(0.9, 1e-9));
    });

    test('applyCropDrag shrinks from the bottom-right', () {
      final crop = WatermarkGeometry.applyCropDrag(
        const CropRect.full(),
        CropHandle.bottomRight,
        const NormalizedOffset(-0.2, -0.2),
        0.05,
      );

      expect(crop.w, closeTo(0.8, 1e-9));
      expect(crop.h, closeTo(0.8, 1e-9));
    });

    test('applyCropDrag moves the whole window without leaving the image', () {
      const crop = CropRect.fromLTWH(0.2, 0.2, 0.3, 0.3);
      final moved = WatermarkGeometry.applyCropDrag(
        crop,
        CropHandle.move,
        const NormalizedOffset(0.9, 0.9),
        0.05,
      );

      expect(moved.x, closeTo(0.7, 1e-9));
      expect(moved.y, closeTo(0.7, 1e-9));
      expect(moved.w, closeTo(0.3, 1e-9));
    });

    test('applyCropDrag enforces the minimum size', () {
      const crop = CropRect.fromLTWH(0, 0, 0.2, 0.2);
      final resized = WatermarkGeometry.applyCropDrag(
        crop,
        CropHandle.right,
        const NormalizedOffset(-0.5, 0),
        0.05,
      );

      expect(resized.w, closeTo(0.05, 1e-9));
    });

    test('cropToSrcRect scales to the natural image size', () {
      const crop = CropRect.fromLTWH(0.1, 0.2, 0.5, 0.6);
      const natural = Size(1000, 2000);
      final src = WatermarkGeometry.cropToSrcRect(crop, natural);

      expect(src.left, closeTo(100, 1e-6));
      expect(src.top, closeTo(400, 1e-6));
      expect(src.width, closeTo(500, 1e-6));
      expect(src.height, closeTo(1200, 1e-6));
    });
  });
}
