import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/normalized_rect.dart';
import '../../../../domain/entities/watermark_element.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/editor_controller.dart';
import '../controller/editor_image_cache.dart';
import 'crop_sheet.dart';
import 'inspector_controls.dart';

/// Everything that only an image watermark has, including the
/// non-destructive crop.
class ImagePropertiesPanel extends StatelessWidget {
  const ImagePropertiesPanel({
    required this.controller,
    required this.element,
    required this.images,
    super.key,
  });

  final EditorController controller;
  final ImageWatermark element;
  final EditorImageCache images;

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final dims = context.dimensions;
    final crop = element.crop;

    void setOpacity(double value) => controller.setOpacity(element.id, value);
    void setRotation(double value) => controller.setRotation(element.id, value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorSection(
          title: l10n.editor_image,
          children: [
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
            InspectorSwitchRow(
              label: l10n.editor_lockAspect,
              value: element.lockAspect,
              onChanged: (value) =>
                  controller.updateImage(element.id, lockAspect: value),
            ),
            Gap(dims.space.s8),
            _CropActions(
              controller: controller,
              element: element,
              images: images,
            ),
          ],
        ),
        if (crop != null)
          InspectorSection(
            title: l10n.editor_crop_title,
            children: [
              BodySmallText.muted(_cropSummary(crop)),
              Gap(dims.space.s8),
              OutlinedButton.icon(
                onPressed: () => controller.resetCrop(element.id),
                icon: const Icon(Icons.crop_free),
                label: Text(l10n.editor_crop_reset),
              ),
            ],
          ),
      ],
    );
  }

  String _cropSummary(CropRect crop) {
    final width = (crop.w * 100).round();
    final height = (crop.h * 100).round();

    return '$width% × $height%';
  }
}

class _CropActions extends StatelessWidget {
  const _CropActions({
    required this.controller,
    required this.element,
    required this.images,
  });

  final EditorController controller;
  final ImageWatermark element;
  final EditorImageCache images;

  Future<void> _crop(BuildContext context) async {
    final l10n = context.locale;
    final bytes = await images.loadBytes(element.assetId);
    final natural = await images.naturalSize(element.assetId);
    if (bytes == null || natural == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.editor_assetUnavailable)),
      );
      return;
    }
    if (!context.mounted) return;

    final decision = await showEditorCropSheet(
      context,
      bytes: bytes,
      naturalSize: Size(natural.width, natural.height),
      crop: element.crop,
    );
    if (decision == null) return;

    final crop = decision.crop;
    if (crop == null) {
      controller.resetCrop(element.id);
    } else {
      controller.applyCrop(element.id, crop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;

    return FilledButton.tonalIcon(
      onPressed: () => _crop(context),
      icon: const Icon(Icons.crop),
      label: Text(l10n.editor_crop_title),
    );
  }
}
