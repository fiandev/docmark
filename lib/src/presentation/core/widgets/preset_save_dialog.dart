import 'package:flutter/material.dart';

import '../../../core/extensions/localization.dart';
import '../../../domain/entities/watermark_element.dart';
import 'text/typography.dart';

/// "Save as preset" dialog.
///
/// OWNER: T5 (presets). The entry point is frozen: callers use
/// `PresetSaveDialog.show(context, elements: ...)`. The stub closes without
/// persisting; T5 replaces the body with the name field and store call.
class PresetSaveDialog extends StatelessWidget {
  const PresetSaveDialog({required this.elements, super.key});

  final List<WatermarkElement> elements;

  /// Opens the dialog. Returns once it is dismissed.
  static Future<void> show(
    BuildContext context, {
    required List<WatermarkElement> elements,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => PresetSaveDialog(elements: elements),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.locale.presets_saveTitle),
      content: BodySmallText.muted(context.locale.presets_saveBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.locale.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.locale.common_save),
        ),
      ],
    );
  }
}
