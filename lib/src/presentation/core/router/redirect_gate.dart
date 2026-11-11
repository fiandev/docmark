import 'routes.dart';

/// The router's gating policy. Pure — no `Ref`, no `BuildContext` — so
/// the whole policy is unit-testable in isolation.
///
/// The gate is one fold over app state (`routerStateProvider`): startup →
/// onboarding → App Lock → home. Splash, onboarding, and lock are hard
/// gates (the user is pinned there); every other destination allows the
/// app routes through.
abstract final class RedirectGate {
  /// Enforces the [gate] destination for [path], or returns `null` to
  /// allow it.
  ///
  /// Idempotent — never returns the path already being visited, which is
  /// what prevents redirect loops.
  static String? redirect(String path, Routes gate) {
    return switch (gate) {
      .splash => path == Routes.splash.path ? null : Routes.splash.path,
      .onboarding =>
        path == Routes.onboarding.path ? null : Routes.onboarding.path,
      .lock => _isLockPath(path) ? null : Routes.lock.path,
      _ => _isGateOnlyPath(path) ? Routes.home.path : null,
    };
  }

  /// The lock screen and the route the gate pins to while locked.
  static bool _isLockPath(String path) => path == Routes.lock.path;

  /// Routes that only exist to serve a gate. Once the gate has released
  /// the user, visiting one of these (or the bare `/`) is bounced home.
  static bool _isGateOnlyPath(String path) =>
      path == Routes.splash.path ||
      path == Routes.onboarding.path ||
      path == Routes.lock.path ||
      path == '/';
}
