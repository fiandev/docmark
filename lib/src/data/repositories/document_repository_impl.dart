import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/base/result.dart';
import '../../core/base/unit.dart';
import '../../core/security/secure_file_vault.dart';
import '../../core/storage/db/app_database.dart';
import '../../core/storage/db/dao/document_dao.dart';
import '../../core/storage/vault/watermark_asset_store.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/image_format.dart';
import '../../domain/entities/watermark_element.dart';
import '../../domain/failures/business_failure.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/services/media_normalizer.dart';
import '../base/repository.dart';
import '../failures/infra_failure.dart';
import '../mappers/docmark_mappers.dart';

/// Documents over the encrypted vault and the SQLCipher database.
///
/// The import path reads bytes the picker already handed over, probes
/// them, and writes them straight into the vault; the source file on disk
/// is never opened or copied back out. Deletion commits the row removal
/// first and only then erases bytes: an orphan blob can be swept, while a
/// row whose blob is already gone is a dangling reference the user cannot
/// repair.
final class DocumentRepositoryImpl extends Repository
    implements DocumentRepository {
  DocumentRepositoryImpl({
    required super.crashReporter,
    required AppDatabase database,
    required SecureFileVault vault,
    required MediaNormalizerService normalizer,
    required WatermarkAssetStore images,
    Uuid uuid = const Uuid(),
    Future<Directory?> Function()? tempDirectory,
  }) : _database = database,
       _documents = DocumentDao(database),
       _images = images,
       _vault = vault,
       _normalizer = normalizer,
       _uuid = uuid,
       _tempDirectory = tempDirectory;

  /// A4 in PDF points, used only when the probe cannot report a size.
  static const double _a4WidthPt = 595.28;
  static const double _a4HeightPt = 841.89;

  final AppDatabase _database;
  final DocumentDao _documents;
  final WatermarkAssetStore _images;
  final SecureFileVault _vault;
  final MediaNormalizerService _normalizer;
  final Uuid _uuid;
  final Future<Directory?> Function()? _tempDirectory;

  @override
  Future<Result<DocumentEntity, BusinessFailure>> importDocument(
    ImportRequest request,
  ) async {
    if (request.bytes.isEmpty) {
      return const Error<DocumentEntity, BusinessFailure>(
        BusinessFailure.invalidInput(),
      );
    }

    final MediaProbe probe;
    try {
      probe = await _normalizer.probe(request.bytes);
    } on FormatException {
      return const Error<DocumentEntity, BusinessFailure>(
        BusinessFailure.invalidInput(),
      );
    }
    if (!probe.format.isSupported) {
      return const Error<DocumentEntity, BusinessFailure>(
        BusinessFailure.invalidInput(),
      );
    }

    return asyncGuard(() async {
      final createdAt = DateTime.now();
      final documentId = _uuid.v4();
      final assetId = _uuid.v4();
      final reference = await _vault.put(
        bytes: request.bytes,
        extension: probe.format.fileExtension,
        assetId: assetId,
      );
      final pages = _pagesForProbe(probe, request.selectedPages);
      final entity = DocumentEntity(
        id: documentId,
        name: request.fileName,
        kind: probe.format == ImageFormat.pdf
            ? DocumentKind.pdf
            : DocumentKind.image,
        pageCount: probe.format == ImageFormat.pdf
            ? _pdfPageCount(probe)
            : 1,
        pageSizes: pages,
        createdAt: createdAt,
      );

      try {
        await _database.transaction(() async {
          await _documents.insert(entity.toRow());
          await _documents.insertPages(
            pages.map((page) => page.toRow(documentId)).toList(),
          );
          await _documents.insertSourceAsset(
            DocumentAssetRow(
              docId: documentId,
              assetId: assetId,
              blobPath: reference.relativePath,
              mime: probe.format.mimeType,
              createdAt: createdAt,
            ),
          );
        });
      } catch (_) {
        // The metadata transaction failed, so the blob has no owner. Remove
        // it rather than leaving encrypted bytes nobody can reach.
        await _vault.delete(reference);
        rethrow;
      }

      return entity;
    });
  }

  @override
  Future<Result<Uint8List, BusinessFailure>> readPage(
    String documentId,
    int pageIndex,
  ) {
    return asyncGuard(
      () async {
        if (await _documents.find(documentId) == null) {
          throw _MissingDocument(documentId);
        }
        // Page identity is the source document's page numbering, and only
        // the pages the importer recorded in `document_pages` are readable:
        // a PDF subset import has no row for a skipped source page.
        final page = await _documents.findPage(documentId, pageIndex);
        if (page == null) throw _MissingDocument('$documentId/$pageIndex');
        final source = await _documents.findSourceAsset(documentId);
        if (source == null) throw _MissingDocument(documentId);

        // The whole source file comes back for a PDF; the renderer selects
        // the page from `RenderRequest.pageIndex`. An image has one page,
        // so the same call is exact.
        return _vault.read(
          AssetRef(id: source.assetId, relativePath: source.blobPath),
        );
      },
      recover: _recoverNotFound<Uint8List>,
    );
  }

  @override
  Future<Result<Unit, BusinessFailure>> saveWatermarkConfig(
    String documentId,
    WatermarkConfig config,
  ) {
    return asyncGuard(
      () async {
        final document = await _documents.find(documentId);
        if (document == null) throw _MissingDocument(documentId);

        await _database.transaction(() async {
          await _documents.updateConfig(documentId, config.toJsonString());
          await _images.replaceLinks(
            ownerType: WatermarkAssetStore.documentOwner,
            ownerId: documentId,
            assetIds: _imageAssetIds(config.elements),
          );
        });

        return Unit.value;
      },
      recover: _recoverNotFound<Unit>,
    );
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String documentId) {
    return asyncGuard(
      () async {
        final document = await _documents.find(documentId);
        if (document == null) throw _MissingDocument(documentId);
        final source = await _documents.findSourceAsset(documentId);
        final linked = await _images.linkedAssetIds(
          ownerType: WatermarkAssetStore.documentOwner,
          ownerId: documentId,
        );

        // Rows first, in one transaction. If the commit fails, nothing was
        // erased and a retry sees the document intact; if a blob delete
        // fails afterwards, the row is already gone and the stray encrypted
        // file is unreachable garbage rather than data loss.
        await _database.transaction(() async {
          await _images.removeLinks(
            ownerType: WatermarkAssetStore.documentOwner,
            ownerId: documentId,
          );
          await _documents.deletePages(documentId);
          await _documents.deleteSourceAssets(documentId);
          await _documents.delete(documentId);
        });

        // Read the remaining claims only after this document's links are
        // gone: what is left is the evidence another owner still needs it.
        if (source != null && !await _images.isShared(source.assetId)) {
          await _vault.delete(
            AssetRef(id: source.assetId, relativePath: source.blobPath),
          );
        }
        for (final assetId in linked) {
          await _images.deleteIfUnreferenced(assetId);
        }
        await _deleteTempFiles(documentId);

        return Unit.value;
      },
      recover: _recoverNotFound<Unit>,
    );
  }

  @override
  Future<Result<List<DocumentEntity>, BusinessFailure>> list() {
    return asyncGuard(() async {
      final rows = await _documents.all();
      final pageRows = await _documents.allPages();
      final pagesByDocument = <String, List<DocumentPage>>{};
      for (final row in pageRows) {
        (pagesByDocument[row.docId] ??= <DocumentPage>[]).add(row.toEntity());
      }

      return rows
          .map(
            (row) => row.toEntity(
              pagesByDocument[row.id] ?? const <DocumentPage>[],
            ),
          )
          .toList();
    });
  }

  @override
  Future<Result<DocumentEntity?, BusinessFailure>> get(String documentId) {
    return asyncGuard(() async {
      final row = await _documents.find(documentId);
      if (row == null) return null;
      final pages = await _documents.pagesFor(documentId);

      return row.toEntity(pages.map((page) => page.toEntity()).toList());
    });
  }

  Result<T, BusinessFailure>? _recoverNotFound<T>(InfraFailure failure) {
    return failure.cause is _MissingDocument
        ? Error<T, BusinessFailure>(BusinessFailure.notFound())
        : null;
  }

  List<String> _imageAssetIds(List<WatermarkElement> elements) {
    return elements
        .whereType<ImageWatermark>()
        .map((element) => element.assetId)
        .where((assetId) => assetId.isNotEmpty)
        .toSet()
        .toList();
  }

  List<DocumentPage> _pagesForProbe(
    MediaProbe probe,
    List<int> selectedPages,
  ) {
    if (probe.format != ImageFormat.pdf) {
      return [
        DocumentPage(
          index: 0,
          widthPt: (probe.width ?? 1).toDouble(),
          heightPt: (probe.height ?? 1).toDouble(),
        ),
      ];
    }

    final total = _pdfPageCount(probe);
    List<int> indexes;
    if (selectedPages.isEmpty) {
      indexes = List<int>.generate(total, (index) => index);
    } else {
      indexes = selectedPages
          .where((index) => index >= 0 && index < total)
          .toSet()
          .toList()
        ..sort();
      // A selection that filtered down to nothing would leave a document
      // with no addressable page; importing everything is the safer read.
      if (indexes.isEmpty) {
        indexes = List<int>.generate(total, (index) => index);
      }
    }

    final width = (probe.width ?? _a4WidthPt).toDouble();
    final height = (probe.height ?? _a4HeightPt).toDouble();

    return indexes
        .map(
          (index) => DocumentPage(
            index: index,
            widthPt: width,
            heightPt: height,
          ),
        )
        .toList();
  }

  int _pdfPageCount(MediaProbe probe) {
    final count = probe.pageCount ?? 1;

    return count < 1 ? 1 : count;
  }

  /// Renderers name their scratch files `<documentId>_*.tmp`, so a delete
  /// can remove a crashed run's leftovers as well as the vault blobs.
  Future<void> _deleteTempFiles(String documentId) async {
    final resolve = _tempDirectory;
    if (resolve == null) return;

    final directory = await resolve();
    if (directory == null || !await directory.exists()) return;

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!p.basename(entity.path).startsWith('${documentId}_')) continue;
      try {
        await entity.delete();
      } catch (_) {
        continue;
      }
    }
  }
}

final class _MissingDocument implements Exception {
  const _MissingDocument(this.id);

  final String id;

  @override
  String toString() => 'MissingDocument($id)';
}
