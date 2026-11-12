import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/base/result.dart';
import '../../../../core/di/features/presets_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/preset.dart';
import '../../../../domain/failures/business_failure.dart';
import '../../../core/failure/business_failure_ui_mapper.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/failure_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/preset_save_dialog.dart';
import '../../../core/widgets/text/typography.dart';
import 'widgets/preset_card.dart';
import 'widgets/preset_name_dialog.dart';

/// Saved watermark presets.
///
/// OWNER: T5 (presets). Lives inside the tab shell, so it renders no
/// AppBar of its own.
class PresetsPage extends ConsumerWidget {
  const PresetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.locale;
    final presets = ref.watch(presetListProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.dimensions.space.s24,
                context.dimensions.space.s16,
                context.dimensions.space.s16,
                context.dimensions.space.s8,
              ),
              child: Row(
                children: [
                  Expanded(child: HeadingLevel1Text(l10n.presets_title)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: l10n.presets_new,
                    onPressed: () => unawaited(_create(context)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: presets.when(
                data: (items) => items.isEmpty
                    ? const _EmptyPresets()
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.dimensions.space.s16,
                          vertical: context.dimensions.space.s8,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            Gap(context.dimensions.space.s8),
                        itemBuilder: (context, index) {
                          final preset = items[index];

                          return PresetCard(
                            preset: preset,
                            onApply: () =>
                                applyPreset(ref, context, preset.id),
                            onRename: () =>
                                unawaited(_rename(context, ref, preset)),
                            onDuplicate: () =>
                                unawaited(_duplicate(context, ref, preset)),
                            onDelete: () =>
                                unawaited(_delete(context, ref, preset)),
                          );
                        },
                      ),
                loading: () => const Center(child: LoadingIndicator()),
                error: (error, _) => FailureView(
                  error: error,
                  onRetry: () => ref.invalidate(presetListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final preset = await PresetSaveDialog.show(context, elements: const []);
    if (preset == null || !context.mounted) return;

    _message(context, context.locale.presets_saved);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    PresetEntity preset,
  ) async {
    final name = await PresetNameDialog.show(
      context,
      title: context.locale.presets_rename,
      initialName: preset.name,
    );
    if (name == null || !context.mounted) return;

    final result = await ref
        .read(presetListProvider.notifier)
        .rename(preset, name);
    if (!context.mounted) return;

    if (result case Error(:final error)) _reportFailure(context, error);
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    PresetEntity preset,
  ) async {
    final result = await ref
        .read(presetListProvider.notifier)
        .duplicate(preset.id);
    if (!context.mounted) return;

    switch (result) {
      case Success():
        _message(context, context.locale.presets_duplicated);
      case Error(:final error):
        _reportFailure(context, error);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PresetEntity preset,
  ) async {
    final l10n = context.locale;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.presets_delete),
        content: Text(l10n.presets_deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(presetListProvider.notifier)
        .delete(preset.id);
    if (!context.mounted) return;

    switch (result) {
      case Success():
        _message(context, context.locale.presets_deleted);
      case Error(:final error):
        _reportFailure(context, error);
    }
  }

  void _reportFailure(BuildContext context, BusinessFailure failure) {
    _message(
      context,
      BusinessFailureUIMapper.map(failure, context.locale).message,
    );
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EmptyPresets extends StatelessWidget {
  const _EmptyPresets();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.dimensions.space.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline,
            size: context.dimensions.size.iconDisplay,
            color: context.color.text.muted,
          ),
          Gap(context.dimensions.space.s16),
          HeadingLevel3Text(
            context.locale.presets_empty,
            textAlign: TextAlign.center,
          ),
          Gap(context.dimensions.space.s8),
          BodySmallText.muted(
            context.locale.presets_emptyBody,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
