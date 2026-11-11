import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../../../core/di/features/import_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../core/router/routes.dart';
import '../../../../domain/entities/document.dart';
import '../../../../domain/failures/business_failure.dart';
import '../../../../domain/repositories/document_repository.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/document_import_controller.dart';

/// Document picker: gallery or file manager, validated by magic bytes.
///
/// OWNER: T2 (import flow). The constructor signature is frozen; all
/// plugins arrive through providers so widget tests can run without a
/// platform channel.
class DocumentPickerPage extends ConsumerStatefulWidget {
  const DocumentPickerPage({super.key});

  @override
  ConsumerState<DocumentPickerPage> createState() => _DocumentPickerPageState();
}

/// The screen's coarse states. [error] covers both an invalid file and a
/// failed import; the message carries the distinction.
enum _PickerStage { idle, reading, selectingPages, importing, error }

enum _PickerError { invalidFormat, failed }

class _DocumentPickerPageState extends ConsumerState<DocumentPickerPage> {
  late final DocumentImportController _controller;

  _PickerStage _stage = _PickerStage.idle;
  _PickerError? _error;
  ImportRequest? _pdfRequest;
  int _pdfPageCount = 0;
  int _previewToken = 0;

  final Set<int> _selectedPages = <int>{};
  final Map<int, Uint8List> _thumbnails = <int, Uint8List>{};

  @override
  void initState() {
    super.initState();
    _controller = DocumentImportController(
      documents: ref.read(documentRepositoryProvider),
      normalizer: ref.read(mediaNormalizerServiceProvider),
      picker: ref.read(documentPickServiceProvider),
      pdfPreview: ref.read(pdfPagePreviewProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(context.locale.import_title),
      ),
      body: SafeArea(
        child: _PickerBody(
          stage: _stage,
          error: _error,
          hasPdfRequest: _pdfRequest != null,
          pageCount: _pdfPageCount,
          thumbnails: _thumbnails,
          selectedPages: _selectedPages,
          onGallery: () => unawaited(_pick(ImportSource.gallery)),
          onFiles: () => unawaited(_pick(ImportSource.filePicker)),
          onDismiss: () => context.pop(),
          onReset: _reset,
          onTogglePage: _togglePage,
          onImportSelected: _selectedPages.isEmpty
              ? null
              : () => unawaited(_importSelected()),
        ),
      ),
    );
  }

  Future<void> _pick(ImportSource source) async {
    if (_stage == _PickerStage.reading || _stage == _PickerStage.importing) {
      return;
    }

    setState(() {
      _stage = _PickerStage.reading;
      _error = null;
      _pdfRequest = null;
      _pdfPageCount = 0;
      _selectedPages.clear();
      _thumbnails.clear();
      _previewToken++;
    });

    ImportOutcome outcome;
    try {
      outcome = await _controller.pick(source);
    } catch (_) {
      outcome = ImportFailed(BusinessFailure.unexpected());
    }
    if (!mounted) return;

    switch (outcome) {
      case ImportCancelled():
        _reset();
      case ImportNotSupported():
        setState(() {
          _stage = _PickerStage.error;
          _error = _PickerError.invalidFormat;
        });
      case ImportNeedsPages(:final request, :final pageCount):
        setState(() {
          _stage = _PickerStage.selectingPages;
          _pdfRequest = request;
          _pdfPageCount = pageCount;
          _selectedPages.addAll(List<int>.generate(pageCount, (i) => i));
        });
        unawaited(_loadThumbnails(request, pageCount));
      case ImportSucceeded(:final document):
        _open(document);
      case ImportFailed():
        setState(() {
          _stage = _PickerStage.error;
          _error = _PickerError.failed;
        });
    }
  }

  Future<void> _importSelected() async {
    final request = _pdfRequest;
    if (request == null ||
        _selectedPages.isEmpty ||
        _stage == _PickerStage.importing) {
      return;
    }

    final pages = _selectedPages.toList()..sort();
    setState(() {
      _stage = _PickerStage.importing;
      _error = null;
    });

    ImportOutcome outcome;
    try {
      outcome = await _controller.importPages(request, pages);
    } catch (_) {
      outcome = ImportFailed(BusinessFailure.unexpected());
    }
    if (!mounted) return;

    switch (outcome) {
      case ImportSucceeded(:final document):
        _open(document);
      case ImportCancelled():
        setState(() => _stage = _PickerStage.selectingPages);
      default:
        setState(() {
          _stage = _PickerStage.error;
          _error = _PickerError.failed;
        });
    }
  }

  Future<void> _loadThumbnails(ImportRequest request, int pageCount) async {
    final token = _previewToken;
    for (var index = 0; index < pageCount; index++) {
      try {
        final bytes = await _controller.pageThumbnail(request.bytes, index);
        if (!mounted || token != _previewToken) return;
        setState(() => _thumbnails[index] = bytes);
      } catch (_) {
        // A page that cannot be rendered keeps its placeholder tile.
      }
    }
  }

  void _togglePage(int index) {
    setState(() {
      if (!_selectedPages.remove(index)) _selectedPages.add(index);
    });
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _stage = _PickerStage.idle;
      _error = null;
      _pdfRequest = null;
      _pdfPageCount = 0;
      _selectedPages.clear();
      _thumbnails.clear();
      _previewToken++;
    });
  }

  void _open(DocumentEntity document) {
    context.goNamed(
      Routes.editor.name,
      pathParameters: <String, String>{'documentId': document.id},
    );
  }
}

class _PickerBody extends StatelessWidget {
  const _PickerBody({
    required this.stage,
    required this.error,
    required this.hasPdfRequest,
    required this.pageCount,
    required this.thumbnails,
    required this.selectedPages,
    required this.onGallery,
    required this.onFiles,
    required this.onDismiss,
    required this.onReset,
    required this.onTogglePage,
    required this.onImportSelected,
  });

