import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/history.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/history_presentation.dart';

/// A status pill using the semantic status tints from the theme.
class HistoryStatusChip extends StatelessWidget {
  const HistoryStatusChip({required this.status, super.key});

  final HistoryStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      HistoryStatus.pending => (
        context.color.status.warningTint,
        context.color.status.warning,
      ),
      HistoryStatus.processing => (
        context.color.status.informationTint,
        context.color.status.information,
      ),
      HistoryStatus.completed => (
        context.color.status.successTint,
        context.color.status.success,
      ),
      HistoryStatus.failed => (
        context.color.status.dangerTint,
        context.color.status.danger,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.dimensions.space.s8,
        vertical: context.dimensions.space.s2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(context.dimensions.radius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: context.dimensions.layout.dot,
            color: foreground,
          ),
          Gap(context.dimensions.space.s4),
          LabelText(historyStatusLabel(status, context.locale)),
        ],
      ),
    );
  }
}
