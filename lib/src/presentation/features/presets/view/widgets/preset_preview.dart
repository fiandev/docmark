import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/watermark/watermark_canvas.dart';
import '../../../../../domain/entities/watermark_element.dart';

/// A preset's layers drawn small.
///
/// The paint comes from `paintWatermarkElements` — the same function the
/// editor and the exporter use — so a thumbnail can never disagree with the
/// result. Image elements are skipped: decoding encrypted assets for a list
/// cell would tie the row's frame time to the number of presets, and the
/// fallback icon already says "image".
class PresetPreview extends StatelessWidget {
  const PresetPreview({required this.elements, super.key});

  final List<WatermarkElement> elements;

  /// A page thumbnail keeps the landscape page's shape.
  static const double _aspectRatio = 4 / 3;

  @override
  Widget build(BuildContext context) {
    final hasText = elements.any(
      (element) =>
          element is TextWatermark &&
          element.visible &&
          element.content.trim().isNotEmpty,
    );
    final radius = BorderRadius.circular(context.dimensions.radius.small);

    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // The page is paper-white in both modes; the watermark ink is
            // authored against white paper.
            color: const ColorExtension.light().background.surface,
            border: Border.all(color: context.color.border.subtle),
            borderRadius: radius,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _PresetPreviewPainter(elements)),
              if (!hasText)
                Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: context.dimensions.size.iconMedium,
                    color: context.color.text.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetPreviewPainter extends CustomPainter {
  const _PresetPreviewPainter(this.elements);

  final List<WatermarkElement> elements;

  @override
  void paint(Canvas canvas, Size size) {
    paintWatermarkElements(canvas, size, elements, _noImage);
  }

  static ui.Image? _noImage(String assetId) => null;

  @override
  bool shouldRepaint(_PresetPreviewPainter oldDelegate) {
    return oldDelegate.elements != elements;
  }
}
