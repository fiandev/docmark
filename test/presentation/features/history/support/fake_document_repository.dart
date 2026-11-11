import 'dart:typed_data';

import 'package:flutter_template/src/core/base/result.dart';
import 'package:flutter_template/src/core/base/unit.dart';
import 'package:flutter_template/src/domain/entities/document.dart';
import 'package:flutter_template/src/domain/failures/business_failure.dart';
import 'package:flutter_template/src/domain/repositories/document_repository.dart';

/// Document lookup seam for the history page's reuse path.
final class FakeDocumentRepository implements DocumentRepository {
  FakeDocumentRepository({Map<String, DocumentEntity>? documents})
    : documents = {...?documents};

  final Map<String, DocumentEntity> documents;

  @override
  Future<Result<DocumentEntity?, BusinessFailure>> get(
    String documentId,
  ) async {
    return Success(documents[documentId]);
  }

  @override
  Future<Result<List<DocumentEntity>, BusinessFailure>> list() async {
    return Success(List<DocumentEntity>.unmodifiable(documents.values));
  }

  @override
  Future<Result<DocumentEntity, BusinessFailure>> importDocument(
    ImportRequest request,
  ) async {
    return const Error(BusinessFailure.unexpected());
  }

  @override
  Future<Result<Uint8List, BusinessFailure>> readPage(
    String documentId,
    int pageIndex,
  ) async {
    return const Error(BusinessFailure.notFound());
  }

  @override
  Future<Result<Unit, BusinessFailure>> saveWatermarkConfig(
    String documentId,
    WatermarkConfig config,
  ) async {
    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String documentId) async {
    documents.remove(documentId);

    return const Success(Unit.value);
  }
}
