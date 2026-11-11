import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import '../entities/normalized_rect.dart';

/// The eight grab handles around a selected element.
enum ResizeHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

/// The eight crop-window handles plus the body drag.
enum CropHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
  move,
}

/// Pure geometry for the watermark editor.
///
/// Every function is a value-in/value-out transform on normalized
/// rectangles: no Flutter widgets, no providers, no side effects. That is
/// what lets the interaction rules be unit-tested without a device, and
/// what keeps the editor's preview and the exporter agreeing on a
/// position.
abstract final class WatermarkGeometry {
  /// The smallest an element may become, as a fraction of the page.
  static const double minNormalizedSize = 0.02;

  /// Whether [point] lies inside [rect] after undoing a rotation of
  /// [rotationDeg] around the rect's centre.
  static bool hitTest(
    NormalizedRect rect,
    NormalizedOffset point,
    double rotationDeg,
  ) {
    if (rect.isEmpty) return false;
    final unrotated = rotatePoint(point, rect.center, -rotationDeg);

    return rect.contains(unrotated);
  }

  /// Rotates [point] around [center] by [degrees] (clockwise).
  static NormalizedOffset rotatePoint(
    NormalizedOffset point,
    NormalizedOffset center,
    double degrees,
  ) {
    final normalized = _normalizeDegrees(degrees);
    if (normalized == 0) return point;

    final radians = normalized * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;

    return NormalizedOffset(
      center.dx + dx * cos - dy * sin,
      center.dy + dx * sin + dy * cos,
    );
  }

  /// The angle of [point] around [center], measured clockwise from 12
  /// o'clock and normalized to `[0, 360)`.
  static double angleFromCenter(
    NormalizedOffset center,
    NormalizedOffset point,
  ) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    final degrees = math.atan2(dx, -dy) * 180 / math.pi;

