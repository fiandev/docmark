import 'package:flutter/material.dart';

/// The biometric unlock affordance on the lock and setup screens.
///
/// Kept separate from the PIN pad so the page can hide it entirely when the
/// user did not opt in; a disabled biometric button is worse than none.
class BiometricButton extends StatelessWidget {
  const BiometricButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.fingerprint),
      label: Text(label),
    );
  }
}
