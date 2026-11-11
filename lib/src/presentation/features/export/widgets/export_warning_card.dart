import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// The permanent "this file leaves the encrypted vault" notice.
class ExportWarningCard extends StatelessWidget {
  const ExportWarningCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.color.status.warningTint,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.dimensions.radius.medium),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.dimensions.space.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: context.color.status.warning,
            ),
            Gap(context.dimensions.space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabelText(context.locale.export_unencrypted_warning_title),
                  Gap(context.dimensions.space.s4),
                  BodySmallText.muted(
                    context.locale.export_unencrypted_warning_body,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
