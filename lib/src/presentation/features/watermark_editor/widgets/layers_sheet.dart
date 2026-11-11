import 'package:flutter/material.dart';

import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/watermark_element.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/editor_controller.dart';

/// Opens the layer list: paint order from top to bottom, with per-element
/// visibility, lock and ordering actions.
Future<void> showLayersSheet(
  BuildContext context, {
  required EditorController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _LayersSheet(controller: controller),
  );
}

class _LayersSheet extends StatelessWidget {
  const _LayersSheet({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;

    return SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          final elements = controller.config.elements;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.all(context.dimensions.space.s16),
                child: LabelText.muted(l10n.editor_layers),
              ),
              if (elements.isEmpty)
                Padding(
                  padding: EdgeInsets.all(context.dimensions.space.s16),
                  child: BodySmallText.muted(l10n.editor_layersEmpty),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final element in elements.reversed)
                        _LayerTile(
                          element: element,
                          controller: controller,
                          selected: element.id == controller.selectedId,
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _LayerAction { front, back, forward, backward, duplicate, delete }

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.element,
    required this.controller,
    required this.selected,
  });

  final WatermarkElement element;
  final EditorController controller;
  final bool selected;

  String _title(BuildContext context) {
    final l10n = context.locale;

    return switch (element) {
      TextWatermark(:final content) =>
        content.trim().isEmpty ? l10n.editor_textContent : content,
      ImageWatermark() => l10n.editor_image,
    };
  }

  void _act(_LayerAction action) {
    switch (action) {
      case _LayerAction.front:
        controller.bringToFront(element.id);
      case _LayerAction.back:
        controller.sendToBack(element.id);
      case _LayerAction.forward:
        controller.moveForward(element.id);
      case _LayerAction.backward:
        controller.moveBackward(element.id);
      case _LayerAction.duplicate:
        controller.duplicate(element.id);
      case _LayerAction.delete:
        controller.remove(element.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;

    return ListTile(
      selected: selected,
      leading: Icon(
        element is TextWatermark ? Icons.text_fields : Icons.image_outlined,
      ),
      title: Text(_title(context)),
      subtitle: Text(
        element.visible ? l10n.editor_visible : l10n.editor_hidden,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: element.visible ? l10n.editor_visible : l10n.editor_hidden,
            onPressed: () => controller.toggleVisibility(element.id),
            icon: Icon(
              element.visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          IconButton(
            tooltip: element.locked ? l10n.editor_unlock : l10n.editor_lock,
            onPressed: () => controller.toggleLock(element.id),
            icon: Icon(
              element.locked ? Icons.lock_outline : Icons.lock_open_outlined,
            ),
          ),
          PopupMenuButton<_LayerAction>(
            onSelected: _act,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _LayerAction.front,
                child: Text(l10n.editor_layerBringFront),
              ),
              PopupMenuItem(
                value: _LayerAction.forward,
                child: Text(l10n.editor_layerForward),
              ),
              PopupMenuItem(
                value: _LayerAction.backward,
                child: Text(l10n.editor_layerBackward),
              ),
              PopupMenuItem(
                value: _LayerAction.back,
                child: Text(l10n.editor_layerSendBack),
              ),
              PopupMenuItem(
                value: _LayerAction.duplicate,
                child: Text(l10n.editor_duplicate),
              ),
              PopupMenuItem(
                value: _LayerAction.delete,
                child: Text(l10n.editor_delete),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        controller.select(element.id);
        Navigator.of(context).pop();
      },
    );
  }
}
