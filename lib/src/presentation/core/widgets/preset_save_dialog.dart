import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/base/result.dart';
import '../../../core/di/features/presets_providers.dart';
import '../../../core/extensions/localization.dart';
import '../../../domain/entities/preset.dart';
import '../../../domain/entities/watermark_element.dart';
import '../failure/business_failure_ui_mapper.dart';
import '../theme/theme.dart';
import 'text/typography.dart';

/// "Save as preset" dialog.
///
/// OWNER: T5 (presets). The entry point stays `PresetSaveDialog.show(...)`
/// so the editor opens it without knowing how presets are stored. The
/// created [PresetEntity] is returned (null on cancel) for callers that want
/// to confirm with a snackbar; the preset list refreshes itself.
class PresetSaveDialog extends ConsumerStatefulWidget {
  const PresetSaveDialog({
    required this.elements,
    this.imageAssetIds = const [],
    super.key,
  });

  /// The editor's current layers. They are stored as-is; image elements
  /// contribute their asset ids to [imageAssetIds] below.
  final List<WatermarkElement> elements;

  /// Vault asset ids the caller already resolved. Unioned with the ids the
  /// image elements carry, because a preset must own every asset it draws.
  final List<String> imageAssetIds;

  static Future<PresetEntity?> show(
    BuildContext context, {
    required List<WatermarkElement> elements,
    List<String> imageAssetIds = const [],
  }) {
    return showDialog<PresetEntity>(
      context: context,
      builder: (context) => PresetSaveDialog(
        elements: elements,
        imageAssetIds: imageAssetIds,
      ),
    );
  }

  @override
  ConsumerState<PresetSaveDialog> createState() => _PresetSaveDialogState();
}

class _PresetSaveDialogState extends ConsumerState<PresetSaveDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _assetIds {
    return <String>{
      ...widget.imageAssetIds,
      for (final element in widget.elements)
        if (element is ImageWatermark && element.assetId.isNotEmpty)
          element.assetId,
    }.toList();
  }

  Future<void> _save() async {
    final l10n = context.locale;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.presets_nameRequired);

      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref
        .read(presetListProvider.notifier)
        .create(
          name: name,
          elements: widget.elements,
          imageAssetIds: _assetIds,
        );
    if (!mounted) return;

    switch (result) {
      case Success(:final data):
        Navigator.of(context).pop(data);
      case Error(:final error):
        setState(() {
          _saving = false;
          _error = BusinessFailureUIMapper.map(error, l10n).message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;

    return AlertDialog(
      title: Text(l10n.presets_saveTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodySmallText.muted(l10n.presets_saveBody),
          Gap(context.dimensions.space.s16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.presets_nameLabel,
              hintText: l10n.presets_nameHint,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.common_save),
        ),
      ],
    );
  }
}
