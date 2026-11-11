import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';

/// The editor's bottom bar: add a text or image element, or open the
/// layer list.
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    required this.onAddText,
    required this.onAddImage,
    required this.onLayers,
    super.key,
  });

  final VoidCallback onAddText;
  final VoidCallback onAddImage;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final dims = context.dimensions;

    return Container(
      height: context.dimensions.docMark.toolbarHeight,
      padding: EdgeInsets.symmetric(horizontal: dims.space.s16),
      decoration: BoxDecoration(
        color: context.color.background.surface,
        border: Border(top: BorderSide(color: context.color.border.subtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onAddText,
              icon: const Icon(Icons.text_fields),
              label: Text(
                l10n.editor_addText,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Gap(dims.space.s8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onAddImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                l10n.editor_addImage,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Gap(dims.space.s8),
          IconButton(
            tooltip: l10n.editor_layers,
            onPressed: onLayers,
            icon: const Icon(Icons.layers_outlined),
          ),
        ],
      ),
    );
  }
}
