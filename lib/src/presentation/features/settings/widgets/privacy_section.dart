import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import 'settings_card.dart';

/// Privacy: the three facts that matter, in plain language.
class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;

    return SettingsCard(
      children: [
        Padding(
          padding: EdgeInsets.all(context.dimensions.space.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodySmallText.muted(l10n.settings_privacyBody),
              Gap(context.dimensions.space.s12),
              _PrivacyPoint(
                icon: Icons.phone_android,
                text: l10n.settings_privacyLocal,
              ),
              Gap(context.dimensions.space.s8),
              _PrivacyPoint(
                icon: Icons.lock_outline,
                text: l10n.settings_privacyEncrypted,
              ),
              Gap(context.dimensions.space.s8),
              _PrivacyPoint(
                icon: Icons.open_in_new,
                text: l10n.settings_privacyExport,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: context.dimensions.size.iconMedium,
          color: context.color.text.muted,
        ),
        Gap(context.dimensions.space.s8),
        Expanded(child: BodySmallText(text)),
      ],
    );
  }
}
