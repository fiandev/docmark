import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/di/features/history_providers.dart';
import '../../../../core/di/features/import_providers.dart';
import '../../../../core/di/features/render_providers.dart';
import '../../../../core/di/features/security_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../domain/entities/document.dart';
import '../../../../domain/entities/image_format.dart';
import '../../../../domain/services/render_contract.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/export_controller.dart';
import '../controller/export_file_writer.dart';
import '../widgets/export_actions.dart';
import '../widgets/export_format_selector.dart';
import '../widgets/export_page_selector.dart';
import '../widgets/export_preview_card.dart';
import '../widgets/export_quality_slider.dart';
import '../widgets/export_warning_card.dart';

/// Export preview: the last look before a file leaves the encrypted vault.
///
/// The preview is produced by the same renderer as the export, so the
/// user approves the actual output. Saving and sharing always write new
/// files; the imported document is only ever read.
class ExportPreviewPage extends ConsumerStatefulWidget {
  const ExportPreviewPage({required this.request, super.key});

  final ExportRequest request;

  @override
  ConsumerState<ExportPreviewPage> createState() => _ExportPreviewPageState();
}

class _ExportPreviewPageState extends ConsumerState<ExportPreviewPage> {
  late final ExportController _controller;
  late final Set<int> _pages;
  late ImageFormat _format;
  late double _quality;

  final Map<int, Uint8List> _thumbnails = <int, Uint8List>{};

  Uint8List? _preview;
  ExportBundle? _bundle;
  String? _bundleKey;

  bool _loadingPreview = false;
  bool _busy = false;
  bool _failed = false;
  int _previewToken = 0;

  bool get _isEmpty => widget.request.document.id.isEmpty;
  bool get _isPdf => widget.request.document.kind == DocumentKind.pdf;

