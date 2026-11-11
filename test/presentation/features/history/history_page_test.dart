import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:docmark/src/core/di/features/history_providers.dart';
import 'package:docmark/src/core/di/features/import_providers.dart';
import 'package:docmark/src/core/gen/l10n/app_localizations.dart';
import 'package:docmark/src/domain/entities/document.dart';
import 'package:docmark/src/domain/entities/history.dart';
import 'package:docmark/src/domain/repositories/document_repository.dart';
import 'package:docmark/src/domain/repositories/history_repository.dart';
import 'package:docmark/src/presentation/core/router/routes.dart';
import 'package:docmark/src/presentation/core/theme/theme.dart';
import 'package:docmark/src/presentation/features/history/controller/history_presentation.dart';
import 'package:docmark/src/presentation/features/history/view/history_page.dart';

import '../../../data/repositories/docmark/harness.dart';
import 'support/fake_document_repository.dart';
import 'support/fake_history_repository.dart';

void main() {
  group('HistoryPage', () {
    testWidgets('renders every entry from the repository', (tester) async {
      final history = FakeHistoryRepository(
        entries: [
          _entry(name: 'alpha.pdf', status: HistoryStatus.completed),
          _entry(
            id: 'h2',
            name: 'beta.png',
            status: HistoryStatus.failed,
          ),
        ],
      );

      await tester.pumpWidget(_pageApp(history: history));
      await tester.pumpAndSettle();

      expect(find.text('alpha.pdf'), findsOneWidget);
      expect(find.text('beta.png'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('shows the empty state and hides clear', (tester) async {
      await tester.pumpWidget(
        _pageApp(history: FakeHistoryRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No history yet'), findsOneWidget);
      expect(
        find.text('Documents you watermark and export are listed here.'),
        findsOneWidget,
      );
      expect(find.text('Clear history'), findsNothing);
    });

    testWidgets('reuse opens the editor for the original document', (
      tester,
    ) async {
      final router = _router();
      await tester.pumpWidget(
        _routerApp(
          history: FakeHistoryRepository(
            entries: [_entry(documentId: 'doc-7')],
          ),
          documents: FakeDocumentRepository(
            documents: {'doc-7': _document('doc-7')},
          ),
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reuse configuration'));
      await tester.pumpAndSettle();

      expect(find.text('editor:doc-7'), findsOneWidget);
    });

    testWidgets('a missing original offers the document picker', (
      tester,
    ) async {
      final router = _router();
      await tester.pumpWidget(
        _routerApp(
          history: FakeHistoryRepository(
            entries: [_entry(documentId: 'gone')],
          ),
          documents: FakeDocumentRepository(),
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reuse configuration'));
      await tester.pumpAndSettle();

      expect(
        find.text('The original document is no longer available.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Import document'));
      await tester.pumpAndSettle();

      expect(find.text('picker'), findsOneWidget);
    });

    test(
      'delete cascades through the repository and leaves no bytes',
      () async {
        final harness = await DocmarkHarness.create();
        addTearDown(harness.dispose);
        final repository = harness.history();
        final original = await harness.vault.put(
          bytes: pngBytes('original'),
          extension: 'png',
        );
        final processed = await harness.vault.put(
          bytes: pngBytes('processed'),
          extension: 'png',
        );
        final entry = HistoryEntryEntity(
          id: 'h1',
          documentName: 'alpha.png',
          createdAt: DateTime.utc(2026, 6, 1),
          status: HistoryStatus.completed,
          originalRef: original,
          processedRef: processed,
        );
        await repository.record(entry);

        final container = ProviderContainer(
          overrides: [
            historyRepositoryProvider.overrideWith((ref) => repository),
          ],
        );
        addTearDown(container.dispose);

        expect(
          await container.read(historyListProvider.future),
          hasLength(1),
        );

        final deleted = await container
            .read(historyListProvider.notifier)
            .deleteEntry('h1');

        expect(deleted, isTrue);
        expect(container.read(historyListProvider).asData?.value, isEmpty);
        expect(await harness.vault.exists(original), isFalse);
        expect(await harness.vault.exists(processed), isFalse);
        expect(await harness.files(), isEmpty);
      },
    );

    test('reuse plan carries the original document id', () {
      final plan = historyReusePlan(_entry(documentId: 'doc-9'));

      expect(plan.target, HistoryReuseTarget.editor);
      expect(plan.documentId, 'doc-9');
    });
  });
}

Widget _pageApp({
  required HistoryRepository history,
  DocumentRepository? documents,
}) {
  return ProviderScope(
    overrides: [
      historyRepositoryProvider.overrideWith((ref) => history),
      documentRepositoryProvider.overrideWith(
        (ref) => documents ?? FakeDocumentRepository(),
      ),
    ],
    child: MaterialApp(
      theme: _testTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Theme(
          data: context.lightTheme,
          child: const HistoryPage(),
        ),
      ),
    ),
  );
}

Widget _routerApp({
  required HistoryRepository history,
  required DocumentRepository documents,
  required GoRouter router,
}) {
  return ProviderScope(
    overrides: [
      historyRepositoryProvider.overrideWith((ref) => history),
      documentRepositoryProvider.overrideWith((ref) => documents),
    ],
    child: MaterialApp.router(
      theme: _testTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

ThemeData _testTheme() {
  return ThemeData(
    extensions: const <ThemeExtension<dynamic>>[
      ColorExtension.light(),
      TextStyleExtension(),
      DimensionsExtension(),
    ],
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: Routes.history.path,
    routes: [
      GoRoute(
        path: Routes.history.path,
        name: Routes.history.name,
        builder: (context, state) => Theme(
          data: context.lightTheme,
          child: const HistoryPage(),
        ),
      ),
      GoRoute(
        path: Routes.editor.path,
        name: Routes.editor.name,
        builder: (context, state) {
          final documentId = state.pathParameters['documentId'];

          return Scaffold(body: Text('editor:$documentId'));
        },
      ),
      GoRoute(
        path: Routes.documentPicker.path,
        name: Routes.documentPicker.name,
        builder: (context, state) {
          return const Scaffold(body: Text('picker'));
        },
      ),
    ],
  );
}

HistoryEntryEntity _entry({
  String id = 'h1',
  String name = 'alpha.pdf',
  HistoryStatus status = HistoryStatus.completed,
  String? documentId,
}) {
  return HistoryEntryEntity(
    id: id,
    documentName: name,
    createdAt: DateTime.utc(2026, 6, 1),
    status: status,
    documentId: documentId,
  );
}

DocumentEntity _document(String id) {
  return DocumentEntity(
    id: id,
    name: 'alpha.pdf',
    kind: DocumentKind.image,
    pageCount: 1,
    pageSizes: const [
      DocumentPage(index: 0, widthPt: 100, heightPt: 100),
    ],
    createdAt: DateTime.utc(2026, 6, 1),
  );
}
