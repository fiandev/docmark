import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:docmark/src/core/base/result.dart';
import 'package:docmark/src/core/base/unit.dart';
import 'package:docmark/src/core/security/secure_file_vault.dart';
import 'package:docmark/src/domain/entities/document.dart';
import 'package:docmark/src/domain/entities/history.dart';
import 'package:docmark/src/domain/entities/image_format.dart';
import 'package:docmark/src/domain/entities/normalized_rect.dart';
import 'package:docmark/src/domain/entities/watermark_element.dart';
import 'package:docmark/src/domain/failures/business_failure.dart';
import 'package:docmark/src/domain/repositories/document_repository.dart';
import 'package:docmark/src/domain/repositories/history_repository.dart';
import 'package:docmark/src/domain/services/render_contract.dart';
import 'package:docmark/src/presentation/features/export/controller/export_controller.dart';
import 'package:docmark/src/presentation/features/export/controller/export_file_writer.dart';

import '../../../support/fake_secure_file_vault.dart';
import '../../../support/fake_watermark_renderer.dart';

void main() {
  const png = ImageFormat.png;

  group('ExportController rendering', () {
    test('an image document exports one PNG and records history', () async {
      final source = Uint8List.fromList(<int>[9, 8, 7]);
      final snapshot = Uint8List.fromList(source);
      final documents = _FakeDocumentRepository(<int, Uint8List>{0: source});
      final history = _FakeHistoryRepository();
      final vault = FakeSecureFileVault();
      final renderer = FakeWatermarkRenderer();
      final controller = _controller(
        document: _imageDocument(),
        documents: documents,
        history: history,
        vault: vault,
        renderer: renderer,
      );

      final bundle = await controller.exportDocument(
        format: png,
        jpegQuality: 0.9,
        pages: const <int>{0},
      );

      expect(documents.reads, <int>[0]);
      expect(renderer.imageCalls, hasLength(1));
      expect(renderer.lastImageFormat, ImageFormat.png);
      expect(bundle.files, hasLength(1));
      expect(bundle.files.first.fileName, 'scan_watermarked.png');
      expect(bundle.vaultRef, isNotNull);
      expect(vault.assets, contains(bundle.vaultRef!.id));
      expect(history.recorded, hasLength(1));
      expect(history.recorded.single.status, HistoryStatus.completed);
      expect(history.recorded.single.processedRef, bundle.vaultRef);
      expect(documents.importCalls, 0);
      expect(documents.deleteCalls, 0);
      expect(documents.saveConfigCalls, 0);
      expect(documents.pages[0], snapshot);
    });

    test('a PDF exported as images reads and renders only selected pages',
        () async {
      final documents = _PdfDocumentRepository();
      final history = _FakeHistoryRepository();
      final renderer = FakeWatermarkRenderer();
      final controller = _controller(
        document: _pdfDocument(),
        documents: documents,
        history: history,
        vault: FakeSecureFileVault(),
        renderer: renderer,
      );

      final bundle = await controller.exportDocument(
        format: png,
        jpegQuality: 0.9,
        pages: const <int>{0, 2},
      );

      expect(documents.reads, <int>[0, 2]);
      expect(renderer.imageCalls, hasLength(2));
      expect(renderer.imageCalls[0].pixelRatio, closeTo(150 / 72, 0.001));
      expect(bundle.files.map((file) => file.fileName), <String>[
        'report_watermarked_p1.png',
        'report_watermarked_p3.png',
      ]);
      expect(history.recorded, hasLength(1));
    });

    test('a PDF page subset exports only the imported source pages', () async {
      final documents = _PdfDocumentRepository();
      final renderer = FakeWatermarkRenderer();
      final controller = _controller(
        document: _pdfSubsetDocument(),
        documents: documents,
        history: _FakeHistoryRepository(),
        vault: FakeSecureFileVault(),
        renderer: renderer,
      );

      // The empty selection resolves to the imported pages, not 0..2.
      expect(controller.pageCount, 2);

      final bundle = await controller.exportDocument(
        format: png,
        jpegQuality: 0.9,
        pages: const <int>{1, 2},
      );

      expect(documents.reads, <int>[1, 2]);
      expect(bundle.files.map((file) => file.fileName), <String>[
        'report_watermarked_p2.png',
        'report_watermarked_p3.png',
      ]);
    });

    test('a PDF exported as PDF rebuilds through the renderer', () async {
      final documents = _PdfDocumentRepository();
      final renderer = FakeWatermarkRenderer();
      final controller = _controller(
        document: _pdfDocument(),
        documents: documents,
        history: _FakeHistoryRepository(),
        vault: FakeSecureFileVault(),
        renderer: renderer,
      );

      final bundle = await controller.exportDocument(
        format: ImageFormat.pdf,
        jpegQuality: 0.9,
        pages: const <int>{0, 2},
      );

      expect(renderer.pdfCalls, hasLength(1));
      expect(renderer.pdfCalls.single.pageIndexes, <int>[0, 2]);
      expect(documents.reads, isEmpty);
      expect(bundle.files.single.fileName, 'report_watermarked.pdf');
      expect(bundle.primary.format, ImageFormat.pdf);
    });

    test('preview reads one page and renders a thumbnail', () async {
      final documents = _PdfDocumentRepository();
      final renderer = FakeWatermarkRenderer();
      final controller = _controller(
        document: _pdfDocument(),
        documents: documents,
        history: _FakeHistoryRepository(),
        vault: FakeSecureFileVault(),
        renderer: renderer,
      );

      await controller.preview(0);

      expect(renderer.thumbnailCalls, hasLength(1));
      expect(documents.reads, <int>[0]);
      expect(documents.deleteCalls, 0);
    });
  });

  group('ExportController file output', () {
    test('save and share write new files, never the source asset', () async {
      final source = Uint8List.fromList(<int>[1, 2, 3]);
      final snapshot = Uint8List.fromList(source);
      final documents = _FakeDocumentRepository(<int, Uint8List>{0: source});
      final writer = _FakeFileWriter();
      final controller = _controller(
        document: _imageDocument(),
        documents: documents,
        history: _FakeHistoryRepository(),
        vault: FakeSecureFileVault(),
        renderer: FakeWatermarkRenderer(),
        fileWriter: writer,
      );
      final bundle = await controller.exportDocument(
        format: png,
        jpegQuality: 0.9,
        pages: const <int>{0},
      );

      final saved = await controller.save(bundle);
      await controller.share(bundle, subject: 'Watermarked document');

      expect(saved, <String>['/saved/scan_watermarked.png']);
      expect(writer.saved, hasLength(1));
      expect(writer.saved.single.$1, 'scan_watermarked.png');
      expect(writer.shared, <String>['/temp/scan_watermarked.png']);
      expect(writer.subject, 'Watermarked document');
      // The staged plaintext copy never outlives the share call.
      expect(writer.deleted, <String>['/temp/scan_watermarked.png']);
      expect(documents.pages[0], snapshot);
      expect(documents.deleteCalls, 0);
    });

    test('a failing share still deletes the staged plaintext files', () async {
      final writer = _FakeFileWriter()..failShare = true;
      final controller = _controller(
        document: _imageDocument(),
        documents: _FakeDocumentRepository(<int, Uint8List>{
          0: Uint8List.fromList(<int>[1, 2, 3]),
        }),
        history: _FakeHistoryRepository(),
        vault: FakeSecureFileVault(),
        renderer: FakeWatermarkRenderer(),
        fileWriter: writer,
      );
      final bundle = await controller.exportDocument(
        format: png,
        jpegQuality: 0.9,
        pages: const <int>{0},
      );

      await expectLater(
        controller.share(bundle, subject: 'Watermarked document'),
        throwsA(isA<StateError>()),
      );

      expect(writer.deleted, <String>['/temp/scan_watermarked.png']);
    });
  });
}

