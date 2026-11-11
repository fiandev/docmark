import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/loading_indicator.dart';

/// The WYSIWYG preview of the first page that will be exported.
///
/// The bytes come from the same renderer the export uses, so what the
/// user sees here is the composited output, not a second drawing path.
class ExportPreviewCard extends StatelessWidget {
  const ExportPreviewCard({
    required this.bytes,
    required this.aspectRatio,
    required this.isLoading,
    super.key,
  });

  final Uint8List? bytes;

  /// Page width / height, so the card reserves the right shape while the
  /// first render is still running.
  final double aspectRatio;

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.dimensions.radius.medium);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.color.background.canvas,
        borderRadius: radius,
        border: Border.all(
          color: context.color.border.defaultValue,
          width: context.dimensions.border.xs,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: aspectRatio > 0 ? aspectRatio : 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                Image.memory(
                  bytes!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                )
              else
                const SizedBox.shrink(),
              if (isLoading) const Center(child: LoadingIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
