import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// A compact, local PIN entry for the Settings App Lock controls.
///
/// Settings must not import the App Lock feature, so this dialog repeats the
/// small amount of entry UI it needs. The digit count comes from the App
/// Lock policy, keeping the six-digit rule in one place.
class PinEntryDialog extends StatefulWidget {
  const PinEntryDialog({
    required this.title,
    required this.body,
    required this.pinLength,
    this.confirm = false,
    super.key,
  });

  final String title;
  final String body;
  final int pinLength;

  /// When true, a second field must repeat the PIN.
  final bool confirm;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String body,
    required int pinLength,
    bool confirm = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => PinEntryDialog(
        title: title,
        body: body,
        pinLength: pinLength,
        confirm: confirm,
      ),
    );
  }

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _repeat = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _repeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final error = _error;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodySmallText.muted(widget.body),
            Gap(context.dimensions.space.s16),
            _PinField(
              controller: _pin,
              label: l10n.settings_pinLabel,
              hint: l10n.settings_pinDigits(widget.pinLength),
              length: widget.pinLength,
              onSubmitted: widget.confirm ? null : _submit,
            ),
            if (widget.confirm) ...[
              Gap(context.dimensions.space.s12),
              _PinField(
                controller: _repeat,
                label: l10n.settings_pinLabel,
                hint: l10n.settings_pinDigits(widget.pinLength),
                length: widget.pinLength,
                onSubmitted: _submit,
              ),
            ],
            if (error != null) ...[
              Gap(context.dimensions.space.s12),
              BodySmallText(error),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: LabelText(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: LabelText(
            widget.confirm ? l10n.common_save : l10n.common_confirm,
          ),
        ),
      ],
    );
  }

  void _submit() {
    final l10n = context.locale;
    final pin = _pin.text;

    if (pin.length != widget.pinLength) {
      setState(() => _error = l10n.settings_pinLengthError(widget.pinLength));
      return;
    }

    if (widget.confirm && _repeat.text != pin) {
      setState(() => _error = l10n.settings_pinMismatch);
      return;
    }

    Navigator.of(context).pop(pin);
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.length,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int length;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: length,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        counterText: '',
      ),
    );
  }
}
