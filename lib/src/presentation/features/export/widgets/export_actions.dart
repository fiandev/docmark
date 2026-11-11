import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/text/typography.dart';

/// The Save and Share buttons, plus the in-flight state.
class ExportActions extends StatelessWidget {
  const ExportActions({
    required this.onSave,
    required this.onShare,
    required this.isBusy,
    super.key,
  });

  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: isBusy ? null : onSave,
          child: Text(context.locale.export_save),
        ),
        Gap(context.dimensions.space.s12),
        OutlinedButton(
          onPressed: isBusy ? null : onShare,
          child: Text(context.locale.export_share),
        ),
        if (isBusy) ...[
          Gap(context.dimensions.space.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LoadingIndicator(),
              Gap(context.dimensions.space.s12),
              BodySmallText.muted(context.locale.export_exporting),
            ],
          ),
        ],
      ],
    );
  }
}
