import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../../../core/base/result.dart';
import '../../../../core/di/features/history_providers.dart';
import '../../../../core/di/features/import_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/document.dart';
import '../../../../domain/entities/history.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/failure_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/history_presentation.dart';
import '../widgets/history_empty_state.dart';
import '../widgets/history_entry_tile.dart';
import '../widgets/history_preview_dialog.dart';

/// Processing history.
///
/// OWNER: T6 (history). Lives inside the tab shell, so it renders no
/// AppBar of its own. The list is read-only over the encrypted vault;
/// delete and clear are the only writes, and both cascade to the blobs.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyListProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HistoryHeader(
              showClear: entries.asData?.value.isNotEmpty ?? false,
              onClear: () => unawaited(_confirmClear(context, ref)),
            ),
            Expanded(
              child: switch (entries) {
                AsyncData(:final value) =>
                  value.isEmpty
                      ? const HistoryEmptyState()
                      : RefreshIndicator(
                          onRefresh: () async {
                            ref
                                .read(historyListProvider.notifier)
                                .refresh();
                            await ref.read(historyListProvider.future);
                          },
                          child: HistoryEntryList(
                            entries: value,
                            onPreview: (entry) => unawaited(
                              _openPreview(context, entry),
                            ),
                            onReuse: (entry) => unawaited(
                              _reuseConfig(context, ref, entry),
                            ),
                            onDelete: (entry) => unawaited(
                              _deleteEntry(context, ref, entry),
                            ),
                          ),
                        ),
                AsyncError(:final error) => FailureView(
                  error: error,
                  onRetry: () => ref.invalidate(historyListProvider),
                ),
                _ => const Center(child: LoadingIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPreview(
    BuildContext context,
    HistoryEntryEntity entry,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => HistoryPreviewDialog(entry: entry),
    );
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    HistoryEntryEntity entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: HeadingLevel3Text(context.locale.history_delete),
        content: BodySmallText(context.locale.history_deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.locale.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.locale.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final deleted = await ref
        .read(historyListProvider.notifier)
        .deleteEntry(entry.id);
    if (deleted || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.locale.history_deleteFailed)),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: HeadingLevel3Text(context.locale.history_clearAll),
        content: BodySmallText(context.locale.history_clearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.locale.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.locale.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final cleared = await ref.read(historyListProvider.notifier).clearAll();
    if (!context.mounted) return;

    final message = cleared
        ? context.locale.history_cleared
        : context.locale.history_clearFailed;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reuseConfig(
    BuildContext context,
    WidgetRef ref,
    HistoryEntryEntity entry,
  ) async {
    final plan = historyReusePlan(entry);
    final documentId = plan.documentId;

    if (documentId != null && await _documentExists(ref, documentId)) {
      if (!context.mounted) return;
      unawaited(
        context.pushNamed(
          Routes.editor.name,
          pathParameters: {'documentId': documentId},
        ),
      );

      return;
    }

    if (!context.mounted) return;
    await _offerImport(context, ref, _configFromEntry(entry));
  }

  /// The configuration snapshot the entry kept, if it can be parsed.
  ///
  /// This is the only copy left once the original document is gone, so a
  /// corrupt snapshot degrades to a plain import rather than blocking it.
  WatermarkConfig? _configFromEntry(HistoryEntryEntity entry) {
    final source = entry.watermarkConfigJson;
    if (source == null || source.isEmpty) return null;

    try {
      return WatermarkConfig.fromJsonString(source);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _documentExists(WidgetRef ref, String documentId) async {
    final result = await ref.read(documentRepositoryProvider).get(documentId);

    return switch (result) {
      Success(:final data) => data != null,
      Error() => false,
    };
  }

  Future<void> _offerImport(
    BuildContext context,
    WidgetRef ref,
    WatermarkConfig? config,
  ) async {
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: HeadingLevel3Text(context.locale.history_reuseConfig),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodySmallText(context.locale.history_originalMissing),
            Gap(context.dimensions.space.s8),
            BodySmallText.muted(context.locale.history_importToReuse),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.locale.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.locale.history_importDocument),
          ),
        ],
      ),
    );
    if (shouldImport != true || !context.mounted) return;

    // Park the snapshot until the editor opens the replacement document;
    // the editor consumes it with preset > snapshot > draft precedence.
    if (config != null) {
      ref.read(pendingWatermarkConfigProvider.notifier).set(config);
    }
    unawaited(context.pushNamed(Routes.documentPicker.name));
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.showClear, required this.onClear});

  final bool showClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.dimensions.space.s16,
        context.dimensions.space.s16,
        context.dimensions.space.s16,
        context.dimensions.space.s4,
      ),
      child: Row(
        children: [
          Expanded(child: HeadingLevel1Text(context.locale.history_title)),
          if (showClear)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(context.locale.history_clearAll),
            ),
        ],
      ),
    );
  }
}
