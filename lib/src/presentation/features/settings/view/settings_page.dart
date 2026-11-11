import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';

/// Settings: security, storage, privacy.
///
/// OWNER: T10 (App Lock settings) and T6 (storage/history). The page is a
/// stub until the settings stores land; it renders no destructive action
/// without the real confirmation flow.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(context.locale.settings_title),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            vertical: context.dimensions.space.s8,
          ),
          children: [
            _SettingsTile(
              icon: Icons.lock_outline,
              title: context.locale.settings_appLock,
              subtitle: context.locale.settings_appLockBody,
            ),
            _SettingsTile(
              icon: Icons.storage_outlined,
              title: context.locale.settings_storage,
              subtitle: context.locale.settings_storageBody,
            ),
            _SettingsTile(
              icon: Icons.delete_outline,
              title: context.locale.settings_clearHistory,
              subtitle: context.locale.settings_clearHistoryBody,
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: context.locale.settings_privacy,
              subtitle: context.locale.settings_privacyBody,
            ),
            Gap(context.dimensions.space.s16),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.dimensions.space.s16,
              ),
              child: BodySmallText.muted(context.locale.settings_version),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.color.text.muted),
      title: LabelText(title),
      subtitle: BodySmallText.muted(subtitle),
    );
  }
}
