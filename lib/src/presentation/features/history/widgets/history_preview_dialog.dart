import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/features/history_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/history.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/text/typography.dart';

/// True when [bytes] starts with the PDF magic number.
///
/// History keeps the processed bytes exactly as exported, so a PDF export
/// arrives here as a document, not as an image widget's input.
bool looksLikePdf(Uint8List bytes) {
  const magic = <int>[0x25, 0x50, 0x44, 0x46];
  if (bytes.length < magic.length) return false;
  for (var index = 0; index < magic.length; index++) {
    if (bytes[index] != magic[index]) return false;
  }

  return true;
}

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
                : looksLikePdf(value)
                ? _PdfPlaceholder(title: context.locale.history_previewTitle)
                : Image.memory(
                    value,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _PreviewUnavailable(
                          message: context.locale.history_previewUnavailable,
                        ),
                  ),
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

/// A PDF has no image to decode; the tile says what the file is instead.
class _PdfPlaceholder extends StatelessWidget {
  const _PdfPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final dims = context.dimensions;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: dims.size.iconDisplay,
            color: context.color.text.muted,
          ),
          SizedBox(height: dims.space.s8),
          BodySmallText(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Shown when image bytes cannot be decoded by the platform decoder.
class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BodySmallText.muted(message, textAlign: TextAlign.center),
    );
  }
}
