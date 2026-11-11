import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/features/home_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/history.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../widgets/home_action_tile.dart';
import '../widgets/recent_processing.dart';

/// DocMark's home dashboard.
///
/// The surface is fixed: New Watermark, Recent Processing, Saved Presets,
/// Settings. There is no logout — the app has no remote session.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.locale;
    final recent = ref.watch(recentProcessingProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.dimensions.space.s16),
          children: [
            HeadingLevel1Text(l10n.home_title),
            Gap(context.dimensions.space.s8),
            BodySmallText.muted(l10n.home_subtitle),
            Gap(context.dimensions.space.s24),
            HomePrimaryAction(
              icon: Icons.add_photo_alternate_outlined,
              title: l10n.home_newWatermark,
              body: l10n.home_newWatermarkBody,
              onTap: () => _go(context, Routes.documentPicker),
            ),
            Gap(context.dimensions.space.s24),
            _SectionHeading(
              title: l10n.home_recent,
              action: l10n.home_viewAll,
              onAction: () => _go(context, Routes.history),
            ),
            Gap(context.dimensions.space.s8),
            switch (recent) {
              AsyncData(:final value) when value.isEmpty =>
                const RecentProcessingEmpty(),
              AsyncData(:final value) => RecentProcessingList(
                entries: value,
                onOpen: (entry) => _open(context, entry),
              ),
              AsyncError() => const RecentProcessingEmpty(),
              _ => BodySmallText.muted(l10n.common_loading),
            },
            Gap(context.dimensions.space.s24),
            _SectionHeading(title: l10n.home_quickStart),
            Gap(context.dimensions.space.s8),
            HomeActionTile(
              icon: Icons.bookmark_outline,
              title: l10n.home_presets,
              body: l10n.home_presetsBody,
              onTap: () => _go(context, Routes.presets),
            ),
            Gap(context.dimensions.space.s8),
            HomeActionTile(
              icon: Icons.settings_outlined,
              title: l10n.home_settings,
              body: l10n.home_settingsBody,
              onTap: () => _go(context, Routes.settings),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Routes route) {
    context.goNamed(route.name);
  }

  void _open(BuildContext context, HistoryEntryEntity entry) {
    final documentId = entry.documentId;
    if (documentId == null || documentId.isEmpty) {
      _go(context, Routes.history);
      return;
    }

    context.goNamed(
      Routes.editor.name,
      pathParameters: {'documentId': documentId},
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    final onAction = this.onAction;

    return Row(
      children: [
        Expanded(child: HeadingLevel3Text(title)),
        if (action != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: LabelText(action),
          ),
      ],
    );
  }
}
