import '../../../../core/gen/l10n/app_localizations.dart';
import '../../../../core/security/lock/app_lock_failure.dart';

/// The localized copy for a failed App Lock operation.
///
/// Presentation-only: the controller never carries user-facing text, and
/// every variant maps to a string that already exists in the ARB files.
String? appLockFailureMessage(
  AppLocalizations l10n,
  AppLockFailure? failure,
) {
  if (failure == null) return null;

  return switch (failure) {
    AppLockWrongPin() => l10n.app_lock_pin_invalid,
    AppLockLockedOut() => l10n.app_lock_too_many_attempts,
    AppLockBiometricsUnavailable() => l10n.app_lock_biometric_unavailable,
    AppLockPinRequired() => l10n.app_lock_pin_required,
    AppLockInvalidPinFormat() => l10n.app_lock_pin_invalid,
    AppLockPinMismatch() => l10n.app_lock_pin_mismatch,
    AppLockNotEnabled() => l10n.app_lock_disabled_body,
    AppLockStorageFailure() ||
    AppLockUnexpectedFailure() ||
    AppLockResetNotConfirmed() => l10n.failures_unknown,
  };
}
