import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/entities/normalized_rect.dart';
import '../../../../domain/entities/watermark_element.dart';
import '../../../../domain/services/watermark_geometry.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/watermark/elements_overlay.dart';
import '../../../core/widgets/watermark/watermark_canvas.dart';
import '../controller/editor_controller.dart';
import '../controller/editor_gestures.dart';

/// The interactive watermark canvas.
///
/// Painting and tap selection come from T4's [ElementsOverlay] — the same
/// painter the exporter uses — and this widget adds the gestures the
/// editor needs: drag to move, corners and edges to resize, and the stem
/// above the frame to rotate. Locked elements can be selected but a drag
/// never changes them.
class WatermarkGestureLayer extends StatefulWidget {
  const WatermarkGestureLayer({
    required this.controller,
    required this.pageSize,
    required this.imageResolver,
    this.child,
    super.key,
  });

  final EditorController controller;

  /// The rendered page's size in logical pixels — the space the painter
  /// and the gesture math share.
  final Size pageSize;

  final WatermarkImageResolver imageResolver;

  /// The document page preview under the elements.
  final Widget? child;

  @override
  State<WatermarkGestureLayer> createState() => _WatermarkGestureLayerState();
}

class _WatermarkGestureLayerState extends State<WatermarkGestureLayer> {
  ElementGrabKind _kind = ElementGrabKind.none;
  ResizeHandle? _handle;
  String? _activeId;
  NormalizedRect _startRect = const NormalizedRect.full();
  double _startRotation = 0;
  Offset _startPoint = Offset.zero;
  Offset _lastPoint = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final selected = controller.selectedElement;
    final colors = context.color.docMark;
    final dims = context.dimensions.docMark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => _start(details.localPosition),
      onPanUpdate: (details) => _update(details.localPosition),
      onPanEnd: (_) => _end(),
      onPanCancel: _end,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ElementsOverlay(
            elements: controller.elementsForCurrentPage,
            pageSize: widget.pageSize,
            imageResolver: widget.imageResolver,
            selectedId: controller.selectedId,
            onSelect: controller.select,
            child: widget.child,
          ),
          if (selected != null)
            IgnorePointer(
              child: CustomPaint(
                painter: _EdgeHandlesPainter(
                  element: selected,
                  pageSize: widget.pageSize,
                  handleFill: colors.elementHandle,
                  handleBorder: colors.elementHandleBorder,
                  radius: dims.elementHandle / 2,
                  strokeWidth: dims.selectionStroke,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _start(Offset point) {
    final controller = widget.controller;
    final pageSize = widget.pageSize;
    if (pageSize.isEmpty) return;

    final dims = context.dimensions.docMark;
    final radius = dims.elementHandleTouch / 2;
    var selected = controller.selectedElement;
    var grab = _resolveGrab(selected, point, radius, dims.rotationHandleOffset);

    if (selected == null || grab.isNone) {
      final hitId = _hitTest(point);
      if (hitId == null) return;
      controller.select(hitId);
      selected = controller.selectedElement;
      grab = _resolveGrab(selected, point, radius, dims.rotationHandleOffset);
    }
    if (selected == null) return;

    _activeId = selected.id;
    _startRect = selected.rect;
    _startRotation = selected.rotationDeg;
    _startPoint = point;
    _lastPoint = point;
    _handle = grab.handle;

    if (!selected.locked && grab.isTransforming) {
      _kind = grab.kind;
    } else {
      _kind = ElementGrabKind.none;
    }
  }

  ElementGrab _resolveGrab(
    WatermarkElement? element,
    Offset point,
    double radius,
    double rotationOffset,
  ) {
    if (element == null) return const ElementGrab.none();

    return resolveElementGrab(
      point: point,
      rect: element.rect,
      rotationDeg: element.rotationDeg,
      pageSize: widget.pageSize,
      handleRadius: radius,
      rotationOffset: rotationOffset,
      rotationHandleRadius: radius,
    );
  }

  void _update(Offset point) {
    final id = _activeId;
    final pageSize = widget.pageSize;
    if (id == null || _kind == ElementGrabKind.none || pageSize.isEmpty) {
      return;
    }

    final controller = widget.controller;

    switch (_kind) {
      case ElementGrabKind.move:
        final delta = normalizedDelta(point - _lastPoint, pageSize);
        _lastPoint = point;
        controller.moveBy(id, delta);
      case ElementGrabKind.resize:
        final handle = _handle;
        if (handle == null) return;
        final element = _element(id);
        final lockAspect = element is ImageWatermark && element.lockAspect;
        final total = normalizedDelta(point - _startPoint, pageSize);
        controller.setRect(
          id,
          WatermarkGeometry.resize(
            _startRect,
            handle,
            total,
            lockAspect: lockAspect,
            minSize: context.dimensions.docMark.minElementSize,
          ),
        );
      case ElementGrabKind.rotate:
        final center = elementFrame(_startRect, pageSize).center;
        controller.setRotation(
          id,
          rotationFromDrag(
            center: center,
            grabPoint: _startPoint,
            dragPoint: point,
            initialRotationDeg: _startRotation,
          ),
        );
      case ElementGrabKind.none:
        return;
    }
  }

  void _end() {
    _kind = ElementGrabKind.none;
    _handle = null;
    _activeId = null;
  }

  String? _hitTest(Offset point) {
    final pageSize = widget.pageSize;
    if (pageSize.isEmpty) return null;

    final normalized = NormalizedOffset.fromOffset(point, pageSize);
    for (final element in widget.controller.elementsForCurrentPage.reversed) {
      if (!element.visible) continue;
      if (WatermarkGeometry.hitTest(
        element.rect,
        normalized,
        element.rotationDeg,
      )) {
        return element.id;
      }
    }

    return null;
  }

  WatermarkElement? _element(String id) {
    for (final element in widget.controller.config.elements) {
      if (element.id == id) return element;
    }

    return null;
  }
}

/// The four mid-edge handles, drawn where the corner handles are not.
///
/// T4's painter owns the frame and corners; the editor needs edge handles
/// too because a watermark is often stretched on one axis only.
class _EdgeHandlesPainter extends CustomPainter {
  const _EdgeHandlesPainter({
    required this.element,
    required this.pageSize,
    required this.handleFill,
    required this.handleBorder,
    required this.radius,
    required this.strokeWidth,
  });

  final WatermarkElement element;
  final Size pageSize;
  final Color handleFill;
  final Color handleBorder;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (pageSize.isEmpty) return;

    final frame = elementFrame(element.rect, pageSize);
    if (frame.isEmpty) return;

    final local = Rect.fromCenter(
      center: Offset.zero,
      width: frame.width,
      height: frame.height,
    );

    canvas.save();
    canvas.translate(frame.center.dx, frame.center.dy);
    canvas.rotate(element.rotationDeg * math.pi / 180);

    final fill = Paint()..color = handleFill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = handleBorder;

    for (final point in <Offset>[
      Offset(local.center.dx, local.top),
      Offset(local.right, local.center.dy),
      Offset(local.center.dx, local.bottom),
      Offset(local.left, local.center.dy),
    ]) {
      canvas.drawCircle(point, radius, fill);
      canvas.drawCircle(point, radius, border);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EdgeHandlesPainter oldDelegate) {
    return oldDelegate.element != element ||
        oldDelegate.pageSize != pageSize ||
        oldDelegate.handleFill != handleFill ||
        oldDelegate.handleBorder != handleBorder ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
