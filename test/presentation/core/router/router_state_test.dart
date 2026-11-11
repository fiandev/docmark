import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docmark/src/core/di/features/app_lock_providers.dart';
import 'package:docmark/src/core/security/lock_controller.dart';
import 'package:docmark/src/presentation/core/application_state/onboarding_status_provider/onboarding_status_provider.dart';
import 'package:docmark/src/presentation/core/application_state/startup_provider/startup_provider.dart';
import 'package:docmark/src/presentation/core/router/router_state/router_state_provider.dart';
import 'package:docmark/src/presentation/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerWith({
    required Future<void> Function(Ref ref) startup,
    bool onboarded = true,
    LockStatus lock = LockStatus.disabled,
  }) {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        startupProvider.overrideWith(startup),
        onboardingStatusProvider.overrideWith((ref) => onboarded),
        appLockStatusProvider.overrideWith((ref) => lock),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  Future<void> startupDone(Ref ref) async {}

  group('routerState', () {
    test('splash while startup is loading', () {
      final container = containerWith(
        startup: (ref) => Completer<void>().future,
      );

      expect(container.read(routerStateProvider), Routes.splash);
    });

    test('splash when startup failed', () async {
      final container = containerWith(
        startup: (ref) async => throw Exception('startup failed'),
      );
      await expectLater(
        container.read(startupProvider.future),
        throwsException,
      );

      expect(container.read(routerStateProvider), Routes.splash);
    });

    test('onboarding before it is completed', () async {
      final container = containerWith(startup: startupDone, onboarded: false);
      await container.read(startupProvider.future);

      expect(container.read(routerStateProvider), Routes.onboarding);
    });

    test('home when App Lock is disabled', () async {
      final container = containerWith(startup: startupDone);
      await container.read(startupProvider.future);

      expect(container.read(routerStateProvider), Routes.home);
    });

    test('home when App Lock is unlocked', () async {
      final container = containerWith(
        startup: startupDone,
        lock: LockStatus.unlocked,
      );
      await container.read(startupProvider.future);

      expect(container.read(routerStateProvider), Routes.home);
    });

    test('lock when App Lock is locked', () async {
      final container = containerWith(
        startup: startupDone,
        lock: LockStatus.locked,
      );
      await container.read(startupProvider.future);

      expect(container.read(routerStateProvider), Routes.lock);
    });

    test('lock wins over onboarding completion', () async {
      final container = containerWith(
        startup: startupDone,
        onboarded: true,
        lock: LockStatus.locked,
      );
      await container.read(startupProvider.future);

      expect(container.read(routerStateProvider), Routes.lock);
    });
  });
}
