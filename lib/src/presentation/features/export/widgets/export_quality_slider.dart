import 'package:flutter/material.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/widgets/text/typography.dart';

/// JPEG quality, 0.5 to 1.0.
class ExportQualitySlider extends StatelessWidget {
  const ExportQualitySlider({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: LabelText(context.locale.export_quality)),
            LabelText(context.locale.export_qualityPercent(percent)),
          ],
        ),
        Slider(
          value: value.clamp(0.5, 1.0).toDouble(),
          min: 0.5,
          max: 1.0,
          divisions: 10,
          label: '$percent%',
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}
