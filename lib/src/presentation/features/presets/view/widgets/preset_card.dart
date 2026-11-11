import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/extensions/localization.dart';
import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/text/typography.dart';
import '../../../../../domain/entities/preset.dart';
import 'preset_preview.dart';

/// One saved preset: thumbnail, name, layer count, and the action menu.
class PresetCard extends StatelessWidget {
  const PresetCard({
    required this.preset,
    required this.onApply,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    super.key,
  });

  final PresetEntity preset;
  final VoidCallback onApply;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final radius = BorderRadius.circular(context.dimensions.radius.medium);

    return Card(
      margin: EdgeInsets.zero,
      color: context.color.background.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: context.color.border.subtle),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onApply,
        child: Padding(
          padding: EdgeInsets.all(context.dimensions.space.s12),
          child: Row(
            children: [
              SizedBox(
                width: context.dimensions.layout.logoSmall,
                child: PresetPreview(elements: preset.elements),
              ),
              Gap(context.dimensions.space.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LabelText(
                      preset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap(context.dimensions.space.s4),
                    BodySmallText.muted(
                      l10n.presets_elementCount(preset.elements.length),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_PresetAction>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) => switch (action) {
                  .apply => onApply(),
                  .rename => onRename(),
                  .duplicate => onDuplicate(),
                  .delete => onDelete(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem<_PresetAction>(
                    value: _PresetAction.apply,
                    child: Text(l10n.presets_apply),
                  ),
                  PopupMenuItem<_PresetAction>(
                    value: _PresetAction.rename,
                    child: Text(l10n.presets_rename),
                  ),
                  PopupMenuItem<_PresetAction>(
                    value: _PresetAction.duplicate,
                    child: Text(l10n.presets_duplicate),
                  ),
                  PopupMenuItem<_PresetAction>(
                    value: _PresetAction.delete,
                    child: Text(l10n.presets_delete),
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

enum _PresetAction { apply, rename, duplicate, delete }