  @override
  void initState() {
    super.initState();

    _format = _supportedFormat(widget.request.options.format);
    _quality = widget.request.options.jpegQuality.clamp(0.5, 1.0).toDouble();
    _pages = <int>{...widget.request.resolvedPages};

    if (!_isEmpty) {
      _controller = ExportController(
        request: widget.request,
        renderer: ref.read(watermarkRendererProvider),
        documents: ref.read(documentRepositoryProvider),
        vault: ref.read(secureFileVaultProvider),
        history: ref.read(historyRepositoryProvider),
        fileWriter: const DeviceExportFileWriter(),
      );
      _loadingPreview = true;
      unawaited(_loadPreview());
      if (_isPdf) unawaited(_loadThumbnails());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(context.locale.export_previewTitle),
      ),
      body: SafeArea(
        child: _isEmpty
            ? Padding(
                padding: EdgeInsets.all(context.dimensions.space.s24),
                child: BodySmallText.muted(context.locale.export_empty),
              )
            : ListView(
                padding: EdgeInsets.all(context.dimensions.space.s16),
                children: [
                  const ExportWarningCard(),
                  Gap(context.dimensions.space.s16),
                  ExportPreviewCard(
                    bytes: _preview,
                    aspectRatio: _aspectRatio,
                    isLoading: _loadingPreview,
                  ),
                  Gap(context.dimensions.space.s16),
                  ExportFormatSelector(
                    selected: _format,
                    onChanged: _onFormatChanged,
                    enabled: !_busy,
                  ),
                  if (_format == ImageFormat.jpeg) ...[
                    Gap(context.dimensions.space.s12),
                    ExportQualitySlider(
                      value: _quality,
                      onChanged: _onQualityChanged,
                      enabled: !_busy,
                    ),
                  ],
                  if (_isPdf) ...[
                    Gap(context.dimensions.space.s16),
                    ExportPageSelector(
                      pages: widget.request.resolvedPages,
                      thumbnails: _thumbnails,
                      selected: _pages,
                      onToggle: _onTogglePage,
                      enabled: !_busy,
                    ),
                  ],
                  Gap(context.dimensions.space.s16),
                  BodySmallText.muted(
                    context.locale.export_pages(_pages.length),
                  ),
                  if (_failed) ...[
                    Gap(context.dimensions.space.s8),
                    BodySmallText.muted(context.locale.export_error),
                  ],
                  Gap(context.dimensions.space.s24),
                  ExportActions(
                    onSave: _pages.isEmpty
                        ? null
                        : () => unawaited(_onSave()),
                    onShare: _pages.isEmpty
                        ? null
                        : () => unawaited(_onShare()),
                    isBusy: _busy,
                  ),
                ],
              ),
      ),
    );
  }

  static ImageFormat _supportedFormat(ImageFormat format) {
    return switch (format) {
      ImageFormat.jpeg || ImageFormat.png || ImageFormat.pdf => format,
      ImageFormat.webp || ImageFormat.unknown => ImageFormat.pdf,
    };
  }

  List<int> _orderedPages() => _pages.toList()..sort();

  double get _aspectRatio {
    final pages = _orderedPages();
    if (pages.isEmpty) return 1.0;

    final page = widget.request.document.pageAt(pages.first);
    if (page == null || page.heightPt <= 0) return 1.0;

    return page.widthPt / page.heightPt;
  }

  Future<void> _loadPreview() async {
    final token = ++_previewToken;
    final pages = _orderedPages();
    if (pages.isEmpty) {
      if (mounted) {
        setState(() {
          _preview = null;
          _loadingPreview = false;
        });
      }
      return;
    }

    try {
      final bytes = await _controller.preview(pages.first);
      if (!mounted || token != _previewToken) return;
      setState(() {
        _preview = bytes;
        _loadingPreview = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || token != _previewToken) return;
      setState(() {
        _loadingPreview = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadThumbnails() async {
    for (final page in _orderedPages()) {
      try {
        final bytes = await _controller.thumbnail(page);
        if (!mounted) return;
        setState(() => _thumbnails[page] = bytes);
      } catch (_) {
        // The placeholder tile is enough; export still works.
      }
    }
  }

  void _onFormatChanged(ImageFormat format) {
    if (format == _format) return;
    setState(() {
      _format = format;
      _invalidateBundle();
      _failed = false;
    });
  }

  void _onQualityChanged(double value) {
    setState(() {
      _quality = value;
      _invalidateBundle();
    });
  }

  void _onTogglePage(int page) {
    setState(() {
      if (!_pages.remove(page)) _pages.add(page);
      _invalidateBundle();
      _loadingPreview = true;
    });
    unawaited(_loadPreview());
  }

  void _invalidateBundle() {
    _bundle = null;
    _bundleKey = null;
  }

  Future<ExportBundle> _prepareBundle() async {
    final key = _bundleSignature;
    final cached = _bundle;
    if (cached != null && _bundleKey == key) return cached;

    ref.read(exportSettingsProvider).jpegQuality = _quality;
    final bundle = await _controller.exportDocument(
      format: _format,
      jpegQuality: _quality,
      pages: _pages,
    );
    _bundle = bundle;
    _bundleKey = key;

    return bundle;
  }

  String get _bundleSignature {
    return '${_format.name}|${_quality.toStringAsFixed(2)}|'
        '${_orderedPages().join(',')}';
  }

  Future<void> _onSave() async {
    if (_pages.isEmpty || _busy) return;
    if (!await _confirmUnencrypted()) return;
    if (!mounted) return;
    final success = context.locale.export_success;

    await _run(() async {
      final bundle = await _prepareBundle();
      await _controller.save(bundle);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    });
  }

  Future<void> _onShare() async {
    if (_pages.isEmpty || _busy) return;
    if (!await _confirmUnencrypted()) return;
    if (!mounted) return;
    final subject = context.locale.export_shareSubject;

    await _run(() async {
      final bundle = await _prepareBundle();
      await _controller.share(bundle, subject: subject);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmUnencrypted() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.locale.export_unencrypted_warning_title),
        content: BodySmallText(
          context.locale.export_unencrypted_warning_body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.locale.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.locale.export_unencrypted_acknowledge),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
