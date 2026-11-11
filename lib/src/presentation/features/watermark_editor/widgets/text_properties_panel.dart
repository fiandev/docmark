import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/image_format.dart';
import '../../../../domain/entities/watermark_element.dart';
import '../../../../domain/services/font_registry.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/editor_controller.dart';
import 'font_picker_sheet.dart';
import 'inspector_controls.dart';

/// Everything that only a text watermark has: the copy, the type, and the
/// optional outline and plate behind it.
class TextPropertiesPanel extends StatelessWidget {
  const TextPropertiesPanel({
    required this.controller,
    required this.element,
    super.key,
  });

  final EditorController controller;
  final TextWatermark element;

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final dims = context.dimensions;
    final outline = element.outline;
    final background = element.background;

    void setContent(String value) =>
        controller.updateText(element.id, content: value);
    void setSize(double value) =>
        controller.updateText(element.id, sizeLogical: value);
    void setColor(int value) =>
        controller.updateText(element.id, colorArgb: value);
    void setBold(bool value) =>
        controller.updateText(element.id, bold: value);
    void setItalic(bool value) =>
        controller.updateText(element.id, italic: value);
    void setOpacity(double value) => controller.setOpacity(element.id, value);
    void setRotation(double value) => controller.setRotation(element.id, value);
    void setAlign(Set<TextAlignType> selection) =>
        controller.updateText(element.id, align: selection.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorSection(
          title: l10n.editor_textContent,
          children: [
            TextFormField(
              key: ValueKey<String>('editor-text-${element.id}'),
              initialValue: element.content,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.editor_textPlaceholder,
              ),
              onChanged: setContent,
            ),
            Gap(dims.space.s8),
            _FontFamilyRow(element: element, controller: controller),
          ],
        ),
        InspectorSection(
          title: l10n.editor_fontSize,
          children: [
            InspectorSlider(
              label: l10n.editor_fontSize,
              value: element.sizeLogical,
              min: 8,
              max: 120,
              valueLabel: '${element.sizeLogical.round()}',
              onChanged: setSize,
            ),
            InspectorColorRow(
              label: l10n.editor_fontColor,
              colorArgb: element.colorArgb,
              onChanged: setColor,
            ),
            InspectorSlider(
              label: l10n.editor_opacity,
              value: element.opacity,
              min: 0,
              max: 1,
              divisions: 20,
              valueLabel: '${(element.opacity * 100).round()}%',
              onChanged: setOpacity,
            ),
            InspectorSlider(
              label: l10n.editor_rotation,
              value: element.rotationDeg,
              min: 0,
              max: 360,
              divisions: 72,
              valueLabel: '${element.rotationDeg.round()}°',
              onChanged: setRotation,
            ),
            Wrap(
              spacing: dims.space.s8,
              children: [
                FilterChip(
                  label: Text(l10n.editor_bold),
                  selected: element.bold,
                  onSelected: setBold,
                ),
                FilterChip(
                  label: Text(l10n.editor_italic),
                  selected: element.italic,
                  onSelected: setItalic,
                ),
              ],
            ),
            Gap(dims.space.s8),
            LabelText(l10n.editor_align),
            Gap(dims.space.s4),
            SegmentedButton<TextAlignType>(
              segments: [
                ButtonSegment(
                  value: TextAlignType.start,
                  icon: const Icon(Icons.format_align_left),
                  tooltip: l10n.editor_align_start,
                ),
                ButtonSegment(
                  value: TextAlignType.center,
                  icon: const Icon(Icons.format_align_center),
                  tooltip: l10n.editor_align_center,
                ),
                ButtonSegment(
                  value: TextAlignType.end,
                  icon: const Icon(Icons.format_align_right),
                  tooltip: l10n.editor_align_end,
                ),
                ButtonSegment(
                  value: TextAlignType.justify,
                  icon: const Icon(Icons.format_align_justify),
                  tooltip: l10n.editor_align_justify,
                ),
              ],
              selected: <TextAlignType>{element.align},
              onSelectionChanged: setAlign,
            ),
          ],
        ),
        InspectorSection(
          title: l10n.editor_decoration_title,
          children: [
            InspectorSwitchRow(
              label: l10n.editor_decoration_outline,
              value: outline != null,
              onChanged: _toggleOutline,
            ),
            if (outline != null) ...[
              InspectorSlider(
                label: l10n.editor_decoration_outlineWidth,
                value: outline.widthLogical,
                min: 0.5,
                max: 12,
                valueLabel: outline.widthLogical.toStringAsFixed(1),
                onChanged: (value) => controller.updateText(
                  element.id,
                  outline: outline.copyWith(widthLogical: value),
                ),
              ),
              InspectorColorRow(
                label: l10n.editor_decoration_outlineColor,
                colorArgb: outline.colorArgb,
                onChanged: (value) => controller.updateText(
                  element.id,
                  outline: outline.copyWith(colorArgb: value),
                ),
              ),
            ],
            InspectorSwitchRow(
              label: l10n.editor_decoration_background,
              value: background != null,
              onChanged: (enabled) => _toggleBackground(context, enabled),
            ),
            if (background != null) ...[
              InspectorSlider(
                label: l10n.editor_decoration_backgroundPadding,
                value: background.paddingLogical,
                min: 0,
                max: 32,
                valueLabel: background.paddingLogical.toStringAsFixed(0),
                onChanged: (value) => controller.updateText(
                  element.id,
                  background: background.copyWith(paddingLogical: value),
                ),
              ),
              InspectorSlider(
                label: l10n.editor_decoration_backgroundRadius,
                value: background.radiusLogical,
                min: 0,
                max: 32,
                valueLabel: background.radiusLogical.toStringAsFixed(0),
                onChanged: (value) => controller.updateText(
                  element.id,
                  background: background.copyWith(radiusLogical: value),
                ),
              ),
              InspectorColorRow(
                label: l10n.editor_decoration_backgroundColor,
                colorArgb: background.colorArgb,
                onChanged: (value) => controller.updateText(
                  element.id,
                  background: background.copyWith(colorArgb: value),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _toggleOutline(bool enabled) {
    if (enabled) {
      controller.updateText(
        element.id,
        outline: OutlineSpec(
          widthLogical: 2,
          colorArgb: element.colorArgb,
        ),
      );
      return;
    }

    controller.updateText(element.id, clearOutline: true);
  }

  void _toggleBackground(BuildContext context, bool enabled) {
    if (enabled) {
      final plate = context.color.docMark.defaultWatermarkBackground;

      controller.updateText(
        element.id,
        background: BackgroundSpec(colorArgb: plate.toARGB32()),
      );
      return;
    }

    controller.updateText(element.id, clearBackground: true);
  }
}

class _FontFamilyRow extends StatelessWidget {
  const _FontFamilyRow({required this.element, required this.controller});

  final TextWatermark element;
  final EditorController controller;

  Future<void> _pick(BuildContext context) async {
    final picked = await showFontPickerSheet(
      context,
      selected: element.font,
    );
    if (picked != null) controller.updateText(element.id, font: picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final dims = context.dimensions;
    final family = FontRegistry.familyOf(element.font);

    return InkWell(
      borderRadius: BorderRadius.circular(dims.radius.small),
      onTap: () => _pick(context),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dims.space.s8),
        child: Row(
          children: [
            Expanded(child: LabelText(l10n.editor_fontFamily)),
            Text(
              fontTokenLabel(l10n, element.font),
              style: TextStyle(fontFamily: family),
            ),
            Gap(dims.space.s4),
            Icon(
              Icons.chevron_right,
              size: dims.size.iconLarge,
              color: context.color.text.muted,
            ),
          ],
        ),
      ),
    );
  }
}
