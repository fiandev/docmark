import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/base/base.dart';
import '../../../../core/di/features/app_lock_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../core/gen/l10n/app_localizations.dart';
import '../../../../core/security/lock/app_lock_failure.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../widgets/app_lock_message.dart';
import '../widgets/pin_dots.dart';
import '../widgets/pin_pad.dart';
import 'app_lock_messages.dart';

/// What the setup screen is being opened for.
enum AppLockSetupMode {
  /// No PIN exists yet: create one and optionally enrol biometrics.
  enable,

  /// Verify the current PIN, then replace it.
  changePin,

  /// Verify the current PIN, then turn App Lock off.
  disable,
}

/// The App Lock setup / change-PIN / disable flow.
///
/// Intentionally unwired for now (dead code): Settings enables the lock
/// through `appLockServiceProvider.enableLock` directly and exposes the
/// biometrics toggle in its own section, so no route mounts this page yet.
/// The security work lives in the controller either way.
class AppLockSetupPage extends ConsumerStatefulWidget {
  const AppLockSetupPage({required this.mode, super.key});

  final AppLockSetupMode mode;

  @override
  ConsumerState<AppLockSetupPage> createState() => _AppLockSetupPageState();
}

enum _Step { current, create, confirm, biometrics }

class _AppLockSetupPageState extends ConsumerState<AppLockSetupPage> {
  String _pin = '';
  String? _currentPin;
  String? _newPin;
  AppLockFailure? _failure;
  bool _busy = false;
  bool _useBiometrics = false;
  int _index = 0;

  List<_Step> get _steps => switch (widget.mode) {
    AppLockSetupMode.enable => const [
      _Step.create,
      _Step.confirm,
      _Step.biometrics,
    ],
    AppLockSetupMode.changePin => const [
      _Step.current,
      _Step.create,
      _Step.confirm,
    ],
    AppLockSetupMode.disable => const [_Step.current],
  };

  _Step get _step => _steps[_index];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appLockStateProvider);
    final l10n = context.locale;
    final failureMessage = appLockFailureMessage(l10n, _failure);

    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(l10n.app_lock_title),
      ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: context.dimensions.size.iconDisplay,
                    color: context.color.text.muted,
                  ),
                  Gap(context.dimensions.space.s16),
                  HeadingLevel3Text(
                    _stepTitle(l10n),
                    textAlign: TextAlign.center,
                  ),
                  Gap(context.dimensions.space.s8),
                  BodySmallText.muted(
                    widget.mode == AppLockSetupMode.enable &&
                            _step == _Step.biometrics
                        ? l10n.app_lock_biometric_reason
                        : l10n.app_lock_setup_body,
                    textAlign: TextAlign.center,
                  ),
                  Gap(context.dimensions.space.s24),
                  if (_step == _Step.biometrics)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BiometricsChoice(
                          value: _useBiometrics,
                          onChanged: (value) =>
                              setState(() => _useBiometrics = value),
                          label: l10n.app_lock_use_biometrics,
                          description: l10n.app_lock_biometric_reason,
                        ),
                        if (failureMessage != null) ...[
                          Gap(context.dimensions.space.s12),
                          AppLockMessage(message: failureMessage),
                        ],
                      ],
                    )
                  else ...[
                    PinDots(
                      length: state.policy.pinLength,
                      filled: _pin.length,
                      error: _failure != null,
                    ),
                    if (failureMessage != null) ...[
                      Gap(context.dimensions.space.s12),
                      AppLockMessage(message: failureMessage),
                    ],
                    Gap(context.dimensions.space.s24),
                    PinPad(
                      enabled: !_busy,
                      onDigit: _handleDigit,
                      onBackspace: _handleBackspace,
                    ),
                  ],
                  if (_step == _Step.biometrics) ...[
                    Gap(context.dimensions.space.s24),
                    FilledButton(
                      onPressed: _busy ? null : _finishEnable,
                      child: Text(l10n.app_lock_enable),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stepTitle(AppLocalizations l10n) {
    return switch (_step) {
      _Step.current =>
        widget.mode == AppLockSetupMode.disable
            ? l10n.app_lock_disable
            : l10n.app_lock_change_pin,
      _Step.create => l10n.app_lock_pin_set,
      _Step.confirm => l10n.app_lock_pin_confirm,
      _Step.biometrics => l10n.app_lock_use_biometrics,
    };
  }

  void _handleDigit(String digit) {
    if (_busy) return;

    final length = ref.read(appLockStateProvider).policy.pinLength;
    if (_pin.length >= length) return;

    setState(() {
      _pin += digit;
      _failure = null;
    });

    if (_pin.length == length) unawaited(_completeStep(_pin));
  }

  void _handleBackspace() {
    if (_busy || _pin.isEmpty) return;

    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _failure = null;
    });
  }

  Future<void> _completeStep(String pin) async {
    switch (_step) {
      case _Step.current:
        if (widget.mode == AppLockSetupMode.disable) {
          await _disable(pin);
          return;
        }

        setState(() {
          _currentPin = pin;
          _pin = '';
          _index += 1;
        });
      case _Step.create:
        setState(() {
          _newPin = pin;
          _pin = '';
          _index += 1;
        });
      case _Step.confirm:
        if (pin != _newPin) {
          setState(() {
            _pin = '';
            _newPin = null;
            _failure = const AppLockPinMismatch();
            _index = _steps.indexOf(_Step.create);
          });
          return;
        }

        if (widget.mode == AppLockSetupMode.changePin) {
          await _changePin(pin);
          return;
        }

        setState(() {
          _pin = '';
          _index += 1;
        });
      case _Step.biometrics:
        return;
    }
  }

  Future<void> _disable(String pin) async {
    setState(() => _busy = true);
    final result = await ref.read(appLockServiceProvider).disableLock(pin);
    if (!mounted) return;

    switch (result) {
      case Success():
        _close();
      case Error(:final error):
        setState(() {
          _busy = false;
          _pin = '';
          _failure = error;
        });
    }
  }

  Future<void> _changePin(String newPin) async {
    setState(() => _busy = true);
    final result = await ref.read(appLockServiceProvider).changePin(
      currentPin: _currentPin ?? '',
      newPin: newPin,
    );
    if (!mounted) return;

    switch (result) {
      case Success():
        _close();
      case Error(:final error):
        setState(() {
          _busy = false;
          _pin = '';
          _failure = error;

          // A rejected current PIN restarts the flow at its first step; any
          // other failure leaves the user on the confirmation step.
          if (error is AppLockWrongPin || error is AppLockLockedOut) {
            _currentPin = null;
            _newPin = null;
            _index = 0;
          }
        });
    }
  }

  Future<void> _finishEnable() async {
    setState(() => _busy = true);
    final result = await ref.read(appLockServiceProvider).enableLock(
      pin: _newPin,
      biometricsEnabled: _useBiometrics,
    );
    if (!mounted) return;

    switch (result) {
      case Success():
        _close();
      case Error(:final error):
        setState(() {
          _busy = false;
          _failure = error;

          // A missing enrolment is fixable on this step (turn the switch
          // off and finish); anything else means the PIN was not stored.
          if (error is! AppLockBiometricsUnavailable) {
            _index = _steps.indexOf(_Step.create);
            _pin = '';
            _newPin = null;
          } else {
            _useBiometrics = false;
          }
        });
    }
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}

class _BiometricsChoice extends StatelessWidget {
  const _BiometricsChoice({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.description,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: LabelText(label),
      subtitle: BodySmallText.muted(description),
    );
  }
}
