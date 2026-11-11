import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:docmark/src/domain/entities/normalized_rect.dart';
import 'package:docmark/src/domain/services/watermark_geometry.dart';
import 'package:docmark/src/presentation/features/watermark_editor/controller/editor_gestures.dart';

void main() {
  const pageSize = Size(1000, 1000);
  const rect = NormalizedRect.fromLTWH(0.2, 0.2, 0.4, 0.4);
  const radius = 12.0;
  const rotationOffset = 32.0;

  ElementGrab grabAt(Offset point, {double rotation = 0}) {
    return resolveElementGrab(
      point: point,
      rect: rect,
      rotationDeg: rotation,
      pageSize: pageSize,
      handleRadius: radius,
      rotationOffset: rotationOffset,
      rotationHandleRadius: radius,
    );
  }

  group('resolveElementGrab', () {
    test('a pointer inside the frame grabs the body', () {
      expect(grabAt(const Offset(400, 400)).kind, ElementGrabKind.move);
    });

    test('the four corners and four edges grab their handles', () {
      expect(grabAt(const Offset(200, 200)).handle, ResizeHandle.topLeft);
      expect(grabAt(const Offset(600, 200)).handle, ResizeHandle.topRight);
      expect(grabAt(const Offset(600, 600)).handle, ResizeHandle.bottomRight);
      expect(grabAt(const Offset(200, 600)).handle, ResizeHandle.bottomLeft);
      expect(grabAt(const Offset(400, 200)).handle, ResizeHandle.top);
      expect(grabAt(const Offset(600, 400)).handle, ResizeHandle.right);
      expect(grabAt(const Offset(400, 600)).handle, ResizeHandle.bottom);
      expect(grabAt(const Offset(200, 400)).handle, ResizeHandle.left);
    });

    test('the stem above the frame grabs rotation', () {
      final handle = Offset(
        rect.center.dx * pageSize.width,
        rect.y * pageSize.height - rotationOffset,
      );

      expect(grabAt(handle).kind, ElementGrabKind.rotate);
    });

    test('a pointer outside the frame grabs nothing', () {
      expect(grabAt(const Offset(50, 50)).isNone, isTrue);
    });

    test('a rotated frame keeps its handles clickable', () {
      final topLeft = edgeHandlePoint(
        ResizeHandle.topLeft,
        rect,
        pageSize,
        90,
      );

      expect(topLeft.dx, closeTo(600, 0.001));
      expect(topLeft.dy, closeTo(200, 0.001));
      expect(grabAt(topLeft, rotation: 90).handle, ResizeHandle.topLeft);
    });
  });

  group('rotationFromDrag', () {
    test('a quarter turn clockwise from the top stem is 90 degrees', () {
      final rotation = rotationFromDrag(
        center: const Offset(500, 500),
        grabPoint: const Offset(500, 300),
        dragPoint: const Offset(700, 500),
        initialRotationDeg: 10,
      );

      expect(rotation, closeTo(100, 0.001));
    });

    test('the result wraps into 0..360', () {
      final rotation = rotationFromDrag(
        center: const Offset(500, 500),
        grabPoint: const Offset(500, 300),
        dragPoint: const Offset(300, 500),
        initialRotationDeg: 10,
      );

      expect(rotation, closeTo(280, 0.001));
    });
  });

  group('drag deltas', () {
    test('a pixel drag projects into normalized units', () {
      final delta = normalizedDelta(
        const Offset(100, 50),
        const Size(1000, 500),
      );

      expect(delta.dx, closeTo(0.1, 0.0001));
      expect(delta.dy, closeTo(0.1, 0.0001));
    });

    test('a zero-sized page yields no movement', () {
      final delta = normalizedDelta(const Offset(10, 10), Size.zero);

      expect(delta.isZero, isTrue);
    });
  });

  group('gesture to normalized rect', () {
    test('a corner drag resizes while the opposite corner stays anchored', () {
      final resized = WatermarkGeometry.resize(
        rect,
        ResizeHandle.bottomRight,
        const NormalizedOffset(0.1, 0.05),
        minSize: 0.02,
      );

      expect(resized.x, closeTo(0.2, 0.0001));
      expect(resized.y, closeTo(0.2, 0.0001));
      expect(resized.w, closeTo(0.5, 0.0001));
      expect(resized.h, closeTo(0.45, 0.0001));
    });

    test('a locked-aspect resize keeps the source ratio', () {
      final resized = WatermarkGeometry.resize(
        rect,
        ResizeHandle.right,
        const NormalizedOffset(0.2, 0),
        lockAspect: true,
        minSize: 0.02,
      );

      expect(resized.w / resized.h, closeTo(1, 0.0001));
      expect(resized.w, greaterThan(rect.w));
    });

    test('a drag translates and clamps inside the page', () {
      final moved = WatermarkGeometry.translate(
        rect,
        const NormalizedOffset(0.5, 0.5),
      );

      expect(moved.right, lessThanOrEqualTo(1));
      expect(moved.bottom, lessThanOrEqualTo(1));
      expect(moved.x, closeTo(0.6, 0.0001));
      expect(moved.y, closeTo(0.6, 0.0001));
    });
  });

  group('crop geometry', () {
    const window = Rect.fromLTWH(0, 0, 100, 100);

    test('corner, edge, body and outside grabs resolve', () {
      expect(
        resolveCropGrab(
          point: const Offset(0, 0),
          cropRect: window,
          handleRadius: radius,
        ),
        CropHandle.topLeft,
      );
      expect(
        resolveCropGrab(
          point: const Offset(100, 50),
          cropRect: window,
          handleRadius: radius,
        ),
        CropHandle.right,
      );
      expect(
        resolveCropGrab(
          point: const Offset(50, 50),
          cropRect: window,
          handleRadius: radius,
        ),
        CropHandle.move,
      );
      expect(
        resolveCropGrab(
          point: const Offset(300, 300),
          cropRect: window,
          handleRadius: radius,
        ),
        isNull,
      );
    });

    test('a crop window maps onto the letterboxed image bounds', () {
      final bounds = containRect(
        const Size(200, 400),
        const Size(400, 400),
      );
      expect(bounds, const Rect.fromLTWH(0, 100, 200, 200));

      final projected = cropWindowRect(
        const CropRect.fromLTWH(0.25, 0.5, 0.5, 0.5),
        bounds,
      );
      expect(projected, const Rect.fromLTWH(50, 200, 100, 100));
    });

    test('the domain crop drag keeps the window inside the source', () {
      final dragged = WatermarkGeometry.applyCropDrag(
        const CropRect.full(),
        CropHandle.right,
        const NormalizedOffset(-0.3, 0),
        0.05,
      );

      expect(dragged.w, closeTo(0.7, 0.0001));
      expect(dragged.x, closeTo(0, 0.0001));
      expect(dragged.isValid, isTrue);

      final moved = WatermarkGeometry.applyCropDrag(
        const CropRect.full(),
        CropHandle.move,
        const NormalizedOffset(0.5, 0.5),
        0.05,
      );
      expect(moved.x, closeTo(0, 0.0001));
      expect(moved.y, closeTo(0, 0.0001));

      final shrunk = WatermarkGeometry.applyCropDrag(
        const CropRect.full(),
        CropHandle.left,
        const NormalizedOffset(0.95, 0),
        0.05,
      );
      expect(shrunk.w, closeTo(0.05, 0.0001));
      expect(shrunk.isValid, isTrue);
    });
  });
}