  final _PickerStage stage;
  final _PickerError? error;
  final bool hasPdfRequest;
  final int pageCount;
  final Map<int, Uint8List> thumbnails;
  final Set<int> selectedPages;
  final VoidCallback onGallery;
  final VoidCallback onFiles;
  final VoidCallback onDismiss;
  final VoidCallback onReset;
  final ValueChanged<int> onTogglePage;
  final VoidCallback? onImportSelected;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      _PickerStage.idle => _IdleView(
        onGallery: onGallery,
        onFiles: onFiles,
        onCancel: onDismiss,
      ),
      _PickerStage.reading => _BusyView(
        message: context.locale.common_loading,
      ),
      _PickerStage.selectingPages => hasPdfRequest
          ? _PageSelectionView(
              pageCount: pageCount,
              thumbnails: thumbnails,
              selectedPages: selectedPages,
              onTogglePage: onTogglePage,
              onCancel: onReset,
              onImportSelected: onImportSelected,
            )
          : _IdleView(
              onGallery: onGallery,
              onFiles: onFiles,
              onCancel: onDismiss,
            ),
      _PickerStage.importing => _BusyView(
        message: context.locale.import_importing,
      ),
      _PickerStage.error => _ErrorView(
        message: error == _PickerError.invalidFormat
            ? context.locale.import_invalidFormat
            : context.locale.import_error,
        onRetry: onReset,
      ),
    };
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.onGallery,
    required this.onFiles,
    required this.onCancel,
  });

  final VoidCallback onGallery;
  final VoidCallback onFiles;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(context.dimensions.space.s16),
      children: [
        FilledButton.icon(
          onPressed: onGallery,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(context.locale.import_fromGallery),
        ),
        Gap(context.dimensions.space.s12),
        OutlinedButton.icon(
          onPressed: onFiles,
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(context.locale.import_fromFiles),
        ),
        Gap(context.dimensions.space.s24),
        BodySmallText.muted(context.locale.import_supportedFormats),
        Gap(context.dimensions.space.s8),
        BodySmallText.muted(context.locale.import_neverModified),
        Gap(context.dimensions.space.s24),
        OutlinedButton(
          onPressed: onCancel,
          child: Text(context.locale.common_cancel),
        ),
      ],
    );
  }
}

class _BusyView extends StatelessWidget {
  const _BusyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: context.dimensions.size.iconLarge,
            height: context.dimensions.size.iconLarge,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                context.color.primary.defaultValue,
              ),
            ),
          ),
          Gap(context.dimensions.space.s16),
          BodySmallText.muted(message),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.dimensions.space.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: context.dimensions.size.iconDisplay,
              color: context.color.text.muted,
            ),
            Gap(context.dimensions.space.s8),
            BodySmallText.muted(message, textAlign: TextAlign.center),
            Gap(context.dimensions.space.s24),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.locale.common_retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageSelectionView extends StatelessWidget {
  const _PageSelectionView({
    required this.pageCount,
    required this.thumbnails,
    required this.selectedPages,
    required this.onTogglePage,
    required this.onCancel,
    required this.onImportSelected,
  });

  static const double _pageTileAspectRatio = 0.72;

  final int pageCount;
  final Map<int, Uint8List> thumbnails;
  final Set<int> selectedPages;
  final ValueChanged<int> onTogglePage;
  final VoidCallback onCancel;
  final VoidCallback? onImportSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.dimensions.space.s16,
            context.dimensions.space.s16,
            context.dimensions.space.s16,
            context.dimensions.space.s8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeadingLevel3Text(context.locale.import_pageSelectTitle),
              Gap(context.dimensions.space.s4),
              BodySmallText.muted(context.locale.import_pageSelectBody),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: context.dimensions.space.s16,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: context.dimensions.space.s12,
              crossAxisSpacing: context.dimensions.space.s12,
              childAspectRatio: _pageTileAspectRatio,
            ),
            itemCount: pageCount,
            itemBuilder: (context, index) {
              return _PdfPageTile(
                pageIndex: index,
                thumbnail: thumbnails[index],
                selected: selectedPages.contains(index),
                onTap: () => onTogglePage(index),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(context.dimensions.space.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BodySmallText.muted(
                context.locale.import_pdfPagesSelected(selectedPages.length),
              ),
              Gap(context.dimensions.space.s12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: Text(context.locale.common_cancel),
                    ),
                  ),
                  Gap(context.dimensions.space.s12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onImportSelected,
                      child: Text(context.locale.import_action),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PdfPageTile extends StatelessWidget {
  const _PdfPageTile({
    required this.pageIndex,
    required this.thumbnail,
    required this.selected,
    required this.onTap,
  });

  final int pageIndex;
  final Uint8List? thumbnail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectionColor = context.color.primary.defaultValue;
    final borderColor = selected
        ? selectionColor
        : context.color.border.defaultValue;
    final radius = BorderRadius.circular(context.dimensions.radius.medium);

    return InkWell(
      key: ValueKey<String>('import-page-$pageIndex'),
      onTap: onTap,
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.color.background.surface,
          borderRadius: radius,
          border: Border.all(
            color: borderColor,
            width: selected
                ? context.dimensions.border.lg
                : context.dimensions.border.xs,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.all(context.dimensions.space.s8),
              child: thumbnail == null
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.color.text.muted,
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(
                        context.dimensions.radius.small,
                      ),
                      child: Image.memory(
                        thumbnail!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
            ),
            Positioned(
              top: context.dimensions.space.s4,
              right: context.dimensions.space.s4,
              child: Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: selected ? selectionColor : context.color.text.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
