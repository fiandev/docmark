import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/features/history_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/history.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/text/typography.dart';

/// Shows the encrypted processed preview kept for one history entry.
class HistoryPreviewDialog extends ConsumerWidget {
  const HistoryPreviewDialog({required this.entry, super.key});

  final HistoryEntryEntity entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(historyPreviewProvider(entry.id));
    final height = MediaQuery.sizeOf(context).height * 0.5;

    return AlertDialog(
      title: HeadingLevel3Text(context.locale.history_previewTitle),
      content: SizedBox(
        width: double.maxFinite,
        height: height,
        child: switch (preview) {
          AsyncData(:final value) =>
            value == null || value.isEmpty
                ? Center(
                    child: BodySmallText.muted(
                      context.locale.history_previewUnavailable,
                      textAlign: TextAlign.center,
                    ),
                  )
                : Image.memory(value, fit: BoxFit.contain),
          AsyncError() => Center(
            child: BodySmallText.muted(
              context.locale.history_previewUnavailable,
              textAlign: TextAlign.center,
            ),
          ),
          _ => const Center(child: LoadingIndicator()),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.locale.common_close),
        ),
      ],
    );
  }
}