ExportController _controller({
  required DocumentEntity document,
  required DocumentRepository documents,
  required HistoryRepository history,
  required SecureFileVault vault,
  required FakeWatermarkRenderer renderer,
  ExportFileWriter? fileWriter,
  List<int> pageIndexes = const <int>[],
}) {
  return ExportController(
    request: ExportRequest(
      document: document,
      config: const WatermarkConfig(
        elements: <WatermarkElement>[
          TextWatermark(
            id: 'text',
            rect: NormalizedRect.fromLTWH(0.1, 0.1, 0.4, 0.2),
            content: 'Confidential',
          ),
        ],
      ),
      pageIndexes: pageIndexes,
    ),
    renderer: renderer,
    documents: documents,
    vault: vault,
    history: history,
    fileWriter: fileWriter ?? _FakeFileWriter(),
    newId: () => 'history-1',
    clock: () => DateTime.utc(2026),
  );
}

DocumentEntity _imageDocument() {
  return DocumentEntity(
    id: 'image-doc',
    name: 'scan.png',
    kind: DocumentKind.image,
    pageCount: 1,
    pageSizes: const <DocumentPage>[
      DocumentPage(index: 0, widthPt: 100, heightPt: 80),
    ],
    createdAt: DateTime.utc(2026),
  );
}

