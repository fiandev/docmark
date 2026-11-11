import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docmark/src/core/di/features/app_lock_providers.dart';
import 'package:docmark/src/core/gen/l10n/app_localizations.dart';
import 'package:docmark/src/core/security/lock/app_lock_service.dart';
import 'package:docmark/src/core/security/lock/lock_controller_impl.dart';
import 'package:docmark/src/core/security/lock_controller.dart';
import 'package:docmark/src/presentation/core/theme/theme.dart';
import 'package:docmark/src/presentation/features/app_lock/view/lock_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/security/lock/support/app_lock_fakes.dart';

void main() {
  Widget app(AppLockService service) {
    return ProviderScope(
      overrides: [
        appLockServiceProvider.overrideWith((ref) => service),
        appLockStateProvider.overrideWith(
          (ref) => ref.watch(appLockServiceProvider).state,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: context.lightTheme,
            child: const LockPage(),
          ),
        ),
      ),
    );
  }

  Future<LockControllerImpl> lockedController() async {
    final controller = buildController();
    await controller.enableLock(pin: '123456');
    await controller.lock();

    return controller;
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('entering the correct PIN unlocks the app', (tester) async {
    final controller = await lockedController();

    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();

    await enterPin(tester, '123456');

    expect(controller.state.status, LockStatus.unlocked);
  });

  testWidgets('a wrong PIN shows the localized error', (tester) async {
    final controller = await lockedController();

    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();

    await enterPin(tester, '000000');

    expect(find.text('Wrong PIN. Try again.'), findsOneWidget);
    expect(controller.state.status, LockStatus.locked);
  });

  testWidgets('the lock screen cannot be popped', (tester) async {
    final controller = await lockedController();

    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(LockPage));

    expect(find.byType(PopScope), findsOneWidget);
    expect(
      ModalRoute.of(context)?.popDisposition,
      RoutePopDisposition.doNotPop,
    );
  });
}
