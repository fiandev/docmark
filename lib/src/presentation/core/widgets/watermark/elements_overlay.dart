import 'package:flutter/material.dart';

import '../../../../domain/entities/normalized_rect.dart';
import '../../../../domain/entities/watermark_element.dart';
import '../../../../domain/services/watermark_geometry.dart';
import 'elements_painter.dart';

/// Gesture surface for the watermark elements over a document preview.
///
/// The overlay paints the elements with the shared [ElementsPainter] and
/// turns a tap into a selection: the topmost element under the pointer
/// wins, and an empty area clears the selection. Drag, resize and rotate
/// gestures build on the same hit test in T3.
class ElementsOverlay extends StatelessWidget {
  const ElementsOverlay({
    required this.elements,
    required this.pageSize,
    required this.imageResolver,
    this.selectedId,
    this.onSelect,
    this.child,
    super.key,
  });

  final List<WatermarkElement> elements;
  final Size pageSize;
  final WatermarkImageResolver imageResolver;
  final String? selectedId;
  final ValueChanged<String?>? onSelect;

  /// The page preview the overlay sits on. Null renders an empty box.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedSize = _resolvedSize(constraints);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: onSelect == null
              ? null
              : (details) => _selectAt(details.localPosition, resolvedSize),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (child != null) child! else const SizedBox.expand(),
              IgnorePointer(
                child: CustomPaint(
                  painter: ElementsPainter(
                    elements: elements,
                    pageSize: resolvedSize,
                    imageResolver: imageResolver,
                    selectedId: selectedId,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Size _resolvedSize(BoxConstraints constraints) {
    if (!pageSize.isEmpty) return pageSize;
    if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
      return constraints.biggest;
    }

    return pageSize;
  }

  void _selectAt(Offset position, Size size) {
    if (size.isEmpty) return;

    final point = NormalizedOffset.fromOffset(position, size);
    for (final element in elements.reversed) {
      if (!element.visible) continue;
      if (WatermarkGeometry.hitTest(
        element.rect,
        point,
        element.rotationDeg,
      )) {
        onSelect?.call(element.id);
        return;
      }
    }

    onSelect?.call(null);
  }
}
