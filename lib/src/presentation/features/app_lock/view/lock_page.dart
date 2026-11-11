import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/base/base.dart';
import '../../../../core/di/features/app_lock_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../core/security/lock/app_lock_failure.dart';
import '../../../../core/security/lock/app_lock_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../widgets/app_lock_message.dart';
import '../widgets/biometric_button.dart';
import '../widgets/pin_dots.dart';
import '../widgets/pin_pad.dart';
import 'app_lock_messages.dart';

/// The App Lock screen the router pins to while locked.
///
/// Not pop-able: the gate owns the exit. A correct PIN or biometric check
/// moves the controller to `unlocked`, the router gate re-evaluates, and
/// this page is replaced by the document shell.
class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  String _pin = '';
  AppLockFailure? _failure;
  bool _busy = false;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncCountdown(ref.read(appLockStateProvider));
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  /// Runs a one-second ticker only while a cooldown is active, so the copy
  /// counts down and the pad re-enables the moment it expires.
  void _syncCountdown(AppLockState state) {
    if (state.backoffRemaining() <= Duration.zero) {
      _countdown?.cancel();
      _countdown = null;
      return;
    }

    _countdown ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final next = ref.read(appLockStateProvider);
      setState(() {});

      if (next.backoffRemaining() <= Duration.zero) {
        _countdown?.cancel();
        _countdown = null;
      }
    });
  }

  void _handleDigit(String digit) {
    if (_busy) return;

    final state = ref.read(appLockStateProvider);
    if (state.backoffRemaining() > Duration.zero) return;
    if (_pin.length >= state.policy.pinLength) return;

    setState(() {
      _pin += digit;
      _failure = null;
    });

    if (_pin.length == state.policy.pinLength) unawaited(_submit(_pin));
  }

  void _handleBackspace() {
    if (_busy || _pin.isEmpty) return;

    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _failure = null;
    });
  }

  Future<void> _submit(String pin) async {
    setState(() => _busy = true);
    final result = await ref.read(appLockServiceProvider).verifyPin(pin);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _pin = '';
      _failure = switch (result) {
        Success() => null,
        Error(:final error) => error,
      };
    });
  }

  Future<void> _unlockWithBiometrics(String reason) async {
    setState(() => _busy = true);
    final result = await ref
        .read(appLockServiceProvider)
        .verifyBiometrics(reason: reason);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _failure = switch (result) {
        Success() => null,
        Error(:final error) => error,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appLockStateProvider);
    final l10n = context.locale;
    final waiting = state.backoffRemaining();
    final backingOff = waiting > Duration.zero;

    ref.listen(appLockStateProvider, (_, next) => _syncCountdown(next));

    // A cooldown failure stays in state after it expires; hide it then so
    // the pad is usable without a stale "try again in 0 seconds" line.
    final failure =
        !backingOff && _failure is AppLockLockedOut ? null : _failure;
    final message = backingOff
        ? l10n.app_lock_retry_in(waiting.inSeconds + 1)
        : appLockFailureMessage(l10n, failure);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: context.dimensions.space.s24,
                vertical: context.dimensions.space.s24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.dimensions.docMark.lockCardMaxWidth,
                ),
                child: Card(
                  color: context.color.docMark.lockCardBackground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      context.dimensions.docMark.lockCardRadius,
                    ),
                    side: BorderSide(
                      color: context.color.docMark.lockCardBorder,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(
                      context.dimensions.docMark.lockCardPadding,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: context.dimensions.size.iconDisplay,
                          color: context.color.text.muted,
                        ),
                        Gap(context.dimensions.space.s16),
                        HeadingLevel3Text(
                          l10n.app_lock_locked_title,
                          textAlign: TextAlign.center,
                        ),
                        Gap(context.dimensions.space.s8),
                        BodySmallText.muted(
                          l10n.app_lock_locked_body,
                          textAlign: TextAlign.center,
                        ),
                        Gap(context.dimensions.space.s24),
                        PinDots(
                          length: state.policy.pinLength,
                          filled: _pin.length,
                          error: failure != null || backingOff,
                        ),
                        if (message != null) ...[
                          Gap(context.dimensions.space.s12),
                          AppLockMessage(
                            message: message,
                            tone: backingOff
                                ? AppLockMessageTone.warning
                                : AppLockMessageTone.danger,
                          ),
                        ],
                        Gap(context.dimensions.space.s24),
                        PinPad(
                          enabled: !_busy && !backingOff,
                          onDigit: _handleDigit,
                          onBackspace: _handleBackspace,
                        ),
                        if (state.biometricsEnabled) ...[
                          Gap(context.dimensions.space.s16),
                          BiometricButton(
                            label: l10n.app_lock_use_biometrics,
                            enabled: !_busy && !backingOff,
                            onPressed: () => unawaited(
                              _unlockWithBiometrics(
                                l10n.app_lock_biometric_reason,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
