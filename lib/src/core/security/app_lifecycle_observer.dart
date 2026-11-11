import 'dart:async';

import 'package:flutter/widgets.dart';

import 'lock/app_lock_service.dart';

/// Registers the App Lock lifecycle hooks. `bootstrap()` calls [register]
/// once, before the first frame.
abstract interface class AppLifecycleObserver {
  void register();
}

/// A placeholder that hooks nothing and cannot fail.
final class NoopAppLifecycleObserver implements AppLifecycleObserver {
  const NoopAppLifecycleObserver();

  @override
  void register() {}
}

/// Feeds foreground/background transitions to App Lock and starts the one
/// state read at process start.
///
/// Registered from `bootstrap()`, so it is the earliest point where the
/// persisted blob is read — before the router can resolve its first gate.
final class LockLifecycleObserver extends WidgetsBindingObserver
    implements AppLifecycleObserver {
  LockLifecycleObserver({required AppLockService service}) : _service = service;

  final AppLockService _service;

  bool _registered = false;

  @override
  void register() {
    if (_registered) return;
    _registered = true;

    WidgetsBinding.instance.addObserver(this);
    unawaited(_service.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case .resumed:
        unawaited(_service.onForeground());
      case .hidden:
      case .paused:
        _service.onBackground();
      // `inactive` fires for transient overlays and for the biometric
      // prompt itself; locking on it would fight the prompt.
      case .inactive:
      case .detached:
        break;
    }
  }
}
