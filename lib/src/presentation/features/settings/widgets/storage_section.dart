import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/base/base.dart';
import '../../../../core/di/features/history_providers.dart';
import '../../../../core/di/features/home_providers.dart';
import '../../../../core/di/features/presets_providers.dart';
import '../../../../core/di/features/storage_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../core/gen/l10n/app_localizations.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/storage_overview.dart';
import 'settings_card.dart';

/// Storage: what is encrypted on disk, and the two destructive actions.
class StorageSection extends ConsumerWidget {
  const StorageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.locale;
    final usage = ref.watch(storageUsageProvider);

    return SettingsCard(
      children: [
        ListTile(
          leading: Icon(
            Icons.storage_outlined,
            color: context.color.text.muted,
          ),
          title: LabelText(l10n.settings_storage),
          subtitle: switch (usage) {
            AsyncData(:final value) => BodySmallText.muted(
              _usageSummary(l10n, value),
            ),
            AsyncError() => BodySmallText.muted(l10n.settings_failure),
            _ => BodySmallText.muted(l10n.common_loading),
          },
          trailing: switch (usage) {
            AsyncData(:final value) => LabelText(_formatBytes(value.bytes)),
            _ => null,
          },
        ),
        ListTile(
          leading: Icon(
            Icons.history_toggle_off,
            color: context.color.text.muted,
          ),
          title: LabelText(l10n.settings_clearHistory),
          subtitle: BodySmallText.muted(l10n.settings_clearHistoryBody),
          onTap: () => unawaited(_clearHistory(context, ref)),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: context.color.status.danger,
          ),
          title: LabelText(l10n.settings_deleteAll),
          subtitle: BodySmallText.muted(l10n.settings_deleteAllBody),
          onTap: () => unawaited(_deleteAll(context, ref)),
        ),
      ],
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final l10n = context.locale;
    final confirmed = await _confirm(
      context,
      title: l10n.settings_clearHistory,
      body: l10n.settings_clearHistoryConfirm,
      action: l10n.common_clear,
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(historyRepositoryProvider).clear();
    if (!context.mounted) return;

    switch (result) {
      case Success():
        ref.invalidate(storageUsageProvider);
        _showSnack(context, l10n.settings_historyCleared);
      case Error():
        _showSnack(context, l10n.settings_failure);
    }
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.locale;
    final confirmed = await _confirm(
      context,
      title: l10n.settings_deleteAll,
      body: l10n.settings_deleteAllConfirm,
      action: l10n.common_delete,
    );
    if (confirmed != true || !context.mounted) return;

    // Every table, every vault blob, and the scratch directories, in one
    // operation: a partial wipe would leave document names or watermark
    // text behind while the UI claims the data is gone.
    try {
      await ref.read(appDataWipeProvider).wipeAll();
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, l10n.settings_failure);

      return;
    }
    if (!context.mounted) return;

    // Cross-feature caches are invalidated through the DI seam so this
    // widget stays free of feature-to-feature imports.
    ref
      ..invalidate(historyListProvider)
      ..invalidate(presetListProvider)
      ..invalidate(recentDocumentsProvider)
      ..invalidate(recentProcessingProvider)
      ..invalidate(storageUsageProvider);
    _showSnack(context, l10n.settings_allDataDeleted);
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.locale;

      return AlertDialog(
        title: Text(title),
        content: BodySmallText(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: LabelText(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: LabelText(action),
          ),
        ],
      );
    },
  );
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _usageSummary(AppLocalizations l10n, StorageUsage usage) {
  if (usage.documentCount == 0 && usage.historyCount == 0) {
    return l10n.settings_storageEmpty;
  }

  return '${l10n.settings_storageDocuments(usage.documentCount)} · '
      '${l10n.settings_storageHistory(usage.historyCount)}';
}

String _formatBytes(int bytes) {
  const int kibibyte = 1024;

  if (bytes < kibibyte) return '$bytes B';

  final kibibytes = bytes / kibibyte;
  if (kibibytes < kibibyte) return '${kibibytes.toStringAsFixed(1)} KB';

  final mebibytes = kibibytes / kibibyte;

  return '${mebibytes.toStringAsFixed(1)} MB';
}
