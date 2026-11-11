import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import '../../../../domain/entities/normalized_rect.dart';
import '../../../../domain/services/watermark_geometry.dart';

/// The pointer part of a selected element a drag started on.
enum ElementGrabKind { none, move, rotate, resize }

/// What a pan gesture grabbed before it produced a delta.
///
/// The canvas asks for a grab once per drag, then feeds the delta to the
/// domain geometry (`WatermarkGeometry`). Keeping the decision here — as a
/// pure function of a pointer position — is what makes the gesture
/// behaviour testable without pumping a widget.
final class ElementGrab {
  const ElementGrab._(this.kind, this.handle);

  const ElementGrab.none() : this._(ElementGrabKind.none, null);

  const ElementGrab.move() : this._(ElementGrabKind.move, null);

  const ElementGrab.rotate() : this._(ElementGrabKind.rotate, null);

  const ElementGrab.resize(ResizeHandle handle)
    : this._(ElementGrabKind.resize, handle);

  final ElementGrabKind kind;

  /// Which edge or corner is being dragged, for a resize grab.
  final ResizeHandle? handle;

  bool get isNone => kind == ElementGrabKind.none;

  bool get isTransforming => kind != ElementGrabKind.none;
}

/// The rectangle an element's unrotated frame occupies in page pixels.
Rect elementFrame(NormalizedRect rect, Size pageSize) => rect.toRect(pageSize);

/// Rotates [vector] clockwise by [degrees], in Flutter's y-down space.
Offset rotateVector(Offset vector, double degrees) {
  final normalized = normalizeDegrees(degrees);
  if (normalized == 0) return vector;

  final radians = normalized * math.pi / 180;
  final cos = math.cos(radians);
  final sin = math.sin(radians);

  return Offset(
    vector.dx * cos - vector.dy * sin,
    vector.dx * sin + vector.dy * cos,
  );
}

/// Moves [point] by [vector] rotated by [degrees] around the origin.
Offset rotateAround(Offset point, Offset center, double degrees) {
  return center + rotateVector(point - center, degrees);
}

/// Which part of [rect] a pointer at [point] grabbed.
///
/// [point] is in page pixels, matching the coordinate space the shared
/// painter draws in. The element's rotation is undone before the hit test,
/// so a handle stays clickable however the element is turned.
ElementGrab resolveElementGrab({
  required Offset point,
  required NormalizedRect rect,
  required double rotationDeg,
  required Size pageSize,
  required double handleRadius,
  required double rotationOffset,
  required double rotationHandleRadius,
}) {
  final frame = elementFrame(rect, pageSize);
  if (frame.isEmpty) return const ElementGrab.none();

  final center = frame.center;
  final local = rotateVector(point - center, -rotationDeg);
  final localFrame = Rect.fromCenter(
    center: Offset.zero,
    width: frame.width,
    height: frame.height,
  );
  if (localFrame.isEmpty) return const ElementGrab.none();

  final rotationHandle = Offset(0, localFrame.top - rotationOffset);
  if ((local - rotationHandle).distance <= rotationHandleRadius) {
    return const ElementGrab.rotate();
  }

  const corners = <ResizeHandle>[
    ResizeHandle.topLeft,
    ResizeHandle.topRight,
    ResizeHandle.bottomRight,
    ResizeHandle.bottomLeft,
  ];
  for (final handle in corners) {
    if ((local - _localHandle(handle, localFrame)).distance <= handleRadius) {
      return ElementGrab.resize(handle);
    }
  }

  const edges = <ResizeHandle>[
    ResizeHandle.top,
    ResizeHandle.right,
    ResizeHandle.bottom,
    ResizeHandle.left,
  ];
  for (final handle in edges) {
    if ((local - _localHandle(handle, localFrame)).distance <= handleRadius) {
      return ElementGrab.resize(handle);
    }
  }

  if (localFrame.contains(local)) return const ElementGrab.move();

  return const ElementGrab.none();
}

/// Where an edge handle sits, in page pixels, for the selection chrome.
Offset edgeHandlePoint(
  ResizeHandle handle,
  NormalizedRect rect,
  Size pageSize,
  double rotationDeg,
) {
  final frame = elementFrame(rect, pageSize);
  final localFrame = Rect.fromCenter(
    center: Offset.zero,
    width: frame.width,
    height: frame.height,
  );

  return rotateAround(
    _localHandle(handle, localFrame),
    frame.center,
    rotationDeg,
  );
}

