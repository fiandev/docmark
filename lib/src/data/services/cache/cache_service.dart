/// Key-value persistence for small app state, keyed by [CacheKey] so
/// every stored name lives in one enum instead of scattered strings.
///
/// Values are primitives only ([String], [int], [bool], [double]);
/// implementations throw [ArgumentError] on anything else rather than
/// coercing. Anything richer belongs in a real store, not a preference
/// cache.
enum CacheKey {
  /// Whether the first-run onboarding slides have been completed.
  onboardingCompleted,

  /// The persisted UI language code.
  language,
}

/// The storage contract behind [CacheKey].
abstract class CacheService {
  Future<void> save<T>(CacheKey key, T value);

  T? get<T>(CacheKey key);

  Future<void> remove(List<CacheKey> keys);

  Future<void> clear();
}
