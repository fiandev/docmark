import 'package:flutter/material.dart';

import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/watermark_element.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/editor_controller.dart';
import '../controller/editor_image_cache.dart';
import 'image_properties_panel.dart';
import 'inspector_controls.dart';
import 'text_properties_panel.dart';

/// The editor's property panel: shared element actions first, then the
/// controls that belong to the selected element's type.
class EditorInspector extends StatelessWidget {
  const EditorInspector({
    required this.controller,
    required this.images,
    super.key,
  });

  final EditorController controller;
  final EditorImageCache images;

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final element = controller.selectedElement;
    final padding = EdgeInsets.all(context.dimensions.docMark.panelPadding);

    if (element == null) {
      return SingleChildScrollView(
        padding: padding,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.dimensions.space.s24,
          ),
          child: BodySmallText.muted(
            l10n.editor_noSelection,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ElementActions(controller: controller, element: element),
          _PositionSection(controller: controller, element: element),
          if (element is TextWatermark)
            TextPropertiesPanel(controller: controller, element: element)
          else
            ImagePropertiesPanel(
              controller: controller,
              element: element as ImageWatermark,
              images: images,
            ),
        ],
      ),
    );
  }
}

class _ElementActions extends StatelessWidget {
  const _ElementActions({required this.controller, required this.element});

  final EditorController controller;
  final WatermarkElement element;

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final id = element.id;

    return InspectorSection(
      title: l10n.editor_layers,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: l10n.editor_layerBringFront,
              onPressed: () => controller.bringToFront(id),
              icon: const Icon(Icons.vertical_align_top),
            ),
            IconButton(
              tooltip: l10n.editor_layerForward,
              onPressed: () => controller.moveForward(id),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: l10n.editor_layerBackward,
              onPressed: () => controller.moveBackward(id),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: l10n.editor_layerSendBack,
              onPressed: () => controller.sendToBack(id),
              icon: const Icon(Icons.vertical_align_bottom),
            ),
            IconButton(
              tooltip: element.locked ? l10n.editor_unlock : l10n.editor_lock,
              onPressed: () => controller.toggleLock(id),
              icon: Icon(
                element.locked ? Icons.lock_outline : Icons.lock_open_outlined,
              ),
            ),
            IconButton(
              tooltip: element.visible
                  ? l10n.editor_visible
                  : l10n.editor_hidden,
              onPressed: () => controller.toggleVisibility(id),
              icon: Icon(
                element.visible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            IconButton(
              tooltip: l10n.editor_duplicate,
              onPressed: () => controller.duplicate(id),
              icon: const Icon(Icons.copy_outlined),
            ),
            IconButton(
              tooltip: l10n.editor_delete,
              onPressed: () => controller.remove(id),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ],
    );
  }
}

class _PositionSection extends StatelessWidget {
  const _PositionSection({required this.controller, required this.element});

  final EditorController controller;
  final WatermarkElement element;

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final id = element.id;
    final everyPage = controller.paintsEveryPage(id);

    return InspectorSection(
      title: l10n.editor_position,
      children: [
        InspectorNudgePad(
          onNudge: (delta) => controller.moveBy(id, delta),
          fineLabel: l10n.editor_positionFine,
          coarseLabel: l10n.editor_positionCoarse,
          stepLabel: l10n.editor_positionStep,
        ),
        if (controller.pageCount > 1) ...[
          InspectorSwitchRow(
            label: l10n.editor_pageOnly,
            value: !everyPage,
            onChanged: (onlyThisPage) {
              final pages = onlyThisPage
                  ? <int>{controller.pageIndex}
                  : controller.pageSourceIndices.toSet();
              controller.setElementPages(id, pages);
            },
          ),
        ],
      ],
    );
  }
}
