import 'dart:typed_data';

import '../../../../core/base/result.dart';
import '../../../../core/di/features/import_providers.dart';
import '../../../../domain/entities/document.dart';
import '../../../../domain/entities/image_format.dart';
import '../../../../domain/failures/business_failure.dart';
import '../../../../domain/repositories/document_repository.dart';
import '../../../../domain/services/media_normalizer.dart';

/// What one pick or import attempt produced.
sealed class ImportOutcome {
  const ImportOutcome();
}

/// The user dismissed the picker; the screen should stay where it was.
final class ImportCancelled extends ImportOutcome {
  const ImportCancelled();
}

/// The bytes are not an MVP document format. The UI shows the localized
/// "not supported" copy; [format] is kept for diagnostics.
final class ImportNotSupported extends ImportOutcome {
  const ImportNotSupported({required this.fileName, required this.format});

  final String fileName;
  final ImageFormat format;
}

/// A PDF was picked: the screen must let the user choose pages first.
final class ImportNeedsPages extends ImportOutcome {
  const ImportNeedsPages({required this.request, required this.pageCount});

  final ImportRequest request;
  final int pageCount;
}

/// The repository stored the document; navigation can open the editor.
final class ImportSucceeded extends ImportOutcome {
  const ImportSucceeded(this.document);

  final DocumentEntity document;
}

/// The import could not be completed.
final class ImportFailed extends ImportOutcome {
  const ImportFailed(this.failure);

  final BusinessFailure failure;
}

/// Drives one import from picked bytes to a stored document.
///
/// The controller only talks to domain interfaces and the DI seam types;
/// the presentation layer never imports the picker plugins or pdfrx. It
/// never opens, writes, or deletes the source file: the bytes handed over
/// by the picker are the only input, and [DocumentRepository] encrypts
/// them into the vault.
final class DocumentImportController {
  DocumentImportController({
    required DocumentRepository documents,
    required MediaNormalizerService normalizer,
    required DocumentPickService picker,
    required PdfPagePreviewService pdfPreview,
  }) : _documents = documents,
       _normalizer = normalizer,
       _picker = picker,
       _pdfPreview = pdfPreview;

  final DocumentRepository _documents;
  final MediaNormalizerService _normalizer;
  final DocumentPickService _picker;
  final PdfPagePreviewService _pdfPreview;

  /// Opens [source] and prepares the bytes for import.
  ///
  /// An image is imported immediately; a PDF comes back as
  /// [ImportNeedsPages] so the UI can show its page grid first.
  Future<ImportOutcome> pick(ImportSource source) async {
    final PickedDocument? picked;
    try {
      picked = switch (source) {
        ImportSource.gallery => await _picker.pickFromGallery(),
        ImportSource.filePicker => await _picker.pickFromFiles(),
      };
    } catch (error) {
      return ImportFailed(_failureFor(error));
    }
    if (picked == null) return const ImportCancelled();

    return _prepare(picked, source);
  }

  /// Imports [request] with only the pages the user kept selected.
  Future<ImportOutcome> importPages(
    ImportRequest request,
    List<int> pageIndexes,
  ) {
    final ordered = pageIndexes.toSet().toList()..sort();
    if (ordered.isEmpty) {
      return Future<ImportOutcome>.value(
        ImportFailed(BusinessFailure.invalidInput()),
      );
    }

    return _import(
      ImportRequest(
        source: request.source,
        fileName: request.fileName,
        bytes: request.bytes,
        declaredFormat: request.declaredFormat,
        selectedPages: ordered,
      ),
    );
  }

  /// A page thumbnail rendered from the picked PDF bytes, in memory.
  Future<Uint8List> pageThumbnail(Uint8List pdfBytes, int pageIndex) {
    return _pdfPreview.renderPageThumbnail(pdfBytes, pageIndex);
  }

  Future<ImportOutcome> _prepare(
    PickedDocument picked,
    ImportSource source,
  ) async {
    final format = DocumentFormatValidator.validate(picked.bytes);
    if (!format.isSupported) {
      return ImportNotSupported(fileName: picked.fileName, format: format);
    }

    final MediaProbe probe;
    try {
      probe = await _normalizer.probe(picked.bytes);
    } on FormatException {
      return ImportNotSupported(fileName: picked.fileName, format: format);
    } catch (error) {
      return ImportFailed(_failureFor(error));
    }

    final request = ImportRequest(
      source: source,
      fileName: picked.fileName,
      bytes: picked.bytes,
      declaredFormat: format,
    );
    if (format != ImageFormat.pdf) return _import(request);

    final pageCount = probe.pageCount ?? 1;

    return ImportNeedsPages(
      request: request,
      pageCount: pageCount < 1 ? 1 : pageCount,
    );
  }

  Future<ImportOutcome> _import(ImportRequest request) async {
    final result = await _documents.importDocument(request);

    return switch (result) {
      Success(:final data) => ImportSucceeded(data),
      Error(:final error) => ImportFailed(error),
    };
  }

  BusinessFailure _failureFor(Object error) {
    return error is BusinessFailure
        ? error
        : BusinessFailure.unexpected(cause: error);
  }
}
