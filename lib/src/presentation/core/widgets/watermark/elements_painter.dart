import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../domain/entities/watermark_element.dart';

/// Resolves an encrypted image asset id to a decoded image for painting.
typedef WatermarkImageResolver = ui.Image? Function(String assetId);

/// Paints the document page's watermark elements.
///
/// OWNER: T4 (editor canvas). The constructor signature is frozen: the
/// canvas hands the painter the resolved element list, the page's pixel
/// size, and the image resolver, and the painter draws nothing until T4
/// implements text and image rendering.
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
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant ElementsPainter oldDelegate) {
    return oldDelegate.elements != elements ||
        oldDelegate.pageSize != pageSize ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.showSelection != showSelection;
  }
}
