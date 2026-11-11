/// The App Lock state the router gate reads.
///
/// [disabled] means the user never turned the feature on, or turned it
/// off: the gate goes straight home. [unlocked] means the app is open in
/// this session. [locked] means a PIN or biometric prompt must succeed
/// before any document is reachable.
enum LockStatus { disabled, unlocked, locked }

/// Timing and attempt rules for App Lock.
final class LockPolicy {
  const LockPolicy({
    this.gracePeriod = const Duration(seconds: 30),
    this.maxPinAttempts = 5,
    this.pinLength = 4,
  });

  /// How long the app may sit in the background before it re-locks on
  /// resume. A shorter interval is friendlier; a longer one is safer.
  final Duration gracePeriod;

  /// Failed PIN attempts before biometrics are disabled and the user is
  /// sent back to the lock screen with a cooldown.
  final int maxPinAttempts;

  final int pinLength;
}

/// App Lock: optional PIN + biometric protection for the whole app.
///
/// The router gate watches [LockStatus] and nothing else; screens call
/// these methods and invalidate the gate's status provider. Implementations
/// must keep the PIN verifier in secure storage — never in shared
/// preferences and never in plaintext.
abstract interface class AppLockController {
  /// The persisted policy. Defaults are used until the user changes them.
  LockPolicy get policy;

  /// Reads the current status without prompting.
  Future<LockStatus> status();

  /// Sets a PIN and turns App Lock on. When [pin] is null the controller
  /// keeps its existing PIN (the enable-biometrics-only path).
  Future<void> enable({String? pin});

  /// Turns App Lock off. Requires the current PIN so a passer-by cannot
  /// disable it from an unlocked session.
  Future<void> disable({required String pin});

  /// Verifies [pin]. Returns false on a wrong value and counts the attempt.
  Future<bool> unlockWithPin(String pin);

  /// Shows the platform biometric prompt. Returns false when the device
  /// has no enrolled biometrics or the user cancels.
  Future<bool> unlockWithBiometrics();

  /// Locks immediately — the resume handler calls this after the grace
  /// period.
  Future<void> lock();
}
