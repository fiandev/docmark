import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docmark/src/core/di/features/presets_providers.dart';
import 'package:docmark/src/core/gen/l10n/app_localizations.dart';
import 'package:docmark/src/domain/entities/normalized_rect.dart';
import 'package:docmark/src/domain/entities/preset.dart';
import 'package:docmark/src/domain/entities/watermark_element.dart';
import 'package:docmark/src/presentation/core/router/routes.dart';
import 'package:docmark/src/presentation/core/theme/theme.dart';
import 'package:docmark/src/presentation/core/widgets/preset_save_dialog.dart';
import 'package:docmark/src/presentation/features/presets/view/presets_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_preset_repository.dart';

void main() {
  final text = TextWatermark(
    id: 'text-1',
    rect: const NormalizedRect.fromLTWH(0.2, 0.4, 0.6, 0.2),
    content: 'Confidential',
  );

  PresetEntity preset(
    String id,
    String name, {
    List<WatermarkElement> elements = const [],
  }) {
    final timestamp = DateTime.utc(2026, 1, 1);

    return PresetEntity(
      id: id,
      name: name,
      elements: elements,
      imageAssetIds: const [],
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  group('PresetsPage', () {
    Future<({ProviderContainer container, FakePresetRepository repository})>
    pumpPage(
      WidgetTester tester, {
      List<PresetEntity> seed = const [],
    }) async {
      final repository = FakePresetRepository(seed: seed);
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          presetRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: Routes.presets.path,
        routes: [
          GoRoute(
            path: Routes.presets.path,
            name: Routes.presets.name,
            builder: (context, state) => Builder(
              builder: (context) => Theme(
                data: context.lightTheme,
                child: const PresetsPage(),
              ),
            ),
          ),
          GoRoute(
            path: Routes.documentPicker.path,
            name: Routes.documentPicker.name,
            builder: (context, state) =>
                const Scaffold(body: Text('picker')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      return (container: container, repository: repository);
    }

    testWidgets('an empty store renders the empty state', (tester) async {
      await pumpPage(tester);

      expect(find.text('No presets yet'), findsOneWidget);
    });

    testWidgets('lists presets with their layer counts', (tester) async {
      await pumpPage(
        tester,
        seed: [
          preset('p1', 'Brand cover', elements: [text]),
          preset('p2', 'Invoice'),
        ],
      );

      expect(find.text('Brand cover'), findsOneWidget);
      expect(find.text('1 elements'), findsOneWidget);
      expect(find.text('0 elements'), findsOneWidget);
    });

    testWidgets('tapping a preset stores it as pending and opens the picker', (
      tester,
    ) async {
      final app = await pumpPage(
        tester,
        seed: [preset('p1', 'Brand cover', elements: [text])],
      );

      await tester.tap(find.text('Brand cover'));
      await tester.pumpAndSettle();

      expect(app.container.read(pendingPresetIdProvider), 'p1');
      expect(find.text('picker'), findsOneWidget);
    });

    testWidgets('deleting from the menu removes the preset', (tester) async {
      final app = await pumpPage(
        tester,
        seed: [preset('p1', 'Brand cover')],
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete preset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(app.repository.presets, isEmpty);
      expect(find.text('Brand cover'), findsNothing);
      expect(find.text('Preset deleted.'), findsOneWidget);
    });

    testWidgets('duplicating adds a second row', (tester) async {
      final app = await pumpPage(
        tester,
        seed: [preset('p1', 'Brand cover')],
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate preset'));
      await tester.pumpAndSettle();

      expect(app.repository.presets, hasLength(2));
      expect(find.text('Brand cover'), findsNWidgets(2));
    });
  });

  group('PresetSaveDialog', () {
    Future<FakePresetRepository> pumpDialog(
      WidgetTester tester, {
      List<WatermarkElement> elements = const [],
    }) async {
      final repository = FakePresetRepository();
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          presetRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Theme(
                data: context.lightTheme,
                child: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => unawaited(
                        PresetSaveDialog.show(context, elements: elements),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      return repository;
    }

    testWidgets('saving a name creates a preset and closes', (tester) async {
      final repository = await pumpDialog(tester, elements: [text]);

      await tester.enterText(find.byType(TextField), '  Brand cover  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(PresetSaveDialog), findsNothing);
      expect(repository.presets, hasLength(1));
      expect(repository.presets.single.name, 'Brand cover');
      expect(repository.presets.single.elements, [text]);
    });

    testWidgets('an empty name keeps the dialog open and explains why', (
      tester,
    ) async {
      final repository = await pumpDialog(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(PresetSaveDialog), findsOneWidget);
      expect(find.text('A preset name is required.'), findsOneWidget);
      expect(repository.presets, isEmpty);
    });
  });
}
