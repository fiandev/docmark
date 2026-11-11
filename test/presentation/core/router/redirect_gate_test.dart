import 'package:flutter_template/src/presentation/core/router/redirect_gate.dart';
import 'package:flutter_template/src/presentation/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RedirectGate', () {
    group('splash gate (startup pending or failed)', () {
      test('pins every path to splash', () {
        expect(RedirectGate.redirect('/', Routes.splash), '/splash');
        expect(RedirectGate.redirect('/home', Routes.splash), '/splash');
        expect(RedirectGate.redirect('/lock', Routes.splash), '/splash');
        expect(
          RedirectGate.redirect('/editor/doc-1', Routes.splash),
          '/splash',
        );
        expect(RedirectGate.redirect('/unknown', Routes.splash), '/splash');
      });

      test('is idempotent at splash', () {
        expect(RedirectGate.redirect('/splash', Routes.splash), isNull);
      });
    });

    group('onboarding gate', () {
      test('pins every path to onboarding', () {
        expect(
          RedirectGate.redirect('/home', Routes.onboarding),
          '/onboarding',
        );
        expect(
          RedirectGate.redirect('/lock', Routes.onboarding),
          '/onboarding',
        );
      });

      test('is idempotent at onboarding', () {
        expect(RedirectGate.redirect('/onboarding', Routes.onboarding), isNull);
      });
    });

    group('lock gate (App Lock locked)', () {
      test('pins every route to the lock screen', () {
        expect(RedirectGate.redirect('/', Routes.lock), '/lock');
        expect(RedirectGate.redirect('/home', Routes.lock), '/lock');
        expect(RedirectGate.redirect('/presets', Routes.lock), '/lock');
        expect(RedirectGate.redirect('/history', Routes.lock), '/lock');
        expect(RedirectGate.redirect('/settings', Routes.lock), '/lock');
        expect(
          RedirectGate.redirect('/editor/doc-1', Routes.lock),
          '/lock',
        );
        expect(RedirectGate.redirect('/splash', Routes.lock), '/lock');
        expect(RedirectGate.redirect('/onboarding', Routes.lock), '/lock');
      });

      test('is idempotent at lock', () {
        expect(RedirectGate.redirect('/lock', Routes.lock), isNull);
      });
    });

    group('home gate (App Lock disabled or unlocked)', () {
      test('keeps in-app navigation free', () {
        expect(RedirectGate.redirect('/home', Routes.home), isNull);
        expect(RedirectGate.redirect('/document-picker', Routes.home), isNull);
        expect(RedirectGate.redirect('/editor/doc-1', Routes.home), isNull);
        expect(RedirectGate.redirect('/presets', Routes.home), isNull);
        expect(RedirectGate.redirect('/history', Routes.home), isNull);
        expect(RedirectGate.redirect('/export-preview', Routes.home), isNull);
        expect(RedirectGate.redirect('/settings', Routes.home), isNull);
        expect(RedirectGate.redirect('/unknown', Routes.home), isNull);
      });

      test('bounces gate-only routes home', () {
        expect(RedirectGate.redirect('/splash', Routes.home), '/home');
        expect(RedirectGate.redirect('/onboarding', Routes.home), '/home');
        expect(RedirectGate.redirect('/lock', Routes.home), '/home');
        expect(RedirectGate.redirect('/', Routes.home), '/home');
      });
    });
  });
}
