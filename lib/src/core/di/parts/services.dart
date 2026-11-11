part of '../dependency_injection.dart';

@Riverpod(keepAlive: true)
CacheService cacheService(Ref ref) {
  return SharedPreferencesService(
    ref.watch(sharedPreferencesProvider).requireValue,
  );
}
