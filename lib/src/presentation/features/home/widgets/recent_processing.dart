import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/history.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// The "Recent Processing" strip on the home dashboard.
class RecentProcessingList extends StatelessWidget {
  const RecentProcessingList({
    required this.entries,
    required this.onOpen,
    super.key,
  });

  final List<HistoryEntryEntity> entries;
  final ValueChanged<HistoryEntryEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          if (index > 0) Gap(context.dimensions.space.s8),
          _RecentEntryTile(
            entry: entries[index],
            onTap: () => onOpen(entries[index]),
          ),
        ],
      ],
    );
  }
}

class _RecentEntryTile extends StatelessWidget {
  const _RecentEntryTile({required this.entry, required this.onTap});

  final HistoryEntryEntity entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(entry.createdAt.toLocal());

    return Card(
      color: context.color.background.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          context.dimensions.radius.medium,
        ),
        side: BorderSide(color: context.color.border.subtle),
      ),
      child: ListTile(
        leading: Icon(
          Icons.description_outlined,
          color: context.color.text.muted,
        ),
        title: LabelText(entry.documentName),
        subtitle: BodySmallText.muted(date),
        trailing: Icon(
          Icons.chevron_right,
          color: context.color.text.muted,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// What the dashboard shows before the first document is processed.
class RecentProcessingEmpty extends StatelessWidget {
  const RecentProcessingEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;

    return Container(
      padding: EdgeInsets.all(context.dimensions.space.s16),
      decoration: BoxDecoration(
        color: context.color.background.surface,
        borderRadius: BorderRadius.circular(context.dimensions.radius.medium),
        border: Border.all(color: context.color.border.subtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.history,
            size: context.dimensions.size.iconDisplay,
            color: context.color.text.muted,
          ),
          Gap(context.dimensions.space.s12),
          BodySmallText(l10n.home_recentEmpty),
          Gap(context.dimensions.space.s4),
          BodySmallText.muted(l10n.home_recentEmptyBody),
        ],
      ),
    );
  }
}
