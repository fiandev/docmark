part of '../dependency_injection.dart';

@Riverpod(keepAlive: true)
LocaleRepository localeRepository(Ref ref) {
  return LocaleRepositoryImpl(ref.watch(cacheServiceProvider));
}
