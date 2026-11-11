import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:uuid/uuid.dart';

import '../../../../core/base/result.dart';
import '../../../../core/security/secure_file_vault.dart';
import '../../../../domain/entities/document.dart';
import '../../../../domain/entities/history.dart';
import '../../../../domain/entities/image_format.dart';
import '../../../../domain/repositories/document_repository.dart';
import '../../../../domain/repositories/history_repository.dart';
import '../../../../domain/services/render_contract.dart';
import 'export_file_writer.dart';

/// One produced file: a whole PDF, or one image for one document page.
final class ExportedFile {
  const ExportedFile({
    required this.pageIndex,
    required this.result,
    required this.fileName,
  });

  /// The document page, or -1 for a document-level PDF.
  final int pageIndex;

  final RenderResult result;
  final String fileName;
}

/// Everything one export produced, after the encrypted copy was recorded.
final class ExportBundle {
  const ExportBundle({
    required this.files,
    required this.vaultRef,
  });

  final List<ExportedFile> files;

  /// The encrypted copy kept in the vault, for the history row.
  final AssetRef? vaultRef;

  RenderResult get primary => files.first.result;
}

/// Drives one export from render to vault, history, save and share.
///
/// The controller only talks to domain interfaces, so the presentation
/// layer never imports the data layer. The source document is only ever
/// read: every operation produces new bytes and a new vault entry.
final class ExportController {
  ExportController({
    required ExportRequest request,
    required WatermarkRenderer renderer,
    required DocumentRepository documents,
    required SecureFileVault vault,
    required HistoryRepository history,
    required ExportFileWriter fileWriter,
    String Function()? newId,
    DateTime Function()? clock,
    void Function()? onExported,
  }) : _request = request,
       _renderer = renderer,
       _documents = documents,
       _vault = vault,
       _history = history,
       _fileWriter = fileWriter,
       _newId = newId ?? _defaultId,
       _clock = clock ?? _defaultClock,
       _onExported = onExported;

  final ExportRequest _request;
  final WatermarkRenderer _renderer;
  final DocumentRepository _documents;
  final SecureFileVault _vault;
  final HistoryRepository _history;
  final ExportFileWriter _fileWriter;
  final String Function() _newId;
  final DateTime Function() _clock;

  /// Called after a successful export has been recorded in history, so the
  /// owning screen can refresh cross-feature caches.
  final void Function()? _onExported;

  int get pageCount => _request.resolvedPages.length;

  /// A composited preview of [pageIndex], sized for the phone screen.
  Future<Uint8List> preview(int pageIndex, {int maxWidth = 900}) async {
    final source = await _readPage(pageIndex);

    return _renderer.thumbnail(
      _renderRequest(pageIndex, source, pixelRatio: 1.0),
      maxWidth: maxWidth,
    );
  }

  /// A small tile for the PDF page picker.
  Future<Uint8List> thumbnail(int pageIndex) =>
      preview(pageIndex, maxWidth: 160);

  /// Renders [pages] in [format], writes the encrypted copy, and records
  /// the history row.
  Future<ExportBundle> exportDocument({
    required ImageFormat format,
    required double jpegQuality,
    required Set<int> pages,
  }) async {
    final ordered = pages.toList()..sort();
    if (ordered.isEmpty) {
      throw const ExportException('no-pages');
    }

    final options = ExportOptions(
      format: format,
      jpegQuality: jpegQuality,
      pdfDpi: _request.options.pdfDpi,
      flatten: true,
    );

    final files = format == ImageFormat.pdf
        ? await _renderBundlePdf(ordered, options)
        : await _renderBundleImages(ordered, options);
    if (files.isEmpty) {
      throw const ExportException('empty-output');
    }

    final vaultRef = await _persist(files.first.result);
    // The history row exists now; the History and Home lists are stale.
    _onExported?.call();

    return ExportBundle(files: files, vaultRef: vaultRef);
  }

  /// Writes every file in [bundle] to a user-visible directory.
  Future<List<String>> save(ExportBundle bundle) async {
    final paths = <String>[];
    for (final file in bundle.files) {
      paths.add(
        await _fileWriter.saveToDevice(
          bytes: file.result.bytes,
          fileName: file.fileName,
        ),
      );
    }

    return paths;
  }

