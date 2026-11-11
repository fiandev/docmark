import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docmark/src/core/di/features/home_providers.dart';
import 'package:docmark/src/core/gen/l10n/app_localizations.dart';
import 'package:docmark/src/domain/entities/history.dart';
import 'package:docmark/src/presentation/core/router/routes.dart';
import 'package:docmark/src/presentation/core/theme/theme.dart';
import 'package:docmark/src/presentation/features/home/view/home_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  HistoryEntryEntity entry(String name) {
    return HistoryEntryEntity(
      id: 'entry-$name',
      documentName: name,
      createdAt: DateTime(2026, 1, 2),
      status: HistoryStatus.completed,
      documentId: 'doc-$name',
    );
  }

  Widget homeApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: context.lightTheme,
            child: const HomePage(),
          ),
        ),
      ),
    );
  }

  Widget routerApp() {
    final router = GoRouter(
      initialLocation: Routes.home.path,
      routes: [
        GoRoute(
          path: Routes.home.path,
          name: Routes.home.name,
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: Routes.documentPicker.path,
          name: Routes.documentPicker.name,
          builder: (context, state) => const _Destination('picker'),
        ),
        GoRoute(
          path: Routes.presets.path,
          name: Routes.presets.name,
          builder: (context, state) => const _Destination('presets'),
        ),
        GoRoute(
          path: Routes.history.path,
          name: Routes.history.name,
          builder: (context, state) => const _Destination('history'),
        ),
        GoRoute(
          path: Routes.settings.path,
          name: Routes.settings.name,
          builder: (context, state) => const _Destination('settings'),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => Theme(
          data: context.lightTheme,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets('renders recent processing entries', (tester) async {
    final entries = [entry('Invoice.pdf'), entry('Contract.png')];

    await tester.pumpWidget(
      homeApp(
        overrides: [
          recentProcessingProvider.overrideWith((ref) async => entries),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invoice.pdf'), findsOneWidget);
    expect(find.text('Contract.png'), findsOneWidget);
  });

  testWidgets('shows the empty recent state before any processing', (
    tester,
  ) async {
    await tester.pumpWidget(homeApp());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No documents processed yet. Import a document to get started.',
      ),
      findsOneWidget,
    );
  });

  group('navigation', () {
    testWidgets('New Watermark opens the document picker', (tester) async {
      await tester.pumpWidget(routerApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Watermark'));
      await tester.pumpAndSettle();

      expect(find.text('picker'), findsOneWidget);
    });

    testWidgets('Saved Presets opens presets', (tester) async {
      await tester.pumpWidget(routerApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Saved Presets'), 200);
      await tester.tap(find.text('Saved Presets'));
      await tester.pumpAndSettle();

      expect(find.text('presets'), findsOneWidget);
    });

    testWidgets('Settings opens settings', (tester) async {
      await tester.pumpWidget(routerApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Settings'), 200);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('settings'), findsOneWidget);
    });

    testWidgets('View all opens history', (tester) async {
      await tester.pumpWidget(routerApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('View all'), 200);
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      expect(find.text('history'), findsOneWidget);
    });
  });
}

class _Destination extends StatelessWidget {
  const _Destination(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(label)),
    );
  }
}
