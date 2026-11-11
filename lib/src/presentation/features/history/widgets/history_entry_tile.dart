import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/di/features/history_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/history.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import 'history_status_chip.dart';

/// One row's action callback.
typedef HistoryEntryCallback = void Function(HistoryEntryEntity entry);

/// The scrollable history rows.
class HistoryEntryList extends StatelessWidget {
  const HistoryEntryList({
    required this.entries,
    required this.onPreview,
    required this.onReuse,
    required this.onDelete,
    super.key,
  });

  final List<HistoryEntryEntity> entries;
  final HistoryEntryCallback onPreview;
  final HistoryEntryCallback onReuse;
  final HistoryEntryCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(context.dimensions.space.s16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (context, index) => Gap(
        context.dimensions.space.s8,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];

        return HistoryEntryTile(
          entry: entry,
          onPreview: () => onPreview(entry),
          onReuse: () => onReuse(entry),
          onDelete: () => onDelete(entry),
        );
      },
    );
  }
}

/// Document name, preview, timestamp, status, and the row actions.
class HistoryEntryTile extends ConsumerWidget {
  const HistoryEntryTile({
    required this.entry,
    required this.onPreview,
    required this.onReuse,
    required this.onDelete,
    super.key,
  });

  final HistoryEntryEntity entry;
  final VoidCallback onPreview;
  final VoidCallback onReuse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = MaterialLocalizations.of(
      context,
    ).formatCompactDate(entry.createdAt.toLocal());

    return Card(
      color: context.color.background.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.dimensions.radius.medium),
        side: BorderSide(color: context.color.border.subtle),
      ),
      child: InkWell(
        onTap: onPreview,
        borderRadius: BorderRadius.circular(context.dimensions.radius.medium),
        child: Padding(
          padding: EdgeInsets.all(context.dimensions.space.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HistoryThumbnail(entryId: entry.id),
              Gap(context.dimensions.space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabelText(
                      entry.documentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap(context.dimensions.space.s4),
                    BodySmallText.muted(
                      context.locale.history_processedAt(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap(context.dimensions.space.s8),
                    HistoryStatusChip(status: entry.status),
                  ],
                ),
              ),
              PopupMenuButton<_HistoryAction>(
                icon: Icon(
                  Icons.more_vert,
                  color: context.color.text.muted,
                ),
                onSelected: (action) {
                  final callback = switch (action) {
                    _HistoryAction.preview => onPreview,
                    _HistoryAction.reuse => onReuse,
                    _HistoryAction.delete => onDelete,
                  };
                  callback();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _HistoryAction.preview,
                    child: _HistoryActionLabel(
                      icon: Icons.visibility_outlined,
                      label: context.locale.history_preview,
                    ),
                  ),
                  PopupMenuItem(
                    value: _HistoryAction.reuse,
                    child: _HistoryActionLabel(
                      icon: Icons.tune,
                      label: context.locale.history_reuseConfig,
                    ),
                  ),
                  PopupMenuItem(
                    value: _HistoryAction.delete,
                    child: _HistoryActionLabel(
                      icon: Icons.delete_outline,
                      label: context.locale.history_delete,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HistoryAction { preview, reuse, delete }

class _HistoryActionLabel extends StatelessWidget {
  const _HistoryActionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: context.dimensions.size.iconMedium,
          color: context.color.text.muted,
        ),
        Gap(context.dimensions.space.s12),
        LabelText(label),
      ],
    );
  }
}

class _HistoryThumbnail extends ConsumerWidget {
  const _HistoryThumbnail({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(historyPreviewProvider(entryId));
    final size = context.dimensions.size.control;

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.dimensions.radius.small),
      child: SizedBox(
        width: size,
        height: size,
        child: switch (preview) {
          AsyncData(:final value) =>
            value == null || value.isEmpty
                ? const _ThumbnailPlaceholder()
                : Image.memory(value, fit: BoxFit.cover),
          _ => const _ThumbnailPlaceholder(),
        },
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.color.background.canvas,
      child: Icon(
        Icons.insert_drive_file_outlined,
        size: context.dimensions.size.iconLarge,
        color: context.color.text.muted,
      ),
    );
  }
}