DocumentEntity _pdfDocument() {
  return DocumentEntity(
    id: 'pdf-doc',
    name: 'report.pdf',
    kind: DocumentKind.pdf,
    pageCount: 3,
    pageSizes: const <DocumentPage>[
      DocumentPage(index: 0, widthPt: 300, heightPt: 400),
      DocumentPage(index: 1, widthPt: 200, heightPt: 500),
      DocumentPage(index: 2, widthPt: 250, heightPt: 350),
    ],
    createdAt: DateTime.utc(2026),
  );
}

DocumentEntity _pdfSubsetDocument() {
  final full = _pdfDocument();

  return full.copyWith(
    pageSizes: full.pageSizes.where((page) => page.index != 0).toList(),
  );
}

class _FakeDocumentRepository implements DocumentRepository {
  _FakeDocumentRepository(this.pages);

  final Map<int, Uint8List> pages;
  final List<int> reads = <int>[];
  int importCalls = 0;
  int deleteCalls = 0;
  int saveConfigCalls = 0;

  @override
  Future<Result<Uint8List, BusinessFailure>> readPage(
    String documentId,
    int pageIndex,
  ) async {
    reads.add(pageIndex);
    final bytes = pages[pageIndex];
    if (bytes == null) return const Error(BusinessFailure.notFound());

    return Success(Uint8List.fromList(bytes));
  }

  @override
  Future<Result<DocumentEntity, BusinessFailure>> importDocument(
    ImportRequest request,
  ) async {
    importCalls += 1;

    return const Error(BusinessFailure.unexpected());
  }

  @override
  Future<Result<Unit, BusinessFailure>> saveWatermarkConfig(
    String documentId,
    WatermarkConfig config,
  ) async {
    saveConfigCalls += 1;

    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String documentId) async {
    deleteCalls += 1;

    return const Success(Unit.value);
  }

  @override
  Future<Result<List<DocumentEntity>, BusinessFailure>> list() async {
    return const Success(<DocumentEntity>[]);
  }

  @override
  Future<Result<DocumentEntity?, BusinessFailure>> get(
    String documentId,
  ) async {
    return const Success(null);
  }
}

class _PdfDocumentRepository extends _FakeDocumentRepository {
  _PdfDocumentRepository()
    : super(<int, Uint8List>{
        0: Uint8List.fromList(<int>[0]),
        1: Uint8List.fromList(<int>[1]),
        2: Uint8List.fromList(<int>[2]),
      });
}

class _FakeHistoryRepository implements HistoryRepository {
  final List<HistoryEntryEntity> recorded = <HistoryEntryEntity>[];

  @override
  Future<Result<HistoryEntryEntity, BusinessFailure>> record(
    HistoryEntryEntity entry,
  ) async {
    recorded.add(entry);

    return Success(entry);
  }

  @override
  Future<Result<List<HistoryEntryEntity>, BusinessFailure>> list() async {
    return Success(recorded);
  }

  @override
  Future<Result<AssetRef, BusinessFailure>> previewRef(String entryId) async {
    return const Error(BusinessFailure.notFound());
  }

  @override
  Future<Result<Unit, BusinessFailure>> delete(String entryId) async {
    return const Success(Unit.value);
  }

  @override
  Future<Result<Unit, BusinessFailure>> clear() async {
    return const Success(Unit.value);
  }
}

class _FakeFileWriter implements ExportFileWriter {
  final List<(String, Uint8List)> saved = <(String, Uint8List)>[];
  final List<String> shared = <String>[];
  final List<String> deleted = <String>[];
  String? subject;
  bool failShare = false;

  @override
  Future<String> saveToDevice({
    required Uint8List bytes,
    required String fileName,
  }) async {
    saved.add((fileName, bytes));

    return '/saved/$fileName';
  }

  @override
  Future<String> writeTempFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return '/temp/$fileName';
  }

  @override
  Future<void> deleteTempFile(String path) async {
    deleted.add(path);
  }

  @override
  Future<void> shareFiles({
    required List<String> paths,
    required String subject,
  }) async {
    if (failShare) throw StateError('share failed');
    this.subject = subject;
    shared.addAll(paths);
  }
}
