import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/base/base.dart';
import '../../../../core/di/features/app_lock_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../core/gen/l10n/app_localizations.dart';
import '../../../../core/security/lock/app_lock_failure.dart';
import '../../../../core/security/lock/app_lock_service.dart';
import '../../../../core/security/lock/lock_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import 'pin_entry_dialog.dart';
import 'settings_card.dart';

/// Security: App Lock enable/disable, PIN change, and the lock delay.
///
/// The state comes from `appLockStateProvider`; every write goes through
/// `appLockServiceProvider`, so the router gate sees the transition through
/// the service's own change stream. Settings never navigates on a lock
/// change — the gate owns that decision.
class AppLockSection extends ConsumerWidget {
  const AppLockSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.locale;
    final state = ref.watch(appLockStateProvider);

    return SettingsCard(
      children: [
        SwitchListTile(
          key: const ValueKey<String>('settings-app-lock-switch'),
          value: state.isEnabled,
          onChanged: (enabled) =>
              unawaited(_toggle(context, ref, enabled: enabled)),
          secondary: Icon(
            Icons.lock_outline,
            color: context.color.text.muted,
          ),
          title: LabelText(l10n.settings_appLock),
          subtitle: BodySmallText.muted(
            state.isEnabled
                ? l10n.settings_appLockOn
                : l10n.settings_appLockOff,
          ),
        ),
        if (state.isEnabled) ...[
          SwitchListTile(
            key: const ValueKey<String>('settings-biometrics-switch'),
            value: state.biometricsEnabled,
            onChanged: (enabled) =>
                unawaited(_toggleBiometrics(context, ref, enabled: enabled)),
            secondary: Icon(
              Icons.fingerprint,
              color: context.color.text.muted,
            ),
            title: LabelText(l10n.settings_biometrics),
            subtitle: BodySmallText.muted(l10n.settings_biometricsBody),
          ),
          ListTile(
            leading: Icon(
              Icons.password_outlined,
              color: context.color.text.muted,
            ),
            title: LabelText(l10n.settings_changePin),
            trailing: Icon(
              Icons.chevron_right,
              color: context.color.text.muted,
            ),
            onTap: () => unawaited(_changePin(context, ref)),
          ),
          _GracePeriodTile(policy: state.policy),
          ListTile(
            key: const ValueKey<String>('settings-reset-lock'),
            leading: Icon(
              Icons.restart_alt,
              color: context.color.status.danger,
            ),
            title: LabelText(l10n.settings_resetLock),
            subtitle: BodySmallText.muted(l10n.settings_resetLockBody),
            onTap: () => unawaited(_resetLock(context, ref)),
          ),
        ],
      ],
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final l10n = context.locale;
    final service = ref.read(appLockServiceProvider);
    final state = ref.read(appLockStateProvider);

    if (enabled) {
      final pin = await PinEntryDialog.show(
        context,
        title: l10n.settings_enableLockTitle,
        body: l10n.settings_enableLockBody(state.policy.pinLength),
        pinLength: state.policy.pinLength,
        confirm: true,
      );
      if (pin == null || !context.mounted) return;

      final result = await service.enableLock(pin: pin);
      if (!context.mounted) return;
      _report(context, l10n, result, l10n.settings_appLockEnabled);
      return;
    }

    final pin = await PinEntryDialog.show(
      context,
      title: l10n.settings_disableLockTitle,
      body: l10n.settings_disableLockBody,
      pinLength: state.policy.pinLength,
    );
    if (pin == null || !context.mounted) return;

    final result = await service.disableLock(pin);
    if (!context.mounted) return;
    _report(context, l10n, result, l10n.settings_appLockDisabled);
  }

