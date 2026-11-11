import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/image_format.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// Choose the file the export produces.
class ExportFormatSelector extends StatelessWidget {
  const ExportFormatSelector({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final ImageFormat selected;
  final ValueChanged<ImageFormat> onChanged;
  final bool enabled;

  static const List<ImageFormat> formats = <ImageFormat>[
    ImageFormat.jpeg,
    ImageFormat.png,
    ImageFormat.pdf,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabelText(context.locale.export_format),
        Gap(context.dimensions.space.s8),
        Wrap(
          spacing: context.dimensions.space.s8,
          runSpacing: context.dimensions.space.s8,
          children: [
            for (final format in formats)
              ChoiceChip(
                label: Text(_label(context, format)),
                selected: format == selected,
                onSelected: enabled ? (_) => onChanged(format) : null,
              ),
          ],
        ),
      ],
    );
  }

  String _label(BuildContext context, ImageFormat format) {
    return switch (format) {
      ImageFormat.jpeg => context.locale.export_formatJpeg,
      ImageFormat.png => context.locale.export_formatPng,
      ImageFormat.pdf => context.locale.export_formatPdf,
      ImageFormat.webp || ImageFormat.unknown => format.name,
    };
  }
}
