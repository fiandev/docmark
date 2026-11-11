import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// How loud an inline App Lock message is.
enum AppLockMessageTone { danger, warning }

/// One line of feedback under the PIN dots.
///
/// The icon carries the colour — typography stays in the type scale, so no
/// screen composes a text style of its own.
class AppLockMessage extends StatelessWidget {
  const AppLockMessage({
    required this.message,
    this.tone = AppLockMessageTone.danger,
    super.key,
  });

  final String message;
  final AppLockMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      .danger => context.color.status.danger,
      .warning => context.color.status.warning,
    };
    final icon = switch (tone) {
      .danger => Icons.error_outline,
      .warning => Icons.schedule,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: context.dimensions.size.iconMedium,
          color: color,
        ),
        Gap(context.dimensions.space.s8),
        Flexible(child: BodySmallText(message)),
      ],
    );
  }
}
