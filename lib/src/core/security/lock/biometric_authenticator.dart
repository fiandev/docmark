import 'package:local_auth/local_auth.dart';

/// The biometric prompt, behind an interface so no test or headless path
/// needs a platform channel.
abstract interface class BiometricAuthenticator {
  /// True only when the device has an enrolled biometric and can prompt.
  Future<bool> isAvailable();

  /// Shows the platform prompt. Returns false on cancel, no enrollment, or
  /// any plugin error — the caller always keeps PIN as the fallback.
  Future<bool> authenticate({required String reason});
}

/// `local_auth`-backed prompt for the app build.
final class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator({
    LocalAuthentication? authentication,
    bool biometricOnly = true,
  }) : _authentication = authentication ?? LocalAuthentication(),
       _biometricOnly = biometricOnly;

  final LocalAuthentication _authentication;

  /// App Lock policy is biometrics-only: the device passcode is a second
  /// secret the user did not configure for this app.
  final bool _biometricOnly;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _authentication.isDeviceSupported()) return false;

      final available = await _authentication.getAvailableBiometrics();

      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: _biometricOnly,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // A cancelled prompt throws on some platforms; the caller only needs
      // "did not unlock", and PIN is always still available.
      return false;
    }
  }
}
