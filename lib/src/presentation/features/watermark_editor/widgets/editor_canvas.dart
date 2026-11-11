import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/base/result.dart';
import '../../../../core/di/features/import_providers.dart';
import '../../../../core/di/features/render_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../domain/services/render_contract.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/editor_controller.dart';
import '../controller/editor_image_cache.dart';
import 'watermark_gesture_layer.dart';

/// The document page plus the interactive watermark layer.
///
/// The page's pixel size is computed from the available space and the
/// page's own aspect ratio, and that same size is handed to the shared
/// painter and the gesture math. Because everything derives from
/// normalized coordinates, the layout can change freely without moving a
/// watermark.
class EditorCanvas extends ConsumerStatefulWidget {
  const EditorCanvas({
    required this.controller,
    required this.images,
    super.key,
  });

  final EditorController controller;
  final EditorImageCache images;

  @override
  ConsumerState<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends ConsumerState<EditorCanvas> {
  Uint8List? _preview;
  bool _loading = true;
  bool _failed = false;
  int _token = 0;
  int _loadedPage = -1;
  int? _loadingPage;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onDraftChanged);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant EditorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;

    oldWidget.controller.removeListener(_onDraftChanged);
    widget.controller.addListener(_onDraftChanged);
    _loadedPage = -1;
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDraftChanged);
    super.dispose();
  }

  void _onDraftChanged() {
    final page = widget.controller.pageIndex;
    if (page == _loadedPage || page == _loadingPage) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    final controller = widget.controller;
    final page = controller.pageIndex;
    final token = ++_token;

    setState(() {
      _loading = true;
      _failed = false;
      _loadingPage = page;
    });

    try {
      final document = controller.document;
      final result = await ref
          .read(documentRepositoryProvider)
          .readPage(document.id, page);

      if (result case Success(:final data)) {
        final pageSize = document.pageAt(page)?.sizePt ?? Size.zero;
        final bytes = await ref
            .read(watermarkRendererProvider)
            .thumbnail(
              RenderRequest(
                sourceBytes: data,
                pageIndex: page,
                pageSize: pageSize,
                elements: const [],
              ),
              maxWidth: 1200,
            );
        if (!mounted || token != _token) return;
        setState(() {
          _preview = bytes;
          _loadedPage = page;
          _loading = false;
          _loadingPage = null;
        });
        return;
      }

      _finishFailed(token, page);
    } catch (_) {
      _finishFailed(token, page);
    }
  }

  void _finishFailed(int token, int page) {
    if (!mounted || token != _token) return;
    setState(() {
      _failed = true;
      _loading = false;
      _loadingPage = null;
      _loadedPage = page;
    });
  }

  double _aspectRatio() {
    final controller = widget.controller;
    final page = controller.document.pageAt(controller.pageIndex);
    if (page == null || page.heightPt <= 0) return 1;

    return page.widthPt / page.heightPt;
  }

  static Size _fit(Size available, double aspect) {
    if (available.isEmpty || aspect <= 0) return Size.zero;

    final width = available.width;
    final height = width / aspect;
    if (height <= available.height) return Size(width, height);

    return Size(available.height * aspect, available.height);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = context.locale;

    if (controller.pageCount <= 0) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.dimensions.space.s24),
          child: BodySmallText.muted(
            l10n.editor_emptyDocument,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(context.dimensions.space.s16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = _fit(
                  Size(constraints.maxWidth, constraints.maxHeight),
                  _aspectRatio(),
                );
                if (size.isEmpty) return const SizedBox.shrink();

                return Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: context.dimensions.elevation.raised,
                      border: Border.all(
                        color: context.color.border.subtle,
                      ),
                    ),
                    child: SizedBox.fromSize(
                      size: size,
                      child: WatermarkGestureLayer(
                        controller: controller,
                        pageSize: size,
                        imageResolver: widget.images.resolve,
                        child: _PagePreview(
                          bytes: _preview,
                          loading: _loading,
                          failed: _failed,
                          failedLabel: l10n.failures_render,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (controller.pageCount > 1) _PageBar(controller: controller),
      ],
    );
  }
}

class _PagePreview extends StatelessWidget {
  const _PagePreview({
    required this.bytes,
    required this.loading,
    required this.failed,
    required this.failedLabel,
  });

  final Uint8List? bytes;
  final bool loading;
  final bool failed;
  final String failedLabel;

  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    if (!loading && !failed && bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            _CanvasPlaceholder(label: failedLabel),
      );
    }

    return _CanvasPlaceholder(
      label: failedLabel,
      loading: loading,
    );
  }
}

class _CanvasPlaceholder extends StatelessWidget {
  const _CanvasPlaceholder({required this.label, this.loading = false});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.color.background.canvas,
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: EdgeInsets.all(context.dimensions.space.s16),
                child: BodySmallText.muted(
                  label,
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}

class _PageBar extends StatelessWidget {
  const _PageBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final page = controller.pageIndex;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.dimensions.space.s16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: l10n.common_back,
            onPressed: page <= 0
                ? null
                : () => controller.setPage(page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Gap(context.dimensions.space.s8),
          BodySmallText(
            l10n.editor_page(page + 1, controller.pageCount),
          ),
          Gap(context.dimensions.space.s8),
          IconButton(
            tooltip: l10n.common_next,
            onPressed: page >= controller.pageCount - 1
                ? null
                : () => controller.setPage(page + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
