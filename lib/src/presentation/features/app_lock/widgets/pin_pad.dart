import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// The 3×4 numeric keypad: digits 1–9, 0, and backspace.
///
/// Purely presentational — the owner holds the entered digits and decides
/// when to submit. Disabled keys are inert but keep their place, so the grid
/// does not reflow while a verification is in flight or a cooldown runs.
class PinPad extends StatelessWidget {
  const PinPad({
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final columnGap = context.dimensions.space.s8;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 3; row++) ...[
          if (row > 0) Gap(columnGap),
          _PinPadRow(
            enabled: enabled,
            onDigit: onDigit,
            start: row * 3 + 1,
          ),
        ],
        Gap(columnGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PinKey.placeholder(),
            Gap(columnGap),
            _PinKey(
              enabled: enabled,
              onPressed: () => onDigit(_zero),
              child: const _DigitLabel(_zero),
            ),
            Gap(columnGap),
            _PinKey(
              enabled: enabled,
              onPressed: onBackspace,
              child: Icon(
                Icons.backspace_outlined,
                size: context.dimensions.size.iconLarge,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const String _zero = '0';
}

class _PinPadRow extends StatelessWidget {
  const _PinPadRow({
    required this.enabled,
    required this.onDigit,
    required this.start,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;

  /// First digit of the row: 1, 4, or 7.
  final int start;

  @override
  Widget build(BuildContext context) {
    final gap = context.dimensions.space.s8;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var offset = 0; offset < 3; offset++) ...[
          if (offset > 0) Gap(gap),
          _PinKey(
            enabled: enabled,
            onPressed: () => onDigit('${start + offset}'),
            child: _DigitLabel('${start + offset}'),
          ),
        ],
      ],
    );
  }
}

class _DigitLabel extends StatelessWidget {
  const _DigitLabel(this.digit);

  final String digit;

  @override
  Widget build(BuildContext context) {
    return HeadingLevel3Text(digit, textAlign: TextAlign.center);
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.enabled,
    required this.onPressed,
    required this.child,
  });

  const _PinKey.placeholder()
    : enabled = false,
      onPressed = null,
      child = const SizedBox.shrink();

  static const double _disabledOpacity = 0.4;

  final bool enabled;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = context.dimensions.size.control;

    return SizedBox(
      width: size,
      height: size,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : _disabledOpacity,
          child: child,
        ),
      ),
    );
  }
}
