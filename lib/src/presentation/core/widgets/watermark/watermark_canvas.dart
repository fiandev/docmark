import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../domain/entities/image_format.dart';
import '../../../../domain/entities/normalized_rect.dart';
import '../../../../domain/entities/watermark_element.dart';
import '../../../../domain/services/font_registry.dart';

/// Resolves an encrypted image asset id to a decoded image for painting.
///
/// The editor keeps a synchronous cache and hands it to the painter; the
/// exporter pre-decodes the same assets and passes the map. Both paths
/// therefore draw the same bytes through the same painter.
typedef WatermarkImageResolver = ui.Image? Function(String assetId);

/// The one watermark painter used by the editor preview and every export.
///
/// Everything here works in page-pixel space: [pageSize] is the rendered
/// page's size, and each element's [NormalizedRect] is projected through
/// [NormalizedRect.toRect]. Because the export raster is only a larger
/// page-size, the normalized geometry, the text scale and the padding
/// all resolve identically at preview and export resolution — that is the
/// whole WYSIWYG contract.
///
/// The function is intentionally free of any `BuildContext`: the data
/// layer receives it through the DI seam and calls it with a raw [Canvas].
void paintWatermarkElements(
  ui.Canvas canvas,
  ui.Size pageSize,
  List<WatermarkElement> elements,
  WatermarkImageResolver imageResolver,
) {
  if (pageSize.width <= 0 || pageSize.height <= 0) return;

  for (final element in elements) {
    if (!element.visible || element.opacity <= 0) continue;
    _paintElement(canvas, element, pageSize, imageResolver);
  }
}

void _paintElement(
  ui.Canvas canvas,
  WatermarkElement element,
  ui.Size pageSize,
  WatermarkImageResolver imageResolver,
) {
  final rect = element.rect.toRect(pageSize);
  if (rect.isEmpty) return;

  final opacity = element.opacity.clamp(0.0, 1.0).toDouble();
  if (opacity <= 0) return;

  canvas.save();
  canvas.translate(rect.center.dx, rect.center.dy);
  canvas.rotate(element.rotationDeg * math.pi / 180);

  final localRect = ui.Rect.fromCenter(
    center: ui.Offset.zero,
    width: rect.width,
    height: rect.height,
  );

  if (opacity < 1) {
    // One layer for the whole element, so the background, the outline and
    // the glyphs fade together instead of stacking into a darker seam.
    canvas.saveLayer(
      null,
      ui.Paint()..color = Colors.black.withValues(alpha: opacity),
    );
  }

  switch (element) {
    case TextWatermark():
      _paintText(canvas, element, localRect, pageSize);
    case ImageWatermark():
      _paintImage(canvas, element, localRect, imageResolver);
  }

  if (opacity < 1) canvas.restore();
  canvas.restore();
}

void _paintText(
  ui.Canvas canvas,
  TextWatermark element,
  ui.Rect rect,
  ui.Size pageSize,
) {
  if (element.content.isEmpty) return;

  // Logical units are authored against a 1000-px-wide page, so the same
  // value means the same physical size on any rendered resolution.
  final scale = pageSize.width <= 0 ? 1.0 : pageSize.width / 1000;
  final fontSize = math.max(1.0, element.sizeLogical * scale);
  final textAlign = _textAlign(element.align);
  final maxWidth = math.max(1.0, rect.width);

  final fillPainter = TextPainter(
    text: TextSpan(
      text: element.content,
      style: _textStyle(
        element,
        fontSize: fontSize,
        color: ui.Color(element.colorArgb),
      ),
    ),
    textAlign: textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  final blockHeight = fillPainter.height;
  final top = rect.top + math.max(0.0, (rect.height - blockHeight) / 2);
  final block = ui.Rect.fromLTWH(
    rect.left,
    top,
    fillPainter.width,
    blockHeight,
  );

  final background = element.background;
  if (background != null) {
    final padding = background.paddingLogical * scale;
    final radius = math.max(0.0, background.radiusLogical * scale);
    final plate = ui.RRect.fromRectAndRadius(
      block.inflate(padding),
      ui.Radius.circular(radius),
    );
    canvas.drawRRect(
      plate,
      ui.Paint()..color = ui.Color(background.colorArgb),
    );
  }

  final outline = element.outline;
  if (outline != null && outline.widthLogical > 0) {
    final strokePainter = TextPainter(
      text: TextSpan(
        text: element.content,
        style: _textStyle(
          element,
          fontSize: fontSize,
          foreground: ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = math.max(0.1, outline.widthLogical * scale)
            ..color = ui.Color(outline.colorArgb),
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    strokePainter.paint(canvas, block.topLeft);
    strokePainter.dispose();
  }

  fillPainter.paint(canvas, block.topLeft);
  fillPainter.dispose();
}

void _paintImage(
  ui.Canvas canvas,
  ImageWatermark element,
  ui.Rect rect,
  WatermarkImageResolver imageResolver,
) {
  final image = imageResolver(element.assetId);
  if (image == null) return;

  final naturalSize = ui.Size(
    image.width.toDouble(),
    image.height.toDouble(),
  );
  final crop = (element.crop ?? const CropRect.full()).clamped();
  final src = crop.toSrcRect(naturalSize);
  if (src.isEmpty) return;

  canvas.drawImageRect(
    image,
    src,
    rect,
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
}

TextStyle _textStyle(
  TextWatermark element, {
  required double fontSize,
  ui.Color? color,
  ui.Paint? foreground,
}) {
  final spec = FontRegistry.catalog[element.font];
  final fallback = spec?.fallback;

  return TextStyle(
    fontFamily: spec?.family,
    fontFamilyFallback: fallback == null ? null : <String>[fallback],
    fontSize: fontSize,
    color: foreground == null ? color : null,
    foreground: foreground,
    fontWeight: element.bold ? FontWeight.bold : FontWeight.normal,
    fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
  );
}

TextAlign _textAlign(TextAlignType align) {
  return switch (align) {
    TextAlignType.start => TextAlign.left,
    TextAlignType.center => TextAlign.center,
    TextAlignType.end => TextAlign.right,
    TextAlignType.justify => TextAlign.justify,
  };
}