/// The rotation an element gets from dragging its rotation handle.
///
/// [center] is the element centre and both points are page pixels, so the
/// angle stays correct on a page that is not square. The result is the
/// initial rotation plus the angle the pointer swept.
double rotationFromDrag({
  required Offset center,
  required Offset grabPoint,
  required Offset dragPoint,
  required double initialRotationDeg,
}) {
  final start = _angleFromCenter(center, grabPoint);
  final current = _angleFromCenter(center, dragPoint);
  var delta = (current - start) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;

  return normalizeDegrees(initialRotationDeg + delta);
}

/// Projects a pixel drag back into normalized page units.
NormalizedOffset normalizedDelta(Offset delta, Size pageSize) {
  if (pageSize.width <= 0 || pageSize.height <= 0) {
    return const NormalizedOffset.zero();
  }

  return NormalizedOffset(
    delta.dx / pageSize.width,
    delta.dy / pageSize.height,
  );
}

/// The corner or edge of a crop window a pointer grabbed, if any.
///
/// [cropRect] is the crop window projected into widget pixels; a pointer
/// outside the window grabs nothing.
CropHandle? resolveCropGrab({
  required Offset point,
  required Rect cropRect,
  required double handleRadius,
}) {
  if (cropRect.isEmpty) return null;

  const corners = <CropHandle>[
    CropHandle.topLeft,
    CropHandle.topRight,
    CropHandle.bottomRight,
    CropHandle.bottomLeft,
  ];
  for (final handle in corners) {
    if ((point - _localCropHandle(handle, cropRect)).distance <=
        handleRadius) {
      return handle;
    }
  }

  const edges = <CropHandle>[
    CropHandle.top,
    CropHandle.right,
    CropHandle.bottom,
    CropHandle.left,
  ];
  for (final handle in edges) {
    if ((point - _localCropHandle(handle, cropRect)).distance <=
        handleRadius) {
      return handle;
    }
  }

  if (cropRect.contains(point)) return CropHandle.move;

  return null;
}

/// The crop window in widget pixels for a natural-size image drawn into
/// [bounds] while preserving its aspect ratio.
Rect cropWindowRect(CropRect crop, Rect bounds) {
  return Rect.fromLTWH(
    bounds.left + crop.x * bounds.width,
    bounds.top + crop.y * bounds.height,
    crop.w * bounds.width,
    crop.h * bounds.height,
  );
}

/// The letterboxed draw area of an image with [natural] size inside
/// [available], preserving aspect ratio.
Rect containRect(Size available, Size natural) {
  if (available.width <= 0 ||
      available.height <= 0 ||
      natural.width <= 0 ||
      natural.height <= 0) {
    return Offset.zero & available;
  }

  final scale = math.min(
    available.width / natural.width,
    available.height / natural.height,
  );
  final width = natural.width * scale;
  final height = natural.height * scale;

  return Rect.fromLTWH(
    (available.width - width) / 2,
    (available.height - height) / 2,
    width,
    height,
  );
}

double normalizeDegrees(double degrees) {
  final result = degrees % 360;

  return result < 0 ? result + 360 : result;
}

Offset _localHandle(ResizeHandle handle, Rect frame) {
  return switch (handle) {
    ResizeHandle.topLeft => frame.topLeft,
    ResizeHandle.topRight => frame.topRight,
    ResizeHandle.bottomRight => frame.bottomRight,
    ResizeHandle.bottomLeft => frame.bottomLeft,
    ResizeHandle.top => Offset(frame.center.dx, frame.top),
    ResizeHandle.right => Offset(frame.right, frame.center.dy),
    ResizeHandle.bottom => Offset(frame.center.dx, frame.bottom),
    ResizeHandle.left => Offset(frame.left, frame.center.dy),
  };
}

Offset _localCropHandle(CropHandle handle, Rect rect) {
  return switch (handle) {
    CropHandle.topLeft => rect.topLeft,
    CropHandle.topRight => rect.topRight,
    CropHandle.bottomRight => rect.bottomRight,
    CropHandle.bottomLeft => rect.bottomLeft,
    CropHandle.top => Offset(rect.center.dx, rect.top),
    CropHandle.right => Offset(rect.right, rect.center.dy),
    CropHandle.bottom => Offset(rect.center.dx, rect.bottom),
    CropHandle.left => Offset(rect.left, rect.center.dy),
    CropHandle.move => rect.center,
  };
}

double _angleFromCenter(Offset center, Offset point) {
  final dx = point.dx - center.dx;
  final dy = point.dy - center.dy;
  final degrees = math.atan2(dx, -dy) * 180 / math.pi;

  return normalizeDegrees(degrees);
}
