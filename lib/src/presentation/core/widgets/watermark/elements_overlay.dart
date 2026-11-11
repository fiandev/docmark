import 'package:flutter/material.dart';

import '../../../../domain/entities/watermark_element.dart';
import 'elements_painter.dart';

/// Gesture surface for the watermark elements over a document preview.
///
/// OWNER: T4 (editor canvas). The constructor signature is frozen; the
/// stub only renders its [child] so the editor page can compose the
/// preview now and T4 can add drag, resize, and rotate handling without
/// touching call sites.
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
    return child ?? const SizedBox.shrink();
  }
}
