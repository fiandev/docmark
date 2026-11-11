import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The row of entry dots above the PIN pad.
///
/// The count is the only information a sighted user gets from the dots, so
/// they are excluded from semantics: a screen reader announces the error
/// text instead, and an unlabelled dot row would only add noise.
class PinDots extends StatelessWidget {
  const PinDots({
    required this.length,
    required this.filled,
    this.error = false,
    super.key,
  });

  /// Digits the PIN requires.
  final int length;

  /// Digits entered so far.
  final int filled;

  /// Paints the row in the danger colour after a failed attempt.
  final bool error;

  @override
  Widget build(BuildContext context) {
    final dot = context.dimensions.space.s12;
    final gap = context.dimensions.space.s12;
    final active = error
        ? context.color.status.danger
        : context.color.text.defaultValue;
    final inactive = error
        ? context.color.status.danger
        : context.color.border.defaultValue;

    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < length; index++) ...[
            if (index > 0) SizedBox(width: gap),
            Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < filled
                    ? active
                    : context.color.background.surface,
                border: Border.all(color: inactive),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