  /// Hands every file in [bundle] to the platform share sheet.
  ///
  /// The staged files are plaintext, so they are deleted once the sheet
  /// returns — success or failure. The `finally` is what guarantees the
  /// copy does not outlive the share.
  Future<void> share(ExportBundle bundle, {required String subject}) async {
    final paths = <String>[];
    try {
      for (final file in bundle.files) {
        paths.add(
          await _fileWriter.writeTempFile(
            bytes: file.result.bytes,
            fileName: file.fileName,
          ),
        );
      }

      await _fileWriter.shareFiles(paths: paths, subject: subject);
    } finally {
      for (final path in paths) {
        await _fileWriter.deleteTempFile(path);
      }
    }
  }

  Future<List<ExportedFile>> _renderBundlePdf(
    List<int> pages,
    ExportOptions options,
  ) async {
    final request = ExportRequest(
      document: _request.document,
      config: _request.config,
      pageIndexes: pages,
      options: options,
    );
    final result = await _renderer.renderPdfPdf(request);

    return <ExportedFile>[
      ExportedFile(
        pageIndex: -1,
        result: result,
        fileName: _fileName(-1, pages.length, result.format),
      ),
    ];
  }

  Future<List<ExportedFile>> _renderBundleImages(
    List<int> ordered,
    ExportOptions options,
  ) async {
    // An image document exports at its native pixels; a PDF page is
    // rasterized at the requested dpi.
    final ratio = _request.document.kind == DocumentKind.image
        ? 1.0
        : (options.pdfDpi <= 0 ? 1.0 : options.pdfDpi / 72);
    final files = <ExportedFile>[];

    for (final pageIndex in ordered) {
      final source = await _readPage(pageIndex);
      final result = await _renderer.renderImage(
        _renderRequest(pageIndex, source, pixelRatio: ratio),
        format: options.format,
      );
      files.add(
        ExportedFile(
          pageIndex: pageIndex,
          result: result,
          fileName: _fileName(pageIndex, ordered.length, options.format),
        ),
      );
    }

    return files;
  }

  Future<AssetRef> _persist(RenderResult primary) async {
    final ref = await _vault.put(
      bytes: primary.bytes,
      extension: primary.format.fileExtension,
    );

    final recorded = await _history.record(
      HistoryEntryEntity(
        id: _newId(),
        documentName: _request.document.name,
        createdAt: _clock(),
        status: HistoryStatus.completed,
        documentId: _request.document.id,
        processedRef: ref,
        watermarkConfigJson: _request.config.toJsonString(),
      ),
    );

    if (recorded is Error) {
      throw const ExportException('history-write-failed');
    }

    return ref;
  }

  Future<Uint8List> _readPage(int pageIndex) async {
    final result = await _documents.readPage(_request.document.id, pageIndex);

    return switch (result) {
      Success(:final data) => data,
      Error() => throw const ExportException('source-unavailable'),
    };
  }

  RenderRequest _renderRequest(
    int pageIndex,
    Uint8List source, {
    required double pixelRatio,
  }) {
    return RenderRequest(
      sourceBytes: source,
      pageIndex: pageIndex,
      pageSize: _pageSize(pageIndex),
      elements: _request.config.elementsForPage(pageIndex),
      pixelRatio: pixelRatio,
    );
  }

  Size _pageSize(int pageIndex) {
    final page = _request.document.pageAt(pageIndex);

    return page?.sizePt ?? Size.zero;
  }

  String _fileName(int pageIndex, int totalPages, ImageFormat format) {
    final base = _safeBaseName(_request.document.name);
    final multiple = totalPages > 1 && pageIndex >= 0;
    final suffix = multiple ? '_p${pageIndex + 1}' : '';

    return '${base}_watermarked$suffix.${format.fileExtension}';
  }

  static String _safeBaseName(String name) {
    final trimmed = name.trim();
    final dot = trimmed.lastIndexOf('.');
    final stem = dot > 0 ? trimmed.substring(0, dot) : trimmed;
    final cleaned = stem
        .replaceAll(RegExp(r'[^\p{L}\p{N} _-]', unicode: true), '_')
        .trim();

    return cleaned.isEmpty ? 'docmark' : cleaned;
  }

  static const Uuid _uuid = Uuid();

  static String _defaultId() => _uuid.v4();

  static DateTime _defaultClock() => DateTime.now().toUtc();
}

/// A render or storage step failed. The message is a stable code, never
/// document content.
final class ExportException implements Exception {
  const ExportException(this.code);

  final String code;

  @override
  String toString() => 'ExportException($code)';
}
