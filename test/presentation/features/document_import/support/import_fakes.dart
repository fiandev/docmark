import 'dart:typed_data';

import 'package:docmark/src/core/base/result.dart';
import 'package:docmark/src/core/base/unit.dart';
import 'package:docmark/src/data/services/media/document_pick_service.dart';
import 'package:docmark/src/data/services/media/pdf_page_preview_service.dart';
import 'package:docmark/src/domain/entities/document.dart';
import 'package:docmark/src/domain/entities/image_format.dart';
import 'package:docmark/src/domain/failures/business_failure.dart';
import 'package:docmark/src/domain/repositories/document_repository.dart';
import 'package:docmark/src/domain/services/format_probe.dart';
import 'package:docmark/src/domain/services/media_normalizer.dart';

final class FakeDocumentPickService implements DocumentPickService {
  FakeDocumentPickService({this.gallery, this.files});

  PickedDocument? gallery;
  PickedDocument? files;

  int galleryCalls = 0;
  int fileCalls = 0;

  @override
  Future<PickedDocument?> pickFromGallery() async {
    galleryCalls++;

    return gallery;
  }

  @override
  Future<PickedDocument?> pickFromFiles() async {
    fileCalls++;

    return files;
  }
}

final class FakePdfPagePreviewService implements PdfPagePreviewService {
  FakePdfPagePreviewService({this.thumbnail});

  Uint8List? thumbnail;

  final List<int> renderedPages = <int>[];

  @override
  Future<Uint8List> renderPageThumbnail(
    Uint8List pdfBytes,
    int pageIndex, {
    int maxPx = 160,
  }) async {
    renderedPages.add(pageIndex);
    final bytes = thumbnail;
    if (bytes == null) throw const FormatException('no preview');
    return bytes;
  }
}

/// Probes magic bytes for the format and reports configurable PDF metadata.
final class FakeProbeNormalizer implements MediaNormalizerService {
  FakeProbeNormalizer({this.pageCount = 1});

  final int pageCount;

  @override
  Future<MediaProbe> probe(Uint8List bytes) async {
    final format = FormatProbe.probe(bytes);

    return MediaProbe(
      format: format,
      width: format == ImageFormat.pdf ? 612 : 100,
      height: format == ImageFormat.pdf ? 792 : 140,
      pageCount: format == ImageFormat.pdf ? pageCount : null,
    );
  }

  @override
  Future<NormalizedMedia> normalizeAsPng(Uint8List bytes) =>
      throw UnimplementedError();
}

/// Records every import request and returns a synthetic document.
final class RecordingDocumentRepository implements DocumentRepository {
  final List<ImportRequest> imports = <ImportRequest>[];
  final List<ImportRequest> importSnapshots = <ImportRequest>[];

  int deleteCalls = 0;
  int saveConfigCalls = 0;

  @override
  Future<Result<DocumentEntity, BusinessFailure>> importDocument(
    ImportRequest request,
  ) async {
    imports.add(request);
    importSnapshots.add(
      ImportRequest(
        source: request.source,
        fileName: request.fileName,
        bytes: Uint8List.fromList(request.bytes),
        declaredFormat: request.declaredFormat,
        selectedPages: List<int>.from(request.selectedPages),
      ),
    );
    final format = FormatProbe.probe(request.bytes);
    final isPdf = format == ImageFormat.pdf;
    final pageIndexes = request.selectedPages.isEmpty
        ? List<int>.generate(isPdf ? 3 : 1, (index) => index)
        : request.selectedPages;

    return Success(
      DocumentEntity(
        id: 'doc-${imports.length}',
        name: request.fileName,
        kind: isPdf ? DocumentKind.pdf : DocumentKind.image,
        pageCount: isPdf ? 3 : 1,
        pageSizes: pageIndexes
            .map(
              (index) => DocumentPage(
                index: index,
                widthPt: isPdf ? 612 : 100,
                heightPt: isPdf ? 792 : 140,
              ),
            )
            .toList(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
  }

  @override
  Future<Result<Uint8List, BusinessFailure>> readPage(
    String documentId,
    int pageIndex,
  ) =>
      throw UnimplementedError();

  @override
  Future<Result<Unit, BusinessFailure>> saveWatermarkConfig(
    String documentId,
    WatermarkConfig config,
  ) async {
    saveConfigCalls++;
    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String documentId) async {
    deleteCalls++;
    return const Success(Unit.value);
  }

  @override
  Future<Result<List<DocumentEntity>, BusinessFailure>> list() =>
      throw UnimplementedError();

  @override
  Future<Result<DocumentEntity?, BusinessFailure>> get(String documentId) =>
      throw UnimplementedError();
}
