/// Why an App Lock operation did not complete.
///
/// The controller returns `Result<T, AppLockFailure>` and the lock screen
/// switches on these variants to pick localized copy. No user-facing text
/// lives here — the copy belongs to the ARB files.
sealed class AppLockFailure {
  const AppLockFailure();
}

/// App Lock is off, so there is no verifier to check against.
final class AppLockNotEnabled extends AppLockFailure {
  const AppLockNotEnabled();
}

/// No PIN was supplied and none has been set yet.
final class AppLockPinRequired extends AppLockFailure {
  const AppLockPinRequired();
}

/// The PIN does not match the required digit count.
final class AppLockInvalidPinFormat extends AppLockFailure {
  const AppLockInvalidPinFormat({required this.expectedLength});

  final int expectedLength;
}

/// The confirmation entry did not match the first PIN.
final class AppLockPinMismatch extends AppLockFailure {
  const AppLockPinMismatch();
}

/// Wrong PIN. [attemptsRemaining] counts down to the cooldown.
final class AppLockWrongPin extends AppLockFailure {
  const AppLockWrongPin({required this.attemptsRemaining});

  final int attemptsRemaining;
}

/// Too many misses: neither PIN nor biometrics are accepted until
/// [remaining] elapses.
final class AppLockLockedOut extends AppLockFailure {
  const AppLockLockedOut({required this.remaining});

  final Duration remaining;
}

/// The device has no enrolled biometrics, or the prompt was dismissed.
final class AppLockBiometricsUnavailable extends AppLockFailure {
  const AppLockBiometricsUnavailable();
}

/// Secure storage or the key-encryption key could not be reached.
final class AppLockStorageFailure extends AppLockFailure {
  const AppLockStorageFailure({this.cause, this.stackTrace});

  final Object? cause;
  final StackTrace? stackTrace;
}

/// Anything else — a malformed blob or a crypto error.
final class AppLockUnexpectedFailure extends AppLockFailure {
  const AppLockUnexpectedFailure({this.cause, this.stackTrace});

  final Object? cause;
  final StackTrace? stackTrace;
}

/// Bridges [AppLockFailure] into the frozen `Future<void>` controller API,
/// which has no `Result` channel. Feature code that can show an error should
/// call the `Result`-returning methods on `AppLockService` instead.
final class AppLockException implements Exception {
  const AppLockException(this.failure);

  final AppLockFailure failure;

  @override
  String toString() => 'AppLockException(${failure.runtimeType})';
}
