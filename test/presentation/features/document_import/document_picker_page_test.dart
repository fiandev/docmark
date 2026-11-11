import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:docmark/src/core/di/features/import_providers.dart';
import 'package:docmark/src/core/di/features/presets_providers.dart';
import 'package:docmark/src/core/gen/l10n/app_localizations.dart';
import 'package:docmark/src/presentation/core/router/routes.dart';
import 'package:docmark/src/presentation/core/theme/theme.dart';
import 'package:docmark/src/presentation/features/document_import/view/document_picker_page.dart';

import 'support/import_fakes.dart';

void main() {
  group('DocumentPickerPage', () {
    testWidgets('a gallery image is imported and opens the editor', (
      tester,
    ) async {
      final source = pngBytes('photo');
      final snapshot = Uint8List.fromList(source);
      final picker = FakeDocumentPickService(
        gallery: PickedDocument(fileName: 'photo.png', bytes: source),
      );
      final repository = RecordingDocumentRepository();
      final router = _router();

      await tester.pumpWidget(
        _app(
          router: router,
          repository: repository,
          picker: picker,
          preview: FakePdfPagePreviewService(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(picker.galleryCalls, 1);
      expect(repository.imports, hasLength(1));
      expect(repository.imports.single.fileName, 'photo.png');
      expect(repository.imports.single.bytes, snapshot);
      expect(repository.imports.single.source.name, 'gallery');
      expect(picker.gallery!.bytes, snapshot);
      expect(router.state.uri.path, '/editor/doc-1');
    });

    testWidgets('PDF pages are chosen before the subset is imported', (
      tester,
    ) async {
      final pdf = pdfBytes('report');
      final snapshot = Uint8List.fromList(pdf);
      final picker = FakeDocumentPickService(
        files: PickedDocument(fileName: 'report.pdf', bytes: pdf),
      );
      final repository = RecordingDocumentRepository();
      final preview = FakePdfPagePreviewService(thumbnail: _tinyPng());
      final router = _router();

      await tester.pumpWidget(
        _app(
          router: router,
          repository: repository,
          picker: picker,
          preview: preview,
          pageCount: 3,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose from Files'));
      await tester.pumpAndSettle();

      expect(find.text('Select pages'), findsOneWidget);
      expect(find.text('3 pages selected'), findsOneWidget);
      expect(preview.renderedPages, <int>[0, 1, 2]);

      await tester.tap(
        find.byKey(const ValueKey<String>('import-page-1')),
      );
      await tester.pump();
      expect(find.text('2 pages selected'), findsOneWidget);

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(repository.imports.single.selectedPages, <int>[0, 2]);
      expect(repository.imports.single.bytes, snapshot);
      expect(picker.files!.bytes, snapshot);
      expect(router.state.uri.path, '/editor/doc-1');
    });

    testWidgets('WebP is rejected with the localized format error', (
      tester,
    ) async {
      final webp = webpBytes();
      final snapshot = Uint8List.fromList(webp);
      final picker = FakeDocumentPickService(
        gallery: PickedDocument(fileName: 'animation.webp', bytes: webp),
      );
      final repository = RecordingDocumentRepository();
      final router = _router();

      await tester.pumpWidget(
        _app(
          router: router,
          repository: repository,
          picker: picker,
          preview: FakePdfPagePreviewService(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(find.text('That file type is not supported.'), findsOneWidget);
      expect(repository.imports, isEmpty);
      expect(picker.gallery!.bytes, snapshot);
      expect(router.state.uri.path, '/document-picker');
    });

    testWidgets('cancelling clears the pending preset and returns home', (
      tester,
    ) async {
      final router = _router();

      await tester.pumpWidget(
        _app(
          router: router,
          repository: RecordingDocumentRepository(),
          picker: FakeDocumentPickService(),
          preview: FakePdfPagePreviewService(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DocumentPickerPage)),
        listen: false,
      );
      container.read(pendingPresetIdProvider.notifier).set('preset-1');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(container.read(pendingPresetIdProvider), isNull);
      expect(router.state.uri.path, Routes.home.path);
    });

    testWidgets('a successful import keeps the preset for the editor', (
      tester,
    ) async {
      final picker = FakeDocumentPickService(
        gallery: PickedDocument(fileName: 'photo.png', bytes: pngBytes()),
      );
      final router = _router();

      await tester.pumpWidget(
        _app(
          router: router,
          repository: RecordingDocumentRepository(),
          picker: picker,
          preview: FakePdfPagePreviewService(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DocumentPickerPage)),
        listen: false,
      );
      container.read(pendingPresetIdProvider.notifier).set('preset-1');

      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/editor/doc-1');
      expect(container.read(pendingPresetIdProvider), 'preset-1');
    });
  });
}

Widget _app({
  required GoRouter router,
  required RecordingDocumentRepository repository,
  required FakeDocumentPickService picker,
  required FakePdfPagePreviewService preview,
  int pageCount = 1,
}) {
  return ProviderScope(
    overrides: [
      documentRepositoryProvider.overrideWithValue(repository),
      mediaNormalizerServiceProvider.overrideWithValue(
        FakeProbeNormalizer(pageCount: pageCount),
      ),
      documentPickServiceProvider.overrideWithValue(picker),
      pdfPagePreviewProvider.overrideWithValue(preview),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) {
        return Theme(data: context.lightTheme, child: child!);
      },
    ),
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: Routes.documentPicker.path,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.home.path,
        name: Routes.home.name,
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: Routes.documentPicker.path,
        name: Routes.documentPicker.name,
        builder: (context, state) => const DocumentPickerPage(),
      ),
      GoRoute(
        path: Routes.editor.path,
        name: Routes.editor.name,
        builder: (context, state) {
          return Scaffold(
            body: Text(state.pathParameters['documentId'] ?? 'missing'),
          );
        },
      ),
    ],
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

Uint8List _tinyPng() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
    'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );
}
