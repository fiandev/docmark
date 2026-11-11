import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_template/src/data/services/media/document_pick_service.dart';
import 'package:flutter_template/src/domain/repositories/document_repository.dart';
import 'package:flutter_template/src/presentation/features/document_import/controller/document_import_controller.dart';

import 'support/import_fakes.dart';

void main() {
  group('DocumentImportController', () {
    test('imports a picked image without touching the source bytes', () async {
      final source = pngBytes('quarterly-photo');
      final original = Uint8List.fromList(source);
      final picker = FakeDocumentPickService(
        gallery: PickedDocument(fileName: 'photo.png', bytes: source),
      );
      final repository = RecordingDocumentRepository();
      final controller = _controller(picker: picker, repository: repository);

      final outcome = await controller.pick(ImportSource.gallery);

      expect(outcome, isA<ImportSucceeded>());
      expect(repository.imports, hasLength(1));
      final request = repository.imports.single;
      expect(request.source, ImportSource.gallery);
      expect(request.fileName, 'photo.png');
      expect(request.bytes, original);
      expect(request.selectedPages, isEmpty);
      expect(repository.deleteCalls, 0);
      expect(picker.gallery!.bytes, original);
    });

    test('rejects WebP bytes as a document', () async {
      final webp = webpBytes();
      final original = Uint8List.fromList(webp);
      final picker = FakeDocumentPickService(
        gallery: PickedDocument(fileName: 'animation.webp', bytes: webp),
      );
      final repository = RecordingDocumentRepository();
      final controller = _controller(picker: picker, repository: repository);

      final outcome = await controller.pick(ImportSource.gallery);

      expect(outcome, isA<ImportNotSupported>());
      expect(repository.imports, isEmpty);
      expect(picker.gallery!.bytes, original);
    });

    test('asks for pages first, then passes the subset through', () async {
      final pdf = pdfBytes();
      final original = Uint8List.fromList(pdf);
      final picker = FakeDocumentPickService(
        files: PickedDocument(fileName: 'report.pdf', bytes: pdf),
      );
      final repository = RecordingDocumentRepository();
      final controller = _controller(
        picker: picker,
        repository: repository,
        pageCount: 3,
      );

      final prepared = await controller.pick(ImportSource.filePicker);

      expect(prepared, isA<ImportNeedsPages>());
      final needsPages = prepared as ImportNeedsPages;
      expect(needsPages.pageCount, 3);
      expect(repository.imports, isEmpty);

      final outcome = await controller.importPages(needsPages.request, [0, 2]);

      expect(outcome, isA<ImportSucceeded>());
      expect(repository.imports, hasLength(1));
      expect(repository.imports.single.selectedPages, [0, 2]);
      expect(repository.imports.single.fileName, 'report.pdf');
      expect(repository.imports.single.bytes, original);
      expect(picker.files!.bytes, original);
    });

    test('a dismissed picker does not call the repository', () async {
      final repository = RecordingDocumentRepository();
      final controller = _controller(repository: repository);

      final outcome = await controller.pick(ImportSource.gallery);

      expect(outcome, isA<ImportCancelled>());
      expect(repository.imports, isEmpty);
    });

    test('page thumbnails come from the injected PDF preview seam', () async {
      final preview = FakePdfPagePreviewService(
        thumbnail: pngBytes('thumb'),
      );
      final controller = _controller(pdfPreview: preview);

      await controller.pageThumbnail(pdfBytes(), 1);

      expect(preview.renderedPages, [1]);
    });
  });
}

DocumentImportController _controller({
  required RecordingDocumentRepository repository,
  FakeDocumentPickService? picker,
  FakePdfPagePreviewService? pdfPreview,
  int pageCount = 1,
}) {
  return DocumentImportController(
    documents: repository,
    normalizer: FakeProbeNormalizer(pageCount: pageCount),
    picker: picker ?? FakeDocumentPickService(),
    pdfPreview: pdfPreview ?? FakePdfPagePreviewService(),
  );
}

Uint8List pngBytes([String marker = 'png']) {
  return Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    ...marker.codeUnits,
  ]);
}

Uint8List pdfBytes([String marker = 'pdf']) {
  return Uint8List.fromList([
    0x25,
    0x50,
    0x44,
    0x46,
    ...marker.codeUnits,
  ]);
}

Uint8List webpBytes() {
  return Uint8List.fromList([
    0x52,
    0x49,
    0x46,
    0x46,
    0x04,
    0x00,
    0x00,
    0x00,
    0x57,
    0x45,
    0x42,
    0x50,
    0x56,
    0x50,
    0x38,
    0x20,
  ]);
}
