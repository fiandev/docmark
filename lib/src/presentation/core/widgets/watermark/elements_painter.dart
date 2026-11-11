import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../domain/entities/watermark_element.dart';
import '../../theme/theme.dart';
import 'watermark_canvas.dart';

export 'watermark_canvas.dart' show WatermarkImageResolver;

/// Paints the document page's watermark elements.
///
/// The element rendering itself lives in [paintWatermarkElements] — the
/// exact function the exporter calls — so the canvas and the exported file
/// can never drift apart. This class adds the editor-only chrome: the
/// selection frame, the corner handles and the rotation stem.
class ElementsPainter extends CustomPainter {
  const ElementsPainter({
    required this.elements,
    required this.pageSize,
    required this.imageResolver,
    this.selectedId,
    this.showSelection = true,
  });

  final List<WatermarkElement> elements;

  /// The page's pixel size at the preview scale — the space elements are
  /// projected into by `NormalizedRect.toRect`.
  final Size pageSize;

  final WatermarkImageResolver imageResolver;

  final String? selectedId;

  /// Whether to draw the selection frame and handles.
  final bool showSelection;

  @override
  void paint(Canvas canvas, Size size) {
    final resolvedSize = pageSize.isEmpty ? size : pageSize;
    if (resolvedSize.isEmpty) return;

    paintWatermarkElements(canvas, resolvedSize, elements, imageResolver);

    if (!showSelection || selectedId == null) return;

    for (final element in elements) {
      if (element.id == selectedId) {
        _paintSelection(canvas, resolvedSize, element);
        break;
      }
    }
  }

  void _paintSelection(
    Canvas canvas,
    Size pageSize,
    WatermarkElement element,
  ) {
    // The page itself is paper-white, so selection ink comes from the
    // light document tokens regardless of the app chrome's brightness.
    final tokens = const ColorExtension.light().docMark;
    final dims = const DimensionsExtension().docMark;

    final rect = element.rect.toRect(pageSize);
    if (rect.isEmpty) return;

    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(element.rotationDeg * math.pi / 180);

    final local = Rect.fromCenter(
      center: Offset.zero,
      width: rect.width,
      height: rect.height,
    );
    final frame = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = dims.selectionStroke
      ..color = tokens.selection;
    canvas.drawRect(local, frame);

    final handleFill = ui.Paint()..color = tokens.elementHandle;
    final handleBorder = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = dims.selectionStroke
      ..color = tokens.elementHandleBorder;

    final radius = dims.elementHandle / 2;
    for (final corner in <Offset>[
      local.topLeft,
      local.topRight,
      local.bottomRight,
      local.bottomLeft,
    ]) {
      canvas.drawCircle(corner, radius, handleFill);
      canvas.drawCircle(corner, radius, handleBorder);
    }

    final rotationPoint = Offset(0, local.top - dims.rotationHandleOffset);
    canvas.drawLine(Offset(0, local.top), rotationPoint, frame);
    canvas.drawCircle(rotationPoint, dims.rotationHandle / 2, handleFill);
    canvas.drawCircle(rotationPoint, dims.rotationHandle / 2, handleBorder);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ElementsPainter oldDelegate) {
    return oldDelegate.elements != elements ||
        oldDelegate.pageSize != pageSize ||
        oldDelegate.imageResolver != imageResolver ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.showSelection != showSelection;
  }
}