  Future<void> _toggleBiometrics(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final l10n = context.locale;
    final result = await ref
        .read(appLockServiceProvider)
        .updateSettings(biometricsEnabled: enabled);
    if (!context.mounted) return;
    _report(
      context,
      l10n,
      result,
      enabled
          ? l10n.settings_biometricsEnabled
          : l10n.settings_biometricsOff,
    );
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final l10n = context.locale;
    final service = ref.read(appLockServiceProvider);
    final pinLength = ref.read(appLockStateProvider).policy.pinLength;

    final currentPin = await PinEntryDialog.show(
      context,
      title: l10n.settings_verifyPinTitle,
      body: l10n.settings_verifyPinBody,
      pinLength: pinLength,
    );
    if (currentPin == null || !context.mounted) return;

    final newPin = await PinEntryDialog.show(
      context,
      title: l10n.settings_changePinTitle,
      body: l10n.settings_changePinBody,
      pinLength: pinLength,
      confirm: true,
    );
    if (newPin == null || !context.mounted) return;

    final result = await service.changePin(
      currentPin: currentPin,
      newPin: newPin,
    );
    if (!context.mounted) return;
    _report(context, l10n, result, l10n.settings_pinChanged);
  }

  /// Recovery path for a user who can no longer unlock: the confirmation is
  /// mandatory, and the service is told it may delete the lock blob.
  Future<void> _resetLock(BuildContext context, WidgetRef ref) async {
    final l10n = context.locale;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_resetLock),
        content: BodySmallText(l10n.settings_resetLockConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_resetLockAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(appLockServiceProvider)
        .resetLockData(confirmed: true);
    if (!context.mounted) return;

    switch (result) {
      case Success():
        _showSnack(context, l10n.settings_resetLockDone);
      case Error():
        _showSnack(context, l10n.settings_resetLockFailed);
    }
  }
}

/// The "lock after leaving the app" choices. Zero means immediately.
class _GracePeriodTile extends ConsumerWidget {
  const _GracePeriodTile({required this.policy});

  final LockPolicy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.locale;

    return ListTile(
      leading: Icon(
        Icons.timer_outlined,
        color: context.color.text.muted,
      ),
      title: LabelText(l10n.settings_lockAfter),
      trailing: DropdownButton<Duration>(
        value: AppLockDefaults.graceOptions.contains(policy.gracePeriod)
            ? policy.gracePeriod
            : AppLockDefaults.gracePeriod,
        underline: const SizedBox.shrink(),
        onChanged: (value) {
          if (value != null) unawaited(_setGrace(context, ref, value));
        },
        items: [
          for (final option in AppLockDefaults.graceOptions)
            DropdownMenuItem<Duration>(
              value: option,
              child: Text(_graceLabel(l10n, option)),
            ),
        ],
      ),
    );
  }

  Future<void> _setGrace(
    BuildContext context,
    WidgetRef ref,
    Duration grace,
  ) async {
    final l10n = context.locale;
    final result = await ref.read(appLockServiceProvider).updateSettings(
      policy: LockPolicy(
        gracePeriod: grace,
        maxPinAttempts: policy.maxPinAttempts,
        pinLength: policy.pinLength,
      ),
    );
    if (!context.mounted) return;

    switch (result) {
      case Success():
        break;
      case Error(:final error):
        _showSnack(context, _failureMessage(l10n, error));
    }
  }
}

void _report(
  BuildContext context,
  AppLocalizations l10n,
  Result<Unit, AppLockFailure> result,
  String success,
) {
  switch (result) {
    case Success():
      _showSnack(context, success);
    case Error(:final error):
      _showSnack(context, _failureMessage(l10n, error));
  }
}

String _failureMessage(AppLocalizations l10n, AppLockFailure failure) {
  return switch (failure) {
    AppLockWrongPin() => l10n.settings_pinInvalid,
    AppLockLockedOut(:final remaining) => l10n.settings_tooManyAttempts(
      remaining.inSeconds < 1 ? 1 : remaining.inSeconds,
    ),
    AppLockInvalidPinFormat(:final expectedLength) =>
      l10n.settings_pinLengthError(expectedLength),
    AppLockPinMismatch() => l10n.settings_pinMismatch,
    AppLockPinRequired() => l10n.settings_pinRequired,
    AppLockNotEnabled() => l10n.settings_appLockOff,
    _ => l10n.settings_failure,
  };
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _graceLabel(AppLocalizations l10n, Duration grace) {
  return switch (grace.inSeconds) {
    0 => l10n.settings_graceImmediately,
    60 => l10n.settings_graceMinute,
    300 => l10n.settings_graceMinutes(grace.inMinutes),
    final seconds => l10n.settings_graceSeconds(seconds),
  };
}
