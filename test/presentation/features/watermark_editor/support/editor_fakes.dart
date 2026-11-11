import 'dart:typed_data';

import 'package:docmark/src/core/base/result.dart';
import 'package:docmark/src/core/base/unit.dart';
import 'package:docmark/src/domain/entities/document.dart';
import 'package:docmark/src/domain/failures/business_failure.dart';
import 'package:docmark/src/domain/repositories/document_repository.dart';

/// [DocumentRepository] that records watermark-config saves.
///
/// Every other method is out of scope for editor tests and throws, so an
/// accidental call shows up as a failure rather than a silent pass.
final class FakeDocumentRepository implements DocumentRepository {
  FakeDocumentRepository({DocumentEntity? document}) : document = document;

  DocumentEntity? document;

  final List<WatermarkConfig> savedConfigs = [];
  final List<String> savedDocumentIds = [];

  /// When set, the next save fails with this failure instead of recording.
  BusinessFailure? nextSaveFailure;

  int reads = 0;

  @override
  Future<Result<DocumentEntity?, BusinessFailure>> get(
    String documentId,
  ) async {
    reads += 1;

    return Success(document);
  }

  @override
  Future<Result<Unit, BusinessFailure>> saveWatermarkConfig(
    String documentId,
    WatermarkConfig config,
  ) async {
    final failure = nextSaveFailure;
    if (failure != null) {
      nextSaveFailure = null;

      return Error(failure);
    }

    savedDocumentIds.add(documentId);
    savedConfigs.add(config);

    return const Success(Unit.value);
  }

  @override
  Future<Result<List<DocumentEntity>, BusinessFailure>> list() async {
    final current = document;

    return Success(current == null ? const [] : [current]);
  }

  @override
  Future<Result<Uint8List, BusinessFailure>> readPage(
    String documentId,
    int pageIndex,
  ) async {
    return Success(Uint8List.fromList(const [1, 2, 3]));
  }

  @override
  Future<Result<DocumentEntity, BusinessFailure>> importDocument(
    ImportRequest request,
  ) {
    throw UnimplementedError('editor tests do not import documents');
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String documentId) {
    throw UnimplementedError('editor tests do not delete documents');
  }
}

/// Deterministic ids so assertions can name the elements.
final class IdGenerator {
  var _next = 0;

  String call() => 'element-${_next++}';
}

/// An image document with [pageCount] pages of 600x800 points.
///
/// [pageIndexes] builds a PDF page-subset fixture: `pageCount` stays the
/// source total while `pageSizes` only carries the named indices.
DocumentEntity testDocument({
  String id = 'doc-1',
  String name = 'scan.png',
  DocumentKind kind = DocumentKind.image,
  int pageCount = 1,
  List<int>? pageIndexes,
  String? watermarkConfigJson,
}) {
  final indexes = pageIndexes ?? List<int>.generate(pageCount, (i) => i);

  return DocumentEntity(
    id: id,
    name: name,
    kind: kind,
    pageCount: pageCount,
    pageSizes: [
      for (final index in indexes)
        DocumentPage(index: index, widthPt: 600, heightPt: 800),
    ],
    watermarkConfigJson: watermarkConfigJson,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
  );
}
