/// Preference keys that more than one layer reads.
///
/// The presentation layer may read onboarding state before the domain has a
/// use case for it, and it must not import the data layer to do so — hence a
/// core constant shared by both sides. Once T1/T2 move onboarding behind a
/// repository, this can collapse into `CacheKey`.
abstract final class StorageKeys {
  /// Whether the first-run onboarding slides have been completed.
  static const String onboardingCompleted = 'onboarding_completed';
}