    return _normalizeDegrees(degrees);
  }

  /// The rotation a handle drag produces.
  ///
  /// [grabPoint] is where the rotation handle was pressed, [dragPoint] the
  /// current pointer position, and [initialRotationDeg] the element's
  /// rotation when the drag started. The result is the initial rotation
  /// plus the angular distance the pointer travelled.
  static double rotateHandle({
    required NormalizedOffset center,
    required NormalizedOffset grabPoint,
    required NormalizedOffset dragPoint,
    required double initialRotationDeg,
  }) {
    final start = angleFromCenter(center, grabPoint);
    final current = angleFromCenter(center, dragPoint);
    final delta = _shortestDelta(start, current);

    return _normalizeDegrees(initialRotationDeg + delta);
  }

  /// Where the rotation handle sits for [rect]: above the top edge, by
  /// [offset] of the page height.
  static NormalizedOffset rotationHandlePosition(
    NormalizedRect rect, {
    double offset = 0.04,
  }) {
    return NormalizedOffset(rect.center.dx, rect.y - offset);
  }

  /// Moves [rect] by [delta], clamped so the element cannot leave the page.
  static NormalizedRect translate(
    NormalizedRect rect,
    NormalizedOffset delta,
  ) {
    return rect.translated(delta).clampToPage();
  }

  /// Resizes [rect] by dragging [handle] by [delta].
  ///
  /// With [lockAspect] the opposite edge/corner stays anchored and the
  /// other dimension follows the source image's aspect ratio. The result
  /// never gets smaller than [minSize] and never leaves the page.
  static NormalizedRect resize(
    NormalizedRect rect,
    ResizeHandle handle,
    NormalizedOffset delta, {
    bool lockAspect = false,
    double minSize = minNormalizedSize,
  }) {
    var left = rect.x;
    var top = rect.y;
    var right = rect.right;
    var bottom = rect.bottom;

    switch (handle) {
      case ResizeHandle.topLeft:
        left += delta.dx;
        top += delta.dy;
      case ResizeHandle.top:
        top += delta.dy;
      case ResizeHandle.topRight:
        right += delta.dx;
        top += delta.dy;
      case ResizeHandle.right:
        right += delta.dx;
      case ResizeHandle.bottomRight:
        right += delta.dx;
        bottom += delta.dy;
      case ResizeHandle.bottom:
        bottom += delta.dy;
      case ResizeHandle.bottomLeft:
        left += delta.dx;
        bottom += delta.dy;
      case ResizeHandle.left:
        left += delta.dx;
    }

    if (right - left < minSize) {
      if (handle == ResizeHandle.left ||
          handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.bottomLeft) {
        left = right - minSize;
      } else {
        right = left + minSize;
      }
    }
    if (bottom - top < minSize) {
      if (handle == ResizeHandle.top ||
          handle == ResizeHandle.topLeft ||
          handle == ResizeHandle.topRight) {
        top = bottom - minSize;
      } else {
        bottom = top + minSize;
      }
    }

    final candidate = NormalizedRect.fromLTWH(
      left,
      top,
      right - left,
      bottom - top,
    );
    if (!lockAspect || candidate.isEmpty) {
      return candidate.clampToPage();
    }

    return _resizeLockedAspect(rect, candidate, handle, minSize)
        .clampToPage();
  }

  /// The nearest point inside the page for [rect], preserving its size.
  static NormalizedRect clampToPage(NormalizedRect rect) =>
      rect.clampToPage();

  /// Moves the layer at [index] to the top of the paint order.
  static List<T> bringToFront<T>(List<T> layers, int index) {
    return _move(layers, index, layers.length - 1);
  }

  /// Moves the layer at [index] to the bottom of the paint order.
  static List<T> sendToBack<T>(List<T> layers, int index) =>
      _move(layers, index, 0);

  /// Moves the layer at [index] one step toward the top.
  static List<T> moveForward<T>(List<T> layers, int index) =>
      _move(layers, index, index + 1);

  /// Moves the layer at [index] one step toward the bottom.
  static List<T> moveBackward<T>(List<T> layers, int index) =>
      _move(layers, index, index - 1);

  /// Applies a drag to a crop window, clamped to the source bounds.
  ///
  /// [minSize] is the smallest crop edge, in normalized units, so a crop
  /// can never collapse to nothing.
  static CropRect applyCropDrag(
    CropRect crop,
    CropHandle handle,
    NormalizedOffset delta,
    double minSize,
  ) {
    var left = crop.x;
    var top = crop.y;
    var right = crop.right;
    var bottom = crop.bottom;

    switch (handle) {
      case CropHandle.move:
        final width = crop.w;
        final height = crop.h;
        final maxX = (1 - width) < 0 ? 0.0 : 1 - width;
        final maxY = (1 - height) < 0 ? 0.0 : 1 - height;
        left = (left + delta.dx).clamp(0.0, maxX).toDouble();
        top = (top + delta.dy).clamp(0.0, maxY).toDouble();

        return CropRect.fromLTWH(left, top, width, height);
      case CropHandle.topLeft:
        left += delta.dx;
        top += delta.dy;
      case CropHandle.top:
        top += delta.dy;
      case CropHandle.topRight:
        right += delta.dx;
        top += delta.dy;
      case CropHandle.right:
        right += delta.dx;
      case CropHandle.bottomRight:
        right += delta.dx;
        bottom += delta.dy;
      case CropHandle.bottom:
        bottom += delta.dy;
      case CropHandle.bottomLeft:
        left += delta.dx;
        bottom += delta.dy;
      case CropHandle.left:
        left += delta.dx;
    }

    left = left.clamp(0.0, 1 - minSize).toDouble();
    right = right.clamp(minSize, 1.0).toDouble();
    top = top.clamp(0.0, 1 - minSize).toDouble();
    bottom = bottom.clamp(minSize, 1.0).toDouble();

    final movesLeftEdge = handle == CropHandle.left ||
        handle == CropHandle.topLeft ||
        handle == CropHandle.bottomLeft;
    if (right - left < minSize) {
      if (movesLeftEdge) {
        left = right - minSize;
      } else {
        right = left + minSize;
      }
    }

    final movesTopEdge = handle == CropHandle.top ||
        handle == CropHandle.topLeft ||
        handle == CropHandle.topRight;
    if (bottom - top < minSize) {
      if (movesTopEdge) {
        top = bottom - minSize;
      } else {
        bottom = top + minSize;
      }
    }

    return CropRect.fromLTWH(left, top, right - left, bottom - top);
  }

  /// The source-image pixel rectangle for [crop].
  static Rect cropToSrcRect(CropRect crop, Size naturalSize) =>
      crop.toSrcRect(naturalSize);

  static NormalizedRect _resizeLockedAspect(
    NormalizedRect original,
    NormalizedRect candidate,
    ResizeHandle handle,
    double minSize,
  ) {
    final aspect = original.h == 0 ? 1.0 : original.w / original.h;
    final horizontal = switch (handle) {
      ResizeHandle.left ||
      ResizeHandle.right ||
      ResizeHandle.topLeft ||
      ResizeHandle.topRight ||
      ResizeHandle.bottomLeft ||
      ResizeHandle.bottomRight => true,
      ResizeHandle.top || ResizeHandle.bottom => false,
    };

    var width = horizontal ? candidate.w : candidate.h * aspect;
    var height = horizontal ? candidate.w / aspect : candidate.h;

    if (width < minSize) {
      width = minSize;
      height = width / aspect;
    }
    if (height < minSize) {
      height = minSize;
      width = height * aspect;
    }

    final center = original.center;
    final anchorX = switch (handle) {
      ResizeHandle.topLeft ||
      ResizeHandle.bottomLeft ||
      ResizeHandle.left => original.right,
      ResizeHandle.topRight ||
      ResizeHandle.bottomRight ||
      ResizeHandle.right => original.x,
      ResizeHandle.top || ResizeHandle.bottom => center.dx,
    };
    final anchorY = switch (handle) {
      ResizeHandle.topLeft ||
      ResizeHandle.topRight ||
      ResizeHandle.top => original.bottom,
      ResizeHandle.bottomLeft ||
      ResizeHandle.bottomRight ||
      ResizeHandle.bottom => original.y,
      ResizeHandle.left || ResizeHandle.right => center.dy,
    };

    final left = switch (handle) {
      ResizeHandle.topLeft ||
      ResizeHandle.bottomLeft ||
      ResizeHandle.left => anchorX - width,
      ResizeHandle.topRight ||
      ResizeHandle.bottomRight ||
      ResizeHandle.right => anchorX,
      ResizeHandle.top || ResizeHandle.bottom => anchorX - width / 2,
    };
    final top = switch (handle) {
      ResizeHandle.topLeft ||
      ResizeHandle.topRight ||
      ResizeHandle.top => anchorY - height,
      ResizeHandle.bottomLeft ||
      ResizeHandle.bottomRight ||
      ResizeHandle.bottom => anchorY,
      ResizeHandle.left || ResizeHandle.right => anchorY - height / 2,
    };

    return NormalizedRect.fromLTWH(left, top, width, height);
  }

  static List<T> _move<T>(List<T> layers, int from, int to) {
    if (from < 0 || from >= layers.length) return layers;
    final target = to.clamp(0, layers.length - 1).toInt();
    if (target == from) return List<T>.of(layers);

    final copy = List<T>.of(layers);
    final item = copy.removeAt(from);
    copy.insert(target, item);

    return copy;
  }

  static double _normalizeDegrees(double degrees) {
    final result = degrees % 360;

    return result < 0 ? result + 360 : result;
  }

  /// The signed shortest angular distance from [from] to [to].
  static double _shortestDelta(double from, double to) {
    var delta = (to - from) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;

    return delta;
  }
}
