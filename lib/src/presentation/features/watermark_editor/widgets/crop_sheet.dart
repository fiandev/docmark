import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/normalized_rect.dart';
import '../../../../domain/services/watermark_geometry.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/editor_gestures.dart';

/// What the crop sheet returns: an applied window, or a reset to the whole
/// source image. Dismissing the sheet returns null.
final class CropDecision {
  const CropDecision.apply(this.crop);

  const CropDecision.reset() : crop = null;

  /// The window to write into the element; null means "no crop".
  final CropRect? crop;
}

/// Opens the crop editor for one image watermark over a scrim.
///
/// The crop is non-destructive: the asset bytes are only displayed, and
/// the returned [CropRect] is a window into them.
Future<CropDecision?> showEditorCropSheet(
  BuildContext context, {
  required Uint8List bytes,
  required Size naturalSize,
  CropRect? crop,
}) {
  return Navigator.of(context).push<CropDecision>(
    MaterialPageRoute<CropDecision>(
      fullscreenDialog: true,
      builder: (context) => _CropSheet(
        bytes: bytes,
        naturalSize: naturalSize,
        initialCrop: crop,
      ),
    ),
  );
}

class _CropSheet extends StatefulWidget {
  const _CropSheet({
    required this.bytes,
    required this.naturalSize,
    required this.initialCrop,
  });

  final Uint8List bytes;
  final Size naturalSize;
  final CropRect? initialCrop;

  @override
  State<_CropSheet> createState() => _CropSheetState();
}

class _CropSheetState extends State<_CropSheet> {
  late CropRect _crop = widget.initialCrop ?? const CropRect.full();

  CropHandle? _handle;
  Offset? _lastPoint;
  Rect _bounds = Rect.zero;

  void _onStart(Offset point) {
    final window = cropWindowRect(_crop, _bounds);
    _handle = resolveCropGrab(
      point: point,
      cropRect: window,
      handleRadius: context.dimensions.docMark.cropHandleTouch / 2,
    );
    _lastPoint = point;
  }

  void _onUpdate(Offset point, double minSize) {
    final handle = _handle;
    final last = _lastPoint;
    if (handle == null || last == null) return;

    final delta = normalizedDelta(point - last, _bounds.size);
    _lastPoint = point;
    setState(() {
      _crop = WatermarkGeometry.applyCropDrag(_crop, handle, delta, minSize);
    });
  }

  void _reset() {
    setState(() {
      _crop = const CropRect.full();
      _handle = null;
      _lastPoint = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final dims = context.dimensions.docMark;
    final colors = context.color.docMark;
    final minSize = dims.minElementSize;

    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(l10n.editor_crop_title),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const CropDecision.reset()),
            child: Text(l10n.editor_crop_reset),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final available = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final bounds = containRect(available, widget.naturalSize);
                  _bounds = bounds;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) => _onStart(details.localPosition),
                    onPanUpdate: (details) =>
                        _onUpdate(details.localPosition, minSize),
                    onPanEnd: (_) {
                      _handle = null;
                    },
                    onPanCancel: () {
                      _handle = null;
                    },
                    child: Stack(
                      children: [
                        Positioned.fromRect(
                          rect: bounds,
                          child: Image.memory(
                            widget.bytes,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CropPainter(
                                crop: _crop,
                                bounds: bounds,
                                scrim: colors.cropScrim,
                                guide: colors.cropGuide,
                                handleFill: colors.cropHandle,
                                handleBorder: colors.elementHandleBorder,
                                handleRadius: dims.cropHandle / 2,
                                strokeWidth: dims.cropGuideStroke,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.all(context.dimensions.space.s16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: Text(l10n.editor_crop_reset),
                    ),
                  ),
                  Gap(context.dimensions.space.s8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        CropDecision.apply(_crop),
                      ),
                      child: Text(l10n.editor_crop_apply),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  const _CropPainter({
    required this.crop,
    required this.bounds,
    required this.scrim,
    required this.guide,
    required this.handleFill,
    required this.handleBorder,
    required this.handleRadius,
    required this.strokeWidth,
  });

  final CropRect crop;
  final Rect bounds;
  final Color scrim;
  final Color guide;
  final Color handleFill;
  final Color handleBorder;
  final double handleRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (bounds.isEmpty) return;

    final window = cropWindowRect(crop, bounds);
    if (window.isEmpty) return;

    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(bounds),
      Path()..addRect(window),
    );
    canvas.drawPath(outside, Paint()..color = scrim);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = guide;
    final thirdWidth = window.width / 3;
    final thirdHeight = window.height / 3;
    for (var i = 1; i < 3; i++) {
      final x = window.left + thirdWidth * i;
      final y = window.top + thirdHeight * i;
      canvas.drawLine(Offset(x, window.top), Offset(x, window.bottom), line);
      canvas.drawLine(Offset(window.left, y), Offset(window.right, y), line);
    }
    canvas.drawRect(window, line);

    final fill = Paint()..color = handleFill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = handleBorder;
    for (final point in _handlePoints(window)) {
      canvas.drawCircle(point, handleRadius, fill);
      canvas.drawCircle(point, handleRadius, border);
    }
  }

  List<Offset> _handlePoints(Rect window) {
    final center = window.center;

    return <Offset>[
      window.topLeft,
      window.topRight,
      window.bottomRight,
      window.bottomLeft,
      Offset(center.dx, window.top),
      Offset(window.right, center.dy),
      Offset(center.dx, window.bottom),
      Offset(window.left, center.dy),
    ];
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.crop != crop ||
        oldDelegate.bounds != bounds ||
        oldDelegate.scrim != scrim ||
        oldDelegate.guide != guide ||
        oldDelegate.handleFill != handleFill ||
        oldDelegate.handleBorder != handleBorder ||
        oldDelegate.handleRadius != handleRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
