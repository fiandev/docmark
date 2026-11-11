import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/src/core/di/features/app_lock_providers.dart';
import 'package:flutter_template/src/core/di/features/history_providers.dart';
import 'package:flutter_template/src/core/di/features/security_providers.dart';
import 'package:flutter_template/src/core/gen/l10n/app_localizations.dart';
import 'package:flutter_template/src/core/security/lock_controller.dart';
import 'package:flutter_template/src/presentation/core/theme/theme.dart';
import 'package:flutter_template/src/presentation/features/settings/controller/storage_overview.dart';
import 'package:flutter_template/src/presentation/features/settings/view/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_secure_file_vault.dart';
import 'support/settings_fakes.dart';

void main() {
  Future<void> pumpSettings(
    WidgetTester tester, {
    required FakeAppLockService service,
    FakeHistoryRepository? history,
    FakeSecureFileVault? vault,
    StorageUsage usage = StorageUsage.empty,
  }) async {
    final repository = history ?? FakeHistoryRepository();
    final fileVault = vault ?? FakeSecureFileVault();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockServiceProvider.overrideWith((ref) => service),
          appLockStateProvider.overrideWith((ref) {
            final service = ref.watch(appLockServiceProvider);
            final subscription = service.changes.listen(
              (_) => ref.invalidateSelf(),
            );
            ref.onDispose(subscription.cancel);

            return service.state;
          }),
          historyRepositoryProvider.overrideWith((ref) => repository),
          secureFileVaultProvider.overrideWith((ref) => fileVault),
          storageUsageProvider.overrideWith((ref) async => usage),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Theme(
              data: context.lightTheme,
              child: const SettingsPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('App Lock section', () {
    testWidgets('enabling App Lock stores the PIN through the service', (
      tester,
    ) async {
      final service = FakeAppLockService();

      await pumpSettings(tester, service: service);
      expect(find.text('App Lock is off'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-app-lock-switch')),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));

      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(service.enableCalls, 1);
      expect(service.pin, '123456');
      expect(find.text('App Lock is on'), findsOneWidget);
    });

    testWidgets('disabling App Lock verifies the PIN and calls the service', (
      tester,
    ) async {
      final service = FakeAppLockService(
        enabled: true,
        initialPin: '123456',
      );

      await pumpSettings(tester, service: service);
      expect(find.text('App Lock is on'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-app-lock-switch')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(service.disableCalls, 1);
      expect(service.state.status, LockStatus.disabled);
      expect(find.text('App Lock is off'), findsOneWidget);
    });

    testWidgets('the biometrics switch updates the service setting', (
      tester,
    ) async {
      final service = FakeAppLockService(
        enabled: true,
        initialPin: '123456',
      );

      await pumpSettings(tester, service: service);
      expect(find.text('Unlock with biometrics'), findsOneWidget);
      expect(service.state.biometricsEnabled, isFalse);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-biometrics-switch')),
      );
      await tester.pumpAndSettle();

      expect(service.updateSettingsCalls, 1);
      expect(service.state.biometricsEnabled, isTrue);
    });
  });

  group('storage management', () {
    testWidgets('clear history asks first, then calls the repository', (
      tester,
    ) async {
      final history = FakeHistoryRepository();

      await pumpSettings(
        tester,
        service: FakeAppLockService(),
        history: history,
      );

      await tester.scrollUntilVisible(
        find.text('Clear processing history'),
        200,
      );
      await tester.tap(find.text('Clear processing history'));
      await tester.pumpAndSettle();

      expect(history.clearCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(history.clearCalls, 1);
    });

    testWidgets('delete all data clears history and the vault', (tester) async {
      final history = FakeHistoryRepository();
      final vault = FakeSecureFileVault();
      vault.assets['asset-1'] = Uint8List.fromList([1, 2, 3]);

      await pumpSettings(
        tester,
        service: FakeAppLockService(),
        history: history,
        vault: vault,
      );

      await tester.scrollUntilVisible(find.text('Delete all app data'), 200);
      await tester.tap(find.text('Delete all app data'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(history.clearCalls, 1);
      expect(vault.assets, isEmpty);
    });
  });

  testWidgets('privacy facts are shown', (tester) async {
    await pumpSettings(tester, service: FakeAppLockService());

    await tester.scrollUntilVisible(
      find.text(
        "Exported files leave DocMark's protection. Share them only with "
        'people you trust.',
      ),
      200,
    );

    expect(
      find.text(
        'Every watermark is added on this device. Nothing is uploaded.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Documents, presets and previews stay encrypted at rest in '
        "DocMark's private storage.",
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        "Exported files leave DocMark's protection. Share them only with "
        'people you trust.',
      ),
      findsOneWidget,
    );
  });

  test('settings imports no other feature', () {
    final directory = Directory('lib/src/presentation/features/settings');
    final importLine = RegExp('^import [\'"]([^\'"]+)[\'"]');
    final offenders = <String>[];

    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      for (final line in entity.readAsLinesSync()) {
        final match = importLine.firstMatch(line.trim());
        if (match == null) continue;

        final uri = match.group(1)!;
        final resolved = uri.startsWith('package:')
            ? uri
            : entity.parent.uri.resolve(uri).path;
        if (!resolved.contains('/presentation/features/')) continue;
        if (resolved.contains('/presentation/features/settings/')) continue;

        offenders.add('${entity.path}: $uri');
      }
    }

    expect(offenders, isEmpty);
  });
}
