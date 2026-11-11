import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'log.dart';

/// Debug provider tracing with no payloads.
///
/// Provider values can be documents, configurations, or asset references;
/// printing them would put user content in the console. Names and types are
/// enough to follow initialization order.
base class RiverpodObserver extends ProviderObserver {
  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    Log.info('Provider ${context.provider.name} initialized');
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    Log.warning('Provider ${context.provider.name} disposed');
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    Log.info('Provider ${context.provider.name} updated');
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    Log.error(
      'Provider ${context.provider.name} failed (${error.runtimeType})',
    );
  }
}
