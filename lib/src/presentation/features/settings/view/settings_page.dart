import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/extensions/localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/text/typography.dart';
import '../widgets/app_lock_section.dart';
import '../widgets/privacy_section.dart';
import '../widgets/storage_section.dart';

/// Settings: security, storage, and privacy.
///
/// Every action goes through a core DI provider — the page imports no other
/// feature. Lock changes never navigate: the router gate reacts to the
/// service's own status stream.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;

    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(l10n.settings_title),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            vertical: context.dimensions.space.s8,
          ),
          children: [
            _SectionHeader(l10n.settings_security),
            const AppLockSection(),
            Gap(context.dimensions.space.s24),
            _SectionHeader(l10n.settings_storage),
            const StorageSection(),
            Gap(context.dimensions.space.s24),
            _SectionHeader(l10n.settings_privacy),
            const PrivacySection(),
            Gap(context.dimensions.space.s16),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.dimensions.space.s16,
              ),
              child: BodySmallText.muted(l10n.settings_version),
            ),
            Gap(context.dimensions.space.s24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.dimensions.space.s16,
        context.dimensions.space.s8,
        context.dimensions.space.s16,
        context.dimensions.space.s8,
      ),
      child: HeadingLevel3Text(title),
    );
  }
}
